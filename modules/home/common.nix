{
  pkgs,
  lib,
  primaryUser,
  ...
}:
{
  home.username = primaryUser;
  home.packages = with pkgs; [
    stow
    wget
    gemini-cli
    silver-searcher
    yubikey-manager
  ];
  home.activation.stowLegacy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d "$HOME/dotfiles" ]; then
      run ${pkgs.stow}/bin/stow -d $HOME/dotfiles -t $HOME legacy
    fi
  '';

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
        . ${../../migrated/.zshrc}
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

  programs.vim = {
    enable = true;
    plugins = with pkgs.vimPlugins; [
      auto-pairs
      ctrlp-vim
      dart-vim-plugin
      nerdcommenter
      nginx-vim
      supertab
      vim-javascript
      vim-lastplace
      vim-sensible
      vim-startify
    ];
    extraConfig = ''
      if filereadable(expand("~/dotfiles/migrated/.vimrc"))
        source ~/dotfiles/migrated/.vimrc
      else
        source ${../../migrated/.vimrc}
      endif
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

  programs.tmux = {
    enable = true;
    shortcut = "a"; # ^a
    escapeTime = 0;
    historyLimit = 10240;

    # hjkl HJKL and mouse to switch between and resize panels.
    mouse = true;
    keyMode = "vi";
    customPaneNavigationAndResize = true;

    extraConfig = ''
      set-environment -g SSH_AUTH_SOCK $HOME/.ssh/ssh_auth_sock
      set-option -g update-environment "DISPLAY SSH_ASKPASS SSH_AGENT_PID SSH_CONNECTION"

      # Instead of flashing or beeping, blink the window in status.
      set -g visual-bell off
      set -g monitor-activity on
      set -g bell-action none
      set -g window-status-activity-style "fg=yellow,blink"

      # Requires support from terminal (e.g. iTerm2).
      set -s set-clipboard on

      # For scrolling through logs.
      bind y set-window-option synchronize-panes

      # Panel configuration.
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind Enter resize-pane -Z

      # Navigation.
      bind -n M-Up new-window -c "#{pane_current_path}"
      bind -n M-Down confirm-before -p "kill-window #W? (y/n)" kill-window
      bind -n M-Left previous-window
      bind -n M-Right next-window

      # Status bar.
      set -g status-interval 5
      set -g status-position bottom
      set -g status-style "bg=default,fg=white"

      set -g status-left-length 20
      set -g status-left "#[fg=green,bold]#H #[fg=white]| "

      set -g status-right-length 60
      set -g status-right "#[fg=cyan]%H:%M %d.%m.%Y #[fg=white]| #[fg=yellow]Load: #(cut -d ' ' -f 1-3 /proc/loadavg)"

      set -g status-justify left
      set -g window-status-format "#[fg=white,dim]#I:#W#F"
      set -g window-status-current-format "#[fg=white,bold,bg=blue] #I:#W#F "
    '';
  };

  home.stateVersion = "25.11"; # never modify
}
