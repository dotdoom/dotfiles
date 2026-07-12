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

    # 1. Move config file to /usr/local/etc/wireguard/wg0.conf
    # 2. sudo wg-quick up wg0
    wireguard-tools
    wireguard-go

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
}
