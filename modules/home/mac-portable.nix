{ pkgs, primaryUser, ... }:
{
  imports = [
    ./common.nix
  ];

  home.homeDirectory = "/Users/${primaryUser}";

  home.packages = with pkgs; [
    secretive
    vlc-bin
  ];

  programs.zsh.envExtra = ''
    # Blocked on https://github.com/overhacked/ssh-agent-mux/issues/56
    # export SSH_AUTH_SOCK=~/.ssh/ssh-agent-mux.sock
    export SSH_AUTH_SOCK=~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
  '';

  nixpkgs.config.allowUnfree = true;
  programs.vscode.enable = true;
}
