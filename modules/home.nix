{ pkgs, ... }:
{
  home.packages = with pkgs; [
    git
    vim
    stow
    wget
  ];

  programs.zsh = {
    enable = true;
    initContent = ''
      # Outside NixOS, we need to load this manually. Same on MacOS, if
      # /etc/zshrc is reset to its default content (post-upgrade).
      if [ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      fi

      if [ -r ~/dotfiles/migrated/.zshrc ]; then
        . ~/dotfiles/migrated/.zshrc
      else
        # If no custom override is available, use the one bundled with flake.
        . ${../migrated/.zshrc}
      fi
    '';

    # At least have the following in .zshenv_local:
    #   export GIT_AUTHOR_NAME='Alfred Muster'
    #   export GIT_AUTHOR_EMAIL='test@example.com'
    #   export GIT_COMMITTER_NAME="${GIT_AUTHOR_NAME?}"
    #   export GIT_COMMITTER_EMAIL="${GIT_AUTHOR_EMAIL?}"
    envExtra = ''
      [ -r ~/.zshenv_local ] && source ~/.zshenv_local || true
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
