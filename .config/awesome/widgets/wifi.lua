-- {{{ OK: Wifi
wifiwidget = {}
wifiwidget.i = wibox.widget.imagebox()
wifiwidget.w = wibox.widget.textbox()
wifiwidget.t = awful.tooltip({ objects = { wifiwidget.w, wifiwidget.i } })
wifiwidget.w:buttons(netwidget.b)
wifiwidget.i:buttons(netwidget.b)
vicious.register(wifiwidget, vicious.widgets.wifi, function(widget, args)
		if args['{ssid}'] == 'N/A' then
			widget.t:set_text('')
			widget.i:set_image(nil)
			widget.w:set_text('')
		else
			widget.t:set_text(
				'mode    : ' .. args['{mode}'] .. '\n' ..
				'rate    : ' .. args['{rate}'] .. ' Mbit/s\n' ..
				'channel : ' .. args['{chan}'] .. '\n' ..
				'strength: ' .. args['{sign}'] .. ' db'
			)
			widget.i:set_image(beautiful.widget_wifi)
			widget.w:set_text(' ' .. args['{ssid}'])
		end
	end, 67, 'wlan0')
-- }}}
