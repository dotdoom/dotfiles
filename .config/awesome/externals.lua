externals = {}

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

--{{{ players.mpd
require('socket')
externals.players.mpd = {
	sock = nil,
	ping_timer = timer({ timeout = 10 }),
	exec = function(command)
		if not externals.players.mpd.sock then
			if not externals.players.mpd.reconnect() then
				return false
			end
		end

		if not externals.players.mpd.sock:send(command .. "\n") then
			externals.players.mpd.disconnect()
			return externals.players.mpd.exec(command)
		end

		local answer = {}
		local line = nil
		while line ~= 'OK' do
			line = externals.players.mpd.sock:receive()
			if not line then
				externals.players.mpd.disconnect()
				break
			end
			if line:sub(1,3) == "ACK" then
				return false
			end
			k, v = string.match(line, "([%w-]+):[%s](.*)$")
			if k ~= nil then
				answer[k] = v
			end
		end
		return answer
	end,

	reconnect = function()
		if externals.players.mpd.sock then
			return true
		end

		externals.players.mpd.sock = socket.connect('localhost', 6600)
		if externals.players.mpd.sock == nil then
			return false
		else
			externals.players.mpd.sock:receive()
			externals.players.mpd.sock:send('password "' .. externals.players.mpd.password .. '"\n')
			externals.players.mpd.sock:receive()
		end

		return true
	end,

	disconnect = function()
		if externals.players.mpd.sock then
			externals.players.mpd.sock:shutdown('both')
			externals.players.mpd.sock:close()
		end
		externals.players.mpd.sock = nil
	end,

	manager = function()
		conexec('ncmpc')
	end,

	stop = function()
		return externals.players.mpd.exec('stop')
	end,

	prev = function()
		return externals.players.mpd.exec('previous')
	end,

	next = function()
		return externals.players.mpd.exec('next')
	end,

	update = function()
		return externals.players.mpd.exec('update')
	end,

	toggle = function()
		if externals.players.mpd.state() == 'stop' then
			return externals.players.mpd.exec('play')
		else
			return externals.players.mpd.exec('pause')
		end
	end,

	ping = function()
		return externals.players.mpd.exec('ping')
	end,

	state = function()
		status = externals.players.mpd.exec('status')
		if status then
			return status.state
		else
			return false
		end
	end,

	search = function(target)
		exec('sh -c \'mpc search any "' .. target .. '" | mpc -q insert; mpc -q next\'')
	end
}
externals.players.mpd.password = '56379534'
externals.players.mpd.ping_timer:connect_signal('timeout', externals.players.mpd.ping)
externals.players.mpd.ping_timer:start()
--}}}

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

--{{{ powers.pm
externals.powers.pm = {
	exec = function(command)
		awful.util.spawn('sudo ' .. command)
	end,

	reboot = function()
		externals.powers.pm.exec('shutdown -r now -t 10')
	end,

	halt = function()
		externals.powers.pm.exec('shutdown -h now -t 10')
	end,

	suspend = function()
		externals.powers.pm.exec('pm-suspend')
	end,

	hibernate = function()
		externals.powers.pm.exec('pm-hibernate')
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
externals.player = externals.players.mpd

externals.browser = externals.browsers.chromium

externals.mail = externals.mails.gmail

externals.sound = externals.sounds.alsa
externals.sound.channel = 'Speaker'

externals.display = {
	switch = function() exec('/opt/powerctl switch-display') end,
	screensaver = function() exec('xautolock -locknow') end,
	toggle = nil,
	turn_off = function() exec('xset dpms force off') end,
	save = function () exec("scrot -e 'mv $f ~/screenshots/'") end,
	backlight = {
		down = function() exec("sudo sh -c 'echo $[$(</sys/class/backlight/intel_backlight/brightness)-100] >/sys/class/backlight/intel_backlight/brightness'") end,
		up = function() exec("sudo sh -c 'echo $[$(</sys/class/backlight/intel_backlight/brightness)+100] >/sys/class/backlight/intel_backlight/brightness'") end
	}
}

externals.power = externals.powers.ck

-- vim: set foldmarker=--{{{,--}}} foldmethod=marker:
