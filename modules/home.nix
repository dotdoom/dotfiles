{ pkgs, ... }:
{
  home.packages = with pkgs; [
    git
    vim
    stow
  ];

  programs.zsh = {
    enable = true;
    initContent = ''
      . ~/dotfiles/migrated/.zshrc

      # Outside NixOS, we need to load this manually. Same on MacOS, if
      # /etc/zshrc is reset to its default content (post-upgrade).
      if [ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      fi
    '';
  };

  programs.home-manager.enable = true;

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;

    config.global = {
      warn_timeout = "30s";
      hide_env_diff = true;
    };
  };

  home.stateVersion = "25.11"; # never modify
}
