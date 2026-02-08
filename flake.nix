{
  description = "home-manager config from dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
    let
      commonModules = [ ./modules/home.nix ];
    in
    {
      homeConfigurations."linux-headless" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = commonModules ++ [
          (
            { ... }:
            {
              home.username = "artem";
              home.homeDirectory = "/home/artem";
            }
          )
        ];
      };

      homeConfigurations."mac-portable" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-darwin;

        modules = commonModules ++ [
          (
            { pkgs, ... }:
            {
              home.username = "artem";
              home.homeDirectory = "/Users/artem";

              home.packages = with pkgs; [
                secretive
              ];

              nixpkgs.config.allowUnfree = true;
              programs.vscode.enable = true;
            }
          )
        ];
      };
    };
}
