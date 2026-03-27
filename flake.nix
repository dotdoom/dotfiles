{
  description = "home-manager config from dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # too many issues with screen 5.0
    # - load average in status broken
    # - background colors in programs (eg less) not showing
    # - caption and hardstatus color lacks intensity
    nixpkgs-screen.url = "github:NixOS/nixpkgs/e518d4ad2bcad74f98fec028cf21ce5b1e5020dd";
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
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      vscode-server,
      ...
    }@inputs:
    let
      trustedSSHKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxRBsFGa8OFbviYDGSAKLgfm/K2XUxvCo+31FW37yab artem"
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJhQjxeLZUWdEPMqPNS8wTTrg4lbzBAOLKvdsJd0fSBcW5ILuEbKQjgEIwmYuR/iGhnqIp7rQK48xL/4CauQUyg= office-dock-usb-a"
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJg7zQ4H0LQeQcILZBwCzQ+MYKtCgKm7HPe9oFeoyprKZXAvpm+HDHtaYdU39JF9f+nvRztzXuMhgETAQMAQCkc= fingerprint@macbook"
      ];
    in
    {
      homeModules.main = {
        imports = [ ./modules/home.nix ];
      };

      homeConfigurations."linux-headless" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          self.homeModules.main
          vscode-server.homeModules.default
          (
            { lib, ... }:
            {
              home.username = "artem";
              home.homeDirectory = "/home/artem";

              services.vscode-server.enable = true;
              services.vscode-server.installPath = [
                "$HOME/.vscode-server"
                "$HOME/.antigravity-server"
              ];
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
              # TODO: consider
              # https://nest.pijul.com/yonkeltron/macOS-nix-config:main/ZLDSMIXK5XFW6.EIAAA
              # and
              # https://github.com/bgub/nix-macos-starter/tree/main

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

      nixosConfigurations.deimos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit trustedSSHKeys;
          pkgs-screen = import inputs.nixpkgs-screen {
            system = "x86_64-linux";
          };
        };
        modules = [
          inputs.fw_nix.nixosModules.nix-gc
          inputs.fw_nix.nixosModules.nix-settings
          inputs.fw_nix.nixosModules.tools
          inputs.fw_nix.nixosModules.sshd
          inputs.fw_nix.nixosModules.futureware
          (
            { modulesPath, pkgs, pkgs-screen, ... }:
            {
              imports = [
                "${modulesPath}/virtualisation/lxc-container.nix"
              ];

              # Incus config:
              # - keep root as-is (requirement from incus; just ignore it)
              # - add a disk for /home/artem
              # - add a disk for /nix
              # "incus config edit deimos" and add under "config:"
              #   raw.lxc: lxc.init.cmd = /nix/var/nix/profiles/system/init

              # TODO: persistence with SSH host keys, then automatically run
              #       "incus rebuild --empty deimos" periodically
              # Needs /sbin to be preset because bootloader installer uses that
              # path; consider either creating using systemd.tmpfiles or
              # overwriting bootloader installer / activation script.
              # https://github.com/NixOS/nixpkgs/blob/c080e09eaca35383aa8dd2be863b37c933ed8812/nixos/modules/virtualisation/lxc-container.nix#L105

              users.users.artem = {
                uid = 1000;
                isNormalUser = true;
                extraGroups = [
                  "wheel"
                  "docker"
                ];
                openssh.authorizedKeys.keys = trustedSSHKeys;
                shell = pkgs.zsh;
              };
              security.sudo.wheelNeedsPassword = false;

              virtualisation.docker.enable = true;

              # TODO: manage /home/artem with home-manager
              programs.zsh.enable = true;
              documentation.man.enable = true;
              programs.direnv = {
                enable = true;
                settings.global = {
                  warn_timeout = "30s";
                  hide_env_diff = true;
                };
              };

              environment.systemPackages = with pkgs; [
                # TODO: clean this up against linux-headless
                git
                pkgs-screen.screen
                sshfs
                silver-searcher
                file
                nixfmt
                nixd
                home-assistant-cli
                gemini-cli
                yt-dlp

                # From hosts/common/tools.nix:
                # Software debug
                iotop
                dool # dool --time --disk -D /dev/sde,/dev/sdf --top-bio --top-cpu --zfs-arc
                strace
                ltrace
                smem # smem -tkP nginx

                # Hardware info and tunables
                parted
                hdparm
                efivar
                efibootmgr
                sg3_utils # sg_unmap
                lm_sensors # sensors
                nvme-cli
                dmidecode
                ethtool
              ];

              # unprivileged LXCs can't set net.ipv4.ping_group_range
              security.wrappers.ping = {
                owner = "root";
                group = "root";
                capabilities = "cap_net_raw+p";
                source = "${pkgs.iputils.out}/bin/ping";
              };

              # For building RPi configs. Extra steps are handled by the host (nas).
              # https://discuss.linuxcontainers.org/t/systemd-binfmt-service-is-masked/21566/4
              boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

              networking = {
                hostName = "deimos";
                domain = "home.arpa";
              };

              system.stateVersion = "25.11"; # Never change this.
            }
          )
        ];
      };
    };
}
