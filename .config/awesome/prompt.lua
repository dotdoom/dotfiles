-- typical mpc/mpd tasks:
-- * 

prompt = {
	box = nil,
	exec = {
		lua = function(command)
		end,
		google = function(command)
		end,
		player = function(command)
		end
	}
}



-- Prompt
    awful.key({ modkey }, "r", function () mypromptbox[mouse.screen]:run() end),

	-- TODO: unite in a single prompt with prefix (=2+2, g weather in Minsk, http://tut.by/ etc)

	awful.key({ modkey }, "x",
		function()
			awful.prompt.run({ prompt = "Run Lua code: " },
				mypromptbox[mouse.screen].widget,
				function (...)
					local result = awful.util.eval(...)
					promptbox.widget:set_text(result) -- I need a calculator :(
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
				externals.music.search, nil,
				awful.util.getdir("cache") .. "/history_play")
		end),

