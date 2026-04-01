{
  modulesPath,
  pkgs,
  pkgs-screen,
  trustedSSHKeys,
  ...
}:
{
  imports = [
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];
  # Disable legacy channel behavior that lxc-container brings in via installer/cd-dvd/channel.nix.
  system.installer.channel.enable = false;

  # Incus config:
  # - keep root as-is (requirement from incus; just ignore it)
  # - add a disk for /home/artem
  # - add a disk for /nix
  # "incus config edit deimos" and add under "config:"
  #   raw.lxc: lxc.init.cmd = /nix/var/nix/profiles/system/init

  # TODO: persistence with SSH host keys, then automatically run
  #       "incus rebuild --empty deimos" periodically
  # Needs /sbin to be preset because bootloader installer uses that
  # path; consider either creating using systemd.tmpfiles or
  # overwriting bootloader installer / activation script.
  # https://github.com/NixOS/nixpkgs/blob/c080e09eaca35383aa8dd2be863b37c933ed8812/nixos/modules/virtualisation/lxc-container.nix#L105

  users.users.artem = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
    openssh.authorizedKeys.keys = trustedSSHKeys;
    shell = pkgs.zsh;
  };
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
    gemini-cli
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
