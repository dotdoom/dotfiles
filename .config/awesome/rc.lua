-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
awful.rules = require("awful.rules")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")

-- Delightful Widgets (OMG paths)
--require('widgets.delightful.delightful.widgets.cpu')
require('widgets.delightful.delightful.widgets.datetime')
--require('widgets.delightful.delightful.widgets.imap')
--require('widgets.delightful.delightful.widgets.memory')
--require('widgets.delightful.delightful.widgets.network')
--require('widgets.delightful.delightful.widgets.pulseaudio')
--require('widgets.delightful.delightful.widgets.weather')

-- External programs
local externals = require("externals")
--{{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
	naughty.notify({
		preset = naughty.config.presets.critical,
		title = "Oops, there were errors during startup!",
		text = awesome.startup_errors
	})
end

-- Handle runtime errors after startup
do
	local in_error = false
	awesome.connect_signal("debug::error", function (err)
		-- Make sure we don't go into an endless error loop
		if in_error then return end
		in_error = true

		naughty.notify({
			preset = naughty.config.presets.critical,
			title = "Oops, an error happened!",
			text = err })
		in_error = false
	end)
end
--}}}

--{{{ Variable definitions
-- Themes define colours, icons, and wallpapers
beautiful.init(".config/awesome/theme/theme.lua")

-- TODO: when launching external app, make con window floating and switch to corresponding tab

-- This is used later as the default terminal and editor to run.
terminal = "xterm"
editor = os.getenv("EDITOR") or "vi"
editor_cmd = terminal .. " -e " .. editor

function exec(command)
	awful.util.spawn(command, false)
end

function conexec(command)
	exec(terminal .. ' -e ' .. command)
end

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"
altkey = "Mod1"
menukey = "Menu"

-- Table of layouts to cover with awful.layout.inc, order matters.
local layouts =
{
	awful.layout.suit.floating, -- 1
	awful.layout.suit.tile, -- 2
	awful.layout.suit.tile.left, -- 3
	awful.layout.suit.tile.bottom, -- 4
	awful.layout.suit.tile.top, -- 5
	awful.layout.suit.fair, -- 6
	awful.layout.suit.fair.horizontal, -- 7
	awful.layout.suit.spiral, -- 8
	awful.layout.suit.spiral.dwindle, -- 9
	awful.layout.suit.max, -- 10
	awful.layout.suit.max.fullscreen, -- 11
	awful.layout.suit.magnifier -- 12
}
--}}}

--{{{ Wallpaper
if beautiful.wallpaper then
	for s = 1, screen.count() do
		gears.wallpaper.maximized(beautiful.wallpaper, s, false, { x = 0, y = -50 })
	end
end
--}}}

--{{{ Tags
-- Define a tag table which hold all screen tags.
tags = {}
for s = 1, screen.count() do
	-- Each screen has its own tag table.
	tags[s] = awful.tag(
		{ "1:term",   "2:bw",	  "3:vim",	 "4:skype",  "5:IM",	  "6:vbox",	7,		  }, s,
		{ layouts[7], layouts[10], layouts[10], layouts[7], layouts[10], layouts[10], layouts[10] }
	)
end
--}}}

--{{{ Menu
-- Create a laucher widget and a main menu
myawesomemenu = {
	{ "manual", terminal .. " -e man awesome" },
	{ "edit config", editor_cmd .. " " .. awesome.conffile },
	{ "restart", awesome.restart },
	{ "quit", awesome.quit }
}

mymainmenu = awful.menu({ items = {
	{ "awesome", myawesomemenu, beautiful.awesome_icon },
	{ "open terminal", terminal },
	{ "shutdown", {
		{ "reboot", externals.power.reboot },
		{ "halt", externals.power.halt },
		{ "suspend", externals.power.suspend },
		{ "hibernate", externals.power.hibernate }
	} }
}})

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it

mylauncher = awful.widget.launcher({
	image = beautiful.awesome_icon,
	menu = mymainmenu
})
--}}}

--{{{ Wibox
--{{{ Reusable separator
separator = wibox.widget.imagebox()
separator:set_image(beautiful.widget_sep)
--}}}

require('externals')

--require('widgets/cpu')
--require('widgets/mem')
--require('widgets/fs')
--require('widgets/net')
--require('widgets/wifi')
--require('widgets/vol')
--require('widgets/mpd')
--require('widgets/wth')
--require('widgets/gmail')
--require('widgets/pkg')
--require('widgets/bat')
--require('widgets/date')

-- Create a wibox for each screen and add it
mywibox = {}
mypromptbox = {}
mylayoutbox = {}
mytaglist = {}
mytaglist.buttons = awful.util.table.join(
					awful.button({ }, 1, awful.tag.viewonly),
					awful.button({ modkey }, 1, awful.client.movetotag),
					awful.button({ }, 3, awful.tag.viewtoggle),
					awful.button({ modkey }, 3, awful.client.toggletag),
					awful.button({ }, 4, function(t) awful.tag.viewnext(awful.tag.getscreen(t)) end),
					awful.button({ }, 5, function(t) awful.tag.viewprev(awful.tag.getscreen(t)) end)
					)
mytasklist = {}
mytasklist.buttons = awful.util.table.join(
	awful.button({ }, 1, function (c)
		if c == client.focus then
			c.minimized = true
		else
			-- Without this, the following
			-- :isvisible() makes no sense
			c.minimized = false
			if not c:isvisible() then
				awful.tag.viewonly(c:tags()[1])
			end
			-- This will also un-minimize
			-- the client, if needed
			client.focus = c
			c:raise()
		end
	end),
	awful.button({ }, 3, function ()
		if instance then
			instance:hide()
			instance = nil
		else
			instance = awful.menu.clients({ width=250 })
		end
	end),
	awful.button({ }, 4, function ()
		awful.client.focus.byidx(1)
		if client.focus then client.focus:raise() end
	end),
	awful.button({ }, 5, function ()
		awful.client.focus.byidx(-1)
		if client.focus then client.focus:raise() end
	end))

for s = 1, screen.count() do
	-- Create a promptbox for each screen
	mypromptbox[s] = awful.widget.prompt()
	-- Create an imagebox widget which will contains an icon indicating which layout we're using.
	-- We need one layoutbox per screen.
	mylayoutbox[s] = awful.widget.layoutbox(s)
	mylayoutbox[s]:buttons(awful.util.table.join(
		awful.button({ }, 1, function () awful.layout.inc(layouts, 1) end),
		awful.button({ }, 3, function () awful.layout.inc(layouts, -1) end),
		awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
		awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)))
	-- Create a taglist widget
	mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.filter.all, mytaglist.buttons)

	-- Create a tasklist widget
	mytasklist[s] = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, mytasklist.buttons)

	-- Create the wibox
	mywibox[s] = awful.wibox({ position = "top", screen = s })

	-- Widgets that are aligned to the left
	local left_layout = wibox.layout.fixed.horizontal()
	left_layout:add(mylauncher)
	left_layout:add(mytaglist[s])
	left_layout:add(mypromptbox[s])

--[[
	local right_widgets = awful.util.table.join({
			cpuwidget.i,
			cpuwidget.g,
			cpuwidget.w,
			separator,

			memwidget.i,
			memwidget.w,
			separator,

			fswidget.i
		},
		fswidget.get_fs_widgets(),
		{

			fswidget.w,
			separator,

			volwidget.i,
			volwidget.w,
			separator,

			mpdwidget.i,
			mpdwidget.w,
			separator,

			netwidget.i_dn,
			netwidget.w,
			netwidget.i_up,
			wifiwidget.i,
			wifiwidget.w,
			separator,

			s == 1 and wibox.widget.systray() or nil,

			gmailwidget.i,
			gmailwidget.w,
			pkgwidget.i,
			pkgwidget.w,
			batwidget.i,
			batwidget.w,
			separator,

			datewidget.i,
			datewidget.w,
			separator,
			mylayoutbox[s]
	})
--]]
	-- Widgets that are aligned to the right
	local right_layout = wibox.layout.fixed.horizontal()
	if s == 1 then right_layout:add(wibox.widget.systray()) end
	--right_layout:add(awful.widget.textclock())

	local delightful_container = { widgets = {}, icons = {} }
	local widgets, icons = delightful.widgets.datetime:load()
	if widgets then
		if not icons then
			icons = {}
		end
		table.insert(delightful_container.widgets, awful.util.table.reverse(widgets))
		table.insert(delightful_container.icons,   awful.util.table.reverse(icons))
	end

	for delightful_container_index, delightful_container_data in pairs(delightful_container.widgets) do
		for widget_index, widget_data in pairs(delightful_container_data) do
			right_layout:add(widget_data)
			if delightful_container.icons[delightful_container_index] and delightful_container.icons[delightful_container_index][widget_index] then
				right_layout:add(delightful_container.icons[delightful_container_index][widget_index])
			end
		end
	end


	right_layout:add(mylayoutbox[s])

	-- Now bring it all together (with the tasklist in the middle)
	local layout = wibox.layout.align.horizontal()
	layout:set_left(left_layout)
	layout:set_middle(mytasklist[s])
	layout:set_right(right_layout)

	mywibox[s]:set_widget(layout)
end
--}}}

--{{{ Mouse bindings
root.buttons(awful.util.table.join(
	awful.button({ }, 3, function () mymainmenu:toggle() end),
	awful.button({ }, 4, awful.tag.viewnext),
	awful.button({ }, 5, awful.tag.viewprev)
))
--}}}

--{{{ Key bindings
-- read with 'xev' (xorg-xev)
globalkeys = awful.util.table.join(
	awful.key({ modkey,		   }, "Left",   awful.tag.viewprev	   ),
	awful.key({ modkey,		   }, "Right",  awful.tag.viewnext	   ),
	awful.key({ modkey,		   }, "Escape", awful.tag.history.restore),

	awful.key({ modkey,		   }, "j",
		function ()
			awful.client.focus.byidx( 1)
			if client.focus then client.focus:raise() end
		end),
	awful.key({ modkey,		   }, "k",
		function ()
			awful.client.focus.byidx(-1)
			if client.focus then client.focus:raise() end
		end),
	awful.key({ modkey,		   }, "w", function () mymainmenu:show({keygrabber=true}) end),

	-- Layout manipulation
	awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)	end),
	awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)	end),
	awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end),
	awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end),
	awful.key({ modkey,		   }, "u", awful.client.urgent.jumpto),
	awful.key({ modkey,		   }, "Tab",
		function ()
			awful.client.focus.history.previous()
			if client.focus then
				client.focus:raise()
			end
		end),

	-- Standard program
	awful.key({ modkey,		   }, "Return", function () awful.util.spawn(terminal) end),
	awful.key({ modkey, "Control" }, "r", awesome.restart),
	awful.key({ modkey, "Shift"   }, "q", awesome.quit),

	awful.key({ modkey,		   }, "l",	 function () awful.tag.incmwfact( 0.05)	end),
	awful.key({ modkey,		   }, "h",	 function () awful.tag.incmwfact(-0.05)	end),
	awful.key({ modkey, "Shift"   }, "h",	 function () awful.tag.incnmaster( 1)	  end),
	awful.key({ modkey, "Shift"   }, "l",	 function () awful.tag.incnmaster(-1)	  end),
	awful.key({ modkey, "Control" }, "h",	 function () awful.tag.incncol( 1)		 end),
	awful.key({ modkey, "Control" }, "l",	 function () awful.tag.incncol(-1)		 end),
	awful.key({ modkey,		   }, "space", function () awful.layout.inc(layouts,  1) end),
	awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),

	awful.key({ modkey, "Control" }, "n", awful.client.restore),
	awful.key({ modkey },			"F12", externals.display.screensaver),

	--awful.key({ modkey, "Control" }, "Up",	externals.player.toggle),
	--awful.key({ modkey, "Control" }, "Down",  externals.player.stop),
	--awful.key({ modkey, "Control" }, "Left",  externals.player.prev),
	--awful.key({ modkey, "Control" }, "Right", externals.player.next),

	awful.key({ modkey }, "Up",	externals.sound.up),
	awful.key({ modkey }, "Down",  externals.sound.down),

	-- Media Keys
	--awful.key({ }, 'XF86AudioPlay', externals.player.toggle),
	--awful.key({ }, 'XF86AudioPrev', externals.player.prev),
	--awful.key({ }, 'XF86AudioNext', externals.player.next),
	--awful.key({ }, 'XF86AudioStop', externals.player.stop),

	awful.key({ }, 'XF86AudioMute', externals.sound.mute),
	awful.key({ }, 'XF86AudioRaiseVolume', externals.sound.up),
	awful.key({ }, 'XF86AudioLowerVolume', externals.sound.down),

	awful.key({ }, 'XF86MonBrightnessDown', externals.display.backlight.down),
	awful.key({ }, 'XF86MonBrightnessUp', externals.display.backlight.up),

	awful.key({ }, 'XF86Search', externals.browser.search), -- this will fail. Use the same func as Meta+S does instead
	awful.key({ }, 'XF86Mail', externals.mail.manager),
	awful.key({ }, 'XF86HomePage', externals.browser.manager),

	awful.key({ }, 'XF86Display', externals.display.switch),
	awful.key({ }, 'XF86ScreenSaver', externals.display.screensaver),
	awful.key({ }, 'XF86Launch6', externals.power.switch_profile),
	--awful.key({ }, 252, externals.display.turn_off),

	awful.key({ }, 'XF86PowerOff', function() end),
	awful.key({ }, 'XF86WLAN', function() end),

	awful.key({ }, "Print", externals.display.save),

	-- Prompt
	awful.key({ modkey },			"r",	 function () mypromptbox[mouse.screen]:run() end),

	-- TODO: unite in a single prompt with prefix (=2+2, g weather in Minsk, http://tut.by/ etc)
	
	awful.key({ modkey }, "x",
		function()
			awful.prompt.run({ prompt = "Eval: " },
				mypromptbox[mouse.screen].widget,
				function (s)
					local result = awful.util.eval('return ' .. s)
					if not result then result = 'Error' end
					mypromptbox[mouse.screen].widget:set_text('[ ' .. result .. ' ]')
				end, nil,
				awful.util.getdir("cache") .. "/history_eval")
		end),

	awful.key({ modkey }, "s",
		function()
			awful.prompt.run({ prompt = "Google: " },
				mypromptbox[mouse.screen].widget,
				externals.browser.search, nil,
				awful.util.getdir("cache") .. "/history_search")
		end),

	awful.key({ modkey }, "p",
		function()
			awful.prompt.run({ prompt = "Play: " },
				mypromptbox[mouse.screen].widget,
				externals.player.search, nil,
				awful.util.getdir("cache") .. "/history_play")
		end),

	awful.key({ modkey }, "g",
		function()
			awful.prompt.run({ prompt = "Go: " },
				mypromptbox[mouse.screen].widget,
				externals.browser.browse, nil,
				awful.util.getdir("cache") .. "/history_goto")
		end),

	awful.key({ modkey }, "b",
		function ()
			mywibox[mouse.screen].visible = not mywibox[mouse.screen].visible
		end)
)

clientkeys = awful.util.table.join(
	awful.key({ modkey,		   }, "f",	  function (c) c.fullscreen = not c.fullscreen  end),
	awful.key({ modkey,		   }, "F4",	 function (c) c:kill()						 end),
	awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle					 ),
	awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
	awful.key({ modkey,		   }, "o",	  awful.client.movetoscreen						),
	awful.key({ modkey,		   }, "t",	  function (c) c.ontop = not c.ontop			end),
	awful.key({ modkey,		   }, "n",
		function (c)
			-- The client currently has the input focus, so it cannot be
			-- minimized, since minimized clients can't have the focus.
			c.minimized = true
		end),
	awful.key({ modkey,		   }, "m",
		function (c)
			c.maximized_horizontal = not c.maximized_horizontal
			c.maximized_vertical   = not c.maximized_vertical
		end)
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
	globalkeys = awful.util.table.join(globalkeys,
		awful.key({ modkey }, "#" .. i + 9,
			function ()
				local screen = mouse.screen
				local tag = awful.tag.gettags(screen)[i]
				if tag then
					awful.tag.viewonly(tag)
				end
			end),
		awful.key({ modkey, "Control" }, "#" .. i + 9,
		function ()
			local screen = mouse.screen
			local tag = awful.tag.gettags(screen)[i]
			if tag then
				awful.tag.viewtoggle(tag)
			end
		end),
		awful.key({ modkey, "Shift" }, "#" .. i + 9,
		function ()
			if client.focus then
				local tag = awful.tag.gettags(client.focus.screen)[i]
				if tag then
					awful.client.movetotag(tag)
				end
			end
		end),
		awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
		function ()
			if client.focus then
				local tag = awful.tag.gettags(client.focus.screen)[i]
				if tag then
					awful.client.toggletag(tag)
				end
			end
		end))
end

clientbuttons = awful.util.table.join(
	awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
	awful.button({ modkey }, 1, awful.mouse.client.move),
	awful.button({ modkey }, 3, awful.mouse.client.resize))

-- Set keys
root.keys(globalkeys)
--}}}

--{{{ Rules
-- get class / etc with 'xprop' (xorg-xprop)
-- ex.: 
-- ...
-- WM_CLASS(STRING) = "Navigator", "Swiftfox"
-- WM_NAME(STRING) = "Problem loading page - Swiftfox"
-- ...
--
-- instance = "Navigator", class = "Swiftfox", name = "Problem loading page - Swiftfox"
awful.rules.rules = {
	-- All clients will match this rule.
	{
		rule = { },
		properties = {
			border_width = beautiful.border_width,
			border_color = beautiful.border_normal,
			focus = true,
			keys = clientkeys,
			buttons = clientbuttons
		}
	}, {
		rule_any = { class = { "MPlayer", "pinentry", "gimp" } },
		properties = { floating = true }
	}, {
		rule_any = { instance = { "Navigator" }, class = { "Chromium" } },
		properties = { tag = tags[1][2] }
	}, {
		rule = { instance = "gvim" },
		properties = { tag = tags[1][3] }
	}, {
		rule = { class = "Skype" },
		properties = { tag = tags[1][4], size_hints_honor = false }
	}, {
		rule = { instance = "gajim" },
		properties = { tag = tags[1][5] }
	}, {
		rule = { class = "XTerm" },
		callback = function(c)
			if c.name:sub(#c.name - 9) == " - mcabber" then
				awful.client.movetotag(tags[1][5], c)
			end

			-- see /usr/share/awesome/lib/wibox/layout/
			--
			-- eval geometry with respect to hint
			--local geom = c:geometry()
			--local hint = c.size_hints

			--print("geom was: " .. geom.width .. "x" .. geom.height)

			--local w_ratio = math.floor((geom.width - hint.base_width) / hint.width_inc)
			--local h_ratio = math.floor((geom.height - hint.base_height) / hint.height_inc)

			--geom.width = hint.base_width + hint.width_inc * w_ratio
			--geom.height = hint.base_height + hint.height_inc * h_ratio

			--print("geom is: " .. geom.width .. "x" .. geom.height)

			--c:geometry(geom)
		end
	}, {
		rule = { class = "XTerm" },
		properties = { opacity = 0.9, size_hints_honor = false }
	}, {
		rule = { instance = "VCLSalFrame.DocumentWindow", class = "LibreOffice 3.5" },
		properties = { size_hints_honor = false }
	}, {
		rule = { class = "VirtualBox" },
		properties = { tag = tags[1][6], switchtotag = true }
	}, {
		rule = { class = "do-not-directly-run-secondlife-bin" },
		properties = {
			tag = tags[1][6],
			switchtotag = true,
			floating = true,
			geometry = { x = 0, y = 0, width = 1364, height = 700 }
		}
	}
}
--}}}

--{{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c, startup)
	-- Add a titlebar
	--awful.titlebar.add(c, { modkey = modkey })

	-- Enable sloppy focus
	c:connect_signal("mouse::enter", function(c)
		if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier and awful.client.focus.filter(c) then
			client.focus = c
		end
	end)

	if not startup then
		-- Set the windows at the slave,
		-- i.e. put it at the end of others instead of setting it master.
		-- awful.client.setslave(c)

		-- Put windows in a smart way, only if they does not set an initial position.
		if not c.size_hints.user_position and not c.size_hints.program_position then
			awful.placement.no_overlap(c)
			awful.placement.no_offscreen(c)
		end
	end

	client.connect_signal("focus", function(c)
		c.border_color = beautiful.border_focus
	end)
	client.connect_signal("unfocus", function(c)
		c.border_color = beautiful.border_normal
		local titlebars_enabled = false
	end)
	local titlebars_enabled = false
	if titlebars_enabled and (c.type == "normal" or c.type == "dialog") then
		-- buttons for the titlebar
		local buttons = awful.util.table.join(
				awful.button({ }, 1, function()
					client.focus = c
					c:raise()
					awful.mouse.client.move(c)
				end),
				awful.button({ }, 3, function()
					client.focus = c
					c:raise()
					awful.mouse.client.resize(c)
				end)
				)

		-- Widgets that are aligned to the left
		local left_layout = wibox.layout.fixed.horizontal()
		left_layout:add(awful.titlebar.widget.iconwidget(c))
		left_layout:buttons(buttons)

		-- Widgets that are aligned to the right
		local right_layout = wibox.layout.fixed.horizontal()
		right_layout:add(awful.titlebar.widget.floatingbutton(c))
		right_layout:add(awful.titlebar.widget.maximizedbutton(c))
		right_layout:add(awful.titlebar.widget.stickybutton(c))
		right_layout:add(awful.titlebar.widget.ontopbutton(c))
		right_layout:add(awful.titlebar.widget.closebutton(c))

		-- The title goes in the middle
		local middle_layout = wibox.layout.flex.horizontal()
		local title = awful.titlebar.widget.titlewidget(c)
		title:set_align("center")
		middle_layout:add(title)
		middle_layout:buttons(buttons)

		-- Now bring it all together
		local layout = wibox.layout.align.horizontal()
		layout:set_left(left_layout)
		layout:set_right(right_layout)
		layout:set_middle(middle_layout)

		awful.titlebar(c):set_widget(layout)
	end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
for s = 1, screen.count() do
	screen[s]:add_signal("tag::history::update", function()
		client.focus = client.focus
	end)
end
--}}}

-- vim: set foldmarker=--{{{,--}}} foldmethod=marker:
