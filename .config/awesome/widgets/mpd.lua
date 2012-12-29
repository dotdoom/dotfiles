-- {{{ OK: MPD
mpdwidget = {};
mpdwidget.i = wibox.widget.imagebox()
mpdwidget.i:set_image(beautiful.widget_music)
mpdwidget.w = wibox.widget.textbox();
mpdwidget.t = awful.tooltip({ objects = { mpdwidget.i, mpdwidget.w } })
mpdwidget.refresh = function() vicious.force({ mpdwidget }) end
externals.hook.after(externals.player, 'update', mpdwidget.refresh)
externals.hook.after(externals.player, 'toggle', mpdwidget.refresh)
externals.hook.after(externals.player, 'prev', mpdwidget.refresh)
externals.hook.after(externals.player, 'next', mpdwidget.refresh)
externals.hook.after(externals.player, 'stop', mpdwidget.refresh)
mpdwidget.b = awful.util.table.join(
	awful.button({ }, 1, function ()
		vicious.force({ mpdwidget })
	end),
	awful.button({ }, 2, externals.player.update),
	awful.button({ }, 3, externals.player.toggle),
	awful.button({ }, 4, externals.player.prev),
	awful.button({ }, 5, externals.player.next)
)
mpdwidget.w:buttons(mpdwidget.b);
vicious.register(mpdwidget, vicious.widgets.mpd, function(widget, args)
	widget.t:set_text(' ' .. args["{Artist}"] .. ' - ' .. args["{Title}"] .. '\n '
		.. args["{Album}"] .. ' (' .. args["{Genre}"] .. ') ')

	local state = args["{state}"]
	if state == "Play" then
		widget.w:set_text('>>')
	else
		if state == "Pause" then
			widget.w:set_text('||')
		else
			widget.w:set_text('[]')
		end
	end
end, 7, { "56379534" })
-- }}}
