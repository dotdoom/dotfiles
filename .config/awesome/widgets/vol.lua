-- {{{ OK: Volume level
volwidget = {}
volwidget.i = wibox.widget.textbox()
--volwidget.i:set_image(beautiful.widget_vol)
volwidget.w = awful.widget.progressbar()
volwidget.w:set_vertical(true):set_ticks(true)
volwidget.w:set_height(height):set_width(8):set_ticks_size(2)
volwidget.w:set_background_color(beautiful.fg_off_widget)
--volwidget.w:set_gradient_colors({
--	beautiful.fg_widget,
--	beautiful.fg_center_widget,
--	beautiful.fg_end_widget
--})
volwidget.t = awful.tooltip({ objects = { volwidget.i, volwidget.w } })
volwidget.refresh = function() vicious.force({ volwidget }) end
externals.hook.after(externals.sound, 'down', volwidget.refresh)
externals.hook.after(externals.sound, 'up', volwidget.refresh)
externals.hook.after(externals.sound, 'mute', volwidget.refresh)
volwidget.b = awful.util.table.join(
	awful.button({ }, 1, externals.sound.mute),
	awful.button({ }, 3, externals.sound.manager),
	awful.button({ }, 4, externals.sound.up),
	awful.button({ }, 5, externals.sound.down)
)
volwidget.i:buttons(volwidget.b)
volwidget.w:buttons(volwidget.b)
vicious.register(volwidget, vicious.widgets.volume, function(widget, args)
		widget.i:set_text(args[2] .. ' ')
		widget.w:set_value(args[1] / 100.0)
		widget.t:set_text(args[1] .. '%')
	end,  15, externals.sound.channel)
-- }}}
