-- {{{ OK: File system usage
fswidget = {}
fswidget.locations = { '/boot', '/', '/home' }
fswidget.i = wibox.widget.imagebox()
fswidget.i:set_image(beautiful.widget_fs)
fswidget.w = wibox.widget.textbox()
fswidget.t = awful.tooltip({
	objects = { fswidget.i, fswidget.w }
})
fswidget.b = awful.util.table.join(
	awful.button({ }, 1, function () vicious.force({ fswidget }) end),
	awful.button({ }, 3, function () conexec('mc') end)
)
fswidget.w:buttons(fswidget.b)
fswidget.i:buttons(fswidget.b)
fswidget.fs_bars = {}

fswidget.get_fs_widgets = function()
	local ws = {}
	for _,v in pairs(fswidget.fs_bars) do table.insert(ws, v) end
	return ws
end

for index, path in pairs(fswidget.locations) do
	local fs_w = awful.widget.progressbar()
	fs_w:set_vertical(true):set_ticks(true)
	fs_w:set_height(height):set_width(5):set_ticks_size(2)
	fs_w:set_border_color(beautiful.border_widget)
	fs_w:set_background_color(beautiful.fg_off_widget)
--	fs_w:set_gradient_colors({ beautiful.fg_widget,
--		beautiful.fg_center_widget, beautiful.fg_end_widget
--	})
	fs_w:buttons(fswidget.b)
	fswidget.fs_bars[path] = fs_w
	fswidget.t:add_to_object(fs_w)
end

vicious.register(fswidget, vicious.widgets.fs, function(widget, args)
	local tip = ''
	for path,w in pairs(widget.fs_bars) do
		w:set_value(args['{' .. path .. ' used_p}'] / 100)
		tip = tip .. path .. ' [' .. args['{' .. path .. ' used_p}'] .. '%] - <b>' .. args['{' .. path .. ' avail_gb}'] .. '</b> GB free\n' ..
			'  ' .. args['{' .. path .. ' used_gb}'] .. ' / ' .. args['{' .. path .. ' size_gb}'] .. ' GB\n\n'
	end
	widget.t:set_text(tip)
end, 599)
vicious.register(fswidget.w, vicious.widgets.hddtemp, ' ${/dev/sda}C', 17)
-- }}}
