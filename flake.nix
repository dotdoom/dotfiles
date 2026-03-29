{
  description = "home-manager config from dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # too many issues with screen 5.0
    # - load average in status broken
    # - background colors in programs (eg less) not showing
    # - caption and hardstatus color lacks intensity
    nixpkgs-screen.url = "github:NixOS/nixpkgs/e518d4ad2bcad74f98fec028cf21ce5b1e5020dd";
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
      trustedSSHKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxRBsFGa8OFbviYDGSAKLgfm/K2XUxvCo+31FW37yab artem"
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJhQjxeLZUWdEPMqPNS8wTTrg4lbzBAOLKvdsJd0fSBcW5ILuEbKQjgEIwmYuR/iGhnqIp7rQK48xL/4CauQUyg= office-dock-usb-a"
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJg7zQ4H0LQeQcILZBwCzQ+MYKtCgKm7HPe9oFeoyprKZXAvpm+HDHtaYdU39JF9f+nvRztzXuMhgETAQMAQCkc= fingerprint@macbook"
      ];
      eachSystem = nixpkgs.lib.genAttrs (import systems);
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
        main = import ./modules/home.nix;
      };
      darwinModules = {
        mac-portable = import ./modules/mac-portable.nix;
      };

      homeConfigurations."artem@deimos" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          self.homeModules.main
          vscode-server.homeModules.default
          ./hosts/deimos/home.nix
        ];
      };

      homeConfigurations."artem@mars" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-darwin;
        modules = [
          self.homeModules.main
          ./hosts/mars/home.nix
        ];
      };

      darwinConfigurations.mars = darwin.lib.darwinSystem {
        system = "x86_64-darwin";
        specialArgs.primaryUser = "artem";
        modules = [
          self.darwinModules.mac-portable
          inputs.fw_nix.nixosModules.tools
          inputs.fw_nix.nixosModules.nix-settings
          inputs.fw_nix.nixosModules.futureware
          inputs.nix-homebrew.darwinModules.nix-homebrew
          (
            { lib, ... }:
            {
              # TODO: find solution to these ugly workarounds
              options.programs.htop = lib.mkOption {
                type = lib.types.deferredModule;
                default = { };
              };
            }
          )
          ./hosts/mars/darwin.nix
        ];
      };

      nixosConfigurations.deimos =
        let
          system = "x86_64-linux";
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit trustedSSHKeys;
            pkgs-screen = import inputs.nixpkgs-screen {
              inherit system;
            };
          };
          modules = [
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
