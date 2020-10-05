--[[
	LUA widget script for showing data from the F5J Comp Widget

	Displays the 5 latest flights from from current date.
	Complete logs can be found in the /LOGS/F5JComp/ folder

	Releases
	1.00	Initial revision

	Knutigro
--]]

local LOG_PATH = '/LOGS/F5JComp/'
local BASE_PATH = '/WIDGETS/F5JLog/'

local options = {}   -- Widget options

local ui = { bitmaps = {} }  -- Widget User Interface

local f5jLog = { flights = {} }  -- F5J Companion Log

--
-- FJ5 Log
--

f5jLog.getFlights = function()
	local count = 0
	for _ in pairs(f5jLog.flights) do count = count + 1 end
	if count == 0 then
		f5jLog.flights = f5jLog.parseCSVLogData()
	end
	return f5jLog.flights
end

f5jLog.getDateItem = function(number)
	local dateString = ""
	if number < 10 then
		dateString = string.format("0%i", number)
	else
		dateString = string.format("%i", number)
	end
	return dateString
end

f5jLog.getDateString = function(date)
	return string.format("%i-%s-%s", date.year, f5jLog.getDateItem(date.mon), f5jLog.getDateItem(date.day))
end

f5jLog.getCSVLogData = function()
	local startDate = f5jLog.getDateString(f5jLog.getDateTime())
	local filename = string.format("%s.csv", startDate)
	local filePath = string.format("%s%s", LOG_PATH, filename)
	local file = io.open(filePath, "r")

	if file == nil then return "" end

	local fileContent = io.read(file, 10000)
	io.close(file)

	return fileContent
end

f5jLog.split = function(s, sepIn)
    local fields = {}
    local sep = sepIn or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

f5jLog.parseCSVLogData = function()
	local csvData = f5jLog.getCSVLogData()

	local lines = f5jLog.split(csvData, "\n")
	local flights = {}

	for i, line in ipairs(lines) do
		if i > 1 then
			local data = f5jLog.split(line, ",")
			local flight = {
				startDate = f5jLog.split(data[1], " ")[1],
				startTime = f5jLog.split(data[1], " ")[2],
				landingTime = data[2],
				alt10 = data[5],
				flightTime = data[6],
				totalFlightTime = data[8],
				score = {
					total = data[9],
					flight = data[10],
					altitude = data[11]
				}
			}
			flights[i-1] = flight
		end
	end
	return flights
end

--
-- UI
--

ui.getBitmap = function(name)
	if ui.bitmaps[name] == nil then
		ui.bitmaps[name] = Bitmap.open(BASE_PATH ..name..".png")
	end

	return ui.bitmaps[name],Bitmap.getSize(ui.bitmaps[name])
end

ui.unloadBitmap = function(name)
	if ui.bitmaps[name] ~= nil then
		ui.bitmaps[name] = nil
	  -- force call to luaDestroyBitmap()
	  collectgarbage()
	  collectgarbage()
	end
end

ui.drawLogo = function(x, y)
	lcd.drawFilledRectangle(x, y, 320, 46, TITLE_BGCOLOR)
	lcd.drawText( x + 4, y + 4, "F5J", DBLSIZE + CUSTOM_COLOR )
	lcd.drawText( x + 64, y + 14, "- Companion", CUSTOM_COLOR )
	lcd.drawBitmap(ui.getBitmap("glider"),x + 234, y)
end

ui.timeString = function(seconds)
	local number = tonumber(seconds)
	if number == nil then return "-" end
	local min = number / 60
	local sec = number % 60

	if sec < 10 then
		return string.format("%i.0%i", min, sec)
	else
		return string.format("%i.%i", min, sec)
	end
end

ui.drawHeader = function(x, y, width, cellWidth, height)
	local lineY = y + height
	lcd.drawLine(x, lineY, width, lineY, SOLID, 0)
	lcd.drawText( x, y, "Start", SMLSIZE)
	x = x + cellWidth
	lcd.drawText( x, y, "Altitude", SMLSIZE)
	x = x + cellWidth
	lcd.drawText( x, y, "Time", SMLSIZE)
	x = x + cellWidth
	lcd.drawText( x, y, "Flight", SMLSIZE)
	x = x + cellWidth
	lcd.drawText( x, y, "Height", SMLSIZE)
	x = x + cellWidth
	lcd.drawText( x, y, "Total", SMLSIZE)
end

ui.drawSingleFlight = function(flight, x, y, cellWidth)
	lcd.drawText( x, y, flight.startTime, SMLSIZE)
	x = x + cellWidth
	lcd.drawText( x, y, string.format("%im", flight.alt10), SMLSIZE)
	x = x + cellWidth
	lcd.drawText( x, y, ui.timeString(flight.flightTime), SMLSIZE)
	x = x + cellWidth
	lcd.drawText( x, y, string.format("%ip", flight.score.flight) , SMLSIZE)
	x = x + cellWidth
	lcd.drawText( x, y, string.format("%ip", -flight.score.altitude), SMLSIZE)
	x = x + cellWidth
	lcd.drawText( x, y, string.format("%ip", flight.score.total), SMLSIZE)
end

ui.drawFlightList = function(flights, x, y, cellWidth, cellHeight)
	if flights ~= nil then
		local max = 5
		local current = 1
		for index = #flights, 1, -1 do
			if flights[index] and current <= max then
				ui.drawSingleFlight(flights[index],x, y, cellWidth)
				y = y + cellHeight
				current = current + 1
			end
		  end
	end
end

ui.drawDashboard = function(pie)
	lcd.setColor(CUSTOM_COLOR, WHITE)

	local x = pie.zone.x
	local y = pie.zone.y
	local width = pie.zone.w

	local cellWidth = 80
	local cellHeight = 20

	ui.drawLogo(x, y)

	y = y + 60
	ui.drawHeader(x, y, width, cellWidth, cellHeight)

	y = y + 30
	ui.drawFlightList(f5jLog.getFlights(), x, y, cellWidth, cellHeight)
end

--
-- Open TX Widget
--

local function create(zone, options)
	local widget = { zone=zone, options=options, counter=0 }
	return widget
end

local function update(widget, options)
	widget.options = options
end

local function background(pie)
	f5jLog.flights = {}
end

function refresh(pie)
	ui.drawDashboard(pie)
end

return { name="F5JLog", options=options, create=create, update=update, refresh=refresh, background=background }