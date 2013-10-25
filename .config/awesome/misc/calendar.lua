function for_month(month, year)
	--local month_end = os.time(year = year, month = month + 1)
	--local d = os.date("*t", month_end)
	--local days, first_day = d.day, (d.wday - d.day) % 7

	-- build header
	local text = "    "
	for day_of_week = 1, 7 do
		-- Jan 1 2006 is Sunday
		text = text .. os.date("%a ", os.time{year = 2006, month = 1, day = day_of_week})
	end

	text = text .. "\n" .. month .. "." .. year

	return text
end

return { for_month = for_month }
