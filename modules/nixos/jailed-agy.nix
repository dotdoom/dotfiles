{
  pkgs,
  jail-nix,
  ...
}:
let
  jail = jail-nix.lib.init pkgs;
in
{
  environment.systemPackages = [
    # Should be started as "jailed-agy --dangerously-skip-permissions"
    (jail "jailed-agy" pkgs.antigravity-cli (
      with jail.combinators;
      [
        network
        time-zone
        no-new-session
        mount-cwd

        (readwrite (noescape "~/.gemini"))
        # The above is a stow-controlled symlink to the following.
        (readwrite (noescape "~/dotfiles/legacy/.gemini"))

        # Enable easy installation of pip packages in the current directory.
        (set-env "PYTHONPATH" (noescape "\"$PWD/.pip-packages\""))
        (set-env "PIP_TARGET" (noescape "\"$PWD/.pip-packages\""))
        (set-env "PIP_CACHE_DIR" (noescape "\"$PWD/.pip-cache\""))
        (set-env "PIP_BREAK_SYSTEM_PACKAGES" "1")

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
            python3Packages.pip
            esphome

            nix
          ]
        ))
      ]
    ))
  ];
}
