-- {{{ OK: Network usage
netwidget = {}
netwidget.i_dn = wibox.widget.imagebox()
netwidget.i_up = wibox.widget.imagebox()
netwidget.i_dn:set_image(beautiful.widget_net)
netwidget.i_up:set_image(beautiful.widget_netup)
netwidget.w = wibox.widget.textbox()
netwidget.t = awful.tooltip({ objects = { netwidget.i_dn, netwidget.i_up, netwidget.w } })
netwidget.b = awful.util.table.join(
	awful.button({ }, 1, function ()
		vicious.force({ netwidget })
	end),
	awful.button({ }, 3, function ()
		conexec('wicd-curses')
	end)
)
netwidget.w:buttons(netwidget.b)
netwidget.i_dn:buttons(netwidget.b)
netwidget.i_up:buttons(netwidget.b)
vicious.register(netwidget, vicious.widgets.net, function(widget, args)
		local up, down, tip = '', '', ''
		for i=0,19 do
			local eth = 'eth' .. i
			if i > 9 then
				eth = 'wlan' .. (i-10)
			end
			if args['{' .. eth .. ' carrier}'] == 1 then
				if down ~= '' then
					down = down .. '/'
					up   = up   .. '/'
				end
				down = down .. args['{' .. eth .. ' down_kb}']
				up   = up   .. args['{' .. eth .. ' up_kb}']
				tip  = tip  .. eth .. '\n  RX: ' .. args['{' .. eth .. ' rx_mb}'] .. ' MB' ..
				                      '\n  TX: ' .. args['{' .. eth .. ' tx_mb}'] .. ' MB' ..
									  '\n'
			end
		end

		if down ~= '' then
			widget.w:set_markup('<span color="' ..
					  beautiful.fg_netdn_widget .. '">' .. down .. '</span> <span color="' ..
					  beautiful.fg_netup_widget .. '">' .. up .. '</span>')
		else
			widget.w:set_text('N/A')
		end
		widget.t:set_text(tip)
	end, 3)
-- }}}
