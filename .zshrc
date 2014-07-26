# zsh
zstyle ':completion:*' completer _complete _ignored _approximate
zstyle ':completion:*' max-errors 2
zstyle ':completion:*' menu select
zstyle ':completion:*' completealiases
zstyle :compinstall filename ~/.zshrc

autoload -Uz compinit
compinit
# End of lines added by compinstall
# Lines configured by zsh-newuser-install
export HISTFILE=~/.histfile
export HISTSIZE=10000
export SAVEHIST=$HISTSIZE
setopt hist_ignore_all_dups
unsetopt extendedglob
setopt autocd
setopt rmstarsilent
bindkey -e
bindkey "\e[1~" beginning-of-line # Home
bindkey "\e[4~" end-of-line # End
bindkey "\e[5~" beginning-of-history # PageUp
bindkey "\e[6~" end-of-history # PageDown
bindkey "\e[2~" quoted-insert # Ins
bindkey "\e[3~" delete-char # Del
bindkey "\e[5C" forward-word
bindkey "\eOc" emacs-forward-word
bindkey "\e[5D" backward-word
bindkey "\eOd" emacs-backward-word
bindkey "\e\e[C" forward-word
bindkey "\e\e[D" backward-word
bindkey "\e[Z" reverse-menu-complete # Shift+Tab
# for rxvt
bindkey "\e[7~" beginning-of-line # Home
bindkey "\e[8~" end-of-line # End
# for non RH/Debian xterm, can't hurt for RH/Debian xterm
bindkey "\eOH" beginning-of-line
bindkey "\eOF" end-of-line
# for freebsd console
bindkey "\e[H" beginning-of-line
bindkey "\e[F" end-of-line
# for guake
bindkey "\eOF" end-of-line
bindkey "\eOH" beginning-of-line
bindkey "^[[1;5D" backward-word
bindkey "^[[1;5C" forward-word
bindkey "\e[3~" delete-char # Del
# Search backwards and forwards with a pattern
bindkey -M vicmd '/' history-incremental-pattern-search-backward
bindkey -M vicmd '?' history-incremental-pattern-search-forward
# set up for insert mode too
bindkey -M viins '^R' history-incremental-pattern-search-backward
bindkey -M viins '^F' history-incremental-pattern-search-forward

#setopt share_history
setopt inc_append_history

autoload -U promptinit
promptinit
prompt clint

# title <tab_title> <window_title>
function title() {
	[ "$DISABLE_AUTO_TITLE" != "true" ] || return
	if [[ "$TERM" == screen* ]]; then
		print -Pn "\ek$1:q\e\\"
	elif [[ "$TERM" == xterm* ]] || [[ $TERM == rxvt* ]] || [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
		# Window title
		[ -n "$2" ] && print -Pn "\e]2;$2:q\a"
		# Tab title (gnome-terminal, konsole)
		print -Pn "\e]1;$1:q\a"
	fi
}

function terminal_title_at_prompt {
	# "pwd" in tab, "user@host: pwd" in window
	title "%15<..<%~%<<" "%n@%m: %~"
}

function terminal_title_on_command {
	title "$1" "$1"
}

__git_files () {
	_wanted files expl 'local files' _files
}

autoload -U add-zsh-hook
add-zsh-hook precmd  terminal_title_at_prompt
add-zsh-hook preexec terminal_title_on_command

alias -s avi=smplayer

source ~/.rc
