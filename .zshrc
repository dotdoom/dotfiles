# Interactive shell.

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt SHARE_HISTORY
setopt hist_ignore_space

export EDITOR=vim
# Noticing this EDITOR setting, zsh will default to vim keybindings. No thanks.
bindkey -e
export PAGER='less -R -F -X -S -n -i -m'
export PYTHONSTARTUP="$HOME/.pythonstartup"
export NCURSES_NO_UTF8_ACS=1
# For ls.
export CLICOLOR=1
# For dark terminal backgrounds.
export LSCOLORS=HxFxCxDxBxEgEdHbHgHcHd

# Looking for more environment variables? Check out .zshenv!

alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'
alias crontab='crontab -i'

alias gb='git branch'
alias gba='git branch -a'
alias gc='git commit -v'
alias gd='git diff'
alias gdc='git diff --cached'
alias gst='git status'

alias sudo='sudo -E '
alias su='su -m'

alias pager=$PAGER
alias grep='grep --line-buffered --color=auto'
alias ipt='iptables -nvL --line-numbers'
alias ip6t='ip6tables -nvL --line-numbers'
alias tcpdump='tcpdump -l'
alias ag='ag -C 2 --pager="$PAGER" --smart-case'
alias mysql='mysql --select_limit=1000'
alias logcat='adb logcat -v "color printable usec year zone" -T 10'
alias readelf='readelf -W'
alias l='ls -lA'
alias ll='ls -la'

alias curl_t='curl -w \
"# dnslookup: %{time_namelookup} | \
connect: %{time_connect} | \
appconnect: %{time_appconnect} | \
pretransfer: %{time_pretransfer} | \
starttransfer: %{time_starttransfer} | \
total: %{time_total} | \
size: %{size_download}\n"'

myip() {
	if [ $# -eq 0 ]; then
		curl -4 --silent http://ipecho.net/plain; echo
		curl -6 --silent http://ipecho.net/plain; echo
	else
		ip addr show "$1" | sed -nr 's/\s+inet ([0-9.]+)\/.*/\1/p'
	fi
}

colordiff() {
	local gitarg file1 file2
	for arg; do
		gitarg="$gitarg $file1"
		file1="$file2"
		file2="$arg"
	done
	# git won't diff against a pipe, so a kind of workaround
	cat "$file2" | git diff --no-prefix $gitarg --no-index "$file1" -
}

alias backup-home-explore='eval "ncdu $(grep -A1 -- --exclude $HOME/bin/backup-home | tr -d \|)"'

if [ -z "$SSH_AUTH_SOCK" ]; then
	eval `ssh-agent -s`
	trap 'kill $SSH_AGENT_PID' EXIT
fi

autoload -Uz vcs_info
precmd_functions+=( vcs_info )
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' stagedstr '%F{green}*%f'
zstyle ':vcs_info:*' unstagedstr '%F{red}*%f'
zstyle ':vcs_info:git:*' formats ' (%F{cyan}%b%f%c%u)'
setopt prompt_subst
PROMPT='%(?..%F{red}%?%f )[%n@%m] %3~${vcs_info_msg_0_} %# '

# At least have the following in .zshrc_local:
#   export GIT_AUTHOR_NAME='Alfred Muster'
#   export GIT_AUTHOR_EMAIL='test@example.com'
#   export GIT_COMMITTER_NAME="${GIT_AUTHOR_NAME?}"
#   export GIT_COMMITTER_EMAIL="${GIT_AUTHOR_EMAIL?}"
[ -r ~/.zshrc_local ] && source ~/.zshrc_local || true
