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
    {
      homeConfigurations."artem" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-darwin;

        modules = [
          (
            { pkgs, ... }:
            {
              home.username = "artem";
              home.homeDirectory = "/Users/artem";
              home.stateVersion = "25.11";

              # vscode
              nixpkgs.config.allowUnfree = true;

              home.packages = with pkgs; [
                git
                vim
                secretive
              ];

              programs.home-manager.enable = true;

              programs.vscode.enable = true;

              programs.direnv = {
                enable = true;
                enableZshIntegration = true;
                nix-direnv.enable = true;

                config.global = {
                  warn_timeout = "30s";
                  hide_env_diff = true;
                };
              };

            }
          )
        ];
      };
    };
}
