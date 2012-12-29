-- {{{ OK: Packages
pkgwidget = {}
pkgwidget.i = wibox.widget.imagebox()
pkgwidget.w = wibox.widget.textbox()
pkgwidget.b = awful.util.table.join(
	awful.button({ }, 1, function ()
		vicious.force({ pkgwidget })
	end),
	awful.button({ }, 3, function ()
		conexec("'yaourt -Suy --aur; read'")
	end)
)
pkgwidget.w:buttons(pkgwidget.b);
pkgwidget.i:buttons(pkgwidget.b);
vicious.register(pkgwidget, vicious.widgets.pkg, function(widget, args)
		local pkcnt = tonumber(args[1])
		if pkcnt > 0 then
			widget.i:set_image(beautiful.widget_pacman)
			widget.w:set_text(pkcnt)
		else
			widget.i:set_image(nil)
			widget.w:set_text('')
		end
	end, 60 * 60 + 13, 'Arch')
-- }}}
