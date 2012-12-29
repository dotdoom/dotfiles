-- {{{ OK: Memory usage
memwidget = {}
memwidget.i = wibox.widget.imagebox()
memwidget.i:set_image(beautiful.widget_mem)
memwidget.w = awful.widget.progressbar()
memwidget.w:set_vertical(true):set_ticks(true)
memwidget.w:set_height(height):set_width(8):set_ticks_size(2)
memwidget.w:set_background_color(beautiful.fg_off_widget)
--memwidget.w:set_gradient_colors({ beautiful.fg_widget,
--	beautiful.fg_center_widget, beautiful.fg_end_widget
--})
memwidget.t = awful.tooltip({
	objects = { memwidget.i, memwidget.w }
})
memwidget.w:buttons(cpuwidget.b);
memwidget.i:buttons(cpuwidget.b);
vicious.register(memwidget, vicious.widgets.mem, function(widget, args)
		widget.t:set_text(
			'RAM  [' .. args[1] .. '%] - <b>' .. args[4] .. '</b> MB free\n' ..
			'  ' .. args[2] .. ' / ' .. args[3] .. ' MB\n\n' ..
			'SWAP [' .. args[5] .. '%] - <b>' .. args[8] .. '</b> MB free\n' ..
			'  ' .. args[6] .. ' / ' .. args[7] .. ' MB\n\n' ..
			'mem+buf+cache: ' .. args[9] .. ' MB')
		memwidget.w:set_value(args[1] / 100)
	end, 13)
-- }}}
