{
  modulesPath,
  pkgs,
  lib,
  persistenceCommon,
  ...
}:
{
  imports = [
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];
  # Disable legacy channel behavior that lxc-container brings in via installer/cd-dvd/channel.nix.
  system.installer.channel.enable = false;

  environment.persistence.${persistenceCommon} = {
    directories = [
      "/var/lib/systemd"
      "/var/lib/nixos"
      "/var/lib/docker"
    ];
    files = [
      "/etc/machine-id"
    ];
  };
  systemd.tmpfiles.rules = [
    "d ${persistenceCommon}/etc/ssh 0755 root root -"
  ];
  services.openssh.hostKeys = [
    {
      path = "${persistenceCommon}/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];
  # rootfs on LXC is also a persistent mountpoint (requirement from Incus), so
  # the host should periodically clean it up using: incus rebuild --empty <vm>.
  #
  # Since rootfs is empty after container rebuild, for the first boot you have
  # to point LXC at the current init (instead of /sbin/init), by adding to the
  # "config:" section in "incus config edit <vm>":
  #   raw.lxc: lxc.init.cmd = /nix/var/nix/profiles/system/init
  #
  # The bootloader installer will later try to symlink it into /sbin/init (which
  # is what the next script prepares for), but that will be erased on the next
  # container rebuild anyway.
  system.activationScripts.bootloader-patch = {
    deps = [ "specialfs" ];
    text = ''
      # lxc-container.nix installBootloader/installInitScript will attempt to
      # symlink /sbin/init, so we have to create the parent directory.
      mkdir -p /sbin
    '';
  };
  system.activationScripts.users.deps = [ "bootloder-patch" ];
  # This is supposed to persist machine-id, but fails.
  systemd.services.systemd-machine-id-commit.enable = false;

  boot.kernel.sysctl = {
    # The default of 0..2^31-1 in systemd's 50-default.conf is not allowed
    # inside containers as it would include user IDs outside the namespace,
    # which defaults to 0..10^9 on Incus containers.
    "net.ipv4.ping_group_range" = "0 65535";
  };

  # Our VMs usually have sufficient RAM, prefer to extend SSD lifetime.
  boot.tmp.useTmpfs = lib.mkDefault true;

  # Host passes through /dev/nvidia* and mounts /run/opengl-driver
  environment.systemPackages = with pkgs; [
    (symlinkJoin {
      name = "nvidia-smi-wrapped";
      paths = [ linuxPackages.nvidiaPackages.dc.bin ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/nvidia-smi \
          --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib"
      '';
    })
    nvtopPackages.nvidia
  ];
}
