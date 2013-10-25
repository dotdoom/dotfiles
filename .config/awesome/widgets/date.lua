local calendar = require("../misc/calendar")
local awful = require('awful')
local beautiful = require('beautiful')
local wibox = require('wibox')
local vicious = require('vicious')

-- {{{ OK: Date and time
function create(self, format)
	local icon = wibox.widget.imagebox()
	icon:set_image(beautiful.widget_date)
	local widget = wibox.widget.textbox()
	local format = format or '%a, %m/%d %R'
	local year, month = 0
	local tooltip = awful.tooltip({
		objects = { widget, icon },
		timer_function = function()
			widget:set_text(os.date(' ' .. format .. ':%S '))
			month, year = os.date('%m'), os.date('%Y')
			return calendar.for_month(month, year)
		end,
		timeout = 60 * 60
	})
	function adjust_calendar(delta_months)
		month = month + delta_months
		tooltip:set_text(calendar.for_month(month, year))
	end

	local button = awful.util.table.join(
		awful.button({ }, 1, function()
			adjust_calendar(-1)
		end),
		awful.button({ }, 3, function()
			adjust_calendar(1)
		end),
		awful.button({ 'Shift' }, 1, function()
			adjust_calendar(-12)
		end),
		awful.button({ 'Shift' }, 3, function()
			adjust_calendar(12)
		end)
	)
	widget:buttons(button)
	icon:buttons(button)
	vicious.register(widget, vicious.widgets.date, ' ' .. format .. ' ', 61)
	return { widget, icon }
end

return { create = create }
-- }}}
