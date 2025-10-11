# Interactive shell.

# Login shell, connected via SSH, interactive (implied by running in this file),
# not in a GNU screen session already and screen is installed: jump to an active
# screen session or start a new, UTF-8 capable.
#
# Since we exec right afterwards, there's no point in setting this shell up.
case "$0" in -*)
	[ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] && \
		[ -z "$STY" ] && \
		which screen 2>/dev/null && \
		exec screen -URR
esac

HISTFILE=~/.zsh_history
# History in the file
HISTSIZE=10000
# History in RAM
SAVEHIST=10000
setopt appendhistory
setopt SHARE_HISTORY
# Self-explanatory
setopt hist_ignore_space
setopt hist_ignore_dups
# Remove older duplicates first
setopt hist_expire_dups_first
# Store timestamps
setopt EXTENDED_HISTORY

export EDITOR=vim
# Noticing this EDITOR setting, zsh will default to vim keybindings. No thanks.
bindkey -e
export PAGER='less -R -F -X -S -n -i -m'
export LESSCHARSET=utf-8
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
# To kill the ControlMaster session (e.g. to modify it or when it's stuck).
alias unssh='ssh -O exit'
alias ffmpeg_q='ffmpeg -hide_banner -nostats -loglevel warning'

alias curl_t='curl -w \
"# dnslookup: %{time_namelookup} | \
connect: %{time_connect} | \
appconnect: %{time_appconnect} | \
pretransfer: %{time_pretransfer} | \
starttransfer: %{time_starttransfer} | \
total: %{time_total} | \
size: %{size_download}\n"'

# nix-deploy # current host
# nix-deploy nas # deploy nas
# nix-deploy test secondary # deploy secondary but do not add to boot
nix-deploy() {
	ACTION=switch
	if [ $# -gt 1 ]; then
		ACTION=$1
		shift
	fi
	if which nixos-rebuild &>/dev/null; then
		COMMAND=(nixos-rebuild)
	else
		COMMAND=(nix run nixpkgs#nixos-rebuild --)
	fi
	if [ $# -gt 0 ]; then
		TARGET_HOST=$1 # user@host.domain
		TARGET_WITH_DOMAIN=${TARGET_HOST#*@} # host.domain
		TARGET=${TARGET_WITH_DOMAIN%%.*} # host
		shift
		"${COMMAND[@]}" "${ACTION?}" \
			--flake ".#${TARGET?}" \
			--target-host "${TARGET_HOST?}" \
			--use-remote-sudo \
			--fast "$@"
	else
		sudo "${COMMAND[@]}" switch --flake . --fast
	fi
}

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

if [ -z "$SSH_AUTH_SOCK" -a -z "$SSH_CLIENT" ]; then
	# This path is only needed in a local shell.
	#
	# In a screen session, we set SSH_AUTH_SOCK to a fixed path in
	# .screenrc before a shell is started.
	#
	# That fixed path is a symlink which gets updated by .ssh/rc scrtipt.
	eval `ssh-agent -s`
	trap 'ssh-agent -k' EXIT
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

# Expand aliases by the press of TAB.
zstyle ':completion:*' completer _expand_alias _complete _ignored

# At least have the following in .zshrc_local:
#   export GIT_AUTHOR_NAME='Alfred Muster'
#   export GIT_AUTHOR_EMAIL='test@example.com'
#   export GIT_COMMITTER_NAME="${GIT_AUTHOR_NAME?}"
#   export GIT_COMMITTER_EMAIL="${GIT_AUTHOR_EMAIL?}"
[ -r ~/.zshrc_local ] && source ~/.zshrc_local || true
