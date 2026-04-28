{
  modulesPath,
  pkgs,
  pkgs-screen,
  trustedSSHKeys,
  jail-nix,
  ...
}:
let
  jail = jail-nix.lib.init pkgs;
in
{
  imports = [
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];
  # Disable legacy channel behavior that lxc-container brings in via installer/cd-dvd/channel.nix.
  system.installer.channel.enable = false;

  # Impermanence setup:
  # 1. There's no initrd/stage 1 in LXC container; /sbin/init is invoked after
  #    LXC finishes setting up special and user-configured filesystems. Any
  #    options in boot.initrd, as well as neededForBoot fileSystems won't be
  #    respected.
  # 2. Non-boot fileSystems (aka systemd) mount too late for systemd or nixos
  #    persistence to be instantiated, so we have to create this script below.
  # 3. The expectation from host is to mount /home and /nix. Root filesystem
  #    will also be a disk, as that's Incus requirement; the host should clean
  #    it up periodically using: "incus rebuild --empty <vm>".
  # 4. Since rootfs will be empty after rebuild, you have to point LXC at the
  #    current init (instead of /sbin/init), by adding to the "config:" section
  #    in "incus config edit <vm>":
  #      raw.lxc: lxc.init.cmd = /nix/var/nix/profiles/system/init
  system.activationScripts.persistence = {
    deps = [ "specialfs" ];
    text = ''
      persist() {
        local item="$1"
        local constructor="''${item%%:*}"
        local target="''${item#*:}"

        mkdir -p "$(dirname "$target")"
        $constructor "$target"

        if ! mountpoint -q "$target"; then
          local source="/home/persistent/$target"

          mkdir -p "$(dirname "$source")"
          $constructor "$source"

          mount --bind "$source" "$target"
        fi
      }

      for item in \
          "mkdir -p:/var/lib/nixos" \
          "mkdir -p:/var/lib/systemd" \
          "touch:/etc/machine-id" \
          "touch:/etc/ssh/ssh_host_ed25519_key" \
      ; do
        persist "$item"
      done

      chmod 0600 /etc/ssh/ssh_host_ed25519_key

      # lxc-container.nix installBootloader/installInitScript will attempt to
      # symlink /sbin/init, so we have to create the parent directory.
      mkdir -p /sbin
    '';
  };
  system.activationScripts.users.deps = [ "persistence" ];
  # This is supposed to persist machine-id, but fails.
  systemd.services.systemd-machine-id-commit.enable = false;

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
  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true;
  security.sudo.wheelNeedsPassword = false;

  virtualisation.docker.enable = true;

  documentation.man.enable = true;

  environment.systemPackages = with pkgs; [
    # TODO: clean this up against artem@deimos
    git
    pkgs-screen.screen
    sshfs

    # https://unix.stackexchange.com/questions/651165/using-systemd-to-mount-remote-filesystems-in-user-bus
    # Have to run the wrapper due to SUID.
    (pkgs.writeShellScriptBin "umount.fuse.sshfs" ''
      exec /run/wrappers/bin/fusermount -u "$1"
    '')

    file
    nixfmt
    nixd
    home-assistant-cli
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
