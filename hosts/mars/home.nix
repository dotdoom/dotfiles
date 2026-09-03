{
  pkgs,
  lib,
  config,
  identities,
  primaryUser,
  ...
}:
{
  imports = [
    ../common/home.nix
  ];

  home.packages = with pkgs; [
    dosbox-staging # dosbox appears broken on darwin

    # 1. Edit config file:
    #    - comment out DNS setting
    #    - add instead, replacing <DNS> with the value of DNS setting:
    #        PostUp = printf "d.init\nd.add ServerAddresses * <DNS>\nd.add SupplementalMatchDomains * \"\"\nset State:/Network/Service/wg0/DNS\n" | scutil
    #        PostDown = printf "remove State:/Network/Service/wg0/DNS\n" | scutil
    # 2. Move config file to /usr/local/etc/wireguard/wg0.conf
    # 3. sudo wg-quick up wg0
    wireguard-tools

    antigravity
  ];

  home.activation.setupAuthorizedKeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -m 0600 -D \
      ${
        pkgs.writeText "keys" (
          builtins.concatStringsSep "\n" (identities.getAccessKeys { user = primaryUser; })
        )
      } \
      ${config.home.homeDirectory}/.ssh/ephemeral_sshd/authorized_keys
  '';

  # TODO: consider
  # https://nest.pijul.com/yonkeltron/macOS-nix-config:main/ZLDSMIXK5XFW6.EIAAA
  # and
  # https://github.com/bgub/nix-macos-starter/tree/main

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
