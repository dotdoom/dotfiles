{ lib, primaryUser, ... }:
{
  imports = [
    ./common.nix
  ];

  home.homeDirectory = lib.mkDefault "/home/${primaryUser}";
}
