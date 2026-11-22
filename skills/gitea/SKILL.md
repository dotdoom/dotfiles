---
name: gitea
description: >-
  Interact with Gitea/Forgejo using the `tea` CLI: add reactions, reply
  in-place to inline PR review threads (`tea pr reply`), resolve review
  threads, post comments/reviews, and manage forks and PRs. Use whenever
  reading, reacting to, reviewing, or replying on Gitea issues or pull requests.
---

# Gitea Workflow (`tea` CLI)

Use `tea` for all Gitea interactions—it reads credentials and the server URL from its configured login (`--login local`, the default). Pass `--login local --repo OWNER/REPO` whenever outside a checkout or when multiple remotes exist.

## 1. Add Reactions (Acknowledge Immediately)

Standard reaction names: `eyes`, `+1`, `-1`, `laugh`, `hooray`, `confused`, `heart`, `rocket`.

- **React to a comment** (issue comment or inline PR review comment by `COMMENT_ID`):

```bash
tea api --login local -f content=eyes /repos/OWNER/REPO/issues/comments/COMMENT_ID/reactions
```

- **React to an issue or PR itself** (assignment, review request, or description mention):

```bash
tea api --login local -f content=eyes /repos/OWNER/REPO/issues/INDEX/reactions
```

## 2. Reply to an Existing Inline PR Review Thread

**ALWAYS** reply inside the existing thread with `tea pr reply`:

```bash
tea pr reply --login local --repo OWNER/REPO PULL_INDEX COMMENT_ID "Your reply"
```

- **NEVER** create a new review (`POST /pulls/.../reviews`) with `path`/`new_position` to answer an existing inline review comment—that opens a duplicate thread on the same line.
- List review comments and their IDs with:

```bash
tea pr review-comments --login local --repo OWNER/REPO PULL_INDEX -o json
```

## 3. Resolve / Unresolve an Inline PR Review Thread

```bash
tea pr resolve --login local --repo OWNER/REPO COMMENT_ID
tea pr unresolve --login local --repo OWNER/REPO COMMENT_ID
```

## 4. Top-Level Issue or PR Comments

```bash
tea comment --login local --repo OWNER/REPO INDEX "Your reply"
```

## 5. PR Reviews (Approve / Request Changes / New Inline Comments)

- Approve or request changes:

```bash
tea pr approve --login local --repo OWNER/REPO PULL_INDEX "Approval summary"
tea pr reject --login local --repo OWNER/REPO PULL_INDEX "Requested changes"
```

- For a review with **brand-new** inline comments (never for replying to an existing thread), pipe JSON to `tea api`:

```bash
jq -n --arg event COMMENT --arg commit HEAD_SHA --arg body "Summary" \
  --arg path "file.nix" --argjson line 42 --arg comment "Note" \
  '{event: $event, commit_id: $commit, body: $body, comments: [{path: $path, new_position: $line, body: $comment}]}' \
  | tea api --login local -d @- /repos/OWNER/REPO/pulls/PULL_INDEX/reviews
```

## 6. Forks & Pull Requests

```bash
tea repo fork --login local --repo OWNER/REPO
# Or with a custom fork name if a repo with the same name already exists:
tea api --login local -f name=custom-name /repos/OWNER/REPO/forks

tea pr create --login local --repo OWNER/REPO \
  --head BOT_USER:BRANCH --base main --title "Title" --description "Body"
```

## 7. Other API Calls

Use `tea api --login local` for any endpoint not covered by a dedicated `tea` subcommand (paths without `/api/` are prefixed with `/api/v1/`; `-f`/`-F`/`-d` default to `POST`):

```bash
tea api --login local /repos/OWNER/REPO/issues/INDEX/timeline
```
