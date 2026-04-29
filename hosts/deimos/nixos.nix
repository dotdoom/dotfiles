{
  pkgs,
  trustedSSHKeys,
  jail-nix,
  ...
}:
let
  jail = jail-nix.lib.init pkgs;
in
{
  users.users.artem = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
    openssh.authorizedKeys.keys = trustedSSHKeys;
    shell = pkgs.zsh;
    linger = true; # Keep sshfs mounted even on logout.
  };

  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    # TODO: move below into hosts/deimos/home.nix
    sshfs
    nixd
    home-assistant-cli
    yt-dlp

    # jailed-gemini --yolo
    (jail "jailed-gemini" pkgs.gemini-cli (
      with jail.combinators;
      [
        network
        time-zone
        no-new-session
        mount-cwd

        (readwrite (noescape "~/.gemini"))
        # The above is a stow-controlled symlink to the following.
        (readwrite (noescape "~/dotfiles/legacy/.gemini"))

        (add-pkg-deps (
          with pkgs;
          [
            bashInteractive
            curl
            wget
            jq
            git
            which
            ripgrep
            gnugrep
            gnused
            gawkInteractive
            ps
            findutils
            gzip
            unzip
            gnutar
            diffutils
            coreutils
            procps

            python3

            nix
          ]
        ))
      ]
    ))
  ];

  # For building RPi configs. Extra steps are handled by the host (nas).
  # https://discuss.linuxcontainers.org/t/systemd-binfmt-service-is-masked/21566/4
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  networking = {
    hostName = "deimos";
    domain = "home.arpa";
  };
}
