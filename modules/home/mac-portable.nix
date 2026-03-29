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

  nixpkgs.config.allowUnfree = true;
  programs.vscode.enable = true;
}
