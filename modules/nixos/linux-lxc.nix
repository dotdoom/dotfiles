{
  modulesPath,
  pkgs,
  ...
}:
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

  # unprivileged LXCs can't set net.ipv4.ping_group_range
  security.wrappers.ping = {
    owner = "root";
    group = "root";
    capabilities = "cap_net_raw+p";
    source = "${pkgs.iputils.out}/bin/ping";
  };
}
