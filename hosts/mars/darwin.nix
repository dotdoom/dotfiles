_: {
  homebrew.casks = [
    "bambu-studio"

    # Not available in nixpkgs-26.05, and latest doesn't support x86_64-darwin
    "antigravity-cli"
  ];
  homebrew.brews = [
    "libimobiledevice"
    "ideviceinstaller"
  ];
}
