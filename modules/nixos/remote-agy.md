# Remote Antigravity Agent Setup

Step-by-step initial setup for `${primaryUser}-agent` (e.g. `artem-agent`):

### 1. Generate Gitea Token

1. Go to [https://git.sheremet.ch/-/admin/users/](https://git.sheremet.ch/-/admin/users/)
2. Open or create user `${primaryUser}-agent`
3. Generate an access token with `repo` and `write:user` scopes

### 2. Save Token

```bash
sudo su - ${USER}-agent
mkdir -p ~/.config
echo "<TOKEN>" > ~/.config/gitea-token
chmod 600 ~/.config/gitea-token
```

### 3. Authenticate Antigravity

While still logged in as `${USER}-agent`:

```bash
antigravity
```

Complete the OAuth flow in the browser, then exit (`/exit`).

### 4. Start Daemon

```bash
sudo systemctl restart antigravity-remote-control
```

SSH transport key, verified GPG signing key, and Gitea registration are configured automatically on startup.
