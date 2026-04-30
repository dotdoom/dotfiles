{
  pkgs,
  ...
}:
{
  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true;
  security.sudo.wheelNeedsPassword = false;

  documentation.man.enable = true;

  environment.systemPackages = with pkgs; [
    # https://unix.stackexchange.com/questions/651165/using-systemd-to-mount-remote-filesystems-in-user-bus
    # Have to run the wrapper due to SUID.
    (pkgs.writeShellScriptBin "umount.fuse.sshfs" ''
      exec /run/wrappers/bin/fusermount -u "$1"
    '')
  ];

  system.stateVersion = "25.11"; # Never change this.
}
