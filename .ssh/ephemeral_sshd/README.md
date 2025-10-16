User-local SSH server.

Remember to populate `authorized_keys`.

```shell
cd ~/.ssh/ephemeral_sshd/
ssh-keygen -t ed25519 -f ssh_host_ed25519_key -N ''
/usr/sbin/sshd -f sshd_config -D
```
