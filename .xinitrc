#!/bin/sh

LOGS_DIR=.cache/xinit
mkdir -p $LOGS_DIR
mv $LOGS_DIR/stdout.log $LOGS_DIR/stdout.log.old 2>/dev/null
mv $LOGS_DIR/stderr.log $LOGS_DIR/stderr.log.old 2>/dev/null
exec >$LOGS_DIR/stdout.log 2>$LOGS_DIR/stderr.log

xrdb -merge .Xresources
setxkbmap -layout "us,ru" -option "grp:caps_toggle,grp_led:caps,compose:ralt"
xset dpms 610 610 610
xset r rate 290 30

if [ -d /etc/X11/xinit/xinitrc.d ]; then
	for f in /etc/X11/xinit/xinitrc.d/*; do
		[ -x "$f" ] && . "$f"
	done
fi

#xset +fp /usr/share/fonts/local
#xset fp rehash
# if this doesn't work, run mkfontdir there

eval $(gnome-keyring-daemon --start --components=gpg,pkcs11,secrets,ssh)
export GNOME_KEYRING_CONTROL GNOME_KEYRING_PID GPG_AGENT_INFO SSH_AUTH_SOCK

(
	xautolock \
		-noclose \
		-locker slock \
		-notify 5 -notifier 'notify-send Screensaver Activating...' \
		-corners 0+-0 -cornerdelay 5 -cornerredelay 900000 &
	twmnd &
	redshift-gtk &
	skype &
	psi-plus &
	nm-applet &
	pa-applet &
	clipit &
	clementine &
	linconnect-server &
	compton &
	devmon -g \
		--exec-on-drive 'notify-send "%l" "%f %d ready"' \
		--exec-on-unmount 'notify-send "%l" "%f %d is safe to remove"' &
)

i3status=~/.config/i3status/config
${i3status}.gen >$i3status
exec i3
