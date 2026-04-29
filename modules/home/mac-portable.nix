{ pkgs, primaryUser, ... }:
{
  imports = [
    ./common.nix
  ];

  home.homeDirectory = "/Users/${primaryUser}";

  home.packages = with pkgs; [
    secretive
    vlc-bin

    # Faster and more feature-rich than Terminal.
    iterm2
  ];

  targets.darwin.defaults."com.googlecode.iterm2" = {
    # $ defaults read ~/Library/Preferences/com.googlecode.iterm2.plist

    # Allow tmux (and others) to use OSC 52 to set clipboard.
    AllowClipboardAccess = true;
    # Allow programs to clear scrollback.
    PreventEscapeSequenceFromClearingHistory = false;

    TripleClickSelectsFullWrappedLines = true;
    WordChars = "/-._~";
    PromptOnQuit = false;
  };
  home.file."Library/Application Support/iTerm2/DynamicProfiles/nix-profile.json".text =
    builtins.toJSON
      {
        Profiles = [
          {
            Name = "Nix-Managed";
            Guid = "17DF2CCB-C7CD-4BCC-AC28-666DD6C8AF4A";
            "Normal Font" = "Menlo-Regular 13";

            Columns = 160;
            Rows = 45;

            # For tmux selection and moving borders.
            "Mouse Reporting" = true;
          }
        ];
      };

  programs.zsh.envExtra = ''
    # If Secretive doesn't recognize your Yubikey PIV, it's possible you
    # generated it using yubikey-agent and that did not update CHUID. Simply
    # running 'ykman piv objects generate chuid' should be sufficient.
    # https://github.com/maxgoedjen/secretive/issues/333

    export SSH_AUTH_SOCK=~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
  '';

  nixpkgs.config.allowUnfree = true;
  programs.vscode.enable = true;
}
