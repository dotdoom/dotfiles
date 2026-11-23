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
    google-chrome
    dosbox-staging # dosbox appears broken on darwin
    antigravity-cli
  ];

  programs.ssh.settings.deimos = {
    ForwardAgent = "yes";
    RemoteForward = "2222 localhost:2222";
  };

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
