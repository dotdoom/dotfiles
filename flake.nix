{
  description = "home-manager config from dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-mars.url = "github:nixos/nixpkgs/nixpkgs-26.05-darwin";
    systems.url = "github:nix-systems/default";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-mars = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-mars";
    };
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-26.05-darwin";
    };
    fw_nix = {
      url = "git+https://github.com/futureware-tech/nix.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-mars";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jail-nix.url = "sourcehut:~alexdavid/jail.nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      home-manager,
      vscode-server,
      darwin,
      ...
    }@inputs:
    let
      homeManagerUser = "artem";
      eachSystem = nixpkgs.lib.genAttrs (import systems);
      nixpkgsFor = system: if system == "x86_64-darwin" then inputs.nixpkgs-mars else nixpkgs;
    in
    {
      checks = eachSystem (system: {
        pre-commit-check =
          let
            # Once x86_64-darwin is removed and we are back to a single nixpkgs
            # version, this can be simplified to:
            #   gitHooksLib = inputs.git-hooks.lib.${system}
            gitHooksLib = import "${inputs.git-hooks}/nix" {
              nixpkgs = nixpkgsFor system;
              inherit system;
              isFlakes = true;
            };
          in
          gitHooksLib.run (
            {
              src = ./.;
              excludes = [
                "^migrated/"
                "^legacy/"
              ];
            }
            // inputs.fw_nix.lib.pre-commit
          );
      });

      homeModules = {
        mac-portable = import ./modules/home/mac-portable.nix;
        linux-headless = import ./modules/home/linux-headless.nix;
      };
      darwinModules = {
        mac-portable = import ./modules/darwin/mac-portable.nix;
      };
      nixosModules = {
        linux-headless = import ./modules/nixos/linux-headless.nix;
        linux-lxc = import ./modules/nixos/linux-lxc.nix;
        jailed-agy = import ./modules/nixos/jailed-agy.nix;
      };

      homeConfigurations."${homeManagerUser}@deimos" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
        };
        extraSpecialArgs.primaryUser = homeManagerUser;
        modules = [
          inputs.fw_nix.nixosModules.identities
          vscode-server.homeModules.default
          self.homeModules.linux-headless
          ./hosts/deimos/home.nix
        ];
      };

      homeConfigurations."${homeManagerUser}@mars" =
        inputs.home-manager-mars.lib.homeManagerConfiguration
          {
            pkgs = import inputs.nixpkgs-mars {
              system = "x86_64-darwin";
              config.allowDeprecatedx86_64Darwin = true;
            };
            extraSpecialArgs = {
              primaryUser = homeManagerUser;
            };
            modules = [
              inputs.fw_nix.nixosModules.identities
              self.homeModules.mac-portable
              ./hosts/mars/home.nix
            ];
          };

      darwinConfigurations.mars = darwin.lib.darwinSystem {
        system = "x86_64-darwin";
        specialArgs.primaryUser = homeManagerUser;
        modules = [
          inputs.fw_nix.nixosModules.identities
          self.darwinModules.mac-portable
          inputs.fw_nix.nixosModules.nix-gc
          inputs.fw_nix.nixosModules.nix-settings
          inputs.fw_nix.nixosModules.tools
          inputs.fw_nix.nixosModules.futureware
          inputs.nix-homebrew.darwinModules.nix-homebrew
          ./hosts/mars/darwin.nix
          {
            nixpkgs.config.allowDeprecatedx86_64Darwin = true;
          }
        ];
      };

      nixosConfigurations.deimos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          primaryUser = homeManagerUser;
          inherit (inputs) jail-nix;
        };
        modules = [
          inputs.fw_nix.nixosModules.identities
          self.nixosModules.linux-headless
          self.nixosModules.linux-lxc
          self.nixosModules.jailed-agy
          inputs.fw_nix.nixosModules.nix-gc
          inputs.fw_nix.nixosModules.nix-settings
          inputs.fw_nix.nixosModules.tools
          inputs.fw_nix.nixosModules.sshd
          inputs.fw_nix.nixosModules.futureware
          ./hosts/deimos/nixos.nix
        ];
      };

      devShells = eachSystem (
        system:
        let
          pkgs = import (nixpkgsFor system) {
            inherit system;
            config.allowDeprecatedx86_64Darwin = true;
          };
          inherit (self.checks.${system}.pre-commit-check) shellHook enabledPackages;
        in
        {
          default = pkgs.mkShell {
            packages = enabledPackages;
            inherit shellHook;
          };
        }
      );
    };
}
