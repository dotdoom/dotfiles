{
  config,
  lib,
  pkgs,
  crush-src,
  ...
}:
let
  utils = import "${pkgs.path}/nixos/lib/utils.nix" { inherit lib pkgs config; };
  haremote-path = "${config.home.homeDirectory}/src/haremote";
  haremote-unit = utils.escapeSystemdPath haremote-path;
in
{
  imports = [
    ../common/home.nix
  ];

  services.vscode-server.enable = true;
  services.vscode-server.installPath = [
    "$HOME/.vscode-server"
    "$HOME/.antigravity-server"
  ];

  home.packages = with pkgs; [
    sshfs
    nixd
    home-assistant-cli
    yt-dlp
    attic-client
    opencode
    (crush.overrideAttrs (_: {
      src = crush-src;
      version = crush-src.shortRev or "dirty";
      vendorHash = "sha256-CGPZLtOWmMksODDV45rJ7qaA1lJKpe5qVP0tyauAoxU=";
      doCheck = false;
    }))
  ];

  systemd.user.mounts."${haremote-unit}" = {
    Unit = {
      Description = "Mount ${haremote-path}";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Mount = {
      What = "root@homeassistant.home.arpa:/homeassistant";
      Where = haremote-path;
      Type = "fuse.sshfs";
      Options = "reconnect,ServerAliveInterval=15,uid=1000,gid=1000,IdentityAgent=${config.home.homeDirectory}/.ssh/ssh_auth_sock";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.signal-cli = {
    Unit = {
      Description = "signal-cli daemon";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${pkgs.signal-cli}/bin/signal-cli daemon --tcp 127.0.0.1:7583 --receive-mode on-start --no-receive-stdout";
      Restart = "always";
      RestartSec = "10s";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  programs.zsh.loginExtra = ''
    if [ -n "$SSH_AUTH_SOCK" ]; then
      mkdir -p ${haremote-path}
      [ -z "$(ls -A ${haremote-path} 2>/dev/null)" ] && systemctl --user restart ${haremote-unit}.mount
    fi
  '';
}
