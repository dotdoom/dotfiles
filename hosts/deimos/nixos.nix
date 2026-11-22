{
  pkgs,
  identities,
  primaryUser,
  claude-plugin-sdd,
  ...
}:
{
  programs.traceroute.enable = true;

  # Spec-Driven Development skills for the remote-control agent. The trim is
  # lighter than the interactive jailed-agy config's: only report-friction is
  # dropped, since setup and backlog bookkeeping can still be useful remotely.
  programs.remote-agy.skillPlugins.claude-plugin-sdd = claude-plugin-sdd;
  programs.remote-agy.disabledSkills = [ "report-friction" ];
  programs.remote-agy.giteaSidecar.allowedUsers = [
    "artem"
    "katarina"
  ];

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

  # For building RPi configs. Extra steps are handled by the host (nas).
  # https://discuss.linuxcontainers.org/t/systemd-binfmt-service-is-masked/21566/4
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  networking = {
    hostName = "deimos";
    domain = "home.arpa";
  };
}
