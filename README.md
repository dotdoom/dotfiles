Step 1.

```
cd
git clone git@github.com:dotdoom/dotfiles.git
cd dotfiles
git submodule update --init
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
      --flake .#artem
stow legacy
```
