-- {{{ OK: gmail
gmailwidget = {}
gmailwidget.i = wibox.widget.imagebox()
gmailwidget.w = wibox.widget.textbox()
gmailwidget.t = awful.tooltip({ objects = { gmailwidget.i, gmailwidget.w } })
gmailwidget.b = awful.util.table.join(
	awful.button({ }, 1, function ()
		vicious.force({ gmailwidget })
	end),
	awful.button({ }, 3, function ()
		externals.mail.open('Inbox')
	end)
)
gmailwidget.w:buttons(gmailwidget.b)
gmailwidget.i:buttons(gmailwidget.b)
vicious.register(gmailwidget, vicious.widgets.gmail, function(widget, args)
		local count = tonumber(args['{count}'])
		if count > 0 then
			widget.t:set_text(args['{subject}'])
			widget.w:set_text(count)
			widget.i:set_image(beautiful.widget_mail)
		else
			widget.w:set_text('')
			widget.i:set_image(nil)
		end
	end, 60 * 15 + 7)
-- }}}
