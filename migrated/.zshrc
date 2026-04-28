# Interactive shell.
export PATH="${HOME}/bin:${PATH}"

# Login shell, connected via SSH, interactive (implied by running in this file),
# not in a GNU screen session already and screen is installed: jump to an active
# screen session or start a new, UTF-8 capable.
#
# Since we exec right afterwards, there's no point in setting this shell up.
if [[ -o login ]]; then
	[ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] && \
		[ -z "$STY" ] && \
		which screen 2>/dev/null && \
		exec screen -URR
fi

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
	local action=switch target config cmd r_flake

	if (( $# == 0 )); then
		# Local deployment.
		if [[ "$OSTYPE" == darwin* ]]; then
			cmd=darwin-rebuild
			r_flake="darwin#darwin-rebuild"
		else
			cmd=nixos-rebuild
			r_flake="nixpkgs#nixos-rebuild"
		fi

		local run_cmd=($cmd)
		command -v "$cmd" >/dev/null 2>&1 || run_cmd=(nix run "$r_flake" --)
		sudo "${run_cmd[@]}" switch --flake . |& nom

		# home-manager switch if exists.
		local hm_conf="$(whoami)@$(hostname -s)"
		if [[ "$(nix eval --json ".#homeConfigurations" --apply "x: x ? \"$hm_conf\"" 2>/dev/null)" == "true" ]]; then
			local hm_run=(home-manager)
			command -v home-manager >/dev/null 2>&1 || hm_run=(nix run "home-manager#home-manager" --)
			"${hm_run[@]}" switch --flake .
		fi
		return
	fi

	# Remote deployment (always NixOS).
	if (( $# == 1 )); then
		target=$1
		shift
	else
		action=$1
		target=$2
		shift 2
	fi

	config=${${target#*@}%%.*}
	cmd=(nixos-rebuild)
	command -v nixos-rebuild >/dev/null 2>&1 || cmd=(nix run "nixpkgs#nixos-rebuild" --)

	"${cmd[@]}" "$action" --flake ".#$config" --target-host "$target" --sudo "$@" |& nom
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

# stderr redirect for if direnv is missing
eval "$(direnv hook zsh 2>/dev/null)"

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
PROMPT='${IN_NIX_SHELL}%(?..%F{red}%?%f )[%n@%m] %3~${vcs_info_msg_0_} %# '

# Expand aliases by the press of TAB.
zstyle ':completion:*' completer _expand_alias _complete _ignored

[ -r ~/.zshrc_local ] && source ~/.zshrc_local || true
