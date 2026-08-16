# AGENTS.md

Repository of personal dotfiles managed via Nix (home-manager, nix-darwin, NixOS) + GNU Stow for legacy config files.

## Project Structure

```
flake.nix                    — Flake entrypoint: home/darwin/nixos configurations
hosts/                       — Per-machine config files
  deimos/                    — Linux server (NixOS machine + home-manager user)
  mars/                      — macOS laptop (nix-darwin machine + home-manager user)
  common/home.nix            — Per-user git config shared across hosts
modules/                     — Reusable exported modules
  home/*.nix                 — Shared home-manager modules (common, linux-headless, mac-portable)
  nixos/*.nix                — NixOS modules (linux-headless, linux-lxc, jailed-agy)
  darwin/*.nix               — nix-darwin modules (mac-portable)
migrated/                    — Raw dotfiles (.zshrc, .vimrc) managed by BOTH stow and home-manager
legacy/                      — Non-Nix config files managed purely via `stow legacy`
```

## Key Conventions

### Flake inputs span multiple Nix versions

The flake uses two nixpkgs sources: `nixpkgs` (nixos-unstable) for Linux, and `nixpkgs-mars` (nixpkgs-26.05-darwin) for macOS. The `darwin`, `home-manager-mars`, and `nix-homebrew` inputs all follow `-mars`. When the darwin-specific inputs are eventually dropped, the flake can be simplified (see comment at `flake.nix:52`).

### Dual-dotfile management

The `migrated/` and `legacy/` directories use GNU Stow to symlink files into `$HOME`. Home-manager also sources `migrated/.zshrc` and `migrated/.vimrc` at runtime via path detection — it checks for a local checkout first (`~/dotfiles/migrated/...`) before falling back to the Nix-built path. This allows live editing without rebuilding.

### Module resolution

Host-level files import shared modules in a chain rather than flat-merging:

- `hosts/<name>/home.nix` → imports `hosts/common/home.nix` at minimum
- `modules/home/linux-headless.nix` and `mac-portable.nix` both import `modules/home/common.nix`

### Secrets via `identities` input

The `fw_nix` input (`futureware-tech/nix`) provides an `identities` module used across all configurations. It exposes:

- `identities.users.${user}.sign.<keyname>.publicKey` — SSH signing keys
- `identities.getAccessKeys { user = ...; }` — authorized_keys for login
- `identities.getSigningEntries {}` — git signers file entries

These are passed via `specialArgs.primaryUser` and the `fw_nix.nixosModules.identities` import. Any host config that touches SSH keys or git signing depends on this.

### SOPS / AGE encryption

Secrets are encrypted with AGE using hardware-backed identities (Apple Secure Enclave, Yubikey). The identities file lives at `~/.config/sops/age/keys.txt` (Linux) or `~/Library/Application Support/sops/age/keys.txt` (macOS). Decryption only works on the hardware device; the identity files themselves are not sensitive.

### Jailed AGY wrapper

The `jailed-agy.nix` module wraps `antigravity-cli` in a sandbox via `jail.nix`. It's highly custom: sets up local pip/ruby/gem paths, forwards Nix vars, bind-mounts Nix store for `nix-shell`, and blocks root. If you need to add tools or adjust the jail, modify the combinator list there.

### macOS SSH agent is Secretive

On Mars (macOS), `SSH_AUTH_SOCK` points to the Secretive app socket manually (not a generic ssh-agent). This was a deliberate tradeoff: `ssh-agent-mux` doesn't work well with Secretive + YubiKey agent together. Commit signing keys use the `key::` SSH URI format (`gpg.format = "ssh"`).

### stateVersion immutability

Both `modules/nixos/linux-headless.nix` and `modules/darwin/mac-portable.nix` have `"Never change"` comments next to `system.stateVersion`. Do not modify these.

## Essential Commands

| Command                                      | Description                                                       |
| -------------------------------------------- | ----------------------------------------------------------------- |
| `nix flake check`                            | Run pre-commit hooks (nixfmt, dead code checks via git-hooks.nix) |
| `nix develop`                                | Enter dev shell with pre-commit hook packages available           |
| `home-manager switch --flake .#artem@deimos` | Apply home-manager config for deimos (Linux)                      |
| `home-manager switch --flake .#artem@mars`   | Apply home-manager config for mars (macOS)                        |
| `darwin-rebuild switch --flake .#mars`       | Apply nix-darwin config for mars                                  |
| `nixos-rebuild switch --flake .#deimos`      | Apply NixOS config for deimos                                     |
| `stow legacy`                                | Symlink non-Nix configs from `legacy/` into `$HOME`               |

### Pre-commit exclusions

The git-hooks.nix pre-commit check explicitly excludes `migrated/` and `legacy/` paths. Formatting tools only run on `.nix` files in `hosts/`, `modules/`, `flake.nix`, etc.

## Gotchas

- **Unused `with pkgs`** — `modules/nixos/linux-headless.nix:14` has an unnecessary `with pkgs; [...]` that nixd warns about but is left as-is since the `[` immediately after it makes the block valid. Consider removing when editing that file.
- **SSH_AUTH_SOCK in tmux** — The tmux config hardcodes `SSH_AUTH_SOCK=$HOME/.ssh/ssh_auth_sock`. On Linux this is a socket symlinked by home-manager; on macOS Secretive provides it. Changing this path breaks SSH inside tmux.
- **Home-assistant sshfs mount** — The deimos home config mounts a remote Home Assistant directory via sshfs. The `umount.fuse.sshfs` wrapper script in `linux-headless.nix` is required because of SUID restrictions on fusermount.
- **Direnv + nix-direnv** — Enabled globally; `.envrc` files use `use flake` to enter dev shells automatically.
- **Zsh loads from file, not Nix attrSet** — The `.zshrc` is sourced as a raw file path (not via `programs.zsh.initExtra`). Modifications to zsh behavior may need to go in either the Nix config (`initContent`) or the raw `migrated/.zshrc` depending on whether you want persistence outside Nix.
