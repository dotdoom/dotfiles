require("../misc/calendar")

-- {{{ OK: Date and time
datewidget = {}
datewidget.i = wibox.widget.imagebox()
datewidget.i:set_image(beautiful.widget_date)
datewidget.w = wibox.widget.textbox()
datewidget.format = '%a, %m/%d %R'
datewidget.t = awful.tooltip({
	objects = { datewidget.w, datewidget.i },
	timer_function = function()
		return calendar();
	end
})
datewidget.b = awful.util.table.join(
	awful.button({ }, 1, function ()
		datewidget.w:set_text(os.date(datewidget.format .. ':%S'))
	end)
)
datewidget.w:buttons(datewidget.b)
datewidget.i:buttons(datewidget.b)
vicious.register(datewidget.w, vicious.widgets.date, datewidget.format, 61)
-- }}}
