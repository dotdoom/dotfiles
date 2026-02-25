# At least have the following in .zshenv_local:
#   export GIT_AUTHOR_NAME='Alfred Muster'
#   export GIT_AUTHOR_EMAIL='test@example.com'
#   export GIT_COMMITTER_NAME="${GIT_AUTHOR_NAME?}"
#   export GIT_COMMITTER_EMAIL="${GIT_AUTHOR_EMAIL?}"
[ -r ~/.zshenv_local ] && source ~/.zshenv_local || true
