# Global agent instructions

## Git

Never perform a git operation that modifies the repository or the working tree
without an explicit request from the user in this session. This includes, but is
not limited to:

- `git commit` (including `--amend` and empty commits)
- `git add`, `git stage`
- `git push`, `git tag`, `git remote` changes
- `git checkout`/`git switch`/`git restore`/`git reset`/`git stash`/`git clean`
- `git rebase`, `git merge`, `git cherry-pick`, `git revert`, `git rm`, `git mv`

Read-only git commands (`status`, `diff`, `log`, `show`, `blame`, `ls-files`,
`rev-parse`, `verify-commit`) are always fine.

The single exception is `git add -N` (`--intent-to-add`), which may be used
freely since it records no content.

When work is finished, leave the changes in the working tree and report them; do
not stage or commit them on your own initiative. If the user asks for a commit,
do exactly what was asked and nothing more (no push unless requested).

## Gitea

You can access local Git server using `tea` command.

## HomeAssistant

Use `hass-cli` command to acccess HomeAssistant.

## Signal

If it takes a long time (more than 10 minutes) to get a response, ping A. on
Signal when you arrive at a solution, or need user input.
