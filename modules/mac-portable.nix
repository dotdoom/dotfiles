{ pkgs, primaryUser, ... }:
{
  nixpkgs.hostPlatform = "x86_64-darwin";
  nixpkgs.config.allowUnfree = true;

  system.primaryUser = primaryUser;
  users.users.${primaryUser} = {
    home = "/Users/${primaryUser}";
    shell = pkgs.zsh;
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    startup.chime = false;

    defaults = {
      loginwindow = {
        GuestEnabled = false;
        DisableConsoleAccess = true;
      };

      finder = {
        AppleShowAllFiles = true; # hidden files
        AppleShowAllExtensions = true; # file extensions
        _FXShowPosixPathInTitle = true; # title bar full path
        ShowPathbar = true; # breadcrumb nav at bottom
        ShowStatusBar = true; # file count & disk space
      };

      NSGlobalDomain = {
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = false;
      };
    };
  };

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true;

  nix-homebrew = {
    # Initial install of homebrew.
    enable = true;
    user = primaryUser;
    autoMigrate = true;
  };
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = false;
      upgrade = true;
    };
  };

  system.stateVersion = 6; # Never change.
}
