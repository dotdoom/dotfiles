#!/bin/sh

LOGS_DIR=.cache/awesome
mkdir -p $LOGS_DIR
exec >$LOGS_DIR/awesome.out 2>$LOGS_DIR/awesome.err

pulseaudio --start
xrdb -merge .Xresources
setxkbmap -layout "us,ru" -option "grp:caps_toggle,grp_led:caps,compose:ralt"
xset dpms 600 600 600
xset r rate 290 30

#xset +fp /usr/share/fonts/local
#xset fp rehash
# if this doesn't work, run mkfontdir there

(
	xautolock -locker slock &
	redshift &
	skype &
	chromium &
	psi-plus &
	nm-applet &
	clipit &
)

exec awesome
