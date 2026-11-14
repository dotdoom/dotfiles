{
  config,
  lib,
  pkgs,
  primaryUser,
  ...
}:
let
  cfg = config.programs.remote-agy;
  user = "${primaryUser}-agent";
  userHome = config.users.users.${user}.home;
  instanceName = config.networking.hostName;
  giteaUrl = "https://git.sheremet.ch";
  giteaSshHost = "git.home.arpa";
  email = "${user}@sheremet.ch";
  tokenFile = "${userHome}/.config/gitea-token";

  antigravity = pkgs.symlinkJoin {
    name = "antigravity";
    paths = [ pkgs.antigravity-cli ];
    postBuild = ''
      ln -s $out/bin/agy $out/bin/antigravity
    '';
  };

  setupScript = pkgs.writeShellScriptBin "remote-agy-setup" ''
    set -euo pipefail

    # 1. Generate SSH key for repository transport (clone/push) if missing
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    SSH_KEY_FILE="$HOME/.ssh/id_ed25519"
    SSH_PUB_FILE="$SSH_KEY_FILE.pub"

    if [ ! -f "$SSH_KEY_FILE" ]; then
      echo "remote-agy-setup: Generating SSH transport key for ${user}..."
      ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -C "${user}@${instanceName}" -f "$SSH_KEY_FILE" -N ""
    fi

    # 2. Generate GPG key for commit signing if missing
    mkdir -p "$HOME/.gnupg"
    chmod 700 "$HOME/.gnupg"
    GPG_KEY_ID="$(( ${pkgs.gnupg}/bin/gpg --list-secret-keys --with-colons "${email}" 2>/dev/null || true) | awk -F: '/^sec:/ {print $5}' | head -n1)"

    if [ -z "$GPG_KEY_ID" ]; then
      echo "remote-agy-setup: Generating GPG signing key for ${email}..."
      printf '%s\n' \
        "%no-protection" \
        "Key-Type: eddsa" \
        "Key-Curve: ed25519" \
        "Key-Usage: sign" \
        "Subkey-Type: ecdh" \
        "Subkey-Curve: cv25519" \
        "Subkey-Usage: encrypt" \
        "Name-Real: ${user}" \
        "Name-Email: ${email}" \
        "Expire-Date: 0" | ${pkgs.gnupg}/bin/gpg --batch --generate-key
      GPG_KEY_ID="$(( ${pkgs.gnupg}/bin/gpg --list-secret-keys --with-colons "${email}" 2>/dev/null || true) | awk -F: '/^sec:/ {print $5}' | head -n1)"
    fi

    # 3. Configure Git for commit signing and identity
    ${pkgs.git}/bin/git config --global user.name "${user}"
    ${pkgs.git}/bin/git config --global user.email "${email}"
    ${pkgs.git}/bin/git config --global gpg.format openpgp
    ${pkgs.git}/bin/git config --global gpg.program "${pkgs.gnupg}/bin/gpg"
    ${pkgs.git}/bin/git config --global user.signingkey "$GPG_KEY_ID"
    ${pkgs.git}/bin/git config --global commit.gpgsign true

    # 4. Gitea automation
    TOKEN_FILE="${tokenFile}"
    if [ -f "$TOKEN_FILE" ]; then
      TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"
      if [ -n "$TOKEN" ]; then
        echo "remote-agy-setup: Configuring tea with Gitea token..."
        CURRENT_TEA_TOKEN="$(grep -A5 'name: local' "$HOME/.config/tea/config.yml" 2>/dev/null | awk '/token:/ {print $2}' || true)"
        if [ "$CURRENT_TEA_TOKEN" != "$TOKEN" ]; then
          ${pkgs.tea}/bin/tea login delete local >/dev/null 2>&1 || true
          ${pkgs.tea}/bin/tea login add --name local --url "${giteaUrl}" --token "$TOKEN" >/dev/null 2>&1 || true
          ${pkgs.tea}/bin/tea login default local >/dev/null 2>&1 || true
        fi

        # Ensure GITEA_SERVER_URL is available for interactive shells
        if [ ! -f "$HOME/.profile" ] || ! grep -q 'GITEA_SERVER_URL' "$HOME/.profile" 2>/dev/null; then
          echo 'export GITEA_SERVER_URL="${giteaUrl}"' >> "$HOME/.profile"
        fi

        # Register SSH key for transport if not already present
        SSH_KEY_TITLE="${user}@${instanceName}"
        OUR_SSH_FP="$(${pkgs.openssh}/bin/ssh-keygen -lf "$SSH_PUB_FILE" | awk '{print $2}')"
        OUR_SSH_BODY="$(awk '{print $1 " " $2}' "$SSH_PUB_FILE")"

        EXISTING_SSH="$(${pkgs.curl}/bin/curl -sf -H "Authorization: token $TOKEN" "${giteaUrl}/api/v1/user/keys" 2>/dev/null || echo "[]")"
        if echo "$EXISTING_SSH" | ${pkgs.jq}/bin/jq -e 'type == "array"' >/dev/null 2>&1; then
          MATCHING_SSH="$(echo "$EXISTING_SSH" | ${pkgs.jq}/bin/jq --arg fp "$OUR_SSH_FP" --arg k "$OUR_SSH_BODY" \
            '[.[] | select(.fingerprint == $fp or (.key | startswith($k)))] | length')"
        else
          MATCHING_SSH=0
        fi

        if [ "$MATCHING_SSH" -gt 0 ]; then
          echo "remote-agy-setup: SSH transport key is active in Gitea."
        else
          echo "remote-agy-setup: Registering SSH transport key with Gitea..."
          SSH_PUB_CONTENT="$(cat "$SSH_PUB_FILE")"
          SSH_PAYLOAD="$(${pkgs.jq}/bin/jq -n --arg t "$SSH_KEY_TITLE" --arg k "$SSH_PUB_CONTENT" '{title: $t, key: $k}')"
          ${pkgs.curl}/bin/curl -sf -X POST "${giteaUrl}/api/v1/user/keys" \
            -H "Authorization: token $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$SSH_PAYLOAD" >/dev/null 2>&1 || \
            ${pkgs.tea}/bin/tea ssh-keys add --title "$SSH_KEY_TITLE" "$SSH_PUB_FILE" 2>/dev/null || \
            echo "remote-agy-setup: Warning: failed to add SSH key to Gitea."
        fi

        # Register and verify GPG key via Gitea API
        EXISTING_GPG="$(${pkgs.curl}/bin/curl -sf -H "Authorization: token $TOKEN" "${giteaUrl}/api/v1/user/gpg_keys" 2>/dev/null || echo "[]")"
        IS_GPG_VERIFIED=0
        if echo "$EXISTING_GPG" | ${pkgs.jq}/bin/jq -e 'type == "array"' >/dev/null 2>&1; then
          IS_GPG_VERIFIED="$(echo "$EXISTING_GPG" | ${pkgs.jq}/bin/jq --arg kid "$GPG_KEY_ID" \
            '[.[] | select(.key_id == $kid and .verified == true)] | length')"
        fi

        if [ "$IS_GPG_VERIFIED" -gt 0 ]; then
          echo "remote-agy-setup: GPG signing key ($GPG_KEY_ID) is already registered and verified in Gitea."
        else
          echo "remote-agy-setup: Requesting GPG verification token from Gitea..."
          VERIF_TOKEN="$(${pkgs.curl}/bin/curl -sf -H "Authorization: token $TOKEN" "${giteaUrl}/api/v1/user/gpg_key_token" 2>/dev/null || true)"
          if [ -n "$VERIF_TOKEN" ]; then
            echo "remote-agy-setup: Signing verification challenge token with GPG..."
            ARMORED_SIG="$(echo -n "$VERIF_TOKEN" | ${pkgs.gnupg}/bin/gpg --batch --yes --detach-sign --armor --default-key "$GPG_KEY_ID")"
            PUB_GPG="$(${pkgs.gnupg}/bin/gpg --armor --export "$GPG_KEY_ID")"
            GPG_PAYLOAD="$(${pkgs.jq}/bin/jq -n --arg k "$PUB_GPG" --arg s "$ARMORED_SIG" '{armored_public_key: $k, armored_signature: $s}')"

            echo "remote-agy-setup: Registering verified GPG key with Gitea..."
            ${pkgs.curl}/bin/curl -sf -X POST "${giteaUrl}/api/v1/user/gpg_keys" \
              -H "Authorization: token $TOKEN" \
              -H "Content-Type: application/json" \
              -d "$GPG_PAYLOAD" >/dev/null 2>&1 || echo "remote-agy-setup: Warning: failed to register GPG key with Gitea."
          else
            echo "remote-agy-setup: Warning: failed to fetch GPG verification token from Gitea."
          fi
        fi

        # Verify SSH connectivity against pinned host key in /etc/ssh/ssh_known_hosts
        echo "remote-agy-setup: Verifying SSH connectivity to git@${giteaSshHost}..."
        ${pkgs.openssh}/bin/ssh -o BatchMode=yes -T "git@${giteaSshHost}" 2>&1 || true
      fi
    else
      echo "remote-agy-setup: Token file not found at $TOKEN_FILE (skipping Gitea key registration)."
    fi
  '';
in
{
  options.programs.remote-agy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the Antigravity remote-control daemon.";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "docker" ];
      description = "Extra groups for the agent user.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      antigravity
      pkgs.tea
      pkgs.gnupg
      setupScript
    ];

    users.users.${user} = {
      isNormalUser = true;
      inherit (cfg) extraGroups;
      shell = pkgs.zsh;
      description = "Antigravity remote agent user";
    };

    systemd.services.antigravity-remote-control = {
      description = "Antigravity Remote Control daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = config.environment.systemPackages;
      environment = {
        GITEA_SERVER_URL = giteaUrl;
      };
      serviceConfig = {
        Type = "simple";
        User = user;
        Group = "users";
        SupplementaryGroups = cfg.extraGroups;
        WorkingDirectory = userHome;
        ExecStartPre = "${setupScript}/bin/remote-agy-setup";
        ExecStart = "${antigravity}/bin/antigravity remote-control serve --name ${instanceName}";
        Restart = "always";
        RestartSec = "10s";
      };
    };
  };
}
