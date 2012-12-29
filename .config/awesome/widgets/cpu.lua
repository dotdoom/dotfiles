-- {{{ OK: CPU usage and temperature
cpuwidget = {}
cpuwidget.i = wibox.widget.imagebox()
cpuwidget.i:set_image(beautiful.widget_cpu)
cpuwidget.g = awful.widget.graph()
cpuwidget.w = wibox.widget.textbox()
cpuwidget.g:set_width(40):set_height(height)
cpuwidget.g:set_background_color(beautiful.fg_off_widget)
--cpuwidget.g:set_gradient_angle(0):set_gradient_colors({
--	beautiful.fg_end_widget, beautiful.fg_center_widget, beautiful.fg_widget
--})
cpuwidget.b = awful.util.table.join(
	awful.button({ }, 1, function ()
		vicious.force({ cpuwidget.w, cpuwidget.g })
	end),
	awful.button({ }, 3, function ()
		conexec('htop')
	end)
)
cpuwidget.w:buttons(cpuwidget.b)
cpuwidget.g:buttons(cpuwidget.b)
cpuwidget.i:buttons(cpuwidget.b)
vicious.register(cpuwidget.g, vicious.widgets.cpu, '$1')
vicious.register(cpuwidget.w, vicious.widgets.thermal, ' $1C', 19, 'thermal_zone0')
-- }}}
