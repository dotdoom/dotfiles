{
  description = "home-manager config from dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    fw_nix = {
      url = "git+https://github.com/futureware-tech/nix.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    impermanence.url = "github:nix-community/impermanence";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jail-nix.url = "sourcehut:~alexdavid/jail.nix";
    # Not following nixpkgs on purpose: the flake is only tested against its own
    # pinned nixpkgs-unstable, and keeping it separate means we hit numtide's cache.
    llm-agents.url = "github:numtide/llm-agents.nix";
    # Spec-Driven Development skill plugin for Crush and Antigravity. Upstream
    # ships no flake, so this is a bare source tree that
    # modules/home/skill-plugins.nix prunes to what the skills load at runtime.
    claude-plugin-sdd = {
      url = "github:joestump/claude-plugin-sdd";
      flake = false;
    };
    # Agent-oriented HA CLI (binary `ha`): JSON on stdout, structured exit codes,
    # and `ha schema` for command discovery. Not in nixpkgs yet.
    homeassistant-cli = {
      url = "github:rvben/homeassistant-cli";
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
      homeManagerUser = "artem";
      eachSystem = nixpkgs.lib.genAttrs (import systems);

      # Numtide's llm-agents tracks agent CLI releases with a bot several
      # times a day; nixpkgs lags by weeks. These overlays pass their prebuilt
      # binaries through our own pkgset (cache.numtide.com serves them), so
      # everything referring to pkgs.<name> gets the fresh build. The guard
      # makes each binding self-retiring: once nixpkgs catches up or passes
      # the fresh source, the nixpkgs package wins again with no change here.
      mkFreshOverlay =
        freshPackagesFor: names: _final: prev:
        let
          inherit (prev.stdenv.hostPlatform) system;
          freshPackages = freshPackagesFor system;
          # The version guard must stay inside a lazily-held expression: an
          # eager fold deciding which names to emit forces `prev.${name}`
          # while nixpkgs' stdenv booter is still assembling the package set,
          # and resolving it needs that very stdenv. So emit every name and
          # decide per value. Every name below exists in at least one source
          # on both our platforms; a name neither provides would bind null,
          # so drop it from the list when that changes.
          preferFresh =
            name:
            let
              fresh = freshPackages.${name} or null;
              current = prev.${name} or null;
            in
            if fresh == null then
              current
            else if current == null then
              fresh
            else if nixpkgs.lib.versionOlder current.version fresh.version then
              fresh
            else
              current;
        in
        nixpkgs.lib.genAttrs names preferFresh;

      llmAgentsOverlay = mkFreshOverlay (system: inputs.llm-agents.packages.${system} or { }) [
        "antigravity-cli"
        "crush"
        "qmd"
      ];

      # Agent-oriented HA CLI (binary `ha`): not in nixpkgs yet, and its flake
      # exposes the package as `default`.
      homeassistantCliOverlay = mkFreshOverlay (system: {
        homeassistant-cli = inputs.homeassistant-cli.packages.${system}.default or null;
      }) [ "homeassistant-cli" ];

      agentOverlays = [
        llmAgentsOverlay
        homeassistantCliOverlay
      ];
    in
    {
      checks = eachSystem (system: {
        pre-commit-check = inputs.git-hooks.lib.${system}.run (
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

      overlays.llm-agents = llmAgentsOverlay;

      homeModules = {
        mac-portable = import ./modules/home/mac-portable.nix;
        linux-headless = import ./modules/home/linux-headless.nix;
        skill-plugins = import ./modules/home/skill-plugins.nix;
      };
      darwinModules = {
        mac-portable = import ./modules/darwin/mac-portable.nix;
      };
      nixosModules = {
        linux-headless = import ./modules/nixos/linux-headless.nix;
        linux-lxc = import ./modules/nixos/linux-lxc.nix;
        jailed-agy = import ./modules/nixos/jailed-agy.nix;
        remote-agy = import ./modules/nixos/remote-agy.nix;
      };

      homeConfigurations."${homeManagerUser}@deimos" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = agentOverlays;
        };
        extraSpecialArgs = {
          primaryUser = homeManagerUser;
          inherit (inputs) claude-plugin-sdd;
        };
        modules = [
          inputs.fw_nix.nixosModules.identities
          vscode-server.homeModules.default
          self.homeModules.linux-headless
          ./hosts/deimos/home.nix
        ];
      };

      homeConfigurations."${homeManagerUser}@mars" = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "aarch64-darwin";
          overlays = agentOverlays;
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
        system = "aarch64-darwin";
        specialArgs.primaryUser = homeManagerUser;
        modules = [
          { nixpkgs.overlays = agentOverlays; }
          inputs.fw_nix.nixosModules.identities
          self.darwinModules.mac-portable
          inputs.fw_nix.nixosModules.nix-gc
          inputs.fw_nix.nixosModules.nix-settings
          inputs.fw_nix.nixosModules.tools
          inputs.fw_nix.nixosModules.futureware
          inputs.nix-homebrew.darwinModules.nix-homebrew
          ./hosts/mars/darwin.nix
        ];
      };

      nixosConfigurations.deimos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          primaryUser = homeManagerUser;

          # /home is the only data-storing mountpoint besides /nix.
          persistenceCommon = "/home/persistent";

          inherit (inputs) jail-nix claude-plugin-sdd;
        };
        modules = [
          { nixpkgs.overlays = agentOverlays; }
          inputs.fw_nix.nixosModules.identities
          self.nixosModules.linux-headless
          self.nixosModules.linux-lxc
          self.nixosModules.jailed-agy
          self.nixosModules.remote-agy
          inputs.impermanence.nixosModules.impermanence
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
