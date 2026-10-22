{
  config,
  pkgs,
  crush-src,
  ...
}:
{
  imports = [
    ../common/home.nix
  ];

  services.vscode-server.enable = true;
  services.vscode-server.installPath = [
    "$HOME/.vscode-server"
    "$HOME/.antigravity-server"
  ];

  home.packages = with pkgs; [
    sshfs
    nixd
    home-assistant-cli
    uv
    python3
    yt-dlp
    attic-client
    opencode
    (crush.overrideAttrs (_: {
      src = crush-src;
      version = crush-src.shortRev or "dirty";
      vendorHash = "sha256-CGPZLtOWmMksODDV45rJ7qaA1lJKpe5qVP0tyauAoxU=";
      doCheck = false;
    }))
  ];

  systemd.user.services.signal-cli = {
    Unit = {
      Description = "signal-cli daemon";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${pkgs.signal-cli}/bin/signal-cli daemon --tcp 127.0.0.1:7583 --receive-mode on-start --no-receive-stdout";
      Restart = "always";
      RestartSec = "10s";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.mercury-halogen-tunnel = {
    Unit = {
      Description = "SSH tunnel to the halogen API on mercury";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = ''
        ${pkgs.openssh}/bin/ssh -N -o BatchMode=yes \
          -o IdentityAgent=${config.home.homeDirectory}/.ssh/ssh_auth_sock \
          -o ControlMaster=no -o ControlPath=none \
          -o ExitOnForwardFailure=yes \
          -o StrictHostKeyChecking=yes \
          -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
          -L 127.0.0.1:8731:127.0.0.1:8731 \
          root@mercury.home.arpa
      '';
      Restart = "always";
      RestartSec = "5s";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
