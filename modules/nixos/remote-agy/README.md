# Remote Antigravity Agent Setup

Step-by-step initial setup for `${primaryUser}-agent` (e.g. `artem-agent`):

### 1. Generate Gitea Token

1. Go to [https://git.sheremet.ch/-/admin/users/](https://git.sheremet.ch/-/admin/users/)
2. Open or create user `${primaryUser}-agent`
3. Generate an access token with `repo`, `write:user`, and `write:notification` scopes

### 2. Save Token

```bash
sudo su - ${USER}-agent
mkdir -p ~/.config
echo "<TOKEN>" > ~/.config/gitea-token
chmod 600 ~/.config/gitea-token
```

### 3. Authenticate Antigravity

While still logged in as `${USER}-agent` over SSH:

```bash
remote-agy-server
```

Open the printed Google OAuth URL in your browser, paste the final redirect URL back into the terminal, then press `Ctrl+C`.

> Upgrading from `antigravity-cli`: `remote-agy-setup` migrates conversations and copies the OAuth token automatically on first start. If token refresh fails afterward, delete `~/.gemini/jetski-standalone-oauth-token` and re-run `remote-agy-server`.

### 4. Start Daemon

```bash
sudo systemctl restart antigravity-remote-control
```

Logs: `journalctl -u antigravity-remote-control -f` and `~${USER}-agent/.gemini/antigravity/sidecar_data/gitea/logs/sidecar.log`.
