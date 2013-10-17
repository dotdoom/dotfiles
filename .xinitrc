#!/bin/sh

LOGS_DIR=.cache/awesome
mkdir -p $LOGS_DIR
exec >$LOGS_DIR/awesome.out 2>$LOGS_DIR/awesome.err

pulseaudio --start
xrdb -merge .Xresources
setxkbmap -layout "us,ru" -option "grp:caps_toggle,grp_led:caps,compose:ralt"
xset r rate 290 30

exec awesome
