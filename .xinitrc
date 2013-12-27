#!/bin/sh

LOGS_DIR=.cache/i3
mkdir -p $LOGS_DIR
exec >$LOGS_DIR/stdout.log 2>$LOGS_DIR/stderr.log

pulseaudio --start
xrdb -merge .Xresources
setxkbmap -layout "us,ru" -option "grp:caps_toggle,grp_led:caps,compose:ralt"
xset dpms 610 610 610
xset r rate 290 30

local i3status=~/.config/i3status/config
${i3status}.gen >$i3status

#xset +fp /usr/share/fonts/local
#xset fp rehash
# if this doesn't work, run mkfontdir there

(
	xautolock -locker '~/bin/screensaver start' -notify 5 -notifier '~/bin/screensaver notify 5' &
	dunst &
	# this pidfile is later used for screensaver
	echo $! >.cache/dunst.pid
	gtk-redshift &
	skype &
	psi-plus &
	nm-applet &
	pa-applet &
	clipit &
	clementine &
)

exec i3
