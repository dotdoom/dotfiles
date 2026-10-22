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

  # Numtide's cache, so llm-agents packages come pre-built instead of compiling.
  nix.settings = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };

  nixpkgs.overlays = [
    (_: prev: {
      # Temporary workaround until upstream nixpkgs fix lands:
      # https://github.com/NixOS/nixpkgs/issues/569695
      ltrace = prev.ltrace.overrideAttrs (_: {
        doCheck = false;
      });
    })
  ];

  # For building RPi configs. Extra steps are handled by the host (nas).
  # https://discuss.linuxcontainers.org/t/systemd-binfmt-service-is-masked/21566/4
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  networking = {
    hostName = "deimos";
    domain = "home.arpa";
  };
}
