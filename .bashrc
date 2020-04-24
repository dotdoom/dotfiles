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
HISTSIZE=100000
HISTFILESIZE=5000000
PROMPT_DIRTRIM=5
# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize
# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

##
## prompt games
##

PS1=''
if [[ "$TERM" == screen* ]]; then
	PS1='\[\033k\033\\\]'
fi

# DYNAMIC: first brace [ color depends on the exit code
PS1="$PS1"'$(if [ $? -eq 0 ]; then echo -ne "\[$BGreen\]"; else echo -ne "\[$BRed\]"; fi)['

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
if which X &>/dev/null; then
	PS1="$PS1\[$BGreen\]"
else
	PS1="$PS1\[$BRed\]"
fi
PS1="$PS1\h "

# DYNAMIC: wd bg is blue for symlinks
PS1="$PS1"'$([ -L "$PWD" ] && echo -ne "\[$On_Blue\]")'

# DYNAMIC: wd length < 6 (/, /etc, /usr, /var, /home etc) brings red wd name
PS1="$PS1"'$(if [ ${#PWD} -lt 6 ]; then echo -ne "\[$BRed\]"; else echo -ne "\[$BYellow\]"; fi)\w'

export GIT_PS1_SHOWDIRTYSTATE=1
export GIT_PS1_SHOWSTASHSTATE=1
PS1="$PS1\[$Color_Off\]\[$BGreen\]]\[$BBlue\]"'$(__git_ps1)'"\[$Color_Off\] \\$ "

export EDITOR=vim
export BROWSER=google-chrome
export PAGER='less -R -F -X -S -n -i -m'

export GOPATH="$HOME/src/go"

export PATH="$HOME/bin:$PATH"
if [ -d "$HOME/.gem/ruby" ]; then
	PATH="$(echo $HOME/.gem/ruby/*/bin | tr ' ' :):$PATH"
fi
if [ -d "$HOME/Android/Sdk" ]; then
	export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
	# ANDROID_HOME for https://issuetracker.google.com/issues/125138969.
	export ANDROID_HOME="${ANDROID_SDK_ROOT?}"
	PATH="$ANDROID_SDK_ROOT/tools:$ANDROID_SDK_ROOT/platform-tools:$PATH"
fi
for extras in \
	"$HOME/pkg/go/bin" \
	"$GOPATH/bin" \
	"$HOME/.local/bin" \
	"$HOME/.npm/bin" \
	"$HOME/.pub-cache/bin" \
	/usr/lib/dart/bin \
	"$HOME/pkg/flutter/bin" \
	; do
	[ -d "$extras" ] && PATH="$extras:$PATH"
done

export DOOMWADDIR=~/dist/games/doom/wad
export DE=generic
export PYTHONSTARTUP="$HOME/.pythonstartup"
# Disable legacy ncurses behavior.
export NCURSES_NO_UTF8_ACS=1

# Disable Wine creating application shortcuts and, most importantly, hijack
# file associations!
export WINEDLLOVERRIDES=winemenubuilder.exe=d

if [[ "$OSTYPE" == "darwin"* ]]; then
	export CLICOLOR=1
	alias ls='ls -hF'
else
	alias ls='ls -hF --color=auto'
	# treat directory name commands as cd. bash is super old on Mac and
	# does not support this option.
	shopt -s autocd
fi
alias pgrep='pgrep -lf'
alias crontab='crontab -i'
alias gmake='make'
alias nc='nc -vv'
alias snc='openssl s_client -connect '
alias vsnc='openssl s_client -showcerts -state -msg -debug -connect '
alias killall='killall -v -r'
alias scrot='scrot -e "mv \$f ~/Pictures/ 2>/dev/null" -cd 5'
alias grep='grep --line-buffered --color=auto'
alias fgrep='grep -Frn --color=always'
alias figrep='fgrep -i'
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
alias xo=xdg-open
alias ag='ag -C 2 --pager="$PAGER" --smart-case'
alias prepend-timestamp='gawk "{ print strftime(\"[%Y-%m-%d %H:%M:%S]\"), \$0; fflush() }"'
alias strace='strace -f -s 1024'
alias readelf='readelf -W'
alias curl_t='curl -w \
"# dnslookup: %{time_namelookup} | \
connect: %{time_connect} | \
appconnect: %{time_appconnect} | \
pretransfer: %{time_pretransfer} | \
starttransfer: %{time_starttransfer} | \
total: %{time_total} | \
size: %{size_download}\n"'
alias ssh-fp='echo /etc/ssh/ssh_host_*_key.pub | xargs -n1 ssh-keygen -l -f'
alias aplay_pcm='aplay -t raw -c 2 -r 44100 -f S16_LE'
alias logcat='adb logcat -v "color printable usec year zone" -T 10'

function git-remaster() {
	local need_stash="$(git status --porcelain)"
	if [ -n "${need_stash}" ]; then
		git stash --quiet --include-untracked || return 1
	fi
	# `git fetch origin master && git rebase origin/master` would also work,
	# but that's cumbersome (ex.: need to find out the name "origin") and
	# does not update local master branch itself, which is often desirable.
	git checkout --quiet master && \
		git pull --rebase && \
		git checkout --quiet - && \
		git rebase master
	if [ $? -eq 0 -a -n "${need_stash}" ]; then
		git stash pop --quiet
	fi
}

function git-recover() {
	echo 'This operation is destructive. Ctrl-C now.'
	read
	find .git/objects/ -size 0 -exec rm -f {} \;
	git fetch origin
	echo 'You may need to run:'
	echo 'git symbolic-ref HEAD refs/heads/mybranch'
}

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
alias gst='git status'
alias gamend='git commit -a --amend --no-edit && git push -f'
alias gnew='git fetch upstream && git co upstream/master -b'
alias greb='git fetch upstream && git rebase upstream/master'

# sudo
alias sudo='sudo -E '
alias su='su -m'

alias dev-docker='docker run --rm \
	--mount type=bind,source=$PWD,target=/home/build/project_src \
	--interactive --tty dasfoo/dev:latest'
alias backup-home-explore='eval "ncdu $(grep -A1 -- --exclude $HOME/bin/backup-home | tr -d \|)"'

# useful stuff
[ -z "$VIM_ORIGINAL" ] && VIM_ORIGINAL="$(which vim)"
function vim() {
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
			"$VIM_ORIGINAL" "$1"
		else
			echo 'this file will be opened with sudo'
			sudo "$VIM_ORIGINAL" "$1" || "$VIM_ORIGINAL" "$1"
		fi
	else
		"$VIM_ORIGINAL" $*
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

vind() {
	local target
	target="$1"
	shift
	find . -name "$target" -exec vim {} "$@" \; -quit
}

cod() { # colordiff replacement with git
	local gitarg file1 file2
	for arg; do
		gitarg="$gitarg $file1"
		file1="$file2"
		file2="$arg"
	done
	# git won't diff against a pipe, so a kind of workaround
	cat $file2 | git diff --no-prefix $gitarg --no-index "$file1" -
}

if [ -z "$SSH_AUTH_SOCK" ]; then
	if [[ $- == *i*  ]]; then
		eval `ssh-agent -s`
		trap 'kill $SSH_AGENT_PID' EXIT
	fi
fi

if [ -r ~/.bashrc_local ]; then
	. ~/.bashrc_local
fi

if [ -x "$(which dircolors 2>/dev/null)" ]; then
	eval $(dircolors)
fi

mosh-cleanup-by-count() {
	# kill all mosh-server processes except for the one that is a parent
	# (hopefully), and another 10 that have been recently started.
	/usr/bin/pgrep -u "$USER" mosh-server |
	grep -vx "$PPID" |
	head -c-1 |
	tr '\n' ',' |
	xargs -r -- \
		/bin/ps \
		--sort=start_time \
		-o pid= \
		-p |
	head -n -10 |
	xargs -r kill
}

mosh-cleanup-by-idle() {
	# kill mosh-server that are idle for more than 3 days.
	for tty in `
			w -sf |
			grep -E "^$USER" |
			grep -E "[3-9]days (mosh-server|-)" |
			cut -c 10-15`; do
		kill -9 `ps -o pid= -t $tty`
	done
}

case $- in
	*i*)
		bind 'set show-all-if-ambiguous on'
		bind 'TAB:menu-complete'
		# only with interactive non-sudo shell
		if [ -n "$SSH_CONNECTION" ] && [ -z "$SUDO_UID" ]; then
			if [ "$(parent)" != "screen" ]; then
				mosh-cleanup-by-idle
				screen -RR
			fi
		fi
		trap 'history -a' DEBUG
		;;
esac

# Remove duplicates from PATH.
export PATH="$(awk -v RS=: -v ORS=: '!arr[$0]++' <<<"$PATH" | head -1)"

# vim: ft=sh
