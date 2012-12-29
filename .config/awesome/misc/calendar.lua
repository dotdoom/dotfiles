function calendar()
	local head = 'Su Mo Tu We Th Fr Sa'
	local title = os.date('%B %Y')
	while title:len() < head:len() do
		title = ' ' .. title .. ' '
	end

	local calendar = title .. "\n" .. head .. "\n"

	local today_w = tonumber(os.date('%u'))
	local today_m = tonumber(os.date('%d'))
	local day_w = (today_w - today_m + 1) % 7

	local daysmap = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	local year = tonumber(os.date('%Y'))
	if year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then
		daysmap[2] = 29
	end

	calendar = calendar .. string.format('%' .. (day_w*3) .. 's', '')
	local month = tonumber(os.date('%m'))

	for day_m = 1,daysmap[month] do
		if day_m > 9 then
			day_s = day_m
		else
			day_s = '0' .. day_m
		end

		if day_m == today_m then
			day_s = '<span color="yellow"><b>' .. day_s .. '</b></span>'
		end

		calendar = calendar .. day_s .. ' '

		day_w = day_w + 1
		if day_w > 6 then
			day_w = 0
			calendar = calendar .. "\n"
		end
	end

	return calendar;
end
