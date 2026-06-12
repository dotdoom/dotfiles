{
  pkgs,
  identities,
  primaryUser,
  ...
}:
{
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

  environment.systemPackages = with pkgs; [
    # TODO: move below into hosts/deimos/home.nix
    sshfs
    nixd
    home-assistant-cli
    yt-dlp
  ];

  # For building RPi configs. Extra steps are handled by the host (nas).
  # https://discuss.linuxcontainers.org/t/systemd-binfmt-service-is-masked/21566/4
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  networking = {
    hostName = "deimos";
    domain = "home.arpa";
  };
}
