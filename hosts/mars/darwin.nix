{ pkgs, primaryUser, ... }:
{
  nixpkgs.hostPlatform = "x86_64-darwin";
  nixpkgs.config.allowUnfree = true;

  system.primaryUser = primaryUser;

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true;

  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };
    casks = [
      "bambu-studio"
    ];
  };

  users.users."${primaryUser}" = {
    name = primaryUser;
    home = "/Users/${primaryUser}";
  };

  system.stateVersion = 6; # Never change.
}
