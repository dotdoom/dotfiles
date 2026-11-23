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

  # Pruning and manifest logic is shared with modules/home/skill-plugins.nix,
  # which does the same registration for home-manager users.
  skill-plugins-lib = import ../../lib/skill-plugins-lib.nix { inherit lib pkgs; };

  skillPaths = skill-plugins-lib.skillDirs cfg.skillPlugins;

  skillsJsonFile = skill-plugins-lib.mkAgyManifest {
    name = "remote-agy-skills";
    paths = skillPaths;
    exclude = cfg.disabledSkills;
  };

  customizeCommands = ''
    ${
      if skillPaths != [ ] then
        ''ln -sfn "${skillsJsonFile}" "$HOME/.gemini/config/skills.json"''
      else
        ''rm -f "$HOME/.gemini/config/skills.json"''
    }
  '';

  globalRulesFile = pkgs.writeText "remote-agy-agents.md" cfg.globalRules;

  giteaSidecar = pkgs.callPackage ./gitea-sidecar.nix { };

  giteaSidecarManifest = pkgs.writeText "remote-agy-gitea-sidecar.json" (
    builtins.toJSON {
      display_name = "Gitea";
      description = "Polls Gitea notifications and routes @mentions, assignments, review requests, and PR replies into Antigravity conversations.";
      command = "${giteaSidecar}/bin/remote-agy-gitea-sidecar";
      args = [ ];
      restart_policy = "always";
      env = {
        GITEA_SERVER_URL = giteaUrl;
        GITEA_TOKEN_FILE = "${userHome}/.config/gitea-token";
        GITEA_POLL_INTERVAL = toString cfg.giteaSidecar.pollInterval;
        GITEA_MAX_CONCURRENCY = toString cfg.giteaSidecar.maxConcurrency;
        GITEA_ALLOWED_USERS = lib.concatStringsSep "," cfg.giteaSidecar.allowedUsers;
      }
      // lib.optionalAttrs (cfg.giteaSidecar.model != null) {
        AGY_MODEL = cfg.giteaSidecar.model;
      };
    }
  );

  serverScript = pkgs.writeShellApplication {
    name = "remote-agy-server";
    text = ''
      exec "${pkgs.antigravity-hub}/share/antigravity/resources/bin/language_server" \
        --standalone \
        --headless \
        --override_ide_name antigravity \
        --subclient_type hub \
        --override_ide_version "${pkgs.antigravity-hub.version}" \
        --override_user_agent_name antigravity \
        --https_server_port 0 \
        --http_server_port 0 \
        --csrf_token "$(< /proc/sys/kernel/random/uuid)" \
        --app_data_dir antigravity \
        --api_server_url https://generativelanguage.googleapis.com \
        --cloud_code_endpoint https://daily-cloudcode-pa.googleapis.com \
        --enable_sidecars
    '';
  };

  setupScript = pkgs.writeShellApplication {
    name = "remote-agy-setup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.openssh
      pkgs.gnupg
      pkgs.git
      pkgs.tea
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      # 1. Symlinks into the store, so a rebuild plus service restart moves them
      #    atomically.
      mkdir -p "$HOME/.gemini/config"
      ln -sfn "${globalRulesFile}" "$HOME/.gemini/config/AGENTS.md"
      ${customizeCommands}
      ${
        if cfg.giteaSidecar.enable then
          ''
            mkdir -p "$HOME/.gemini/config/sidecars/gitea"
            ln -sfn "${giteaSidecarManifest}" "$HOME/.gemini/config/sidecars/gitea/sidecar.json"
          ''
        else
          ''
            rm -rf "$HOME/.gemini/config/sidecars/gitea"
          ''
      }

      CONFIG_JSON="$HOME/.gemini/config/config.json"
      if [ ! -f "$CONFIG_JSON" ] || ! jq -e 'type == "object"' "$CONFIG_JSON" >/dev/null 2>&1; then
        printf '{}\n' > "$CONFIG_JSON"
      fi
      jq \
        --arg host "${instanceName}" \
        --argjson enableGitea ${if cfg.giteaSidecar.enable then "true" else "false"} \
        '
          .userSettings = ((.userSettings // {}) + {
            remoteControlEnabled: true,
            remoteControlHostname: $host
          })
          | if $enableGitea then
              .sidecars = ((.sidecars // {}) | .gitea = ((.gitea // {}) + {enabled: true}))
            elif (.sidecars.gitea? != null) then
              .sidecars.gitea.enabled = false
            else
              .
            end
        ' "$CONFIG_JSON" > "$CONFIG_JSON.tmp"
      chmod 600 "$CONFIG_JSON.tmp"
      mv -f "$CONFIG_JSON.tmp" "$CONFIG_JSON"

      # 2. Generate SSH key for repository transport (clone/push) if missing
      mkdir -p "$HOME/.ssh"
      chmod 700 "$HOME/.ssh"
      SSH_KEY_FILE="$HOME/.ssh/id_ed25519"
      SSH_PUB_FILE="$SSH_KEY_FILE.pub"

      if [ ! -f "$SSH_KEY_FILE" ]; then
        echo "remote-agy-setup: Generating SSH transport key for ${user}..."
        ssh-keygen -t ed25519 -C "${user}@${instanceName}" -f "$SSH_KEY_FILE" -N ""
      fi

      # 3. Generate GPG key for commit signing if missing
      mkdir -p "$HOME/.gnupg"
      chmod 700 "$HOME/.gnupg"
      GPG_KEY_ID="$( { gpg --list-secret-keys --with-colons "${email}" 2>/dev/null || true; } | awk -F: '/^sec:/ {print $5}' | head -n1 )"

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
          "Expire-Date: 0" | gpg --batch --generate-key
        GPG_KEY_ID="$( { gpg --list-secret-keys --with-colons "${email}" 2>/dev/null || true; } | awk -F: '/^sec:/ {print $5}' | head -n1 )"
      fi

      # 4. Configure Git for commit signing and identity
      git config --global user.name "${user}"
      git config --global user.email "${email}"
      git config --global gpg.format openpgp
      git config --global gpg.program "${pkgs.gnupg}/bin/gpg"
      git config --global user.signingkey "$GPG_KEY_ID"
      git config --global commit.gpgsign true

      # 5. Gitea automation
      TOKEN_FILE="$HOME/.config/gitea-token"
      if [ -f "$TOKEN_FILE" ]; then
        TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"
        if [ -n "$TOKEN" ]; then
          echo "remote-agy-setup: Configuring tea with Gitea token..."
          CURRENT_TEA_TOKEN="$(grep -A5 'name: local' "$HOME/.config/tea/config.yml" 2>/dev/null | awk '/token:/ {print $2}' || true)"
          if [ "$CURRENT_TEA_TOKEN" != "$TOKEN" ]; then
            tea login delete local >/dev/null 2>&1 || true
            tea login add --name local --url "${giteaUrl}" --token "$TOKEN" >/dev/null 2>&1 || true
            tea login default local >/dev/null 2>&1 || true
          fi

          # Ensure GITEA_SERVER_URL is available for interactive shells
          if [ ! -f "$HOME/.profile" ] || ! grep -q 'GITEA_SERVER_URL' "$HOME/.profile" 2>/dev/null; then
            echo 'export GITEA_SERVER_URL="${giteaUrl}"' >> "$HOME/.profile"
          fi

          # Register SSH key for transport if not already present
          SSH_KEY_TITLE="${user}@${instanceName}"
          OUR_SSH_FP="$(ssh-keygen -lf "$SSH_PUB_FILE" | awk '{print $2}')"
          OUR_SSH_BODY="$(awk '{print $1 " " $2}' "$SSH_PUB_FILE")"

          EXISTING_SSH="$(curl -sf -H "Authorization: token $TOKEN" "${giteaUrl}/api/v1/user/keys" 2>/dev/null || echo "[]")"
          if echo "$EXISTING_SSH" | jq -e 'type == "array"' >/dev/null 2>&1; then
            MATCHING_SSH="$(echo "$EXISTING_SSH" | jq --arg fp "$OUR_SSH_FP" --arg k "$OUR_SSH_BODY" \
              '[.[] | select(.fingerprint == $fp or (.key | startswith($k)))] | length')"
          else
            MATCHING_SSH=0
          fi

          if [ "$MATCHING_SSH" -gt 0 ]; then
            echo "remote-agy-setup: SSH transport key is active in Gitea."
          else
            echo "remote-agy-setup: Registering SSH transport key with Gitea..."
            SSH_PUB_CONTENT="$(cat "$SSH_PUB_FILE")"
            SSH_PAYLOAD="$(jq -n --arg t "$SSH_KEY_TITLE" --arg k "$SSH_PUB_CONTENT" '{title: $t, key: $k}')"
            curl -sf -X POST "${giteaUrl}/api/v1/user/keys" \
              -H "Authorization: token $TOKEN" \
              -H "Content-Type: application/json" \
              -d "$SSH_PAYLOAD" >/dev/null 2>&1 || \
              tea ssh-keys add --title "$SSH_KEY_TITLE" "$SSH_PUB_FILE" 2>/dev/null || \
              echo "remote-agy-setup: Warning: failed to add SSH key to Gitea."
          fi

          # Register and verify GPG key via Gitea API
          EXISTING_GPG="$(curl -sf -H "Authorization: token $TOKEN" "${giteaUrl}/api/v1/user/gpg_keys" 2>/dev/null || echo "[]")"
          IS_GPG_VERIFIED=0
          if echo "$EXISTING_GPG" | jq -e 'type == "array"' >/dev/null 2>&1; then
            IS_GPG_VERIFIED="$(echo "$EXISTING_GPG" | jq --arg kid "$GPG_KEY_ID" \
              '[.[] | select(.key_id == $kid and .verified == true)] | length')"
          fi

          if [ "$IS_GPG_VERIFIED" -gt 0 ]; then
            echo "remote-agy-setup: GPG signing key ($GPG_KEY_ID) is already registered and verified in Gitea."
          else
            echo "remote-agy-setup: Requesting GPG verification token from Gitea..."
            VERIF_TOKEN="$(curl -sf -H "Authorization: token $TOKEN" "${giteaUrl}/api/v1/user/gpg_key_token" 2>/dev/null || true)"
            if [ -n "$VERIF_TOKEN" ]; then
              echo "remote-agy-setup: Signing verification challenge token with GPG..."
              ARMORED_SIG="$(printf '%s' "$VERIF_TOKEN" | gpg --batch --yes --detach-sign --armor --default-key "$GPG_KEY_ID")"
              PUB_GPG="$(gpg --armor --export "$GPG_KEY_ID")"
              GPG_PAYLOAD="$(jq -n --arg k "$PUB_GPG" --arg s "$ARMORED_SIG" '{armored_public_key: $k, armored_signature: $s}')"

              echo "remote-agy-setup: Registering verified GPG key with Gitea..."
              curl -sf -X POST "${giteaUrl}/api/v1/user/gpg_keys" \
                -H "Authorization: token $TOKEN" \
                -H "Content-Type: application/json" \
                -d "$GPG_PAYLOAD" >/dev/null 2>&1 || echo "remote-agy-setup: Warning: failed to register GPG key with Gitea."
            else
              echo "remote-agy-setup: Warning: failed to fetch GPG verification token from Gitea."
            fi
          fi

          # Verify SSH connectivity against pinned host key in /etc/ssh/ssh_known_hosts
          echo "remote-agy-setup: Verifying SSH connectivity to git@${giteaSshHost}..."
          ssh -o BatchMode=yes -T "git@${giteaSshHost}" 2>&1 || true
        fi
      else
        echo "remote-agy-setup: Token file not found at $TOKEN_FILE (skipping Gitea key registration)."
      fi
    '';
  };
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

    skillPlugins = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.path lib.types.package);
      default = { };
      example = lib.literalExpression ''
        { claude-plugin-sdd = claude-plugin-sdd; }
      '';
      description = ''
        Skill plugins to register with the remote-control daemon's
        Antigravity config ({file}`~${user}/.gemini/config/skills.json`).
        Each source is a directory holding a {file}`skills/` directory of
        skill folders, each containing a {file}`SKILL.md`.
        {file}`references/`, {file}`templates/` and {file}`scripts/` are
        copied alongside, because skills load their assets relative to the
        plugin root; the rest of the source is dropped.

        Every skill's name and description are injected into the system
        prompt whether or not it is used, so a large plugin is a standing
        token cost. Use {option}`programs.remote-agy.disabledSkills` to
        trim the ones the agent should never see.
      '';
    };

    disabledSkills = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = lib.literalExpression ''[ "init" "report-friction" ]'';
      description = ''
        Names of skills from {option}`programs.remote-agy.skillPlugins` to
        hide from the agent. A disabled skill is dropped from the prompt and
        cannot be invoked, so this is the lever for keeping an
        otherwise-large plugin off the always-on token budget.
      '';
    };

    globalRules = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Global rules Antigravity loads into every session of the
        agent user, written to {file}`~${user}/.gemini/config/AGENTS.md`.
        The module ships a Gitea and repository-conventions section
        {func}`lib.mkBefore`, so any assignment is appended after it and
        every {env}`types.lines` assignment is kept;
        {func}`lib.mkForce` replaces the whole thing.
      '';
    };

    giteaSidecar = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to register and enable the Gitea notifications sidecar
          ({file}`~/.gemini/config/sidecars/gitea/sidecar.json`) under the
          Antigravity language server's native SidecarManager, polling Gitea
          and routing mentions, assignments, review requests, and PR replies
          into Antigravity conversations via `agentapi`.
        '';
      };

      pollInterval = lib.mkOption {
        type = lib.types.ints.positive;
        default = 30;
        description = "Seconds between Gitea notification/issue search polls.";
      };

      maxConcurrency = lib.mkOption {
        type = lib.types.ints.positive;
        default = 2;
        description = "Maximum number of Gitea notification threads dispatched concurrently.";
      };

      model = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "pro";
        description = "Optional model tier or ID passed to `agentapi new-conversation --model`.";
      };

      allowedUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ primaryUser ];
        example = [
          "artem"
          "katarina"
        ];
        description = ''
          Gitea usernames allowed to trigger the sidecar (mentions, comments,
          reviews, assignments, and review requests). An empty list disables
          the allowlist and accepts events from any user.
        '';
      };

      extraPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Extra packages added to the remote Antigravity daemon and sidecar PATH.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # An option's `default` yields entirely to assignments, so the shipped
    # text lives in config instead: lines merge by concatenation, and
    # mkBefore pins it ahead of anything a host declares.
    programs.remote-agy.globalRules = lib.mkBefore ''
      ## Gitea "DasFoo" instance

      You can access local Git server using `tea` command. The instance is
      available at `git.home.arpa:3000` and also has a public URL available
      via HTTPS. SSH clone is always done over `git@git.home.arpa`.

      Repositories are checked out under `~/src`, either `~/src/<repo>` or
      `~/src/<owner>/<repo>`. Clone new repositories there so the Gitea
      sidecar finds them for future events.

      ## Before making changes

      Once per task, right before the first line of code is written (not on
      every iteration or response), bring the branch up to date: `git fetch`
      and check whether it is behind its remote, e.g. with `git status -sb`.
      If it is stale and no other instruction pins the work to a branch or
      commit, pull the latest changes first.
    '';

    # Progressive disclosure: keep Gitea/tea recipes off the always-on prompt budget.
    programs.remote-agy.skillPlugins.gitea = lib.mkDefault (
      lib.fileset.toSource {
        root = ../../..;
        fileset = ../../../skills/gitea;
      }
    );

    assertions = [
      (skill-plugins-lib.trimNeedsPluginsAssertion {
        optionNames = "programs.remote-agy.disabledSkills";
        disabled = cfg.disabledSkills;
        paths = skillPaths;
      })
    ];

    environment.systemPackages = [
      pkgs.tea
      pkgs.gnupg
      setupScript
      serverScript
    ]
    ++ lib.optional cfg.giteaSidecar.enable giteaSidecar;

    users.users.${user} = {
      isNormalUser = true;
      inherit (cfg) extraGroups;
      shell = pkgs.zsh;
      description = "Antigravity remote agent user";
    };

    systemd.services.antigravity-remote-control = {
      description = "Antigravity Remote Control language server daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path =
        config.environment.systemPackages
        ++ [
          pkgs.git
          pkgs.openssh
          pkgs.curl
          pkgs.jq
          pkgs.python3
        ]
        ++ lib.optionals cfg.giteaSidecar.enable cfg.giteaSidecar.extraPackages;
      environment = {
        GITEA_SERVER_URL = giteaUrl;
        # SSH_CONNECTION triggers file-based OAuth token storage instead of
        # requiring a desktop D-Bus keyring.
        SSH_CONNECTION = "1";
      };
      serviceConfig = {
        Type = "simple";
        User = user;
        Group = "users";
        SupplementaryGroups = cfg.extraGroups;
        WorkingDirectory = userHome;
        ExecStartPre = "${setupScript}/bin/remote-agy-setup";
        ExecStart = "${serverScript}/bin/remote-agy-server";
        Restart = "always";
        RestartSec = "10s";
      };
    };
  };
}
