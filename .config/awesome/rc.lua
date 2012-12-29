---- Standard awesome library
awful = require("awful")
awful.autofocus = require("awful.autofocus")
awful.rules = require("awful.rules")
-- Widget and layout library
wibox = require("wibox")
-- Theme handling library
beautiful = require("beautiful")
-- Notification library
naughty = require("naughty")
-- External programs
require("externals")

--{{{ Variable definitions
-- Themes define colours, icons, and wallpapers
beautiful.init(".config/awesome/theme/theme.lua")

-- TODO: when launching external app, make con window floating and switch to corresponding tab

-- This is used later as the default terminal and editor to run.
terminal = "xterm"
editor = os.getenv("EDITOR") or "vim"
editor_cmd = terminal .. " -e " .. editor
height = 18

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
layouts =
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

--{{{ Tags
-- Define a tag table which hold all screen tags.
tags = {}
for s = 1, screen.count() do
	-- Each screen has its own tag table.
	tags[s] = awful.tag(
		{ "1:term",   "2:bw",      "3:vim",     "4:skype",  "5:mcb",     "6:vbox",    7,          }, s,
		{ layouts[7], layouts[10], layouts[10], layouts[7], layouts[10], layouts[10], layouts[10] }
	)
end
--}}}

--{{{ Menu
-- Create a laucher widget and a main menu
myawesomemenu = {
	{ "manual", terminal .. " -e man awesome" },
	{ "edit config", editor_cmd .. " " .. awful.util.getdir("config") .. "/rc.lua" },
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
	awful.button({ }, 4, awful.tag.viewnext),
	awful.button({ }, 5, awful.tag.viewprev)
)


mytasklist = {}
mytasklist.buttons = awful.util.table.join(
	awful.button({ }, 1, function (c)
		if c == client.focus then
			c.minimized = true
		else
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
	end)
)

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
		awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)
	))
	-- Create a taglist widget
	mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.filter.all, mytaglist.buttons)

	-- Create a tasklist widget
	mytasklist[s] = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, mytasklist.buttons)

	-- Create the wibox
	mywibox[s] = awful.wibox({ position = "top", screen = s })

	local left_widgets = {
		mylauncher,
		mytaglist[s],
		mypromptbox[s]
	}
	local left_layout = wibox.layout.fixed.horizontal()
	for i, widget in pairs(left_widgets) do
		left_layout:add(widget)
	end

	local right_widgets = awful.util.table.join({
--[[
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
--]]

			s == 1 and wibox.widget.systray() or nil,

--[[
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
--]]
			mylayoutbox[s]
	})
	local right_layout = wibox.layout.fixed.horizontal()
	for i, widget in pairs(right_widgets) do
		if widget then
			right_layout:add(widget)
		end
	end


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
	awful.key({ modkey,           }, "Left",   awful.tag.viewprev       ),
	awful.key({ modkey,           }, "Right",  awful.tag.viewnext       ),
	awful.key({ modkey,           }, "Escape", awful.tag.history.restore),

	awful.key({ modkey,           }, "j",
		function ()
		awful.client.focus.byidx( 1)
		if client.focus then client.focus:raise() end
		end),
	awful.key({ modkey,           }, "k",
		function ()
		awful.client.focus.byidx(-1)
		if client.focus then client.focus:raise() end
		end),
	awful.key({ modkey,           }, "w", function () mymainmenu:show({keygrabber=true}) end),

	-- Layout manipulation
	awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end),
	awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end),
	awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end),
	awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end),
	awful.key({ modkey,           }, "u", awful.client.urgent.jumpto),
	awful.key({ modkey,           }, "Tab",
		function ()
		awful.client.focus.history.previous()
		if client.focus then
		client.focus:raise()
		end
		end),

	-- Standard program
	awful.key({ modkey,           }, "Return", function () awful.util.spawn(terminal) end),
	awful.key({ modkey, "Control" }, "r", awesome.restart),
	awful.key({ modkey, "Shift"   }, "q", awesome.quit),

	awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)    end),
	awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)    end),
	awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1)      end),
	awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1)      end),
	awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1)         end),
	awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1)         end),
	awful.key({ modkey,           }, "space", function () awful.layout.inc(layouts,  1) end),
	awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),

	awful.key({ modkey, "Control" }, "n", awful.client.restore),
	awful.key({ modkey },            "F12", externals.display.screensaver),

	awful.key({ modkey, "Control" }, "Up",    externals.player.toggle),
	awful.key({ modkey, "Control" }, "Down",  externals.player.stop),
	awful.key({ modkey, "Control" }, "Left",  externals.player.prev),
	awful.key({ modkey, "Control" }, "Right", externals.player.next),

	awful.key({ modkey }, "Up",    externals.sound.up),
	awful.key({ modkey }, "Down",  externals.sound.down),

	-- Media Keys
	awful.key({ }, 'XF86AudioPlay', externals.player.toggle),
	awful.key({ }, 'XF86AudioPrev', externals.player.prev),
	awful.key({ }, 'XF86AudioNext', externals.player.next),
	awful.key({ }, 'XF86AudioStop', externals.player.stop),

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
	awful.key({ modkey }, "r", function () mypromptbox[mouse.screen]:run() end),

	-- TODO: unite in a single prompt with prefix (=2+2, g weather in Minsk, http://tut.by/ etc)
	
	awful.key({ modkey }, "x",
		function()
			awful.prompt.run({ prompt = "Eval: " },
				mypromptbox[mouse.screen].widget,
				function (s)
					local result = awful.util.eval('return ' .. s)
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
	awful.key({ modkey,           }, "f",      function (c) c.fullscreen = not c.fullscreen  end),
	awful.key({ modkey,           }, "F4",     function (c) c:kill()                         end),
	awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ),
	awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
	awful.key({ modkey,           }, "o",      awful.client.movetoscreen                        ),
	awful.key({ modkey, "Shift"   }, "r",      function (c) c:redraw()                       end),
	awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end),
	awful.key({ modkey,           }, "n",
		function (c)
		-- The client currently has the input focus, so it cannot be
		-- minimized, since minimized clients can't have the focus.
		c.minimized = true
		end),
	awful.key({ modkey,           }, "m",
		function (c)
		c.maximized_horizontal = not c.maximized_horizontal
		c.maximized_vertical   = not c.maximized_vertical
		end)
)

-- Compute the maximum number of digit we need, limited to 9
keynumber = 0
for s = 1, screen.count() do
   keynumber = math.min(9, math.max(#tags[s], keynumber));
end

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, keynumber do
	globalkeys = awful.util.table.join(globalkeys,
		awful.key({ modkey }, "#" .. i + 9,
			function ()
				local screen = mouse.screen
				if tags[screen][i] then
					awful.tag.viewonly(tags[screen][i])
				end
			end),
		awful.key({ modkey, "Control" }, "#" .. i + 9,
			function ()
				local screen = mouse.screen
				if tags[screen][i] then
					awful.tag.viewtoggle(tags[screen][i])
				end
			end),
		awful.key({ modkey, "Shift" }, "#" .. i + 9,
			function ()
				if client.focus and tags[client.focus.screen][i] then
					awful.client.movetotag(tags[client.focus.screen][i])
				end
			end),
		awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
			function ()
				if client.focus and tags[client.focus.screen][i] then
					awful.client.toggletag(tags[client.focus.screen][i])
				end
			end)
	)
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
end)

client.connect_signal("focus", function(c)
	c.border_color = beautiful.border_focus
end)
client.connect_signal("unfocus", function(c)
	c.border_color = beautiful.border_normal
end)

for s = 1, screen.count() do
	screen[s]:add_signal("tag::history::update", function()
		client.focus = client.focus
	end)
end
--}}}

-- vim: set foldmarker=--{{{,--}}} foldmethod=marker:
