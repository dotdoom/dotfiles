# colors
. ~/.bash_colors

# bash history with time
export HISTTIMEFORMAT="%F %T "

##
## prompt games
##

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

# DYNAMIC: wd length < 6 (/, /etc, /usr, /var, /home etc) brings red wd name
PS1="$PS1"'$(if [ ${#PWD} -lt 6 ]; then echo -ne "\[$BRed\]"; else echo -ne "\[$BGreen\]"; fi)\W'

PS1="$PS1\[$Color_Off\]\[$BGreen\]]\\$\[$Color_Off\] "

source ~/.rc
