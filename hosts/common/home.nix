{
  identities,
  primaryUser,
  ...
}:
let
  user = identities.users.${primaryUser};
in
{
  programs.git = {
    signing = {
      # Will be available on remote machines via SSH agent (Secretive).
      key = "key::" + user.sign."sign@mars".publicKey;
      signByDefault = true;
    };

    settings.user = {
      name = "Artem Sheremet";
      inherit (user) email;
    };
  };
}
