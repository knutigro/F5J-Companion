--[[
	LUA widget script for F5J logging

	Displays the max altitude within 10s after engine cut-off, max reached during the flight and current altitudee
	Displays the flight time, remaining work time and the remaining engine time
	Displays Total points scored in flight by subtracting the altitude points from the flight points

	NB: You probably want your timer 1 set to Countdown: Voice with Minute Call
			       and timer 2 set to Countdown: Voice

	Widget Settings:
	- Trigger -> Throttle kill off + Throttle
	- StateSwitch -> Is used to signal the start of thee flight (down), end of the flight and stop the timers (middle) then reset everything (up)
	- Throttle -> Is used to start the timer. Change to your throttle output.
	- Altitude -> Telemetry for altitude
	- TotalTime -> Maximum flighttime in minutes

	Customization:
	(1) The value where the throttle is meant to be active (defaults to -1024)

	Releases
	1.00	Initial revision

	Knut, knutigro
--]]

local options = {
	{ "Trigger", SOURCE, 0},
	{ "StateSwitch", SOURCE, 0},
	{ "Throttle", SOURCE, 0},
	{ "Altitude", SOURCE, 0 },
	{ "TotalTime", VALUE, 10 }
}

local TRIGGER = getFieldInfo( 'ch3' ).id
local THR = getFieldInfo( 'ch3' ).id
local ALT = getFieldInfo( 'ch2' ).id
local SA = getFieldInfo( 'sa' ).id

local THROTTLE_MIN = -1020			-- (1) (normally -1024)
local TOTAL_FLIGHT_TIME = 10
local MAX_ENGINE_TIME = 30
local THROTTLE_MIN_HYSTERESIS = THROTTLE_MIN + 4
local BASE_PATH = '/WIDGETS/F5JComp/'
local SOUND_PATH = '/WIDGETS/F5JComp/SOUND/'
local LOG_PATH = '/LOGS/F5JComp/'

local f5jLog = {}  -- F5J Companion Log
local ui = { bitmaps = {} }  -- Widget User Interface

--
-- Timer wrapping
--
-- NB:
-- countdownBeep 	integer (none, beep, voice)
-- minuteBeep		bool
-- persistent		integer (none, flight, manual reset)
--
local function createTimer( timerId, startValue, countdownBeep, minuteBeep, persistent, startIt )
	-- Precondition: timerId is either 0 or 1
	local id = timerId
	local timer = model.getTimer( id )
	local target = 0


	local function getVal()
		timer.value = model.getTimer( id ).value
		return timer.value
	end

	local function setTarget( t )
		target = t
	end

	local function start()
		timer.mode = 1
		model.setTimer( id, timer )
	end

	local function stop()
		timer = model.getTimer( id )
		timer.mode = 0
		model.setTimer( id, timer )
		return timer.value
	end

	local function reset()
		timer.value = timer.start
		model.setTimer( id, timer )
		model.resetTimer( id )
	end


	local function drawImpl( x, y, val, att )
		lcd.drawTimer( x, y, val, att )
		return val
	end

	local function draw( x, y, att )
		return drawImpl( x, y, getVal(), att )
	end

	local function drawReverse( x, y, att )
		return drawImpl( x, y, target - getVal(), att )
	end


	-- "constructor"
	if countdownBeep ~= null then
		timer.countdownBeep = countdownBeep
	end

	if minuteBeep ~= null then
		timer.minuteBeep = minuteBeep
	end

	if persistent ~= null then
		timer.persistent = persistent
	end

	if startValue then
		timer.value = startValue
		timer.start = startValue
		target = startValue
	end

	timer.mode = startIt and 1 or 0
	model.setTimer( id, timer )

	return {
		start = start,
		stop = stop,
		reset = reset,
		draw = draw,
		drawReverse = drawReverse,
		getVal = getVal,
		setTarget = setTarget
	}
end

local f5j = {
	flight = {    
		alt = 0,
		alt10 = 0,
		max = 0,
		startTime = 0,
		landingTime = 0,
		state = 1, -- 1=reset; 2=launch; 3=cutoff; 4=glide; 5=landed;
		score = {
			flight = 0,
			altitude = 0,
			landing = 0,
			punishment = 0,
			total = 0
		},
		time3 = 0,
		timer1 = createTimer( 0, TOTAL_FLIGHT_TIME ),	-- flight time
		timer2 = createTimer( 1, MAX_ENGINE_TIME )	-- engine time
	}
}

---
--- Logs
---

f5jLog.stateToString = function()
	local state = f5j.flight.state
	if state == 1 then return "Ready for launch"
	elseif state == 2 then return "Launching"
	elseif state == 3 then return "Start height"
	elseif state == 4 then return "Gliding"
	elseif state == 5 then return "Landed"
	else return "invalid"
	end
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

f5jLog.getDateTimeString = function(date)
	return string.format("%s %s:%s:%s", f5jLog.getDateString(date), f5jLog.getDateItem(date.hour), f5jLog.getDateItem(date.min), f5jLog.getDateItem(date.sec))
end

f5jLog.saveFlight = function()
	local startDate = f5jLog.getDateString(f5j.flight.startTime)

	local filename = string.format("%s.csv", startDate)
	local filePath = string.format("%s%s", LOG_PATH, filename)
	local fileExist = io.open(filePath, "r")
	local file = io.open(filePath, "a+")

	local fileContent = ""

	if fileExist then
		fileContent = fileContent .. "\n"
	else
		local header = "Start, Land, State, Max Altitude, Start Altitude, Airtime (s), Engingetime (s), MaxLaptime (s),TotalScore, FlightScore, AltitudeScore, LandingScore, Punishment\n"
		fileContent = fileContent .. header
	end

	fileContent = fileContent .. string.format("%s", f5jLog.getDateTimeString(f5j.flight.startTime))
	fileContent = fileContent .. string.format(",%s", f5jLog.getDateTimeString(f5j.flight.landingTime))
	fileContent = fileContent .. string.format(",%s", f5jLog.stateToString())
	fileContent = fileContent .. string.format(",%i", f5j.flight.max)
	fileContent = fileContent .. string.format(",%i", f5j.flight.alt10)
	fileContent = fileContent .. string.format(",%i", f5j.flight.time3)
	fileContent = fileContent .. string.format(",%i", f5j.flight.timer2.getVal())
	fileContent = fileContent .. string.format(",%i", TOTAL_FLIGHT_TIME)
	fileContent = fileContent .. string.format(",%i", f5j.flight.score.total)
	fileContent = fileContent .. string.format(",%i", f5j.flight.score.flight)
	fileContent = fileContent .. string.format(",%i", f5j.flight.score.altitude)
	fileContent = fileContent .. ",0"
	fileContent = fileContent .. ",0"

	local result = io.write(file, fileContent)
	print(result)
	io.close(file)
end

---
--- F5J
---

f5j.vocalEnabled = function()
	return true
end

f5j.handleScore =  function()
	f5j.flight.score.flight = f5j.flight.time3

	if f5j.flight.alt10 > 0 then
		f5j.flight.score.altitude = math.min (f5j.flight.alt10, 200) * 0.5
		if f5j.flight.alt10 > 200 then
			f5j.flight.score.altitude = f5j.flight.score.altitude + ((f5j.flight.alt10  - 200) * 3)
		end
	end

	f5j.flight.score.total = f5j.flight.score.flight - f5j.flight.score.altitude
end

f5j.handleMaxAltitude = function()
	local a = math.min (getValue( ALT ), 500)
	if a > f5j.flight.max then
		f5j.flight.max = a
	end
	return a
end

f5j.handleStartAltitude = function()
	f5j.flight.alt10 = math.max (f5j.handleMaxAltitude(), f5j.flight.alt10)
end

f5j.checkThrottle = function()
	if getValue( THR ) > THROTTLE_MIN_HYSTERESIS then
		playTone(888, 100, 0, 0)
	end
end

f5j.checkReset = function()
	if getValue( SA ) < 0 then
		f5j.flight.timer2.stop()
		f5j.flight.timer1.stop()
		f5j.flight.timer2.reset()
		f5j.flight.timer1.reset()
		f5j.flight.time3 = 0

		f5j.flight.time3 = 0
		f5j.flight.alt = 0
		f5j.flight.alt10 = 0
		f5j.flight.max = 0

		f5j.flight.score.altitude = 0
		f5j.flight.score.flight = 0
		f5j.flight.score.total = 0

		f5j.flight.state = 1
		return true
	end
	return false
end

f5j.checkEnd = function()
	return (getValue( SA ) == 0) or f5j.flight.time3 >= TOTAL_FLIGHT_TIME
end

f5j.goToLandedState = function()
	f5j.flight.landingTime = getDateTime()
	f5j.flight.timer2.stop()
	f5j.flight.timer1.stop()
	f5j.flight.state = 5
	f5jLog.saveFlight()
end

f5j.resetState = function()
	-- wait for take-off
	if getValue( TRIGGER ) > THROTTLE_MIN_HYSTERESIS then
		playFile( SOUND_PATH .. 'engon.wav' )
		f5j.flight.timer2.start()
		f5j.flight.timer1.start()
		f5j.flight.startTime = getDateTime()
		f5j.flight.state = 2
	end
end

f5j.launchState = function()
	f5j.handleMaxAltitude()
	f5j.handleStartAltitude()
	f5j.handleScore()

	-- wait for the motor cut
	if f5j.checkEnd() then
		f5j.goToLandedState()
	elseif getValue( THR ) <= THROTTLE_MIN then
		f5j.flight.timer2.stop()
		if f5j.vocalEnabled() then
			playNumber( f5j.flight.alt, 0, 0 )
		end
		f5j.flight.state = 3
	elseif f5j.flight.time3 >= MAX_ENGINE_TIME then
		f5j.flight.timer2.stop()
		playFile( SOUND_PATH .. 'engoff.wav' )
		f5j.flight.state = 3
	end
end

f5j.cutoffState = function()
	f5j.handleStartAltitude()
	f5j.handleScore()

	if f5j.checkEnd() then
		f5j.goToLandedState()
	else
		-- wait for the 10s end
		if (f5j.flight.time3 - (MAX_ENGINE_TIME - f5j.flight.timer2.getVal())) >= 10 then
				if f5j.vocalEnabled() then
					playNumber( f5j.flight.alt10, 0, 0 )
				end
				f5j.flight.state = 4
		else
			f5j.checkThrottle()
		end
	end
end

f5j.glideState = function()
	f5j.handleMaxAltitude()
	f5j.handleScore()

	-- wait for the end of flight
	if f5j.checkEnd() then
		f5j.goToLandedState()
	else
		f5j.checkThrottle()
	end
end

f5j.landedState = function()
	-- wait for reset
	f5j.checkReset()
end

f5j.functions = { f5j.resetState, f5j.launchState, f5j.cutoffState, f5j.glideState, f5j.landedState }

f5j.main = function()
	f5j.flight.time3 = TOTAL_FLIGHT_TIME - f5j.flight.timer1.getVal()
	f5j.functions[ f5j.flight.state ]()
	f5j.checkReset()
end

---
--- UI
---

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

ui.drawHeader = function(x, y)
	lcd.drawFilledRectangle(x, y, 180, 65, TITLE_BGCOLOR)
	lcd.drawBitmap(ui.getBitmap("glider"),x + 4 , y + 4)
	lcd.drawText( x + 102, y, "F5J", DBLSIZE + CUSTOM_COLOR )
	lcd.drawText( x + 56, y + 38, "- Companion", CUSTOM_COLOR )
end

ui.drawAltitude = function(x, y, margin, lineDistance)
	lcd.drawText( x, y, "Altitude:", MIDSIZE )
	lcd.drawText( x + margin - 2, y, string.format("%im", f5j.flight.alt10), MIDSIZE )

	y = y + lineDistance + 10

	lcd.drawText( x, y, "Current:")
	lcd.drawText( x + margin, y, string.format("%im", getValue( ALT )) )

	y = y + lineDistance

	lcd.drawText( x, y, "Max:")
	lcd.drawText( x + margin, y, string.format("%im", f5j.flight.max) )
end

ui.drawScore = function(x, y, margin, lineDistance)
	lcd.drawText( x, y, "Score:", MIDSIZE )
	lcd.drawText( x + margin - 2, y, string.format("%i", f5j.flight.score.total), MIDSIZE )

	y = y + lineDistance + 10

	lcd.drawText( x, y, "Flight score:")
	lcd.drawText( x + margin, y, string.format("%i", f5j.flight.score.flight) )

	y = y + lineDistance

	lcd.drawText( x, y, "Altitude:")
	lcd.drawText( x + margin, y, string.format("%i", -f5j.flight.score.altitude) )
end

ui.drawTime = function(x, y, margin, lineDistance)
	lcd.drawText( x, y, "Time:", MIDSIZE )
	lcd.drawTimer( x + margin - 2, y, f5j.flight.time3, MIDSIZE  )

	y = y + lineDistance + 10

	lcd.drawText( x, y, "Work:" )
	f5j.flight.timer1.draw( x + margin, y)

	y = y + lineDistance

	lcd.drawText( x, y, "Engine:" )
	f5j.flight.timer2.draw( x + margin , y )
end

ui.drawState = function(x, y)
	lcd.drawText( x + 50, y, string.format("- %s -", f5jLog.stateToString()), SMLSIZE )
end

ui.drawDashboard = function(pie)
	lcd.setColor(CUSTOM_COLOR, WHITE)

	local x = pie.zone.x
	local y = pie.zone.y
	local width = pie.zone.w
	local column2x = (width / 2) + 50
	local lineDistance = 20
	local margin = 120

	ui.drawHeader(x, y)

	ui.drawScore(column2x, y, margin, lineDistance)

	ui.drawTime(x, y + 90, margin, lineDistance)

	ui.drawState(x + 110, y + 190)

	ui.drawAltitude(column2x, y + 90, margin, lineDistance)
end

--
-- Open TX Widget
--

local function updateWithOptions(options)
	TOTAL_FLIGHT_TIME = 10 * 60 -- options.TotalTime * 60
	ALT = options.Altitude
	SA = options.StateSwitch
	THR = options.Throttle
	TRIGGER = options.Trigger

	f5j.flight.timer1 = createTimer( 0, TOTAL_FLIGHT_TIME )	-- flight time
	f5j.flight.timer2 = createTimer( 1, MAX_ENGINE_TIME )	-- engine time
end

local function create(zone, options)
	local widget = { zone=zone, options=options, counter=0 }
	updateWithOptions(options)

	return widget
end

local function update(widget, options)
	widget.options = options
	updateWithOptions(options)
end

local function background(pie)
	ui.unloadBitmap("glider")
end

function refresh(pie)
	f5j.main()
	ui.drawDashboard(pie)
end

return { name="F5JComp", options=options, create=create, update=update, refresh=refresh, background=background }