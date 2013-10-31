local awful = require("awful")

local externals = {}

--{{{ helpers
externals.hook = {
	before = function(object, handler, hook)
		local prev_handler = object[handler]
		object[handler] = function(...)
			if hook(...) then
				prev_handler(...)
			end
		end
	end,
	after = function(object, handler, hook)
		local prev_handler = object[handler]
		object[handler] = function(...)
			hook(..., prev_handler(...))
		end
	end
}
--}}}

-- specific
externals.players = {}
externals.browsers = {}
externals.powers = {}
externals.sounds = {}
externals.mails = {}
externals.displays = {}

--{{{ browsers.firefox
externals.browsers.firefox = {
	exec = function(command)
		awful.util.spawn('firefox ' .. command)
	end,

	manager = function()
		awful.util.spawn('firefox')
	end,

	search = function(term)
		externals.browsers.firefox.exec('http://www.google.com/search?q=' .. string.gsub(term, ' ', '+'))
	end,

	browse = function(...)
		externals.browsers.firefox.exec(...)
	end
}
--}}}

--{{{ browsers.chromium
externals.browsers.chromium = {
	exec = function(command)
		awful.util.spawn('chromium ' .. command)
	end,

	manager = function()
		awful.util.spawn('chromium')
	end,

	search = function(term)
		externals.browsers.chromium.exec('http://www.google.com/search?q=' .. string.gsub(term, ' ', '+'))
	end,

	browse = function(...)
		externals.browsers.chromium.exec(...)
	end
}
--}}}

--{{{ sounds.alsa
externals.sounds.alsa = {
	exec = function(command)
		exec('amixer -q ' .. command)
	end,

	manager = function()
		conexec('alsamixer')
	end,

	mute = function()
		externals.sounds.alsa.exec('set ' .. externals.sound.channel .. ' toggle')
	end,

	up = function()
		externals.sounds.alsa.exec('set ' .. externals.sound.channel .. ' 2dB+')
	end,

	down = function()
		externals.sounds.alsa.exec('set ' .. externals.sound.channel .. ' 2dB-')
	end
}
--}}}

--{{{ sounds.pulse
externals.sounds.pulse = {
	exec = function(command)
		exec('amixer -q ' .. command)
	end,

	manager = function()
		conexec('alsamixer')
	end,

	mute = function()
		externals.sounds.alsa.exec('set ' .. externals.sound.channel .. ' toggle')
	end,

	up = function()
		externals.sounds.alsa.exec('set ' .. externals.sound.channel .. ' 2dB+')
	end,

	down = function()
		externals.sounds.alsa.exec('set ' .. externals.sound.channel .. ' 2dB-')
	end
}
--}}}

--{{{ powers.pm
externals.powers.pm = {
	exec = function(command)
		awful.util.spawn('systemctl ' .. command)
	end,

	reboot = function()
		externals.powers.pm.exec('reboot')
	end,

	halt = function()
		externals.powers.pm.exec('poweroff')
	end,

	suspend = function()
		externals.powers.pm.exec('suspend')
	end,

	hibernate = function()
		externals.powers.pm.exec('hibernate')
	end,

	switch_profile = function()
		externals.powers.pm.exec('/opt/bin/powerctl switch')
	end
}
--}}}

--{{{ powers.ck
externals.powers.ck = {
	exec = function(command)
		awful.util.spawn('dbus-send --system --print-reply --dest="org.freedesktop.ConsoleKit" /org/freedesktop/ConsoleKit/Manager org.freedesktop.ConsoleKit.Manager.' .. command)
	end,

	reboot = function()
		externals.powers.ck.exec('Restart')
	end,

	halt = function()
		externals.powers.ck.exec('Stop')
	end,

	pm_exec = function(command)
		awful.util.spawn('dbus-send --system --print-reply --dest="org.freedesktop.UPower" /org/freedesktop/UPower org.freedesktop.UPower.' .. command)
	end,

	suspend = function()
		externals.powers.ck.pm_exec('Suspend')
	end,

	hibernate = function()
		externals.powers.ck.pm_exec('Hibernate')
	end
}
--}}}

--{{{ mails.gmail
externals.mails.gmail = {
	open = function(target)
		externals.browser.browse("https://gmail.com")
	end,

	manager = function(...)
		externals.mail.open(...)
	end
}
--}}}

-- general
--externals.player = externals.players.mpd

externals.browser = externals.browsers.chromium

externals.mail = externals.mails.gmail

externals.sound = externals.sounds.alsa
externals.sound.channel = 'Speaker'

externals.display = {
	switch = function() exec('/opt/powerctl switch-display') end,
	screensaver = function() exec('xautolock -locknow') end,
	toggle = nil,
	turn_off = function() exec('xset dpms force off') end,
	save = function () exec("scrot -e 'mv $f ~/Pictures/'") end,
	backlight = {
		down = function() exec("sudo sh -c 'echo $[$(</sys/class/backlight/intel_backlight/brightness)-100] >/sys/class/backlight/intel_backlight/brightness'") end,
		up = function() exec("sudo sh -c 'echo $[$(</sys/class/backlight/intel_backlight/brightness)+100] >/sys/class/backlight/intel_backlight/brightness'") end
	}
}

externals.power = externals.powers.ck

return externals

-- vim: set foldmarker=--{{{,--}}} foldmethod=marker:
