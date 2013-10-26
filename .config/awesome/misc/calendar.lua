function for_month(month, year, formats)
	-- build header
	local text = "    "
	for day_of_week = 1, 7 do
		-- Jan 1 2006 is Sunday
		text = text .. os.date("%a ", os.time{year = 2006, month = 1, day = day_of_week})
	end

	formats = formats or {}

	local week = tonumber(os.date("%V", os.time{year = year, month = month, day = 1}))
	local current_day = os.date("*t")

	local prev_month_last_day = os.date("*t", os.time{year = year, month = month, day = 0})
	local month_last_day = os.date("*t", os.time{year = year, month = month + 1, day = 0})
	for day = 1 - (prev_month_last_day.wday % 7), month_last_day.day do
		if (day + prev_month_last_day.wday - 1) % 7 == 0 then
			text = text .. "\n " .. string.format("%.2d", week)
			week = week + 1
		end
		local day_format, day_number
		if day <= 0 then
			day_format = "prev_month"
			day_number = prev_month_last_day.day + day
		elseif day == current_day.day and
				month_last_day.month == current_day.month and 
				month_last_day.year == current_day.year then
			day_format = "today"
			day_number = day
		else
			day_format = "default"
			day_number = day
		end

		text = text .. "  " .. string.format(formats[day_format] or "%s", string.format("%2d", day_number))
	end

	return string.format("%.2d.%d", month_last_day.month, month_last_day.year) .. "\n" .. text
end

return { for_month = for_month }
