# User and machine configs

## Installation

Step 1.

```
cd
git clone git@github.com:dotdoom/dotfiles.git
cd dotfiles
```

Step 2 - stow.

```
stow migrated
stow legacy
```

Step 2 - Nix.

```
nix run \
  --extra-experimental-features 'nix-command flakes' \
  home-manager/master -- \
    switch \
      --extra-experimental-features 'nix-command flakes' \
      --flake .#artem@deimos
```

## Layout

- `migrated`: files which are assets for home-manager, but can still be used to
  stow
- `legacy`: files to be placed under `$HOME` which are still under stow
- `hosts/*/{darwin,nixos,home}.nix`: personal machine nix configs
- `modules/{darwin,nixos,home}/*.nix`: exported nix configs

TODO: rename `migrated` to `assets` and create `exported` which would be the
exact mirror of nix-built configuration, but without nix (for machines where nix
can not be installed). That `exported` will then be used by stow.

## Security

Risks taken (disclaimer):

- hardware attestation (this documentation and some code lists almost precisely
  the hardware I use, and the way I use it)
- privacy (committing public keys technically allows verifying which servers I
  have access to).

### SSH client

- `.ssh/id_XXXXX`

  Static keys (stored in bitwarden). These have to be passphrase-protected when
  stored on a disk; use `ssh-keygen -p -f .ssh/id_XXXXX`.

  The use of these keys is expected to be low, but SSH may always fall back to
  it, in which case you have to remember and type the passphrase. Use
  `ssh-add -D` to remove unencrypted identity from memory afterwards. Saving a
  passphrase in keychain is possible, but using Security Enclave is recommended
  instead.

- Apple Security Enclave

  This is the most used but also most ephemeral key, because it's bound to a
  machine. It's provided by Secretive app acting as an SSH agent and the private
  key is stored in Apple Security Enclave on a MacBook, requiring a fingerprint
  touch on SSH.

- Yubikey

  Yubikey PIV can be used as Smart Card, requiring a daemon and PGP
  infrastructure. It's useful when a root entity is signing certificates from
  multiple Yubikey owners, i.e. in large enterprise.

  Another obstacle is that we already use Secretive as our SSH agent, and it
  doesn't mux well with Yubikey agent, see `mac-portable.nix` for details.

  Instead of PIV, we use FIDO2 slots on Yubikey to generate resident (i.e.
  stored solely on Yubikey itself) SSH keys using modern OpenSSH client built-in
  FIDO2 support. This doesn't need an agent or a background daemon. The lack of
  agent however means that these keys can not be forwarded to remote host for
  further SSH, Git signing or push.

  To generate a new key:

  ```
  ssh-keygen -t ed25519-sk -O resident -O verify-required
  # Omit "-O verify-required" to skip PIN; only if key is physically safe.
  # Add "-O no-touch-required" to skip touch.
  ```

  To restore "private key" files (remove `_rk` and drop them into `.ssh`):

  ```
  ssh-keygen -K
  ```

  To list or delete FIDO2 (and WebAuthn) credentials:

  ```
  ykman fido credentials list
  ykman fido credentials delete abcdef123
  ```

### SSH from VM

For trusted VMs, ssh-agent forwarding is configured in `.ssh/config.d/local`:

```
Host deimos
  ForwardAgent yes
```

### Commit signing

Use SSH keys (from Apple SE and Yubikey) to sign commits. Make sure to generate
a different set of keys for signing than the one you use for authentication, to
decouple authentication from authorization and reduce key leakage blast radius.
Add `-O application=ssh:git-signature` to mark the key for signing (personal
convention).

### AGE encryption

All files are encrypted using some sort of hardware. Using an on-disk key alone
is not sufficient.

Each of the AGE plugins generates and subsequently during decryption uses a
(usually not sensitive) identity, which contains metadata about how to access
the specific cryptography on underlying hardware. Use the plugin directly to
initialize the hardware:

- `age-plugin-se keygen --access-control any-biometry-or-passcode`
- `age-plugin-yubikey --generate`

The identities which can be used to decrypt the secrets for editing (i.e.
Yubikey PIV, Apple SE) are concatenated into a single file:

- MacOS: `~/Library/Application Support/sops/age/keys.txt`
- Linux: `~/.config/sops/age/keys.txt`

which is not secret. You can only decrypt the data on the device where Yubikey
is plugged into, or one that has Apple SE or a TPM.

For Yubikey, you can also retrieve the identity using `age-plugin-yubikey -i`,
feeding the output directly into the identities file. To manage a Yubikey:

```
# Disable unused features
$ ykman config nfc --disable OTP
$ ykman config usb --disable OTP

# Check what's already there; slot 9A can be used by `O=yubikey-agent`; we don't
# rely on that key at the moment, see SSH above
$ ykman piv info

# To delete a key (age-plugin-yubikey uses 82 for slot 1, 83 for slot 2 etc).
$ ykman piv certificates delete 82

# Fully reset (initialize).
$ ykman piv reset

# See Bitwarden for keys
$ ykman piv access change-pin
$ ykman piv access change-puk
```

### Remote decryption

There's an ephemeral SSH server configured in `.ssh/ephemeral_sshd` which will
listen on localhost. If you port-forward it to remote machine, it can be
configured to run certain binaries (age plugins) through a reverse SSH
connection, which enables the use of local hardware to decrypt remote secrets.
