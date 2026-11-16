# Shared between modules/home/skill-plugins.nix (home-manager, per-user) and
# modules/nixos/remote-agy.nix (NixOS, per-service). Both register skill
# directories with Antigravity through the same skills.json manifest shape, so
# the pruning logic lives here once.
{ lib, pkgs }:
let
  # A skill resolves `${CLAUDE_PLUGIN_ROOT}` by walking two levels up from its
  # own SKILL.md, so these have to stay siblings in the deployed tree. The rest
  # of a plugin checkout (docs, CI, evals) is dead weight in the closure.
  pluginPaths = [
    "skills"
    "references"
    "templates"
    "scripts"
    "LICENSE"
  ];

  preparePlugin =
    name: src:
    pkgs.runCommand "skill-plugin-${name}" { } ''
      mkdir -p "$out"
      for path in ${lib.concatStringsSep " " pluginPaths}; do
        if [ -e "${src}/$path" ]; then
          cp -R "${src}/$path" "$out/"
        fi
      done
      if [ ! -d "$out/skills" ]; then
        echo "skillPlugins: plugin '${name}' has no skills/ directory" >&2
        exit 1
      fi
      # A source tree can carry a committed or build-time __pycache__, which
      # arrives read-only (the store is) and cp -R keeps that mode, so rm -rf
      # would fail. Re-open the copy before pruning.
      chmod -R u+w "$out"
      find "$out" -name __pycache__ -prune -exec rm -rf {} +
    '';

  skillDirs = lib.mapAttrsToList (name: src: "${preparePlugin name src}/skills");

  # Antigravity's global customization root takes a manifest of extra skill
  # directories instead of a search path. One entry per plugin, with per-entry
  # `exclude` so the trim never touches default-discovered skills: a top-level
  # `exclude` applies only to configured paths, never to default-discovered
  # ones, and per-entry scoping keeps the trim from also filtering a personal
  # skill that shares a name.
  mkAgyManifestJson =
    {
      paths,
      exclude ? [ ],
    }:
    builtins.toJSON {
      entries = map (
        path:
        {
          inherit path;
        }
        // lib.optionalAttrs (exclude != [ ]) {
          exclude = lib.unique exclude;
        }
      ) paths;
    };

  mkAgyManifest =
    {
      name ? "agy-skills",
      paths,
      exclude ? [ ],
    }:
    pkgs.writeText "${name}.json" (mkAgyManifestJson {
      inherit paths exclude;
    });

  # agy can only exclude skills reached through a manifest entry, so a trim
  # with no plugins has nothing to act on.
  trimNeedsPluginsAssertion =
    {
      optionNames,
      disabled,
      paths,
    }:
    {
      assertion = disabled == [ ] || paths != [ ];
      message = ''
        ${optionNames} name [${lib.concatStringsSep " " disabled}], but no
        skillPlugins are set. Antigravity can only exclude skills reached
        through a skillPlugins entry; there is no way to trim
        default-discovered skills. Remove the disabled names or add a plugin.
      '';
    };
in
{
  inherit
    preparePlugin
    skillDirs
    mkAgyManifest
    mkAgyManifestJson
    trimNeedsPluginsAssertion
    ;
}
