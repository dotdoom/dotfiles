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
    # If Secretive doesn't recognize your Yubikey PIV, it's possible you
    # generated it using yubikey-agent and that did not update CHUID. Simply
    # running 'ykman piv objects generate chuid' should be sufficient.
    # https://github.com/maxgoedjen/secretive/issues/333

    export SSH_AUTH_SOCK=~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
  '';

  nixpkgs.config.allowUnfree = true;
  programs.vscode.enable = true;
}
