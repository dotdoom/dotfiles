{
  pkgs,
  identities,
  primaryUser,
  ...
}:
{
  programs.traceroute.enable = true;
  users.users.${primaryUser} = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
      "kvm"
    ];
    openssh.authorizedKeys.keys = identities.getAccessKeys { user = primaryUser; };
    shell = pkgs.zsh;
    linger = true; # Keep sshfs mounted even on logout.
  };

  virtualisation.docker.enable = true;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (_: prev: {
      # Temporary workaround until upstream nixpkgs fix lands:
      # https://github.com/NixOS/nixpkgs/issues/569695
      ltrace = prev.ltrace.overrideAttrs (_: {
        doCheck = false;
      });
    })
  ];

  programs.fuse.enable = true; # for ~/src/haremote mount

  # For building RPi configs. Extra steps are handled by the host (nas).
  # https://discuss.linuxcontainers.org/t/systemd-binfmt-service-is-masked/21566/4
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  networking = {
    hostName = "deimos";
    domain = "home.arpa";
  };
}
