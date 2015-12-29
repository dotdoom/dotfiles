. /etc/profile
# colors
. ~/.bash_colors

# bash history with time
export HISTTIMEFORMAT="%F %T "
# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth
# append to the history file, don't overwrite it
shopt -s histappend
# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=10000
HISTFILESIZE=500000
# treat directory name commands as cd
shopt -s autocd
# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize
# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

bind 'set show-all-if-ambiguous on'
bind 'TAB:menu-complete'

##
## prompt games
##

function title() {
	[ "$DISABLE_AUTO_TITLE" != "true" ] || return
	if [[ "$TERM" == screen* ]]; then
		echo -en "\033k"; echo -n "$1"; echo -ne "\033\\"
	elif [[ "$TERM" == xterm* ]] || [[ $TERM == rxvt* ]] || [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
		# Window title
		[ -n "$2" ] && echo -en "\033]2;"; echo -n "$2"; echo -en "\a"
		# Tab title (gnome-terminal, konsole)
		echo -en "\033]1;"; echo -n "$1"; echo -en "\a"
	fi
}

# DYNAMIC: first brace [ color depends on the exit code
PS1='$(if [ $? -eq 0 ]; then echo -ne "\[$BGreen\]"; else echo -ne "\[$BRed\]"; fi)['

# STATIC: username color depends on UID
if [ $UID -eq 0 ]; then
	PS1="$PS1\[$BRed\]"
else
	PS1="$PS1\[$BGreen\]"
fi
PS1="$PS1\u\[$BGreen\]"

# STATIC: @ color depends on session (X11/console)
if [ -z "$DISPLAY" ]; then
	PS1="$PS1\[$BRed\]"
else
	PS1="$PS1\[$BGreen\]"
fi
PS1="$PS1@"

# STATIC: hostname depends on Xorg installed (w/o Xorg looks like headless, thus RED)
if which X >/dev/null 2>&1; then
	PS1="$PS1\[$BGreen\]"
else
	PS1="$PS1\[$BRed\]"
fi
PS1="$PS1\h "

# DYNAMIC: wd bg is blue for symlinks
PS1="$PS1"'$(if [ -L "$PWD" ]; then echo -ne "\[$On_Blue\]"; fi)'

# DYNAMIC: pwd in title
PS1="$PS1"'\[$(title \W)\]'

# DYNAMIC: wd length < 6 (/, /etc, /usr, /var, /home etc) brings red wd name
PS1="$PS1"'$(if [ ${#PWD} -lt 6 ]; then echo -ne "\[$BRed\]"; else echo -ne "\[$BGreen\]"; fi)\W'

PS1="$PS1\[$Color_Off\]\[$BGreen\]]"'$git_branch$git_dirty'"\\$\[$Color_Off\] "

export EDITOR=vim
export BROWSER=chromium
export PAGER='less -R -F -X -S -n -i -m'

export GOPATH=~/src/go
export GOROOT=~/pkg/go
export PATH="$HOME/bin:$PATH:$GOROOT/bin:$GOPATH/bin"
if [ -d $HOME/.gem/ruby ]; then
	export PATH="$PATH:$(echo $HOME/.gem/ruby/*/bin | tr ' ' :)"
fi
export DOOMWADDIR=~/dist/games/doom/wad
export DE=generic
export CLICOLOR=1

alias ls='ls -hF --color=auto'
alias pgrep='pgrep -lf'
alias crontab='crontab -i'
alias gmake='make'
alias nc='nc -vv'
alias snc='openssl s_client -connect '
alias vsnc='openssl s_client -showcerts -state -msg -debug -connect '
alias killall='killall -v -r'
alias scrot='scrot -e "mv \$f ~/Pictures/ 2>/dev/null" -cd 5'
alias qiv='qiv -fml -M'
alias qivr='qiv -u'
alias grep='grep --line-buffered --color=auto'
alias fgrep='grep -Frn --color=always'
alias figrep='fgrep -i'
alias svn='svn --no-auth-cache'
alias mysql='mysql --select_limit=1000'
alias ka='killall'
alias fsck='fsck -C'
alias pager=$PAGER
alias npager='pager -N'
alias l='ls -lA'
alias ll='ls -la'
alias la='cat /proc/loadavg'
alias ipt='iptables -nvL --line-numbers'
alias ip6t='ip6tables -nvL --line-numbers'
alias psa='ps axfo pid,euser,bsdstart,vsz,rss,bsdtime,args'
alias parent='ps -p $PPID -o comm='
alias dbgrep='dbgrep.pl -vpuroot'
alias tcpdump='tcpdump -l'
alias pacman='pacman --color auto'
alias xo=xdg-open
alias ag='ag -C 2 --pager="$PAGER" --smart-case'
alias prepend-timestamp='gawk "{ print strftime(\"[%Y-%m-%d %H:%M:%S]\"), \$0; fflush() }"'
alias strace='strace -f -s 1024'
alias readelf='readelf -W'

function ds() {
	du -sh "$@" | sort -rh
}

function i4() {
	if [ $# -eq 0 ]; then
		curl --silent http://ipecho.net/plain; echo
	else
		ip addr show "$1" | sed -nr 's/\s+inet ([0-9.]+)\/.*/\1/p'
	fi
}

# mysqldump extraction
function mysql_extract_db() {
	sed -n "/^-- Current Database: \`$1\`/,/^-- Current Database: \`/p"
}
function mysql_extract_table() {
	sed -n "/^-- Table structure for table \`$1\`/,/^-- Table structure for table \`/p"
}

# LOL protect me
alias mv='mv -i'
alias cp='cp -i'
alias rm='rm -i'

# git aliases
alias gb='git branch'
alias gba='git branch -av'
alias gc='git commit -v'
alias gd='git di'
alias gdc='gd --cached'
alias gdm='gd master --stat --relative'
alias gl='git pull'
alias gp='git push'
alias gst='git status'

# sudo
alias sudo='sudo -E '
alias su='su -m'

# useful stuff
[ -z "$VIM_ORIGINAL" ] && VIM_ORIGINAL="$(which vim)"
function vim() {
	if [ "$TERM" = "linux" ]; then
		local COMPAT_TERM=$TERM
	else
		local COMPAT_TERM="xterm-256color"
	fi
	# we only handle single-argument VIM
	if [ $# -eq 1 ]; then
		if [ -e "$1" ]; then
			# editing an existing file
			FILENAME="$1"
		else
			# trying to create new file, will check it's directory for WRITE access
			FILENAME="`dirname $1 2>/dev/null`"
		fi

		if [ -w "$FILENAME" ]; then
			# yahoo! writable
			TERM=$COMPAT_TERM "$VIM_ORIGINAL" "$1"
		else
			echo 'this file will be opened with sudo'
			TERM=$COMPAT_TERM sudo "$VIM_ORIGINAL" "$1" || "$VIM_ORIGINAL" "$1"
		fi
	else
		TERM=$COMPAT_TERM "$VIM_ORIGINAL" $*
	fi
}

function dl() {
	for entry in "$@"; do
		printf '%-7d %s\n' $(find $entry | wc -l) "$entry"
	done | sort -rn
}

function mkcd() {
	mkdir -p "$@"
	cd "$@"
}
function cpcd() {
	cp "$@"
	cd $_
}
function cdls() {
	cd "$1"
	shift
	ls "$@"
}

function fin() {
	local filename="$1"
	find . -iname "*$filename*"
}

function tt() {
	tail -f "$@" | prepend-timestamp
}

function ip4tables-fwd() {
	if [ $# -eq 1 ]; then
		local SRC_ADDR="$(i4)"
		local DST_ADDR="$1"
	elif [ $# -eq 2 ]; then
		local SRC_ADDR="$1"
		local DST_ADDR="$2"
	else
		echo "Usage: $0 [<src-addr:src-port>] <dst-addr:dst-port>" >&2
		return 1
	fi

	local SRC_HOST=${SRC_ADDR/:*/}
	if [ "$SRC_HOST" != "$SRC_ADDR" ]; then
		local SRC_PORT=${SRC_ADDR/*:/}
	fi

	local DST_HOST=${DST_ADDR/:*/}
	if [ "$DST_HOST" = "$DST_ADDR" ]; then
		if [ -z "$SRC_PORT" ]; then
			echo "Cannot detect forwarding port. At least one address must have it's port specified." >&2
			return 1
		fi
		local DST_PORT=$SRC_PORT
	else
		local DST_PORT=${DST_ADDR/*:/}
	fi

	[ -z "$SRC_PORT" ] && local SRC_PORT=$DST_PORT

	echo "To forward <$SRC_HOST> port <$SRC_PORT> to <$DST_HOST> port <$DST_PORT>:
iptables -t nat -A PREROUTING  -d $SRC_HOST -p tcp --dport $SRC_PORT -j DNAT --to-destination $DST_HOST:$DST_PORT
iptables -t nat -A POSTROUTING -d $DST_HOST -p tcp --dport $DST_PORT -j SNAT --to-source $SRC_HOST
"
}

if [ -r ~/.bashrc_local ]; then
	. ~/.bashrc_local
fi

if [ -x "$(which dircolors 2>/dev/null)" ]; then
	eval $(dircolors)
fi

case $- in
	*i*)
		# only with interactive non-sudo shell
		if [ -n "$SSH_CONNECTION" ] && [ -z "$SUDO_UID" ]; then
			[ "$(parent)" = "screen" ] || screen -RR
		fi
		;;
esac

trap 'title "$BASH_COMMAND"' DEBUG

# vim: ft=sh
