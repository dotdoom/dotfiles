local awful = require('awful')
local beautiful = require('beautiful')
local wibox = require('wibox')
local vicious = require('vicious')

-- {{{ OK: Battery state
function create(self, bat)
	local widget = wibox.widget.textbox()
	local icon = wibox.widget.imagebox()
	local tooltip = awful.tooltip({
		objects = { widget, icon }
	})
--[[
batwidget.b = awful.util.table.join(
	awful.button({ }, 1, function ()
		vicious.force({ batwidget })
	end),
	awful.button({ }, 3, function ()
		conexec("'sudo powertop'")
	end)
)
batwidget.w:buttons(batwidget.b)
batwidget.i:buttons(batwidget.b)
--]]
	vicious.register({}, vicious.widgets.bat, function(widget, args)
		--if args[2] == 0 then
		--	widget:set_text('')
		--	icon:set_image(nil)
		--else
			widget:set_text(args[1] .. args[2] .. '%')
			icon:set_image(beautiful.widget_bat)
		--end

		--if args[3] == 'N/A' then
		--	tooltip:set_text('')
		--else
			tooltip:set_text(args[3] .. ' remaining')
		--end
	end, 57, bat)

	return { widget }, { icon }
end

return { create = create }
-- }}}
