-- {{{ OK: Weather
wthwidget = {}
wthwidget.w = widget({ type = "textbox" })
wthwidget.t = awful.tooltip({
	objects = { wthwidget.w }
})
wthwidget.b = awful.util.table.join(
	awful.button({ }, 1, function ()
		vicious.force({ wthwidget })
	end),
	awful.button({ }, 3, function ()
		awful.util.spawn('firefox http://www.weathercity.com/by/minsk/')
	end)
)
wthwidget.w:buttons(wthwidget.b)
vicious.register(wthwidget, vicious.widgets.weather, function(widget, args)
		widget.w:set_text(' ' .. args['{city}'] .. ': ' .. args['{tempc}'] .. 'C')
		widget.t:set_text(
			'Weather for ' .. args['{city}'] .. '\n' ..
			'  wind    : ' .. args['{wind}'] .. ' ' .. args['{windkmh}'] .. ' km/h\n' ..
			'  sky     : ' .. args['{sky}'] .. '\n' ..
			'  humidity: ' .. args['{humid}'] .. '%\n' ..
			'  pressure: ' .. args['{press}'] .. ' mm')
	end, 60 * 30 + 23, 'UMMS')
-- }}}
