{ pkgs, primaryUser, ... }:
{
  nixpkgs.hostPlatform = "x86_64-darwin";

  # TODO: consider
  # https://nest.pijul.com/yonkeltron/macOS-nix-config:main/ZLDSMIXK5XFW6.EIAAA
  # and
  # https://github.com/bgub/nix-macos-starter/tree/main

  home.username = primaryUser;
  home.homeDirectory = "/Users/${primaryUser}";

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
