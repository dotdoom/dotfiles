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

### 4. Start Daemon

```bash
sudo systemctl restart antigravity-remote-control
```

Logs: `journalctl -u antigravity-remote-control -f` and `~${USER}-agent/.gemini/antigravity/sidecar_data/gitea/logs/sidecar.log`.

## When the Gitea Sidecar Wakes the Agent

Every trigger must come from a user in `programs.remote-agy.giteaSidecar.allowedUsers` (when non-empty) and not from the agent itself.

### Always wakes (open, closed, or merged)

- **Direct `@mention`** of the agent in an issue/PR body (first time seen), issue/PR comment, PR review summary, inline PR review comment, or commit comment.

### Open issues and PRs only

- **Assignment or review request**: fires once when the agent becomes an assignee or requested reviewer (the actor who assigned/requested it is verified against `allowedUsers`).
- **Threads owned by or assigned to the agent** (author, assignee, or requested reviewer):
  - Any new top-level comment.
  - Any new PR review with a body or state `REQUEST_CHANGES` / `REQUEST_REVIEW`.
  - Any new inline PR review comment.
- **Someone else's issue/PR where the agent already participated**:
  - Any new top-level comment, if the agent previously posted a top-level comment on that thread.
  - Any new inline PR review comment inside an inline review thread where the agent previously commented.

### Explicitly ignored

- Comments or reviews that `@mention` other user(s) without mentioning the agent (mentions inside code blocks/backticks, emails, and `@scope/pkg` paths are ignored).
- Unrelated PR reviews (`REQUEST_CHANGES` or new inline threads) on someone else's PR that do not `@mention` the agent.
- Pending (unsubmitted) PR reviews, and empty `APPROVED`/`COMMENT` reviews without inline comments.
- Threads older than 1 hour on cold start (seeded as seen without triggering).
