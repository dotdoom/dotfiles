-- {{{ OK: Battery state
batwidget = {}
batwidget.i = wibox.widget.imagebox()
batwidget.w = wibox.widget.textbox()
batwidget.t = awful.tooltip({
	objects = { batwidget.i, batwidget.w }
})
batwidget.b = awful.util.table.join(
	awful.button({ }, 1, function ()
		vicious.force({ batwidget })
	end),
	awful.button({ }, 3, function ()
		conexec("'sudo powertop'")
	end)
)
batwidget.w:buttons(batwidget.b)
batwidget.i:buttons(batwidget.b)
vicious.register(batwidget, vicious.widgets.bat, function(widget, args)
	if args[2] == 0 then
		widget.w:set_text('')
		widget.i:set_image(nil)
	else
		widget.w:set_text(args[1] .. args[2] .. '%')
		widget.i:set_image(beautiful.widget_bat)
	end

	if args[3] == 'N/A' then
		widget.t:set_text('')
	else
		widget.t:set_text(args[3] .. ' remaining')
	end
end, 57, "BAT0")
-- }}}
