{
  config,
  pkgs,
  crush-src,
  llm-agents,
  claude-plugin-sdd,
  ...
}:
let
  # All 22 SDD skills cost ~1.5k prompt tokens on every request, whether used
  # or not. These four are one-time setup or upstream-feedback chores that
  # should never trigger from a normal session, so they are dropped from the
  # always-on list. The rest stay: they are the actual SDD workflow.
  sddTrimmedSkills = [
    "init"
    "report-friction"
    "enrich"
    "organize"
  ];
in
{
  imports = [
    ../common/home.nix
    ../../modules/home/skill-plugins.nix
  ];

  # Spec-Driven Development skills (ADRs, specs, sprint planning). Pinned by
  # the flake input, so a rebuild moves them, not a git pull. Here Antigravity
  # is only ever run through the jail, so the plugins go to that namespace.
  programs.crush.skillPlugins.claude-plugin-sdd = claude-plugin-sdd;
  programs.jailed-agy.skillPlugins.claude-plugin-sdd = claude-plugin-sdd;

  programs.crush.disabledSkills = sddTrimmedSkills;
  programs.jailed-agy.disabledSkills = sddTrimmedSkills;

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
    tea
    llm-agents.packages.${pkgs.system}.qmd
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
