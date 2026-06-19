{
  config,
  lib,
  pkgs,
  jail-nix,
  primaryUser,
  ...
}:
let
  jail = jail-nix.lib.init pkgs;
  allPackages =
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
      python3Packages.pip
      esphome

      ruby
      go
      gcc
      gnumake
      pkg-config

      nix
    ]
    ++ config.programs.jailed-agy.extraPackages;
in
{
  options.programs.jailed-agy = {
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages to append to the jailed-agy environment.";
    };
  };

  config = {
    environment.systemPackages = [
      (jail "jailed-agy" pkgs.antigravity-cli (
        with jail.combinators;
        [
          network
          time-zone
          no-new-session
          mount-cwd

          # Enforce that the wrapper is not run as root/privileged user
          (add-runtime ''
            if [ "$(id -u)" -eq 0 ]; then
              echo "Error: jailed-agy must not be run as root/privileged user!" >&2
              exit 1
            fi
          '')

          # Automatically append --dangerously-skip-permissions to agy invocation
          (set-argv [
            "--dangerously-skip-permissions"
            (noescape "\"$@\"")
          ])

          (readwrite (noescape "~/.gemini"))
          # The above is a stow-controlled symlink to the following.
          (readwrite (noescape "~/dotfiles/legacy/.gemini"))

          # Enable easy installation of pip packages in the current directory.
          (set-env "PYTHONPATH" (noescape "\"$PWD/.pip-packages\""))
          (set-env "PIP_TARGET" (noescape "\"$PWD/.pip-packages\""))
          (set-env "PIP_CACHE_DIR" (noescape "\"$PWD/.pip-cache\""))
          (set-env "PIP_BREAK_SYSTEM_PACKAGES" "1")

          # Enable easy installation and persistence of RubyGems in the current directory.
          (set-env "GEM_HOME" (noescape "\"$PWD/.gem\""))

          # Enable easy installation and persistence of Go modules and caches in the current directory.
          (set-env "GOPATH" (noescape "\"$PWD/.go\""))
          (set-env "GOCACHE" (noescape "\"$PWD/.go-cache\""))

          # Preconfigure compiler and linker flags dynamically for all jail packages.
          # This allows compiling Ruby gems (e.g. ffi, which requires libffi) and Go packages
          # (e.g. YubiKey plugins, which require pcsclite) out-of-the-box.
          (set-env "PKG_CONFIG_PATH" (
            lib.concatStringsSep ":" (map (pkg: "${pkg.dev or pkg}/lib/pkgconfig") allPackages)
          ))
          (set-env "NIX_CFLAGS_COMPILE" (
            lib.concatStringsSep " " (map (pkg: "-isystem ${pkg.dev or pkg}/include") allPackages)
          ))
          (set-env "NIX_LDFLAGS" (
            lib.concatStringsSep " " (map (pkg: "-L${pkg.out or pkg}/lib") allPackages)
          ))

          # Mount system and user profiles so their packages are automatically available at runtime
          (try-ro-bind "/run/current-system/sw" "/run/current-system/sw")
          (try-ro-bind "/etc/profiles/per-user/${primaryUser}" "/etc/profiles/per-user/${primaryUser}")

          # Mount Nix files and directories to support nix-shell and Nix operations in jail
          (try-ro-bind "/nix/store" "/nix/store")
          (try-ro-bind "/nix/var/nix/daemon-socket" "/nix/var/nix/daemon-socket")
          (try-ro-bind "/nix/var/nix/profiles" "/nix/var/nix/profiles")
          (try-ro-bind "/etc/nix" "/etc/nix")
          (try-ro-bind "/etc/static" "/etc/static")

          # Forward Nix environment variables
          (try-fwd-env "NIX_REMOTE")
          (try-fwd-env "NIX_PATH")
          (try-fwd-env "NIX_SSL_CERT_FILE")

          (add-pkg-deps allPackages)

          # Prepend local project binary directories, system, and user bin paths to the jail's PATH.
          # Note: We place this after `add-pkg-deps` so that local paths take highest precedence.
          # We use explicit double quotes to allow bash to expand $PWD at runtime and handle spaces.
          (
            state:
            state
            // {
              env = state.env // {
                PATH =
                  if state.env ? PATH && state.env.PATH != "" then
                    "\"\$PWD/.gem/bin:\$PWD/.go/bin:\$PWD/.pip-packages/bin:/run/current-system/sw/bin:/etc/profiles/per-user/${primaryUser}/bin:${state.env.PATH}\""
                  else
                    "\"\$PWD/.gem/bin:\$PWD/.go/bin:\$PWD/.pip-packages/bin:/run/current-system/sw/bin:/etc/profiles/per-user/${primaryUser}/bin\"";
              };
            }
          )
        ]
      ))
    ];
  };
}
