{
  config,
  lib,
  pkgs,
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

  programs.zsh.loginExtra = ''
    if [ -n "$SSH_AUTH_SOCK" ]; then
      mkdir -p ${haremote-path}
      [ -z "$(ls -A ${haremote-path} 2>/dev/null)" ] && systemctl --user restart ${haremote-unit}.mount
    fi
  '';
}
