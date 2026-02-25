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
      homeModules.main = {
        imports = [ ./modules/home.nix ];
      };

      homeConfigurations."linux-headless" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          self.homeModules.main
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

        modules = [
          self.homeModules.main
          (
            { pkgs, ... }:
            {
              home.username = "artem";
              home.homeDirectory = "/Users/artem";

              home.packages = with pkgs; [
                secretive
                vlc-bin
                dosbox-staging # dosbox appears broken on darwin

                # 1. Move config file to /usr/local/etc/wireguard/wg0.conf
                # 2. sudo wg-quick up wg0
                wireguard-tools
                wireguard-go

                antigravity
              ];

              nixpkgs.config.allowUnfree = true;
              programs.vscode.enable = true;

              launchd.agents.keyboard-remap = {
                # Remap top-left key (paragraph) to backquote and backslash like
                # proper ISO keyboard does, and the key right to the LShift to
                # Shift.
                enable = true;
                config = {
                  Label = "com.user.keyboard-remap";
                  ProgramArguments = [
                    "/usr/bin/hidutil"
                    "property"
                    "--set"
                    ''
                      {"UserKeyMapping":
                        [
                          {"HIDKeyboardModifierMappingSrc":0x700000035, "HIDKeyboardModifierMappingDst":0x7000000e1},
                          {"HIDKeyboardModifierMappingSrc":0x700000064, "HIDKeyboardModifierMappingDst":0x700000035},
                        ]
                      }''
                  ];
                  RunAtLoad = true;
                };
              };
            }
          )
        ];
      };
    };
}
