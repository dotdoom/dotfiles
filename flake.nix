{
  description = "home-manager config from dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    systems.url = "github:nix-systems/default";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fw_nix = {
      url = "git+https://github.com/futureware-tech/nix.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
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
      nixpkgs-master,
      systems,
      home-manager,
      vscode-server,
      darwin,
      ...
    }@inputs:
    let
      homeManagerUser = "artem";
      eachSystem = nixpkgs.lib.genAttrs (import systems);
      overlay-master = _: prev: {
        inherit
          (import nixpkgs-master {
            system = prev.stdenv.hostPlatform.system;
            config = {
              allowUnfree = true;
            };
          })
          antigravity-cli
          ;
      };
    in
    {
      checks = eachSystem (system: {
        pre-commit-check = inputs.git-hooks.lib.${system}.run (
          {
            src = ./.;
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
      };

      homeConfigurations."${homeManagerUser}@deimos" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [ overlay-master ];
        };
        extraSpecialArgs.primaryUser = homeManagerUser;
        modules = [
          inputs.fw_nix.nixosModules.identities
          vscode-server.homeModules.default
          self.homeModules.linux-headless
          ./hosts/deimos/home.nix
        ];
      };

      homeConfigurations."${homeManagerUser}@mars" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-darwin";
          overlays = [ overlay-master ];
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
          (_: {
            nixpkgs.overlays = [ overlay-master ];
          })
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
          inputs.fw_nix.nixosModules.nix-gc
          inputs.fw_nix.nixosModules.nix-settings
          inputs.fw_nix.nixosModules.tools
          inputs.fw_nix.nixosModules.sshd
          inputs.fw_nix.nixosModules.futureware
          ./hosts/deimos/nixos.nix
          (_: {
            nixpkgs.overlays = [ overlay-master ];
          })
        ];
      };

      devShells = eachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
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
