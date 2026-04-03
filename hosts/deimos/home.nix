_: {
  home.homeDirectory = "/home/artem";

  services.vscode-server.enable = true;
  services.vscode-server.installPath = [
    "$HOME/.vscode-server"
    "$HOME/.antigravity-server"
  ];

  systemd.user.mounts.home-artem-src-haremote = {
    Unit = {
      Description = "Mount ~/src/haremote";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Mount = {
      What = "root@homeassistant.home.arpa:/homeassistant";
      Where = "/home/artem/src/haremote";
      Type = "fuse.sshfs";
      Options = "reconnect,ServerAliveInterval=15,uid=1000,gid=1000,IdentityAgent=/home/artem/.ssh/ssh_auth_sock";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  programs.zsh.loginExtra = ''
    if [ -n "$SSH_AUTH_SOCK" ]; then
      mkdir -p ~/src/haremote
      [ -z "$(ls -A ~/src/haremote 2>/dev/null)" ] && systemctl --user restart home-artem-src-haremote.mount
    fi
  '';
}
