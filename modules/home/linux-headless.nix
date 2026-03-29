{ primaryUser, ... }:
{
  imports = [
    ./common.nix
  ];

  home.homeDirectory = "/home/${primaryUser}";
}
