-- AllTheInfo CSP Lua App
-- Authored by ohyeah2389


local car = ac.getCar(0)
local sim = ac.getSim()
local session = ac.getSession(sim.currentSessionIndex)
local font_whiteRabbit = ui.DWriteFont("fonts/whitrabt.ttf")


-- UI Settings
local config = {
    rpm = {
        shiftLightsEnabled = true,
        fadeStart = 0.6,
        lightsStart = 0.76,
        shiftPoint = 0.96
    },
    delta = {
        compareMode = "SESSION",
        numberShown = true,
        extrapolationTime = 0.5,
        resolution = 0.05
    },
    tire = {
        zeroWearState = 0.9,
        tempThresholds = { 0.4, 0.8, 0.05, 1.2, 1.4 },
        wearThresholds = { 10, 20, 35, 80 }
    },
    fuel = {
        maxHistorySize = 5,
        improvementThreshold = 0.97
    },
    flash = {
        duration = 0.15,
        count = 5
    }
}

local displaySettings = {
    positions = {
        [1680] = { -- 1050p
            dash = { offset = 1040 },
            delta = { offset = 800 }
        },
        [2560] = { -- 1440p
            dash = { offset = 155 },
            delta = { offset = 1050 }
        },
        [7680] = { -- Triple screen
            dash = { offset = 1430 },
            delta = { offset = 1050 }
        },
        [1920] = { -- 1080p
            dash = { offset = 155 },
            delta = { offset = 865 }
        },
        default = { -- Default fallback
            dash = { offset = 155 },
            delta = { offset = 865 }
        }
    }
}

local tireTempColors = {
    ambient = rgbm(0.2, 0, 0.4, 1),    -- Purple for ambient temperature
    cold = rgbm(0, 0, 1, 1),           -- Blue for cold
    optimal = rgbm(0, 1, 0, 1),        -- Green for optimal temperature
    hot = rgbm(1, 1, 0, 1),            -- Yellow for hot
    veryhot = rgbm(1, 0, 0, 1),        -- Red for very hot
    explosion = rgbm(0.1, 0.1, 0.1, 1) -- Black for explosion temperature
}

local tireTempThresholds = {
    ambient = 0.4,  -- Purple below this % of optimal
    cold = 0.8,     -- Blue between ambient and this % of optimal
    optimal = 0.05, -- Green within this +/- % of optimal
    hot = 1.2,      -- Yellow between optimal and this, Red above
    explosion = 1.4 -- Black above this (near explosion temp)
}

local tireWearConfig = {
    thresholds = {
        transparent = 10, -- Below this % wear is transparent
        yellow = 20,      -- Fade from transparent to yellow up to this %
        red = 35,         -- Fade from yellow to red up to this %
        black = 80        -- Fade from red to black up to this %
    },
    colors = {
        transparent = rgbm(0, 0, 0, 0),
        yellow = rgbm(1, 1, 0, 0.8),
        red = rgbm(1, 0, 0, 1),
        black = rgbm(0, 0, 0, 1)
    }
}

local drsColors = {
    inactive = rgbm(0.5, 0.5, 0.5, 1), -- Grey for out of DRS zone
    available = rgbm(1, 1, 0, 1),      -- Yellow for available but not active
    active = rgbm(0, 1, 0, 1)          -- Green for active
}

local assistColors = {
    abs = rgbm(1, 0.2, 0.2, 0.7),
    tc = rgbm(0, 0.2, 1, 0.7)
}


-- Constants
local newTimeFlashDuration = 0.15     -- Duration of each flash (on/off) - faster flashing
local newTimeFlashCount = 5           -- Number of flashes
local deltaExtrapolationTime = 0.5    -- How long to extrapolate delta for (in seconds)
local fuelImprovementThreshold = 0.97 -- 3% improvement is considered significant

local raceSimEnabled = false          -- Default to disabled
local raceSimMode = "time"            -- "time" or "laps"
local raceSimTime = 1800              -- Default 30 minutes (in seconds)
local raceSimLaps = 10                -- Default 10 laps


-- Track and car identifiers
local trackDataFile = nil
local personalBestDir = nil
local trackRecords = {}
local allTimeBestLap = 0


-- Delta tracking
local deltaCompareModes = { SESSION = "SB", PERSONAL = "PB" }
local currentDelta = nil
local currentDeltaChangeRate = nil
local lastGoodDelta = nil
local lastGoodDeltaTime = 0
local lastGoodDeltaChangeRate = nil
local deltaTimer = 0
local posList = {}
local timeList = {}
local bestPosList = {}
local bestTimeList = {}
local personalBestPosList = {}
local personalBestTimeList = {}


-- Lap tracking
local previousLapCount = 0
local previousLapProgressValue = 0
local currentLapIsInvalid = false
local previousLapValidityValue = false
local lastLapValue = 0
local bestLapValue = 0
local personalBestLapValue = 0


-- Delta trend tracking
local prevt = 0
local prevt2 = 0
local trendBuffer = {}     -- Buffer to store recent trend values
local trendBufferIndex = 1 -- Current position in circular buffer


-- Lap status flags and timing
local lastLapWasSessionBest = false
local lastLapWasPersonalBest = false
local sessionBestWasSetTime = 0
local personalBestWasSetTime = 0
local lapCountWhenTimeExpired = 0
local timeExpired = false


-- Fuel tracking
local fuelUsageHistory = {}
local maxFuelHistorySize = 5
local lastLapFuelLevel = car.fuel
local lastLapFuelUsed = 0
local personalBestFuelUsage = nil
local FuelDataPoint = {
    usage = 0,
    weight = 0,
    lapTime = 0
}


-- Performance tracking
local maxSeenBoost = 0


-- Debug variables
local debugI = 0
local debugP1 = nil
local debugP2 = nil
local debugT1 = nil
local debugT2 = nil


-- Tire wear tracking
local tireWearLUTs = {
    front = nil,                 -- Will be loaded on first use
    rear = nil,                  -- Will be loaded on first use
    frontPeak = nil,             -- Cache the peak grip value
    rearPeak = nil               -- Cache the peak grip value
}
local currentCompoundIndex = nil -- Track current compound to detect changes


-- UI state
local personalBestFlashStartTime = 0
local PERSONAL_BEST_FLASH_DURATION = 0.1
local PERSONAL_BEST_FLASH_COUNT = 8
local sessionBestFlashStartTime = 0
local SESSION_BEST_FLASH_DURATION = 0.1
local SESSION_BEST_FLASH_COUNT = 8


local lastSessionTimeLeft = 0       -- Track previous session time
local sessionTimeJumpThreshold = 10 -- Time jump threshold in seconds


function FuelDataPoint.new(usage, weight)
    return { usage = usage, weight = weight, lapTime = 0 }
end

local function getNextMode(currentMode)
    local modes = {}
    for mode in pairs(deltaCompareModes) do
        table.insert(modes, mode)
    end
    table.sort(modes) -- Ensure consistent order

    for i, mode in ipairs(modes) do
        if mode == currentMode then
            return modes[i == #modes and 1 or i + 1]
        end
    end
    return modes[1] -- Fallback to first mode
end


local function getTrackIdentifier()
    local layout = ac.getTrackLayout()
    if layout and layout ~= "" then
        return ac.getTrackID() .. '_' .. layout
    end
    return ac.getTrackID()
end


local function getWindDirectionText(degrees)
    degrees = degrees % 360
    local directions = {
        { name = "N",   range = 11.25 },
        { name = "NNE", range = 33.75 },
        { name = "NE",  range = 56.25 },
        { name = "ENE", range = 78.75 },
        { name = "E",   range = 101.25 },
        { name = "ESE", range = 123.75 },
        { name = "SE",  range = 146.25 },
        { name = "SSE", range = 168.75 },
        { name = "S",   range = 191.25 },
        { name = "SSW", range = 213.75 },
        { name = "SW",  range = 236.25 },
        { name = "WSW", range = 258.75 },
        { name = "W",   range = 281.25 },
        { name = "WNW", range = 303.75 },
        { name = "NW",  range = 326.25 },
        { name = "NNW", range = 348.75 },
        { name = "N",   range = 360 }
    }

    for i, dir in ipairs(directions) do
        if degrees <= dir.range then
            return dir.name
        end
    end
    return "N" -- fallback
end


local function getElementPosition(elementWidth, elementType)
    local horizontalCenter = (sim.windowWidth / 2) - (elementWidth / 2)
    local preset = displaySettings.positions[sim.windowWidth] or displaySettings.positions.default
    local verticalOffset = preset[elementType].offset

    return vec2(horizontalCenter, sim.windowHeight - verticalOffset)
end


-- Math helper function, like Map Range in Blender
local function mapRange(n, start, stop, newStart, newStop, clamp)
    local value = ((n - start) / (stop - start)) * (newStop - newStart) + newStart

    -- Returns basic value
    if not clamp then
        return value
    end

    -- Returns values constrained to exact range
    if newStart < newStop then
        return math.clamp(value, newStart, newStop)
    else
        return math.clamp(value, newStop, newStart)
    end
end


-- Helper function for calculating background alpha fading
local function fadeBackground(setTime)
    local timeSinceSet = os.clock() - setTime
    if timeSinceSet < 3 then
        return 0.5                                -- Full opacity for first 3 seconds
    elseif timeSinceSet < 6 then
        return 0.5 * (1 - (timeSinceSet - 3) / 3) -- Fade out over next 3 seconds
    end
    return 0                                      -- Fully transparent after 6 seconds
end


local function findPeakGrip(lut)
    local peak = 0
    local serialized = lut:serialize()

    -- Debug raw LUT data
    ac.debug("Raw LUT data", serialized)

    -- Parse the serialized LUT data to find peak value
    for line in serialized:gmatch("[^\r\n]+") do
        -- Remove any whitespace
        line = line:gsub("%s+", "")
        -- Split on pipe character
        local parts = {}
        for part in line:gmatch("[^|]+") do
            table.insert(parts, part)
        end

        if #parts >= 2 then
            local value = tonumber(parts[2])
            if value then
                peak = math.max(peak, value)
                ac.debug("Found value", value)
                ac.debug("Peak grip", peak)
            end
        end
    end

    if peak == 0 then
        -- Fallback to 100 if we couldn't parse the LUT
        ac.log("Warning: Could not find peak grip value, using fallback of 100")
        peak = 100
    end

    return peak
end


local function getTireGripFromWear(wheel)
    -- Load LUTs if not already loaded
    if not tireWearLUTs.front or not tireWearLUTs.rear then
        -- Get tire data to find wear curve filenames
        local tireData = ac.INIConfig.carData(0, "tyres.ini")

        -- Get current compound index
        local compoundIndex = ac.getCar(0).compoundIndex

        -- Build section names based on compound index
        local frontSection = compoundIndex == 0 and "FRONT" or string.format("FRONT_%d", compoundIndex)
        local rearSection = compoundIndex == 0 and "REAR" or string.format("REAR_%d", compoundIndex)

        -- Get wear curve filenames for current compound
        local frontWearCurve = tireData:get(frontSection, "WEAR_CURVE", "tyres_wear_curve.lut")
        local rearWearCurve = tireData:get(rearSection, "WEAR_CURVE", "tyres_wear_curve.lut")

        ac.debug("Compound index", compoundIndex)
        ac.debug("Front section", frontSection)
        ac.debug("Rear section", rearSection)
        ac.debug("Front wear curve", frontWearCurve)
        ac.debug("Rear wear curve", rearWearCurve)

        -- Load the wear curves
        tireWearLUTs.front = ac.DataLUT11.carData(0, frontWearCurve)
        tireWearLUTs.rear = ac.DataLUT11.carData(0, rearWearCurve)

        -- Find and cache peak grip values
        tireWearLUTs.frontPeak = findPeakGrip(tireWearLUTs.front)
        tireWearLUTs.rearPeak = findPeakGrip(tireWearLUTs.rear)

        ac.debug("Front peak grip", tireWearLUTs.frontPeak)
        ac.debug("Rear peak grip", tireWearLUTs.rearPeak)
    end

    -- Get the appropriate LUT and peak value based on wheel position
    local isFront = (wheel == 0 or wheel == 1)
    local wearLUT = isFront and tireWearLUTs.front or tireWearLUTs.rear
    local peakGrip = isFront and tireWearLUTs.frontPeak or tireWearLUTs.rearPeak

    -- Get virtual KM for this wheel
    local vkm = ac.getCar(0).wheels[wheel].tyreVirtualKM

    -- Get raw grip value from LUT
    local rawGrip = wearLUT:get(vkm)

    -- Rescale grip value:
    -- 1. Normalize to peak (handles break-in period by using peak as 100%)
    -- 2. Rescale so that 80% becomes 0% on display
    local normalizedGrip = rawGrip / peakGrip                                                          -- Now 0-1 relative to peak
    local displayGrip = (normalizedGrip - config.tire.zeroWearState) /
    (1 - config.tire.zeroWearState)                                                                    -- Rescale 0.8-1.0 to 0-1

    -- Clamp final value to 0-1 range
    displayGrip = math.clamp(displayGrip, 0, 1)

    -- Debug values
    ac.debug(string.format("Wheel %d raw grip", wheel), rawGrip)
    ac.debug(string.format("Wheel %d normalized", wheel), normalizedGrip)
    ac.debug(string.format("Wheel %d display", wheel), displayGrip)

    return displayGrip
end


-- Initialize paths after state variables are declared
trackDataFile = string.format("%s/lua/AllTheInfo/track_records/%s.ini",
    ac.getFolder(ac.FolderID.ACApps),
    ac.getCarID(0))


personalBestDir = string.format("%s/lua/AllTheInfo/personal_best/%s",
    ac.getFolder(ac.FolderID.ACApps),
    ac.getCarID(0))



function table.shallow_copy(t)
    local t2 = {}
    for k, v in pairs(t) do
        t2[k] = v
    end
    return t2
end

local function loadTrackRecords()
    -- Create directories if they don't exist
    local baseDir = ac.getFolder(ac.FolderID.ACApps) .. '/lua/AllTheInfo'
    local recordsDir = baseDir .. '/track_records'

    if not io.exists(baseDir) then
        os.execute('mkdir "' .. baseDir .. '"')
    end
    if not io.exists(recordsDir) then
        os.execute('mkdir "' .. recordsDir .. '"')
    end

    -- Try to load existing records
    if io.exists(trackDataFile) then
        local records = {}
        local ini = ac.INIConfig.load(trackDataFile)

        -- Verify ini loaded correctly
        if type(ini) == 'table' then
            -- Load each track's data from the INI
            for section in pairs(ini) do
                if section ~= 'HEADER' and type(ini[section]) == 'table' then
                    local timeValue = tonumber(ini[section].time)
                    if timeValue then
                        records[section] = {
                            time = timeValue,
                            date = ini[section].date or os.date("%Y-%m-%d %H:%M:%S")
                        }
                    end
                end
            end
        end
        return records
    end
    return {}
end
local trackRecords = loadTrackRecords()

-- Update the resetSessionData function to be more selective
local function resetSessionData()
    -- Reset lap tracking
    previousLapCount = 0
    previousLapProgressValue = 0
    currentLapIsInvalid = false
    previousLapValidityValue = false
    lastLapValue = 0
    bestLapValue = 0 -- Reset session best

    -- Reset current lap delta tracking but preserve comparison data
    posList = {}
    timeList = {}
    currentDelta = nil
    currentDeltaChangeRate = nil
    lastGoodDelta = nil
    lastGoodDeltaTime = 0

    -- Reset fuel tracking for new session
    fuelUsageHistory = {}
    lastLapFuelLevel = car.fuel
    lastLapFuelUsed = 0

    -- Reset trend tracking
    prevt = 0
    prevt2 = 0
    ttb = 0
    trendBuffer = {}
    trendBufferIndex = 1

    -- Reset lap status flags
    lastLapWasSessionBest = false
    lastLapWasPersonalBest = false

    -- Reset additional lap tracking
    timeExpired = false
    lapCountWhenTimeExpired = 0

    -- Reset max boost tracking
    maxSeenBoost = 0

    print("Session data reset completed - Lap count:" .. car.lapCount)
end


local function savePersonalBest()
    -- Create directories if needed
    local baseDir = ac.getFolder(ac.FolderID.ACApps) .. '/lua/AllTheInfo'
    local fullDir = personalBestDir

    if not io.exists(baseDir) then
        os.execute('mkdir "' .. baseDir .. '"')
    end
    if not io.exists(fullDir) then
        os.execute('mkdir "' .. fullDir .. '"')
    end

    -- Generate filename
    local filename = string.format("%s/%s.txt", fullDir, getTrackIdentifier())

    -- Create simple text file with data
    local file = io.open(filename, "w")
    if file then
        -- Write metadata
        file:write(string.format("TIME=%d\n", personalBestLapValue))   -- Changed to use personalBestLapValue
        file:write(string.format("DATE=%s\n", os.date("%Y-%m-%d %H:%M:%S")))
        file:write(string.format("POINTS=%d\n", #personalBestPosList)) -- Changed to use personalBestPosList
        -- Add fuel usage data
        file:write(string.format("FUEL=%.3f\n", lastLapFuelUsed))

        -- Write positions - make sure we have data to write
        if #personalBestPosList > 0 then                 -- Changed to use personalBestPosList
            file:write("POSITIONS\n")
            for i, pos in ipairs(personalBestPosList) do -- Changed to use personalBestPosList
                file:write(string.format("%d=%f\n", i, pos))
            end
        end

        -- Write times - make sure we have data to write
        if #personalBestTimeList > 0 then                  -- Changed to use personalBestTimeList
            file:write("TIMES\n")
            for i, time in ipairs(personalBestTimeList) do -- Changed to use personalBestTimeList
                file:write(string.format("%d=%d\n", i, time))
            end
        end

        file:close()
        ac.log("Saved personal best with positions:" .. #personalBestPosList) -- Changed debug output
        ac.log("Saved personal best with times:" .. #personalBestTimeList)    -- Changed debug output
    end
end


local function loadPersonalBest()
    local filename = string.format("%s/%s.txt", personalBestDir, getTrackIdentifier())

    if io.exists(filename) then
        local file = io.open(filename, "r")
        if file then
            -- Clear existing data
            personalBestPosList = {}
            personalBestTimeList = {}
            personalBestFuelUsage = nil

            local section = ""
            for line in file:lines() do
                -- Check for metadata
                local time = line:match("TIME=(%d+)")
                if time then
                    personalBestLapValue = tonumber(time)
                end

                -- Check for fuel usage data
                local fuel = line:match("FUEL=([%d%.]+)")
                if fuel then
                    personalBestFuelUsage = tonumber(fuel)
                end

                -- Track which section we're in
                if line == "POSITIONS" then
                    section = "positions"
                elseif line == "TIMES" then
                    section = "times"
                else
                    -- Parse data lines
                    local index, value = line:match("(%d+)=([%d%.]+)")
                    if index and value then
                        if section == "positions" then
                            personalBestPosList[tonumber(index)] = tonumber(value)
                        elseif section == "times" then
                            personalBestTimeList[tonumber(index)] = tonumber(value)
                        end
                    end
                end
            end

            file:close()
            ac.log("Loaded personal best:" .. personalBestLapValue)
            ac.log("Loaded positions:" .. #personalBestPosList)
            ac.log("Loaded times:" .. #personalBestTimeList)
            ac.log("Loaded fuel usage:" .. personalBestFuelUsage)
        end
    end
end


local function getLapDelta()
    local deltaT = ac.getGameDeltaT()
    local currentLapTime = car.lapTimeMs
    local lapProgress = car.splinePosition

    -- Combined early exits and lap reset
    if currentLapTime > 500 and currentLapTime < 1000 then
        posList, timeList = {}, {}
        previousLapProgressValue, prevt, prevt2, ttb = 0, 0, 0, 0
        trendBuffer, trendBufferIndex = {}, 1
        currentLapIsInvalid, lastGoodDelta, lastGoodDeltaTime = false, nil, 0
    end

    -- Update data collection
    deltaTimer = deltaTimer + deltaT
    if deltaTimer > config.delta.resolution then
        deltaTimer = 0
        if lapProgress > previousLapProgressValue and lapProgress < 1 then
            table.insert(timeList, currentLapTime)
            table.insert(posList, lapProgress)
        end
        previousLapProgressValue = lapProgress
    end

    -- Combined early exit conditions
    if currentLapTime <= 500 or lapProgress <= 0.001 or lapProgress >= 0.999 or
        #(config.delta.compareMode == "SESSION" and bestPosList or personalBestPosList) == 0 then
        return lastGoodDelta and (sim.time - lastGoodDeltaTime) < config.delta.extrapolationTime and
            lastGoodDelta + (lastGoodDeltaChangeRate or 0) * deltaT or nil, lastGoodDeltaChangeRate
    end

    -- Get comparison data
    local compList = config.delta.compareMode == "SESSION" and { bestPosList, bestTimeList } or
    { personalBestPosList, personalBestTimeList }

    -- Find interpolation points
    local i = 1
    while i < #compList[1] and compList[1][i] < lapProgress do i = i + 1 end
    i = math.max(1, i - 1)

    local p1, p2 = compList[1][i], compList[1][i + 1]
    local t1, t2 = compList[2][i], compList[2][i + 1]

    -- Handle close points
    if p1 and p2 and math.abs(p2 - p1) < 0.0001 then
        local j = i + 2
        while j <= #compList[1] and math.abs(compList[1][j] - p1) < 0.0001 do j = j + 1 end
        if j <= #compList[1] then p2, t2 = compList[1][j], compList[2][j] end
    end

    -- Calculate delta and trend in one block
    if p1 and p2 and t1 and t2 and math.abs(p2 - p1) >= 0.0001 then
        local interpolatedTime = t1 + ((t2 - t1) / (p2 - p1)) * (lapProgress - p1)
        local delta = (currentLapTime - interpolatedTime) / 1000

        -- Integrated trend calculation
        local trend = 0
        if prevt2 and currentLapTime > 1500 then
            local newTrend = 2 * delta - prevt - prevt2
            trendBuffer[trendBufferIndex] = newTrend
            trendBufferIndex = trendBufferIndex % 10 + 1

            local sum, count = 0, 0
            for _, v in pairs(trendBuffer) do
                if v then sum, count = sum + v, count + 1 end
            end
            trend = count > 0 and sum / count or 0
        end

        prevt2, prevt = prevt, delta
        lastGoodDelta, lastGoodDeltaTime, lastGoodDeltaChangeRate = delta, sim.time, trend

        return delta, trend
    end

    -- Extrapolation fallback
    return lastGoodDelta and (sim.time - lastGoodDeltaTime) < config.delta.extrapolationTime and
        lastGoodDelta + (lastGoodDeltaChangeRate or 0) * deltaT or nil, lastGoodDeltaChangeRate
end


local function storeBestLap()
    -- Only store if we have enough data points and the lap was valid
    if #posList > 10 and not currentLapIsInvalid and lastLapValue > 0 then
        -- Create copies of the lists BEFORE clearing them
        local posListCopy = table.shallow_copy(posList)
        local timeListCopy = table.shallow_copy(timeList)

        ac.log("Storing best lap with positions:" .. #posListCopy)
        ac.log("Storing best lap with times:" .. #timeListCopy)

        -- Reset flags first
        lastLapWasSessionBest = false
        lastLapWasPersonalBest = false

        -- Update session best if this lap is faster
        if bestLapValue == 0 or lastLapValue < bestLapValue then
            bestPosList = table.shallow_copy(posListCopy)
            bestTimeList = table.shallow_copy(timeListCopy)
            bestLapValue = lastLapValue
            lastLapWasSessionBest = true
            sessionBestWasSetTime = os.clock()
            sessionBestFlashStartTime = os.clock()
        end

        -- Update personal best if this lap is faster
        if personalBestLapValue == 0 or lastLapValue < personalBestLapValue then
            personalBestPosList = table.shallow_copy(posListCopy)
            personalBestTimeList = table.shallow_copy(timeListCopy)
            personalBestLapValue = lastLapValue
            lastLapWasPersonalBest = true
            personalBestWasSetTime = os.clock()
            personalBestFlashStartTime = os.clock()
            savePersonalBest() -- Save to file
        end

        -- Update all-time best if this lap is faster
        if allTimeBestLap == 0 or lastLapValue < allTimeBestLap then
            allTimeBestLap = lastLapValue
            trackRecords[getTrackIdentifier()] = {
                time = lastLapValue,
                date = os.date("%Y-%m-%d %H:%M:%S")
            }
            -- Save to INI file
            local success, ini = pcall(function()
                local newIni = ac.INIConfig.new()
                for track, data in pairs(trackRecords) do
                    if type(data) == 'table' and type(data.time) == 'number' then
                        newIni:set(track, 'time', tostring(data.time))
                        newIni:set(track, 'date', data.date or '')
                    end
                end
                newIni:save(trackDataFile)
                return newIni
            end)
        end

        -- Reset current lap data AFTER copying and storing
        posList = {}
        timeList = {}
        previousLapProgressValue = 0
        prevt = 0
        prevt2 = 0
        ttb = 0
    end
end


local function drawTextWithBackground(text, size, x, y, width, height, bgColor, textColor, alignment)
    -- Default to left alignment if not specified
    alignment = alignment or ui.Alignment.Start

    -- Draw background
    if bgColor then
        if alignment == ui.Alignment.Start then
            ui.drawRectFilled(vec2(x - 2, y - 2), vec2(x + width - 2, y + height + 2), bgColor, 3)
        elseif alignment == ui.Alignment.End then
            ui.drawRectFilled(vec2(x - width - 2, y - 2), vec2(x + 2, y + height + 2), bgColor, 3)
        elseif alignment == ui.Alignment.Center then
            ui.drawRectFilled(vec2(x - width / 2 - 2, y - 2), vec2(x + width / 2 + 2, y + height + 2), bgColor, 3)
        end
    end

    -- Draw text with specified alignment
    if alignment == ui.Alignment.End then
        ui.dwriteDrawTextClipped(
            text,
            size,
            vec2(x - width, y),
            vec2(x, y + height),
            alignment,
            ui.Alignment.Start,
            false,
            textColor or rgbm(1, 1, 1, 1)
        )
    else
        ui.dwriteDrawTextClipped(
            text,
            size,
            vec2(x, y),
            vec2(x + width, y + height),
            alignment,
            ui.Alignment.Start,
            false,
            textColor or rgbm(1, 1, 1, 1)
        )
    end
end


local function getTireWearColor(wear)
    -- Convert wear from 0-1 to percentage
    local wearPercent = wear * 100

    -- Clear/transparent below threshold
    if wearPercent < tireWearConfig.thresholds.transparent then
        return tireWearConfig.colors.transparent
        -- Fade from transparent to yellow between thresholds
    elseif wearPercent < tireWearConfig.thresholds.yellow then
        local t = (wearPercent - tireWearConfig.thresholds.transparent) /
            (tireWearConfig.thresholds.yellow - tireWearConfig.thresholds.transparent)
        return rgbm(1, 1, 0, t * 0.5)
        -- Fade from yellow to red between thresholds
    elseif wearPercent < tireWearConfig.thresholds.red then
        local t = (wearPercent - tireWearConfig.thresholds.yellow) /
            (tireWearConfig.thresholds.red - tireWearConfig.thresholds.yellow)
        return rgbm(1, 1 - t, 0, 0.5)
        -- Fade from red to black between thresholds
    elseif wearPercent < tireWearConfig.thresholds.black then
        local t = (wearPercent - tireWearConfig.thresholds.red) /
            (tireWearConfig.thresholds.black - tireWearConfig.thresholds.red)
        return rgbm(1 - t, 0, 0, 0.5 + (t * 0.5))
        -- Full black above threshold
    else
        return tireWearConfig.colors.black
    end
end


local function getFlashState(setTime)
    local timeSince = os.clock() - setTime
    if timeSince < newTimeFlashDuration * newTimeFlashCount * 2 then -- Total duration = flash duration * 2 (on/off) * count
        -- Flash on/off based on time
        return math.floor(timeSince / newTimeFlashDuration) % 2 == 0
    end
    return true -- Always visible after flash sequence
end


local function getTempColor(temp, optimalTemp)
    -- Calculate temperature ratio
    local ratio = temp / optimalTemp

    -- Create color based on temperature ratio
    if ratio < tireTempThresholds.ambient then
        -- Purple (cold/ambient)
        return tireTempColors.ambient
    elseif ratio < tireTempThresholds.cold then
        -- Interpolate between purple and blue
        local t = (ratio - tireTempThresholds.ambient) / (tireTempThresholds.cold - tireTempThresholds.ambient)
        return rgbm(
            tireTempColors.ambient.r * (1 - t) + tireTempColors.cold.r * t,
            tireTempColors.ambient.g * (1 - t) + tireTempColors.cold.g * t,
            tireTempColors.ambient.b * (1 - t) + tireTempColors.cold.b * t,
            1
        )
    elseif ratio < (1 - tireTempThresholds.optimal) then
        -- Interpolate between blue and green
        local t = (ratio - tireTempThresholds.cold) / ((1 - tireTempThresholds.optimal) - tireTempThresholds.cold)
        return rgbm(
            tireTempColors.cold.r * (1 - t) + tireTempColors.optimal.r * t,
            tireTempColors.cold.g * (1 - t) + tireTempColors.optimal.g * t,
            tireTempColors.cold.b * (1 - t) + tireTempColors.optimal.b * t,
            1
        )
    elseif ratio <= (1 + tireTempThresholds.optimal) then
        -- Green (optimal)
        return tireTempColors.optimal
    elseif ratio < tireTempThresholds.hot then
        -- Interpolate between green and yellow
        local t = (ratio - (1 + tireTempThresholds.optimal)) /
        (tireTempThresholds.hot - (1 + tireTempThresholds.optimal))
        return rgbm(
            tireTempColors.optimal.r * (1 - t) + tireTempColors.hot.r * t,
            tireTempColors.optimal.g * (1 - t) + tireTempColors.hot.g * t,
            tireTempColors.optimal.b * (1 - t) + tireTempColors.hot.b * t,
            1
        )
    elseif ratio < tireTempThresholds.explosion then
        -- Interpolate between yellow and red
        local t = (ratio - tireTempThresholds.hot) / (tireTempThresholds.explosion - tireTempThresholds.hot)
        return rgbm(
            tireTempColors.hot.r * (1 - t) + tireTempColors.veryhot.r * t,
            tireTempColors.hot.g * (1 - t) + tireTempColors.veryhot.g * t,
            tireTempColors.hot.b * (1 - t) + tireTempColors.veryhot.b * t,
            1
        )
    else
        -- Interpolate from red to black for explosion temperature
        local t = math.min((ratio - tireTempThresholds.explosion) / 0.1, 1) -- Adjust 0.1 to control fade speed
        return rgbm(
            tireTempColors.veryhot.r * (1 - t) + tireTempColors.explosion.r * t,
            tireTempColors.veryhot.g * (1 - t) + tireTempColors.explosion.g * t,
            tireTempColors.veryhot.b * (1 - t) + tireTempColors.explosion.b * t,
            1
        )
    end
end


local function getPressureColor(current, optimal)
    local delta = current - optimal
    local pressureColors = {
        low = rgbm(0.2, 0, 0.4, 1),   -- Purple for too low
        optimal = rgbm(0, 0.5, 0, 1), -- Deep green for optimal
        high = rgbm(0.6, 0, 0, 1)     -- Dark red for too high
    }

    local optimalRange = 0.5    -- Within 0.5 PSI is considered optimal
    local transitionRange = 1.0 -- Range over which colors blend

    if math.abs(delta) < optimalRange then
        return pressureColors.optimal
    elseif delta < 0 then
        -- Interpolate between purple and green
        local t = math.min(math.abs(delta) - optimalRange, transitionRange) / transitionRange
        return rgbm(
            pressureColors.low.r * t + pressureColors.optimal.r * (1 - t),
            pressureColors.low.g * t + pressureColors.optimal.g * (1 - t),
            pressureColors.low.b * t + pressureColors.optimal.b * (1 - t),
            1
        )
    else
        -- Interpolate between green and red
        local t = math.min(delta - optimalRange, transitionRange) / transitionRange
        return rgbm(
            pressureColors.optimal.r * (1 - t) + pressureColors.high.r * t,
            pressureColors.optimal.g * (1 - t) + pressureColors.high.g * (1 - t),
            pressureColors.optimal.b * (1 - t) + pressureColors.high.b * t,
            1
        )
    end
end


local function estimateRemainingLaps()
    if sim.raceSessionType == ac.SessionType.Race then
        -- Use actual session data if in a race
        local timeLeft = (sim.sessionTimeLeft / 1000)
        local isTimedRace = session.isTimedRace
        local predictiveLapValue = (config.delta.compareMode == "SESSION" and bestLapValue or personalBestLapValue) +
        ((currentDelta ~= nil and currentDelta or 0) * 1000)
        local referenceLapValue = bestLapValue ~= 0 and bestLapValue or lastLapValue ~= 0 and lastLapValue or
        personalBestLapValue
        referenceLapValue = predictiveLapValue > 0 and predictiveLapValue < referenceLapValue and predictiveLapValue or
        referenceLapValue

        if isTimedRace then
            if timeLeft <= 0 and session.hasAdditionalLap then
                -- If we're still on the same lap as when time expired
                if car.lapCount == lapCountWhenTimeExpired then
                    return 2 - car.splinePosition
                else
                    -- We've completed at least one lap since time expired
                    return 1 - car.splinePosition
                end
            elseif timeLeft <= 0 then
                return 1 - car.splinePosition
            end
            return (timeLeft / (referenceLapValue / 1000)) + (session.hasAdditionalLap and 1 or 0)
        else
            return (session.laps - car.lapCount - car.splinePosition)
        end
    elseif raceSimEnabled then -- Only use simulation if enabled
        -- Use simulation settings when not in race
        if raceSimMode == "time" then
            if lastLapValue <= 0 then return nil end -- No valid lap time yet
            return raceSimTime / (lastLapValue / 1000)
        else
            return raceSimLaps
        end
    end
    return nil
end


local function calculateFuelWeight(lapTime, fuelUsed)
    if not bestLapValue or bestLapValue == 0 or not lapTime or lapTime == 0 then
        return 1 -- Default weight if we don't have enough data
    end

    -- First check if this is likely a standing/rolling start lap
    -- by comparing fuel usage to the average of existing data
    if #fuelUsageHistory > 0 then
        local avgFuel = 0
        local count = 0
        for _, data in ipairs(fuelUsageHistory) do
            avgFuel = avgFuel + data.usage
            count = count + 1
        end
        avgFuel = avgFuel / count

        -- If fuel usage is significantly lower than average (less than 75%),
        -- this is likely a standing/rolling start lap
        if fuelUsed < (avgFuel * 0.75) then
            return 0.1 -- Drastically reduce weight for standing/rolling start laps
        end
    end

    local timeRatio = lapTime / bestLapValue

    -- Faster than best lap (rare, but possible)
    if timeRatio < 1 then
        return 2 -- 100% higher weight for faster laps
    end

    -- Normal racing laps (within 102% of best)
    if timeRatio <= 1.02 then
        return 1
    end

    -- More aggressive reduction for slower laps
    -- At 105% of best time, weight should be 0.25 (changed from 110%)
    if timeRatio <= 1.05 then
        return math.max(0,
            1 - ((timeRatio - 1.02) * (0.75 / 0.03)) -- 0.03 is the range (1.05 - 1.02)
        )
    end

    -- Beyond 105% of best time, weight drops even more rapidly
    -- At 110% it should reach 0 (changed from 120%)
    if timeRatio <= 1.10 then
        return math.max(0,
            0.25 * (1 - ((timeRatio - 1.05) / 0.05)) -- 0.05 is the range (1.10 - 1.05)
        )
    end

    return 0 -- Any lap more than 10% slower gets zero weight
end


local settingsFile = ac.getFolder(ac.FolderID.ACApps) .. '/lua/AllTheInfo/settings.txt'

local function saveSettings()
    -- Create directory if it doesn't exist
    local dir = ac.getFolder(ac.FolderID.ACApps) .. '/lua/AllTheInfo'
    if not io.exists(dir) then
        os.execute('mkdir "' .. dir .. '"')
    end

    local file = io.open(settingsFile, "w")
    if file then
        file:write(string.format("deltaCompareMode=%s\n", config.delta.compareMode))
        file:write(string.format("deltaNumberShown=%s\n", tostring(config.delta.numberShown)))
        file:close()
    end
end

local function loadSettings()
    if io.exists(settingsFile) then
        local file = io.open(settingsFile, "r")
        if file then
            for line in file:lines() do
                local key, value = line:match("(.+)=(.+)")
                if key and value then
                    if key == "deltaCompareMode" then
                        config.delta.compareMode = value
                    elseif key == "deltaNumberShown" then
                        config.delta.numberShown = value == "true"
                    end
                end
            end
            file:close()
        end
    end
end


loadPersonalBest()
loadSettings()


function drawDash()
    ui.drawRectFilled(vec2(0, 0), vec2(700, 150), rgbm(0, 0, 0, 0.25), 10, ui.CornerFlags.All)

    ui.pushDWriteFont(font_whiteRabbit)

    -- Load all-time best for current track if not already loaded
    if allTimeBestLap == 0 and trackRecords[getTrackIdentifier()] then
        allTimeBestLap = trackRecords[getTrackIdentifier()].time
    end

    -- Gear
    drawTextWithBackground(
        car.gear == -1 and "R" or (car.gear == 0 and "N" or tostring(car.gear)),
        40,
        13,
        9,
        27,
        29,
        rgbm(0, 0, 0, 1),
        rgbm(1, 1, 1, 1),
        ui.Alignment.Start
    )

    -- RPM
    ui.dwriteDrawTextClipped(
        string.format("%d", car.rpm),
        32,
        vec2(32, 9),
        vec2(132, 43),
        ui.Alignment.End,
        ui.Alignment.Center,
        false,
        rgbm(1, 1, 1, 1)
    )

    -- RPM Background bar
    local rpmBarStartX = 140
    local rpmBarEndX = 700 - 140
    local rpmBarHeight = 38 - 11
    local rpmBarPadding = 2
    local rpmBarWidth = rpmBarEndX - rpmBarStartX

    ui.drawRectFilled(vec2(rpmBarStartX, 11), vec2(rpmBarEndX, 38), rgbm(0.2, 0.2, 0.2, 0.9), 4, ui.CornerFlags.All)
    local progressWidth = mapRange(math.clamp(car.rpm, 0, car.rpmLimiter * config.rpm.lightsStart), 0,
        car.rpmLimiter * config.rpm.lightsStart, 0, rpmBarWidth - rpmBarPadding * 2, true)
    ui.drawRectFilled(vec2(rpmBarStartX + rpmBarPadding, 13), vec2(rpmBarStartX + rpmBarPadding + progressWidth, 36),
        rgbm(0.8, 0.8, 0.8,
            mapRange(car.rpm, car.rpmLimiter * config.rpm.fadeStart, car.rpmLimiter * config.rpm.lightsStart, 0.5, 0.1,
                true)), 3, ui.CornerFlags.All)

    -- RPM light sections
    if config.rpm.shiftLightsEnabled then
        local numSections = 6 -- Can be configured
        local sectionStartX = rpmBarStartX + 4
        local sectionEndX = rpmBarEndX - 4
        local totalWidth = sectionEndX - sectionStartX -- Total available width
        local sectionWidth = totalWidth / numSections  -- Each section exactly same size
        local rpmStart = car.rpmLimiter * config.rpm.lightsStart
        local rpmRange = (car.rpmLimiter * config.rpm.shiftPoint) - rpmStart
        local isOverShiftPoint = car.rpm >= (car.rpmLimiter * config.rpm.shiftPoint)
        local isOverRedline = car.rpm >= (car.rpmLimiter - 50)
        local flashState = isOverRedline and math.floor(sim.time * 0.02) % 2 == 0
        for i = 0, numSections - 1 do
            local x1 = sectionStartX + (sectionWidth * i)
            local x2 = sectionStartX + (sectionWidth * (i + 1))
            if i < numSections - 1 then
                x2 = x2 - 4 -- Add small gap between sections, except for last one
            end

            -- Only show section if RPM is high enough
            local sectionRpmThreshold = rpmStart + (rpmRange * (i / numSections))
            if car.rpm >= sectionRpmThreshold then
                -- Set color based on whether we're over redline
                local color
                if isOverRedline then
                    -- Alternate orange and white at 20Hz
                    if (i % 2 == 0) == flashState then
                        color = rgbm(1, 1, 0, 1) -- Yellow
                    else
                        color = rgbm(1, 0, 0, 1) -- Red
                    end
                elseif isOverShiftPoint and (car.gear ~= car.gearCount) then
                    color = rgbm(0, 0.5, 1, 2) -- Blue when over shift point
                else
                    if i >= numSections - 2 then
                        color = rgbm(0.8, 0.2, 0.2, 1) -- Red
                    elseif i >= numSections - 4 then
                        color = rgbm(0.8, 0.8, 0.2, 1) -- Yellow
                    else
                        color = rgbm(0.2, 0.8, 0.2, 1) -- Green
                    end
                end
                ui.drawRectFilled(vec2(x1, 15), vec2(x2, 34), color, 2, ui.CornerFlags.All)
            end
        end
    end

    -- Speed
    ui.dwriteDrawTextClipped(
        string.format("%d", car.speedKmh),
        32,
        vec2(590, 9),
        vec2(690, 43),
        ui.Alignment.End,
        ui.Alignment.Center,
        false,
        rgbm(1, 1, 1, 1)
    )

    -- Boost bar
    if car.turboCount > 0 then
        local boostBarStartX = 140
        local boostBarWidth = 420 -- 560 - 140
        local boostBarY1 = 3
        local boostBarY2 = 9

        ui.drawRectFilled(vec2(boostBarStartX, boostBarY1), vec2(boostBarStartX + boostBarWidth, boostBarY2),
            rgbm(0.15, 0.15, 0.15, 0.9), 2)
        local boostPercent = math.clamp(car.turboBoost / maxSeenBoost, 0.0, 1.0) -- Normalize to max seen boost
        local boostWidth = boostBarWidth * boostPercent
        local boostColor

        -- Color configuration for boost gauge
        local colorStops = {
            { percent = 0.0, color = rgbm(0.5, 0.5, 0.5, 1) }, -- Grey
            { percent = 0.3, color = rgbm(1.0, 0.5, 0.0, 1) }, -- Orange
            { percent = 0.4, color = rgbm(1.0, 1.0, 0.0, 1) }, -- Yellow
            { percent = 0.8, color = rgbm(0.0, 1.0, 0.5, 1) }  -- Green
        }

        -- Find the two color stops to interpolate between
        local stop1, stop2
        for i = 1, #colorStops do
            if boostPercent <= colorStops[i].percent or i == #colorStops then
                stop2 = colorStops[i]
                stop1 = colorStops[i - 1] or stop2
                break
            end
        end

        -- Calculate interpolation factor
        local t = 0
        if stop1.percent ~= stop2.percent then
            t = (boostPercent - stop1.percent) / (stop2.percent - stop1.percent)
        end

        -- Interpolate between colors
        boostColor = rgbm(
            stop1.color.r + (stop2.color.r - stop1.color.r) * t,
            stop1.color.g + (stop2.color.g - stop1.color.g) * t,
            stop1.color.b + (stop2.color.b - stop1.color.b) * t,
            1
        )

        ui.drawRectFilled(
            vec2(boostBarStartX + 2, boostBarY1 + 2),
            vec2(mapRange(boostPercent, 0, 1, boostBarStartX + 2, boostBarStartX - 2 + boostWidth, true), boostBarY2 - 2),
            boostColor,
            2
        )
    end

    -- Separator line
    ui.drawLine(vec2(5, 45), vec2(695, 45), rgbm(1, 1, 1, 0.2), 1)

    -- Predictive current lap
    ui.dwriteDrawTextClipped(
        "EST",
        14,
        vec2(9, 52),
        vec2(150, 68),
        ui.Alignment.Start,
        ui.Alignment.Start,
        false,
        rgbm(1, 1, 1, 1)
    )
    local delta, deltaChangeRate = currentDelta, currentDeltaChangeRate
    local timeText
    local bgColor = nil
    if delta == nil then
        timeText = "-:--.---"
    else
        local comparisonValue = config.delta.compareMode == "SESSION" and bestLapValue or personalBestLapValue
        local predictiveLapValue = comparisonValue + (delta * 1000)
        if math.floor(predictiveLapValue / 60000) >= 100 then
            timeText = string.format("%01d:%02d.%0d", math.floor(predictiveLapValue / 60000),
                math.floor(predictiveLapValue / 1000) % 60, math.floor(predictiveLapValue % 1000 / 100))
        elseif math.floor(predictiveLapValue / 60000) >= 10 then
            timeText = string.format("%01d:%02d.%02d", math.floor(predictiveLapValue / 60000),
                math.floor(predictiveLapValue / 1000) % 60, math.floor(predictiveLapValue % 1000 / 10))
        else
            timeText = string.format("%01d:%02d.%03d", math.floor(predictiveLapValue / 60000),
                math.floor(predictiveLapValue / 1000) % 60, predictiveLapValue % 1000)
        end

        if currentLapIsInvalid then
            bgColor = rgbm(0.8, 0, 0, 0.5)     -- Brighter red background for invalid lap
        elseif predictiveLapValue < personalBestLapValue or (personalBestLapValue == 0 and predictiveLapValue < bestLapValue) then
            bgColor = rgbm(0.3, 0.3, 0.8, 0.5) -- Brighter blue background for beating personal best
        elseif predictiveLapValue < bestLapValue then
            bgColor = rgbm(0.3, 0.8, 0.3, 0.5) -- Brighter green background for beating session best
        end
    end
    drawTextWithBackground(timeText, 24, 35, 52, 115, 16, bgColor)

    -- Previous lap time
    ui.dwriteDrawTextClipped(
        "LST",
        14,
        vec2(9, 52 + 23),
        vec2(150, 68 + 23),
        ui.Alignment.Start,
        ui.Alignment.Start,
        false,
        rgbm(1, 1, 1, 1)
    )
    local lastLapBg = previousLapValidityValue and rgbm(0.8, 0, 0, 0.5) or     -- Brighter red for invalid lap
        lastLapWasPersonalBest and rgbm(0.3, 0.3, 0.8, 0.5) or                 -- Brighter blue for personal best
        lastLapWasSessionBest and rgbm(0.3, 0.8, 0.3, 0.5) or nil              -- Brighter green for session best

    if math.floor(lastLapValue / 60000) >= 100 then
        timeText = string.format("%01d:%02d.%0d", math.floor(lastLapValue / 60000), math.floor(lastLapValue / 1000) % 60,
            lastLapValue % 1000)
    elseif math.floor(lastLapValue / 60000) >= 10 then
        timeText = string.format("%01d:%02d.%02d", math.floor(lastLapValue / 60000), math.floor(lastLapValue / 1000) % 60,
            math.floor(lastLapValue % 1000 / 10))
    else
        timeText = string.format("%01d:%02d.%03d", math.floor(lastLapValue / 60000), math.floor(lastLapValue / 1000) % 60,
            lastLapValue % 1000)
    end
    drawTextWithBackground(
        lastLapValue > 0
        and timeText
        or "-:--.---",
        24, 35, 52 + 23, 115, 16, lastLapBg
    )

    -- Separator line between lap times
    ui.drawLine(vec2(5, 95), vec2(148, 95), rgbm(1, 1, 1, 0.2), 1)

    -- Session best laptime
    drawTextWithBackground(
        "BST",
        14,
        9,
        52 + 49,
        27,
        9,
        config.delta.compareMode == "SESSION" and rgbm(0, 0, 0, 0.3) or nil,
        rgbm(1, 1, 1, 1)
    )
    local sessionBestBg = nil
    local sessionBestColor = rgbm(1, 1, 1, 1) -- Default white
    if lastLapWasSessionBest then
        local alpha = fadeBackground(sessionBestWasSetTime)
        if alpha > 0 then
            sessionBestBg = lastLapWasPersonalBest and
                rgbm(0.3, 0.3, 0.8, alpha) or -- Blue if both
                rgbm(0.3, 0.8, 0.3, alpha)    -- Green if just session best

            -- Flash the text instead of hiding background
            if not getFlashState(sessionBestWasSetTime) then
                sessionBestColor = rgbm(1, 1, 1, 0.5) -- Half-transparent white during flash off
            end
        end
    end
    if math.floor(bestLapValue / 60000) >= 100 then
        timeText = string.format("%01d:%02d.%0d", math.floor(bestLapValue / 60000), math.floor(bestLapValue / 1000) % 60,
            bestLapValue % 1000)
    elseif math.floor(bestLapValue / 60000) >= 10 then
        timeText = string.format("%01d:%02d.%02d", math.floor(bestLapValue / 60000), math.floor(bestLapValue / 1000) % 60,
            math.floor(bestLapValue % 1000 / 10))
    else
        timeText = string.format("%01d:%02d.%03d", math.floor(bestLapValue / 60000), math.floor(bestLapValue / 1000) % 60,
            bestLapValue % 1000)
    end
    drawTextWithBackground(
        bestLapValue > 0
        and timeText
        or "-:--.---",
        24, 35, 52 + 49, 115, 16, sessionBestBg,
        sessionBestColor
    )

    -- All-time best
    drawTextWithBackground(
        "PB",
        14,
        17,
        52 + 72,
        19,
        9,
        config.delta.compareMode == "PERSONAL" and rgbm(0, 0, 0, 0.3) or nil,
        rgbm(1, 1, 1, 1)
    )
    local pbBg = nil
    local pbColor = rgbm(1, 1, 1, 1) -- Default white
    if lastLapWasPersonalBest then
        local alpha = fadeBackground(personalBestWasSetTime)
        if alpha > 0 then
            pbBg = rgbm(0.3, 0.3, 0.8, alpha) -- Blue with fade

            -- Flash the text instead of hiding background
            if not getFlashState(personalBestWasSetTime) then
                pbColor = rgbm(1, 1, 1, 0.5) -- Half-transparent white during flash off
            end
        end
    end
    if math.floor(personalBestLapValue / 60000) >= 100 then
        timeText = string.format("%01d:%02d.%0d", math.floor(personalBestLapValue / 60000),
            math.floor(personalBestLapValue / 1000) % 60, personalBestLapValue % 1000)
    elseif math.floor(personalBestLapValue / 60000) >= 10 then
        timeText = string.format("%01d:%02d.%02d", math.floor(personalBestLapValue / 60000),
            math.floor(personalBestLapValue / 1000) % 60, math.floor(personalBestLapValue % 1000 / 10))
    else
        timeText = string.format("%01d:%02d.%03d", math.floor(personalBestLapValue / 60000),
            math.floor(personalBestLapValue / 1000) % 60, personalBestLapValue % 1000)
    end
    drawTextWithBackground(
        personalBestLapValue > 0
        and timeText
        or "-:--.---",
        24, 35, 52 + 72, 115, 16, pbBg, -- Changed from 69 to 71
        pbColor
    )

    -- Session time and laps remaining display
    local timeLeft = sim.sessionTimeLeft / 1000
    local isTimedRace = timeLeft > 0

    -- Time remaining display
    local timeRemainingText
    if isTimedRace then
        local hours = math.floor(timeLeft / 3600)
        local minutes = math.floor((timeLeft % 3600) / 60)
        local seconds = math.floor(timeLeft % 60)

        if hours > 0 then
            timeRemainingText = string.format("%d:%02d:%02d", hours, minutes, seconds)
        else
            timeRemainingText = string.format("%02d:%02d", minutes, seconds)
        end
    else
        timeRemainingText = "--:--"
    end

    -- Draw time remaining
    drawTextWithBackground(
        "TIME",
        14,
        159, -- Position to the right of lap times
        53,
        40,  -- width
        16,  -- height
        nil, -- No background
        rgbm(1, 1, 1, 1),
        ui.Alignment.Start
    )
    drawTextWithBackground(
        timeRemainingText,
        24,
        200, -- Position after "TIME" label
        52,  -- Same Y as label
        100, -- width
        16,  -- height
        nil, -- No background
        timeLeft > 0 and rgbm(1, 1, 1, 1) or rgbm(1, 1, 1, 0.5),
        ui.Alignment.Start
    )

    -- Laps remaining display
    local remainingLaps = estimateRemainingLaps()
    local lapsRemainingText = remainingLaps and string.format(remainingLaps >= 100 and "%.0f" or remainingLaps >= 10 and "%.1f" or "%.2f", remainingLaps) or "--.-"

    -- Draw laps remaining
    drawTextWithBackground(
        "LAPS",
        14,
        160, -- Same X as "TIME"
        75,  -- Below time display
        40,  -- width
        16,  -- height
        nil, -- No background
        rgbm(1, 1, 1, 1),
        ui.Alignment.Start
    )
    drawTextWithBackground(
        lapsRemainingText,
        24,
        200, -- Same X as time value
        75,  -- Same Y as "LAPS" label
        100, -- width
        16,  -- height
        nil, -- No background
        timeLeft > 0 and rgbm(1, 1, 1, 0.5) or rgbm(1, 1, 1, 1),
        ui.Alignment.Start
    )

    -- Position display
    local position = ac.getCarLeaderboardPosition(0) -- Get current car's position
    local totalCars = ac.getSim().carsCount          -- Get total number of cars
    local positionText = string.format("%s/%d", position, totalCars)

    -- Draw position
    drawTextWithBackground(
        "POS",
        14,
        160, -- Same X as "TIME" and "LAPS"
        98,  -- Below laps display
        40,  -- width
        16,  -- height
        nil, -- No background
        rgbm(1, 1, 1, 1),
        ui.Alignment.Start
    )
    drawTextWithBackground(
        positionText,
        24,
        200, -- Same X as time and laps values
        98,  -- Same Y as "POS" label
        100, -- width
        16,  -- height
        nil, -- No background
        rgbm(1, 1, 1, 1),
        ui.Alignment.Start
    )

    -- Add separator line between laptiming and time/laps left
    ui.drawLine(
        vec2(152, 49),
        vec2(152, 147),
        rgbm(1, 1, 1, 0.2),
        1
    )

    -- Add seperator between time/laps/pos and tires
    ui.drawLine(
        vec2(273, 49),
        vec2(273, 147),
        rgbm(1, 1, 1, 0.2),
        1
    )

    -- Tire blocks visualization
    local tireBlockWidth = 30                                             -- Width of each tire block
    local tireStripeWidth = 10                                            -- Width of each stripe within a block
    local tireBlockHeight = 40                                            -- Total height of tire block
    local tireCoreSectionHeight = 15                                      -- Height of the core temperature section
    local tireSurfaceHeight = tireBlockHeight - tireCoreSectionHeight -
    1                                                                     -- Height of surface temps section (subtract 1 for gap)
    local tireBlockSpacing = 10                                           -- Space between left/right blocks
    local tireVerticalSpacing = 10                                        -- Space between front/rear tires
    local tireBlockY = 52                                                 -- Y position to match with other elements

    -- Calculate center position and block positions
    local centerX = 350 -- Approximate center position
    local leftBlocksX = centerX - tireBlockWidth - (tireBlockSpacing / 2)
    local rightBlocksX = centerX + (tireBlockSpacing / 2)

    local tireCoreTemps = { car.wheels[ac.Wheel.FrontLeft].tyreCoreTemperature, car.wheels[ac.Wheel.FrontRight]
        .tyreCoreTemperature, car.wheels[ac.Wheel.RearLeft].tyreCoreTemperature, car.wheels[ac.Wheel.RearRight]
        .tyreCoreTemperature }
    local tireInnerTemps = { car.wheels[ac.Wheel.FrontLeft].tyreInsideTemperature, car.wheels[ac.Wheel.FrontRight]
        .tyreInsideTemperature, car.wheels[ac.Wheel.RearLeft].tyreInsideTemperature, car.wheels[ac.Wheel.RearRight]
        .tyreInsideTemperature }
    local tireMiddleTemps = { car.wheels[ac.Wheel.FrontLeft].tyreMiddleTemperature, car.wheels[ac.Wheel.FrontRight]
        .tyreMiddleTemperature, car.wheels[ac.Wheel.RearLeft].tyreMiddleTemperature, car.wheels[ac.Wheel.RearRight]
        .tyreMiddleTemperature }
    local tireOuterTemps = { car.wheels[ac.Wheel.FrontLeft].tyreOutsideTemperature, car.wheels[ac.Wheel.FrontRight]
        .tyreOutsideTemperature, car.wheels[ac.Wheel.RearLeft].tyreOutsideTemperature, car.wheels[ac.Wheel.RearRight]
        .tyreOutsideTemperature }
    local tireOptimumTemps = {
        car.wheels[ac.Wheel.FrontLeft].tyreOptimumTemperature or 80,
        car.wheels[ac.Wheel.FrontRight].tyreOptimumTemperature or 80,
        car.wheels[ac.Wheel.RearLeft].tyreOptimumTemperature or 80,
        car.wheels[ac.Wheel.RearRight].tyreOptimumTemperature or 80
    }
    local tirePressures = { car.wheels[ac.Wheel.FrontLeft].tyrePressure, car.wheels[ac.Wheel.FrontRight].tyrePressure,
        car.wheels[ac.Wheel.RearLeft].tyrePressure, car.wheels[ac.Wheel.RearRight].tyrePressure }
    local tireFL_grip = getTireGripFromWear(0)
    local tireFR_grip = getTireGripFromWear(1)
    local tireRL_grip = getTireGripFromWear(2)
    local tireRR_grip = getTireGripFromWear(3)

    -- Load tire data from car's data files
    local tireData = ac.INIConfig.carData(0, "tyres.ini")
    local tireOptimumPressures = {
        tonumber(tireData:get(car.compoundIndex == 0 and "FRONT" or "FRONT_" .. (car.compoundIndex + 1), "PRESSURE_IDEAL",
            26)),                                                                                                                -- Front tires, default 26 PSI
        tonumber(tireData:get(car.compoundIndex == 0 and "FRONT" or "FRONT_" .. (car.compoundIndex + 1), "PRESSURE_IDEAL",
            26)),
        tonumber(tireData:get(car.compoundIndex == 0 and "REAR" or "REAR_" .. (car.compoundIndex + 1), "PRESSURE_IDEAL",
            26)),                                                                                                                -- Rear tires
        tonumber(tireData:get(car.compoundIndex == 0 and "REAR" or "REAR_" .. (car.compoundIndex + 1), "PRESSURE_IDEAL",
            26))
    }
    local tireExplosionTemp = tonumber(tireData:get("EXPLOSION", "TEMPERATURE", (tireOptimumTemps[1] * 3)))

    -- Update explosion threshold based on actual explosion temp
    -- We'll set it to show black when within 20°C of explosion temp
    tireTempThresholds.explosion = (tireExplosionTemp - 20) / tireOptimumTemps[1]

    -- Draw front left tire block
    -- Core temperature section
    ui.drawRectFilled(
        vec2(leftBlocksX, tireBlockY),
        vec2(leftBlocksX + tireBlockWidth - 1, tireBlockY + tireCoreSectionHeight),
        getTempColor(tireCoreTemps[1], tireOptimumTemps[1]),
        0, -- No rounding
        0  -- No corner flags
    )
    -- Surface temperature stripes for front left (from left to right: outer, middle, inner)
    for i = 0, 2 do
        local stripeIndex = 2 - i -- Reverse order: 0=outer, 1=middle, 2=inner
        local temp = stripeIndex == 0 and tireOuterTemps[1] or
            stripeIndex == 1 and tireMiddleTemps[1] or
            tireInnerTemps[1]
        ui.drawRectFilled(
            vec2(leftBlocksX + (i * tireStripeWidth), tireBlockY + tireCoreSectionHeight + 1),
            vec2(leftBlocksX + (i * tireStripeWidth) + tireStripeWidth - 1, tireBlockY + tireBlockHeight),
            getTempColor(temp, tireOptimumTemps[1]),
            (i == 0 or i == 2) and 3 or 0,               -- Round corners for outer and inner bands
            (i == 0 and ui.CornerFlags.BottomLeft) or    -- Round outer band's left corner
            (i == 2 and ui.CornerFlags.BottomRight) or 0 -- Round inner band's right corner
        )
    end

    -- Draw front right tire block
    -- Core temperature section
    ui.drawRectFilled(
        vec2(rightBlocksX, tireBlockY),
        vec2(rightBlocksX + tireBlockWidth - 1, tireBlockY + tireCoreSectionHeight),
        getTempColor(tireCoreTemps[2], tireOptimumTemps[2]),
        0, -- No rounding
        0  -- No corner flags
    )
    -- Surface temperature stripes for right tires (from left to right: inner, middle, outer)
    for i = 0, 2 do
        local stripeIndex = i -- Keep original order: 0=inner, 1=middle, 2=outer
        local temp = stripeIndex == 0 and tireInnerTemps[2] or
            stripeIndex == 1 and tireMiddleTemps[2] or
            tireOuterTemps[2]
        ui.drawRectFilled(
            vec2(rightBlocksX + (i * tireStripeWidth), tireBlockY + tireCoreSectionHeight + 1),
            vec2(rightBlocksX + (i * tireStripeWidth) + tireStripeWidth - 1, tireBlockY + tireBlockHeight),
            getTempColor(temp, tireOptimumTemps[2]),
            (i == 0 or i == 2) and 3 or 0,
            (i == 0 and ui.CornerFlags.BottomLeft) or    -- Round inner band's left corner
            (i == 2 and ui.CornerFlags.BottomRight) or 0 -- Round outer band's right corner
        )
    end

    -- Draw rear left tire block
    -- Core temperature section
    ui.drawRectFilled(
        vec2(leftBlocksX, tireBlockY + tireBlockHeight + tireVerticalSpacing),
        vec2(leftBlocksX + tireBlockWidth - 1, tireBlockY + tireBlockHeight + tireVerticalSpacing + tireCoreSectionHeight),
        getTempColor(tireCoreTemps[3], tireOptimumTemps[3]),
        0, -- No rounding
        0  -- No corner flags
    )
    -- Surface temperature stripes for rear left (from left to right: outer, middle, inner)
    for i = 0, 2 do
        local stripeIndex = 2 - i -- Reverse order: 0=outer, 1=middle, 2=inner (changed from i)
        local temp = stripeIndex == 0 and tireOuterTemps[3] or
            stripeIndex == 1 and tireMiddleTemps[3] or
            tireInnerTemps[3]
        ui.drawRectFilled(
            vec2(leftBlocksX + (i * tireStripeWidth),
                tireBlockY + tireBlockHeight + tireVerticalSpacing + tireCoreSectionHeight + 1),
            vec2(leftBlocksX + (i * tireStripeWidth) + tireStripeWidth - 1,
                tireBlockY + tireBlockHeight + tireVerticalSpacing + tireBlockHeight),
            getTempColor(temp, tireOptimumTemps[3]),
            (i == 0 or i == 2) and 3 or 0,
            (i == 0 and ui.CornerFlags.BottomLeft) or
            (i == 2 and ui.CornerFlags.BottomRight) or 0
        )
    end

    -- Draw rear right tire block
    -- Core temperature section
    ui.drawRectFilled(
        vec2(rightBlocksX, tireBlockY + tireBlockHeight + tireVerticalSpacing),
        vec2(rightBlocksX + tireBlockWidth - 1,
            tireBlockY + tireBlockHeight + tireVerticalSpacing + tireCoreSectionHeight),
        getTempColor(tireCoreTemps[4], tireOptimumTemps[4]),
        0, -- No rounding
        0  -- No corner flags
    )
    -- Surface temperature stripes for rear right (from left to right: inner, middle, outer)
    for i = 0, 2 do
        local stripeIndex = i -- Keep original order: 0=inner, 1=middle, 2=outer
        local temp = stripeIndex == 0 and tireInnerTemps[4] or
            stripeIndex == 1 and tireMiddleTemps[4] or
            tireOuterTemps[4]
        ui.drawRectFilled(
            vec2(rightBlocksX + (stripeIndex * tireStripeWidth),
                tireBlockY + tireBlockHeight + tireVerticalSpacing + tireCoreSectionHeight + 1),
            vec2(rightBlocksX + (stripeIndex * tireStripeWidth) + tireStripeWidth - 1,
                tireBlockY + tireBlockHeight + tireVerticalSpacing + tireBlockHeight),
            getTempColor(temp, tireOptimumTemps[4]),
            (stripeIndex == 0 or stripeIndex == 2) and 3 or 0,
            (stripeIndex == 0 and ui.CornerFlags.BottomLeft) or
            (stripeIndex == 2 and ui.CornerFlags.BottomRight) or 0
        )
    end

    -- Draw front left tire block
    -- Pressure delta and wear display
    local pressureDelta = tirePressures[1] - tireOptimumPressures[1]
    drawTextWithBackground(
        string.format((pressureDelta > 0 and "+" or "") .. (math.abs(pressureDelta) < 10 and "%.1f" or "%.0f"),
            pressureDelta),
        13,
        leftBlocksX - 35,
        tireBlockY + 5,
        34,              -- width increased by 4
        10,              -- height decreased by 4
        getPressureColor(tirePressures[1], tireOptimumPressures[1]),
        rgbm(1, 1, 1, 1) -- White text
    )
    drawTextWithBackground(
        string.format(tireFL_grip < 0.999 and "%.1f%%" or "%.0f%%", tireFL_grip * 100),
        11,
        leftBlocksX - 5,  -- Adjusted position
        tireBlockY + tireBlockHeight - 15,
        31,               -- Width for background
        7,                -- Height for background
        getTireWearColor(1 - tireFL_grip),
        rgbm(1, 1, 1, 1), -- White text
        ui.Alignment.End  -- Right alignment for left tires
    )

    -- Draw front right tire block
    pressureDelta = tirePressures[2] - tireOptimumPressures[2]
    drawTextWithBackground(
        string.format((pressureDelta > 0 and "+" or "") .. (math.abs(pressureDelta) < 10 and "%.1f" or "%.0f"),
            pressureDelta),
        13,
        rightBlocksX + tireBlockWidth + 5,
        tireBlockY + 5,
        34, -- width increased by 4
        10, -- height decreased by 4
        getPressureColor(tirePressures[2], tireOptimumPressures[2]),
        rgbm(1, 1, 1, 1)
    )
    drawTextWithBackground(
        string.format(tireFR_grip < 0.999 and "%.1f%%" or "%.0f%%", tireFR_grip * 100),
        11,
        rightBlocksX + tireBlockWidth + 5,
        tireBlockY + tireBlockHeight - 15,
        37,                                -- Width for background
        7,                                 -- Height for background
        getTireWearColor(1 - tireFR_grip), -- Convert grip to wear
        rgbm(1, 1, 1, 1),                  -- White text
        ui.Alignment.Start                 -- Left alignment for right tires
    )

    -- Draw rear left tire block
    pressureDelta = tirePressures[3] - tireOptimumPressures[3]
    drawTextWithBackground(
        string.format((pressureDelta > 0 and "+" or "") .. (math.abs(pressureDelta) < 10 and "%.1f" or "%.0f"),
            pressureDelta),
        13,
        leftBlocksX - 35,
        tireBlockY + tireBlockHeight + tireVerticalSpacing + 5,
        34, -- width increased by 4
        10, -- height decreased by 4
        getPressureColor(tirePressures[3], tireOptimumPressures[3]),
        rgbm(1, 1, 1, 1)
    )
    drawTextWithBackground(
        string.format(tireRL_grip < 0.999 and "%.1f%%" or "%.0f%%", tireRL_grip * 100),
        11,
        leftBlocksX - 5,                   -- Adjusted position
        tireBlockY + tireBlockHeight + tireVerticalSpacing + tireBlockHeight - 15,
        31,                                -- Width for background
        7,                                 -- Height for background
        getTireWearColor(1 - tireRL_grip), -- Convert grip to wear
        rgbm(1, 1, 1, 1),                  -- White text
        ui.Alignment.End                   -- Right alignment for left tires
    )

    -- Draw rear right tire block
    pressureDelta = tirePressures[4] - tireOptimumPressures[4]
    drawTextWithBackground(
        string.format((pressureDelta > 0 and "+" or "") .. (math.abs(pressureDelta) < 10 and "%.1f" or "%.0f"),
            pressureDelta),
        13,
        rightBlocksX + tireBlockWidth + 5,
        tireBlockY + tireBlockHeight + tireVerticalSpacing + 5,
        34, -- width increased by 4
        10, -- height decreased by 4
        getPressureColor(tirePressures[4], tireOptimumPressures[4]),
        rgbm(1, 1, 1, 1)
    )
    drawTextWithBackground(
        string.format(tireRR_grip < 0.999 and "%.1f%%" or "%.0f%%", tireRR_grip * 100),
        11,
        rightBlocksX + tireBlockWidth + 5,
        tireBlockY + tireBlockHeight + tireVerticalSpacing + tireBlockHeight - 15,
        37,                                -- Width for background
        7,                                 -- Height for background
        getTireWearColor(1 - tireRR_grip), -- Convert grip to wear
        rgbm(1, 1, 1, 1),                  -- White text
        ui.Alignment.Start                 -- Left alignment for right tires
    )

    -- Add seperator between tires and ABS/TC/BB
    ui.drawLine(
        vec2(427, 49),
        vec2(427, 147),
        rgbm(1, 1, 1, 0.2),
        1
    )

    -- Fuel level display
    local fuelText = string.format("LVL %6.2f L", car.fuel):gsub("^%s+", "")
    drawTextWithBackground(
        fuelText,
        16,
        690,
        54,
        110,              -- width
        12,               -- height
        rgbm(0, 0, 0, 0), -- No background
        rgbm(1, 1, 1, 1), -- White text
        ui.Alignment.End  -- Right alignment
    )

    -- Last lap fuel usage display
    local lastLapFuelText = lastLapFuelUsed > 0
        and string.format("LST %6.2f L", lastLapFuelUsed):gsub("^%s+", "")
        or "LST  --.-- L"
    drawTextWithBackground(
        lastLapFuelText,
        16,
        690,
        54 + (19 * 1),    -- Position below fuel level
        110,              -- width
        12,               -- height
        rgbm(0, 0, 0, 0), -- No background
        rgbm(1, 1, 1, 1), -- White text
        ui.Alignment.End  -- Right alignment
    )

    -- Average fuel per lap display (weighted)
    local avgFuelPerLap = 0
    if #fuelUsageHistory > 0 then
        local weightedSum = 0
        local totalWeight = 0
        for _, data in ipairs(fuelUsageHistory) do
            weightedSum = weightedSum + (data.usage * data.weight)
            totalWeight = totalWeight + data.weight
        end
        avgFuelPerLap = totalWeight > 0 and (weightedSum / totalWeight) or 0
    elseif personalBestFuelUsage then
        -- Use personal best fuel usage if no other data available
        avgFuelPerLap = personalBestFuelUsage
    end

    local fuelPerLapText = (avgFuelPerLap > 0)
        and string.format("AVG %6.2f L", avgFuelPerLap):gsub("^%s+", "")
        or "AVG  --.-- L"
    drawTextWithBackground(
        fuelPerLapText,
        16,
        690,
        54 + (19 * 2),    -- Position below last lap fuel usage
        110,              -- width
        12,               -- height
        rgbm(0, 0, 0, 0), -- No background
        rgbm(1, 1, 1, 1), -- White text
        ui.Alignment.End  -- Right alignment
    )

    -- Calculate how many laps possible with current fuel
    local possibleLaps = "--.-"
    local possibleLapsColor = rgbm(1, 1, 1, 1) -- Default white text
    local possibleLapsBg = rgbm(0, 0, 0, 0)    -- Default transparent background

    if avgFuelPerLap > 0 then
        local lapsLeft = car.fuel / avgFuelPerLap
        possibleLaps = string.format("%.1f", lapsLeft)

        -- Set warning colors based on laps remaining
        if lapsLeft < 1 then
            possibleLapsColor = rgbm(0, 0, 0, 1) -- Black text
            possibleLapsBg = rgbm(1, 0, 0, 0.8)  -- Red background
        elseif lapsLeft < 2 then
            possibleLapsColor = rgbm(0, 0, 0, 1) -- Black text
            possibleLapsBg = rgbm(1, 1, 0, 0.8)  -- Yellow background
        end
    end

    local possibleLapsText = string.format("LPS%6s LP", possibleLaps):gsub("^%s+", "")
    drawTextWithBackground(
        possibleLapsText,
        16,
        690,
        54 + (19 * 3),     -- Position below average fuel
        110,               -- width
        12,                -- height
        possibleLapsBg,    -- Warning background colors
        possibleLapsColor, -- Black text with warning backgrounds
        ui.Alignment.End   -- Right alignment
    )

    -- Calculate remaining laps and fuel for race
    local remainingLaps = estimateRemainingLaps()

    -- Always show the END fuel display, but with different values based on race state
    local fuelRemainingText
    local fuelTextColor = rgbm(1, 1, 1, 1) -- Default white text
    local fuelBgColor = rgbm(0, 0, 0, 0)   -- Default transparent background

    if remainingLaps and avgFuelPerLap > 0 then
        -- Calculate fuel needed more precisely
        local fullLaps = math.floor(remainingLaps)
        local partialLap = remainingLaps - fullLaps
        local fuelNeeded = fullLaps * avgFuelPerLap + (partialLap * avgFuelPerLap)
        local fuelRemaining = car.fuel - fuelNeeded

        fuelRemainingText = string.format("END %6.2f L", fuelRemaining):gsub("^%s+", "")

        if fuelRemaining < 0 then
            fuelTextColor = rgbm(0, 0, 0, 1) -- Black text
            fuelBgColor = rgbm(1, 0, 0, 0.8) -- Bright red background
        end
    else
        fuelRemainingText = "END  --.-- L"
    end

    drawTextWithBackground(
        fuelRemainingText,
        16,
        690,
        54 + (19 * 4),   -- Position below laps possible
        110,             -- width
        12,              -- height
        fuelBgColor,     -- Background color for negative values
        fuelTextColor,   -- Text color (black for negative values)
        ui.Alignment.End -- Right alignment
    )

    if car.drsPresent then
        -- DRS indicator background
        local drsX = 700 - 140 + 10
        local drsWidth = 40
        local drsHeight = 38 - 11
        local drsY = 11

        -- Determine DRS state and color
        local drsColor = drsColors.inactive
        if car.drsActive then
            drsColor = drsColors.active
        elseif car.drsAvailable then
            drsColor = drsColors.available
        end

        -- Draw DRS background and text
        ui.drawRectFilled(vec2(drsX, drsY), vec2(drsX + drsWidth, drsY + drsHeight), drsColor, 4, ui.CornerFlags.All)

        -- Draw "DRS" text
        ui.dwriteDrawTextClipped(
            "DRS",
            16,
            vec2(drsX, drsY),
            vec2(drsX + drsWidth, drsY + drsHeight),
            ui.Alignment.Center,
            ui.Alignment.Center,
            false,
            rgbm(0, 0, 0, 1) -- Black text
        )
    else
        -- Draw app icon when no DRS
        local iconX = 700 - 140 + 6
        local iconY = 1
        local iconSize = 41
        ui.drawImage(
            "icon.png",
            vec2(iconX, iconY),
            vec2(iconX + iconSize, iconY + iconSize)
        )
    end

    -- Driver assists display (after tire blocks)
    local assistsX = rightBlocksX + tireBlockWidth + 50 -- Position to the right of tire blocks
    local assistsY = tireBlockY + 1                     -- Align with other readouts

    -- ABS Display
    local absText = car.absModes > 0
        and string.format("%2d/%d", car.absMode, car.absModes)
        or " N/A"
    drawTextWithBackground(
        "ABS",
        14, -- Small text for label
        assistsX,
        assistsY,
        29,                                          -- Width for label
        9,                                           -- Height to match other readouts
        car.absInAction and assistColors.abs or nil, -- No background
        rgbm(1, 1, 1, 1)
    )
    drawTextWithBackground(
        absText,
        22,
        assistsX + 28, -- Position after label
        assistsY,
        65,            -- Width for value
        22,
        nil,
        rgbm(1, 1, 1, 1)
    )

    -- TC Display
    local tcText = car.tractionControlModes > 0
        and string.format("%2d/%d", car.tractionControlMode, car.tractionControlModes)
        or " N/A"
    drawTextWithBackground(
        "TC",
        14,
        assistsX,
        assistsY + 22, -- Stack below ABS
        21,
        9,
        car.tractionControlInAction and assistColors.tc or nil,
        rgbm(1, 1, 1, 1)
    )
    drawTextWithBackground(
        tcText,
        22,
        assistsX + 28,
        assistsY + 22,
        65,
        22,
        nil,
        rgbm(1, 1, 1, 1)
    )

    ui.drawLine(
        vec2(assistsX + 94, assistsY - 4),
        vec2(assistsX + 94, assistsY + 94),
        rgbm(1, 1, 1, 0.2),
        1
    )

    -- Wind Display
    drawTextWithBackground(
        string.format("%s", getWindDirectionText(sim.windDirectionDeg)),
        22,
        assistsX + 100, -- Position to right of TC/ABS
        assistsY,
        35,
        22,
        nil,
        rgbm(1, 1, 1, 1),
        ui.Alignment.Center
    )
    drawTextWithBackground(
        string.format("%.0f", sim.windSpeedKmh),
        22,
        assistsX + 100,
        assistsY + 22,
        35,
        22,
        nil,
        rgbm(1, 1, 1, 1),
        ui.Alignment.Center
    )

    drawTextWithBackground(
        string.format("%.0fA", sim.ambientTemperature),
        16,
        assistsX + 100,
        assistsY + 47,
        35,
        18,
        nil,
        rgbm(1, 1, 1, 1),
        ui.Alignment.Center
    )

    drawTextWithBackground(
        string.format("%.0fT", sim.roadTemperature),
        16,
        assistsX + 100,
        assistsY + 63,
        35,
        18,
        nil,
        rgbm(1, 1, 1, 1),
        ui.Alignment.Center
    )

    drawTextWithBackground(
        string.format("%.01f%%", sim.roadGrip * 100),
        13,
        assistsX + 99,
        assistsY + 80,
        40,
        18,
        nil,
        rgbm(1, 1, 1, 1),
        ui.Alignment.Center
    )

    -- Brake Bias Display
    drawTextWithBackground(
        "BB",
        14,
        assistsX,
        assistsY + 44, -- Stack below TC
        40,
        22,
        nil,
        rgbm(1, 1, 1, 1)
    )
    drawTextWithBackground(
        string.format("%.1f%%", car.brakeBias * 100),
        22,
        assistsX + 28,
        assistsY + 44,
        65,
        22,
        nil,
        rgbm(1, 1, 1, 1)
    )

    ui.drawLine(
        vec2(assistsX + 140, assistsY - 4),
        vec2(assistsX + 140, assistsY + 94),
        rgbm(1, 1, 1, 0.2),
        1
    )

    -- Invisible button to swap SB and PB comparison, like the one in the deltabar
    if ui.rectHovered(vec2(0, 0), vec2(700, 150), false) then
        ui.drawRectFilled(vec2(4, 98), vec2(150, 146), rgbm(0, 0, 0, 0.1))
    end
    ui.setCursor(vec2(4, 98))
    if ui.invisibleButton("Swap SB and PB", vec2(146, 48)) then
        config.delta.compareMode = config.delta.compareMode == "SESSION" and "PERSONAL" or "SESSION"
    end

    -- Invisible button to toggle the presence of shift lights
    local shiftLightButtonTL = vec2(145, 16)
    local shiftLightButtonBR = vec2(208, 33)
    if ui.rectHovered(vec2(0, 0), vec2(700, 150), false) then
        ui.drawRectFilled(shiftLightButtonTL, shiftLightButtonBR, rgbm(0, 0, 0, 0.3), 2, ui.CornerFlags.All)
        ui.dwriteDrawText("LGT " .. (config.rpm.shiftLightsEnabled and "ON" or "OFF"), 14,
            shiftLightButtonTL + vec2(3, 4), rgbm(1, 1, 1, 1))
    end
    ui.setCursor(shiftLightButtonTL)
    if ui.invisibleButton("Shift Lights", shiftLightButtonBR - shiftLightButtonTL) then
        config.rpm.shiftLightsEnabled = not config.rpm.shiftLightsEnabled
    end


    ui.popDWriteFont()
end

function drawDeltabar()
    ui.pushDWriteFont(font_whiteRabbit)

    ui.drawRectFilled(vec2(0, 0), vec2(424, 31), rgbm(0, 0, 0, 0.25), 5, ui.CornerFlags.All)

    -- Get delta values
    local delta, deltaChangeRate = currentDelta, currentDeltaChangeRate

    -- Delta bar settings
    local barWidth = 419 -- Window width (424) - 2px padding
    local barHeight = 29 -- Window height (31) - 2px padding
    local centerX = 212  -- Center point of the window (424/2)
    local startY = 1     -- 1px padding from top

    -- Calculate bar progress with two different scales
    local maxDelta = 2.0      -- Maximum delta to show
    local detailedDelta = 0.5 -- More detailed range near center
    local progressWidth

    -- Remove the conditional opacity for tick marks
    local tickColor = 0.2 -- Constant opacity for ticks

    -- Background bar
    ui.drawRectFilled(vec2(1, startY),
        vec2(423, startY + barHeight),
        rgbm(0.2, 0.2, 0.2, 0.9), 3)

    -- Draw horizontal line across the bar
    ui.drawRectFilled(vec2(2, startY + barHeight / 2),
        vec2(422, startY + barHeight / 2 + 1),
        rgbm(1, 1, 1, tickColor), 0)

    -- Draw tick marks
    local smallTickHeight = 5

    -- Draw center line
    ui.drawRectFilled(vec2(centerX, startY),
        vec2(centerX + 1, startY + barHeight),
        rgbm(1, 1, 1, tickColor), 0)

    -- Draw small ticks at 0.05s intervals
    for i = 1, 9 do
        local smallTickDelta = (i * 0.05)
        local smallTickWidth = (smallTickDelta / detailedDelta) * (barWidth / 4)

        -- Left side small ticks
        ui.drawRectFilled(vec2(centerX - smallTickWidth, startY + (barHeight - smallTickHeight) / 2),
            vec2(centerX - smallTickWidth + 1, startY + (barHeight + smallTickHeight) / 2),
            rgbm(1, 1, 1, tickColor), 0)

        -- Right side small ticks
        ui.drawRectFilled(vec2(centerX + smallTickWidth, startY + (barHeight - smallTickHeight) / 2),
            vec2(centerX + smallTickWidth + 1, startY + (barHeight + smallTickHeight) / 2),
            rgbm(1, 1, 1, tickColor), 0)
    end

    -- Draw outer range ticks (0.5s intervals from 0.5s to 2.0s)
    for i = 1, 4 do
        local tickDelta = i * 0.5
        local remainingDelta = tickDelta - detailedDelta
        local remainingRange = maxDelta - detailedDelta
        local tickWidth = (barWidth / 4) + (remainingDelta / remainingRange) * (barWidth / 4)

        -- Left side ticks
        ui.drawRectFilled(vec2(centerX - tickWidth, startY + 1),
            vec2(centerX - tickWidth + 1, startY + barHeight - 1),
            rgbm(1, 1, 1, tickColor), 0)

        -- Right side ticks
        ui.drawRectFilled(vec2(centerX + tickWidth, startY + 1),
            vec2(centerX + tickWidth + 1, startY + barHeight - 1),
            rgbm(1, 1, 1, tickColor), 0)
    end

    if delta then
        if math.abs(delta) <= detailedDelta then
            -- First half of the bar's width represents ±0.5s
            progressWidth = math.abs(delta) / detailedDelta * (barWidth / 4)
        else
            -- Second half represents remaining range up to maxDelta
            local remainingDelta = math.abs(delta) - detailedDelta
            local remainingRange = maxDelta - detailedDelta
            local detailedWidth = barWidth / 4 -- Width for first 0.5s
            local extraWidth = (remainingDelta / remainingRange) * (barWidth / 4)
            progressWidth = detailedWidth + extraWidth
        end
        progressWidth = math.min(progressWidth, barWidth / 2) -- Ensure we don't exceed half the bar

        -- Draw the colored bar
        local deltaBarEnd
        if delta > 0 then
            -- Lost time - Red bar to the left (center moves right 1px)
            deltaBarEnd = centerX - progressWidth
            ui.drawRectFilled(vec2(deltaBarEnd, startY + 2),
                vec2(centerX + 1, startY + barHeight - 2),
                rgbm(0.8, 0.2, 0.2, 1), 2)
        else
            -- Gained time - Green bar to the right (center moves left 1px)
            deltaBarEnd = centerX + progressWidth
            ui.drawRectFilled(vec2(centerX - 1, startY + 2),
                vec2(deltaBarEnd, startY + barHeight - 2),
                rgbm(0.2, 0.8, 0.2, 1), 2)
        end

        -- Draw trend bar
        -- Changed condition to check if deltaChangeRate is not nil (zero is valid)
        if deltaChangeRate ~= nil then
            if deltaChangeRate > 0 then
                -- Trending towards positive (losing more time) - point right
                ui.drawRectFilled(vec2(deltaBarEnd - (deltaChangeRate * 5000), startY + 3),
                    vec2(deltaBarEnd + 1, startY + barHeight - 3),
                    rgbm(1, 1, 0, 0.5))
            elseif deltaChangeRate < 0 then -- Explicit check for negative
                -- Trending towards negative (gaining more time) - point left
                ui.drawRectFilled(vec2(deltaBarEnd - 1, startY + 3),
                    vec2(deltaBarEnd + (deltaChangeRate * -5000), startY + barHeight - 3),
                    rgbm(1, 1, 0, 0.5))
            end
            -- When deltaChangeRate is exactly 0, we don't draw a trend bar
        end

        if config.delta.numberShown then
            -- Draw delta text with background
            local deltaText = string.format(
            "%+." ..
            (math.abs(delta) >= 100 and "1" or math.abs(delta) >= 10 and "2" or math.abs(delta) >= 1 and "3" or "3") ..
            "f", delta)
            -- First draw the background
            ui.drawRectFilled(
                vec2(centerX - 35, startY + 5),
                vec2(centerX + 35, startY + barHeight - 5),
                rgbm(0.15, 0.15, 0.15, 1),
                3
            )
            -- Then draw the text
            ui.dwriteDrawTextClipped(
                deltaText,
                18,
                vec2(centerX - 100, startY + 1),
                vec2(centerX + 100, startY + barHeight),
                ui.Alignment.Center,
                ui.Alignment.Center,
                false,
                rgbm(1, 1, 1, 0.8)
            )
        end
    else
        if config.delta.numberShown then
            -- No delta available
            ui.dwriteDrawTextClipped(
                "NO DELTA AVAILABLE",
                18,
                vec2(0, 1),
                vec2(426, 30),
                ui.Alignment.Center,
                ui.Alignment.Center,
                false,
                rgbm(1, 1, 1, (math.sin(sim.time * 0.003) + 2) / 3)
            )
        end
    end

    local buttonShowNumberPos = vec2(350, 10)
    local buttonShowNumberSize = vec2(63, 12)
    local buttonComparePos = vec2(10, 10)
    local buttonCompareSize = vec2(54, 12)

    -- Hover buttons
    if ui.rectHovered(vec2(0, 0), vec2(424, 31), false) then
        ui.drawRectFilled(buttonShowNumberPos - 2, buttonShowNumberPos + buttonShowNumberSize + 2, rgbm(0.1, 0.1, 0.1, 1),
            3)
        ui.dwriteDrawText(config.delta.numberShown and "Hide DT" or "Show DT", 16, buttonShowNumberPos, rgbm(1, 1, 1, 1))

        ui.drawRectFilled(buttonComparePos - 2, buttonComparePos + buttonCompareSize + 2, rgbm(0.1, 0.1, 0.1, 1), 3)
        local nextMode = getNextMode(config.delta.compareMode)
        ui.dwriteDrawText("Use " .. deltaCompareModes[nextMode], 16, buttonComparePos, rgbm(1, 1, 1, 1))
    end

    ui.setCursor(buttonShowNumberPos)
    if ui.invisibleButton("showHideDT", buttonShowNumberSize) then
        config.delta.numberShown = not config.delta.numberShown
        saveSettings()
    end

    ui.setCursor(buttonComparePos)
    if ui.invisibleButton("compareMode", buttonCompareSize) then
        config.delta.compareMode = getNextMode(config.delta.compareMode)
        saveSettings()
    end

    -- Draw flashing "NEW BEST" text if needed
    local timeSincePersonalBest = os.clock() - personalBestFlashStartTime
    local totalFlashDuration = PERSONAL_BEST_FLASH_DURATION * PERSONAL_BEST_FLASH_COUNT * 2
    local timeSinceSessionBest = os.clock() - sessionBestFlashStartTime
    local totalSessionFlashDuration = SESSION_BEST_FLASH_DURATION * SESSION_BEST_FLASH_COUNT * 2

    if timeSincePersonalBest < totalFlashDuration then
        -- Calculate flash state (0.5 to 1.0 opacity)
        local flashState = math.floor(timeSincePersonalBest / PERSONAL_BEST_FLASH_DURATION) % 2 == 0
        local textOpacity = flashState and 1 or 0.5

        -- Draw white background (always visible)
        ui.drawRectFilled(
            vec2(centerX - 92, startY + 5),
            vec2(centerX + 92, startY + barHeight - 5),
            rgbm(0.2, 0.5, 1, 1),
            3
        )
        ui.dwriteDrawTextClipped(
            "NEW PERSONAL BEST",
            18,
            vec2(centerX - 100, startY - 1),
            vec2(centerX + 98, startY + barHeight),
            ui.Alignment.Center,
            ui.Alignment.Center,
            false,
            rgbm(0, 0, 0, textOpacity)
        )
        ui.dwriteDrawTextClipped(
            "NEW PERSONAL BEST",
            18,
            vec2(centerX - 100, startY + 2),
            vec2(centerX + 102, startY + barHeight),
            ui.Alignment.Center,
            ui.Alignment.Center,
            false,
            rgbm(0, 0, 0, textOpacity)
        )
        ui.dwriteDrawTextClipped(
            "NEW PERSONAL BEST",
            18,
            vec2(centerX - 100, startY + 1),
            vec2(centerX + 100, startY + barHeight),
            ui.Alignment.Center,
            ui.Alignment.Center,
            false,
            rgbm(1, 1, 1, textOpacity)
        )
    elseif timeSinceSessionBest < totalSessionFlashDuration then
        -- Calculate flash state (0.5 to 1.0 opacity)
        local flashState = math.floor(timeSinceSessionBest / SESSION_BEST_FLASH_DURATION) % 2 == 0
        local textOpacity = flashState and 1 or 0.5

        -- Draw background
        ui.drawRectFilled(
            vec2(centerX - 92, startY + 5),
            vec2(centerX + 92, startY + barHeight - 5),
            rgbm(0.2, 0.5, 0.2, 1), -- Green background for session best
            3
        )
        -- Draw shadow text
        ui.dwriteDrawTextClipped(
            "NEW SESSION BEST",
            18,
            vec2(centerX - 100, startY - 1),
            vec2(centerX + 98, startY + barHeight),
            ui.Alignment.Center,
            ui.Alignment.Center,
            false,
            rgbm(0, 0, 0, textOpacity)
        )
        ui.dwriteDrawTextClipped(
            "NEW SESSION BEST",
            18,
            vec2(centerX - 100, startY + 2),
            vec2(centerX + 102, startY + barHeight),
            ui.Alignment.Center,
            ui.Alignment.Center,
            false,
            rgbm(0, 0, 0, textOpacity)
        )
        -- Draw main text
        ui.dwriteDrawTextClipped(
            "NEW SESSION BEST",
            18,
            vec2(centerX - 100, startY + 1),
            vec2(centerX + 100, startY + barHeight),
            ui.Alignment.Center,
            ui.Alignment.Center,
            false,
            rgbm(1, 1, 1, textOpacity)
        )
    end

    ui.popDWriteFont()
end

local dashPosition = getElementPosition(700, "dash")
local deltabarPosition = getElementPosition(424, "delta")


function script.windowMain(dt)
    if not ac.isInReplayMode() then
        ui.transparentWindow("AllTheInfo_Dash", dashPosition, vec2(700, 150), true, true, function() drawDash() end)
    end
end

function script.windowSettings(dt)
    local changed = false

    ui.text("Delta To:")
    if ui.radioButton('Session Best', config.delta.compareMode == "SESSION") then
        config.delta.compareMode = "SESSION"
        changed = true
    end
    if ui.radioButton('Personal Best', config.delta.compareMode == "PERSONAL") then
        config.delta.compareMode = "PERSONAL"
        changed = true
    end

    ui.newLine()

    ui.text("Show Delta Value:")
    if ui.checkbox("Show", config.delta.numberShown) then
        config.delta.numberShown = not config.delta.numberShown
        changed = true
    end

    if changed then
        saveSettings()
    end
    ui.newLine()
    ui.text("Race Fuel Simulation:")

    if ui.checkbox("Enable Simulation", raceSimEnabled) then
        raceSimEnabled = not raceSimEnabled
    end

    -- Only show simulation settings if enabled
    if raceSimEnabled then
        ui.text("Set Race Duration:")
        ui.sameLine()
        if ui.radioButton("Time", raceSimMode == "time") then
            raceSimMode = "time"
        end
        ui.sameLine()
        if ui.radioButton("Laps", raceSimMode == "laps") then
            raceSimMode = "laps"
        end

        if raceSimMode == "time" then
            local mins = math.floor(raceSimTime / 60)
            local secs = raceSimTime % 60
            local changed = false

            ui.pushItemWidth(50)
            local minsChanged, minsText = ui.inputText("Minutes", tostring(mins), 3)
            if minsChanged then
                local newMins = tonumber(minsText) or mins
                mins = math.max(0, newMins)
                changed = true
            end

            ui.sameLine()
            local secsChanged, secsText = ui.inputText("Seconds", tostring(secs), 2)
            if secsChanged then
                local newSecs = tonumber(secsText) or secs
                secs = math.clamp(newSecs, 0, 59)
                changed = true
            end
            ui.popItemWidth()

            if changed then
                raceSimTime = mins * 60 + secs
            end
        else
            ui.pushItemWidth(100)
            local lapsChanged, lapsText = ui.inputText("Laps", tostring(raceSimLaps), 3)
            if lapsChanged then
                local newLaps = tonumber(lapsText) or raceSimLaps
                raceSimLaps = math.max(1, newLaps)
            end
            ui.popItemWidth()
        end
    end

    if ui.button("Reset Fuel Data") then
        lastLapFuelUsed = 0
        if fuelUsageData then
            fuelUsageData = {}
        end
        personalBestFuelUsage = nil
    end

    ui.newLine()
    ui.text("Personal Best Records:")
    if ui.button("Delete PB for Current Car/Track") then
        ui.modalDialog("Confirm Delete", function()
            ui.text(
            "Are you sure you want to delete the personal best record\nfor the current car and track combination?")
            ui.newLine()
            if ui.button("Yes") then
                -- Delete PB file if it exists, use .txt extension to match savePersonalBest()
                local pbFile = string.format("%s/%s.txt", personalBestDir, getTrackIdentifier())
                if io.exists(pbFile) then
                    os.remove(pbFile)
                    -- Reset all PB-related data
                    personalBestLapValue = 0
                    personalBestPosList = {}
                    personalBestTimeList = {}
                    personalBestFuelUsage = nil
                    ui.toast(ui.Icons.Warning, "Personal best record deleted")
                end
                return true
            end
            ui.sameLine()
            if ui.button("No") then
                return true
            end
        end)
    end

    ui.newLine()
    ui.text("Testing:")
    if ui.button("Test PB Flash Animation") then
        personalBestFlashStartTime = os.clock()
    end
    ui.sameLine()
    if ui.button("Test SB Flash Animation") then
        sessionBestFlashStartTime = os.clock()
    end
end

function script.windowDelta()
    if not ac.isInReplayMode() then
        ui.transparentWindow("AllTheInfo_Delta", deltabarPosition, vec2(424, 31), true, true,
            function() drawDeltabar() end)
    end
end

---@diagnostic disable: duplicate-set-field
function script.update()
    -- Check for session change by looking for large time remaining jumps
    local currentSessionTime = sim.sessionTimeLeft / 1000 -- Convert to seconds
    local timeDelta = math.abs(currentSessionTime - lastSessionTimeLeft)

    -- Only consider it a session change if:
    -- 1. Time jumps by more than threshold AND
    -- 2. Current time is larger than previous time (session restart/new session) AND
    -- 3. We're not just starting up (lastSessionTimeLeft should not be 0) AND
    -- 4. We're not in the middle of a lap
    if timeDelta > sessionTimeJumpThreshold and
        currentSessionTime > lastSessionTimeLeft and
        lastSessionTimeLeft ~= 0 and
        car.lapTimeMs < 1000 then -- Only reset near the start of a lap
        resetSessionData()
        print("Session change detected - time delta:" .. timeDelta)
        print("Current lap time: " .. car.lapTimeMs)
    end

    -- Always update last session time, but only after checking for changes
    lastSessionTimeLeft = currentSessionTime

    -- Remove the session index check since we're using time jumps
    -- if sim.currentSessionIndex ~= currentSessionIndex then
    --     currentSessionIndex = sim.currentSessionIndex
    --     resetSessionData()
    -- end

    -- Reset tire LUTs if compound changes
    if car.compoundIndex ~= currentCompoundIndex then
        tireWearLUTs.front = nil
        tireWearLUTs.rear = nil
        currentCompoundIndex = car.compoundIndex
    end

    local lapCount = car.lapCount

    -- Invalidate lap if car enters pits
    if car.isInPitlane then
        currentLapIsInvalid = true
    end

    -- Store best lap data when completing a lap
    if lapCount > previousLapCount then
        lastLapValue = car.previousLapTimeMs
        previousLapValidityValue = currentLapIsInvalid -- Store the validity state of the completed lap

        -- Calculate and store fuel usage for completed lap
        if lastLapFuelLevel > 0 then
            lastLapFuelUsed = lastLapFuelLevel - car.fuel -- Store last lap fuel usage regardless of validity

            if not currentLapIsInvalid and lastLapFuelUsed > 0 then
                -- Check if this lap is significantly faster than our fuel usage history
                local shouldResetHistory = false
                if #fuelUsageHistory > 0 then
                    -- Calculate average lap time from existing history
                    local avgLapTime = 0
                    local weightSum = 0
                    for _, data in ipairs(fuelUsageHistory) do
                        -- We need to store lap times with fuel usage data
                        if data.lapTime then
                            avgLapTime = avgLapTime + (data.lapTime * data.weight)
                            weightSum = weightSum + data.weight
                        end
                    end

                    if weightSum > 0 then
                        avgLapTime = avgLapTime / weightSum
                        -- If new lap is significantly faster (3% or more), reset history
                        if lastLapValue < (avgLapTime * fuelImprovementThreshold) then
                            shouldResetHistory = true
                            ac.log("Fuel history" .. "Resetting due to significant lap time improvement")
                            ac.log("New lap" .. lastLapValue)
                            ac.log("Avg previous" .. avgLapTime)
                        end
                    end
                end

                if shouldResetHistory then
                    -- Clear the history and start fresh with this lap
                    fuelUsageHistory = {}
                end

                -- Calculate weight based on both lap time and fuel usage
                local weight = calculateFuelWeight(lastLapValue, lastLapFuelUsed)

                -- Create new data point with lap time included
                local newDataPoint = FuelDataPoint.new(lastLapFuelUsed, weight)
                newDataPoint.lapTime = lastLapValue -- Add lap time to the data point

                -- Store both fuel usage and its weight
                table.insert(fuelUsageHistory, 1, newDataPoint)

                -- Keep only the last N laps, but ensure we have at least 2 representative laps
                while #fuelUsageHistory > maxFuelHistorySize do
                    -- Check if removing the last entry would leave us with enough good data
                    local goodDataCount = 0
                    for i = 1, #fuelUsageHistory - 1 do          -- Don't count the one we might remove
                        if fuelUsageHistory[i].weight > 0.5 then -- Consider laps with weight > 0.5 as "good"
                            goodDataCount = goodDataCount + 1
                        end
                    end

                    if goodDataCount >= 2 then -- Only remove if we have at least 2 good laps remaining
                        table.remove(fuelUsageHistory)
                    else
                        break -- Keep the data until we have enough good laps
                    end
                end
            end
        end

        -- Update fuel level for next lap
        lastLapFuelLevel = car.fuel

        -- Store best lap data if the lap was valid and has a valid time
        if not currentLapIsInvalid and lastLapValue > 0 then
            storeBestLap()
        end

        previousLapCount = lapCount
        currentLapIsInvalid = false -- Reset validity for new lap
    end

    -- Track lap validity - check for wheels outside track
    if car.wheelsOutside > 2 then  -- If more than 2 wheels are outside
        currentLapIsInvalid = true -- Mark lap as invalid
    end

    if car.turboBoost > maxSeenBoost then
        maxSeenBoost = car.turboBoost
    end

    -- Calculate delta once per update
    currentDelta, currentDeltaChangeRate = getLapDelta()

    -- Debug output for delta calculation
    ac.debug("delta", currentDelta)
    ac.debug("deltaChangeRate", currentDeltaChangeRate)
    ac.debug("currentLapTime", car.lapTimeMs)
    ac.debug("lapProgress", car.splinePosition)
    ac.debug("wheelsOutside", car.wheelsOutside)
    ac.debug("isInvalid", currentLapIsInvalid)
    ac.debug("comparisonPoints", config.delta.compareMode == "SESSION" and #bestPosList or #personalBestPosList)
    ac.debug("lastGoodDelta", lastGoodDelta)
    ac.debug("timeSinceGoodDelta", sim.time - lastGoodDeltaTime)
    ac.debug("session.laps", session.laps)
    ac.debug("car.lapCount", car.lapCount)
    ac.debug("car.splinePosition", car.splinePosition)
    ac.debug("sim.sessionTimeLeft", sim.sessionTimeLeft)
    ac.debug("sim.sessionsCount", sim.sessionsCount)

    -- Tire wear debug information
    ac.debug("tireWear: FL vKM", car.wheels[ac.Wheel.FrontLeft].tyreVirtualKM)
    ac.debug("tireWear: FR vKM", car.wheels[ac.Wheel.FrontRight].tyreVirtualKM)
    ac.debug("tireWear: RL vKM", car.wheels[ac.Wheel.RearLeft].tyreVirtualKM)
    ac.debug("tireWear: RR vKM", car.wheels[ac.Wheel.RearRight].tyreVirtualKM)

    ac.debug("tireWear: FL grip%", getTireGripFromWear(0))
    ac.debug("tireWear: FR grip%", getTireGripFromWear(1))
    ac.debug("tireWear: RL grip%", getTireGripFromWear(2))
    ac.debug("tireWear: RR grip%", getTireGripFromWear(3))

    -- Debug interpolation values
    ac.debug("deltaInterp: i", debugI)
    ac.debug("deltaInterp: p1", debugP1)
    ac.debug("deltaInterp: p2", debugP2)
    ac.debug("deltaInterp: t1", debugT1)
    ac.debug("deltaInterp: t2", debugT2)

    -- Debug the early exit conditions
    local earlyExitReason = ""
    if car.lapTimeMs <= 500 then
        earlyExitReason = "too early in lap"
    elseif car.splinePosition <= 0.001 then
        earlyExitReason = "too close to start"
    elseif car.splinePosition >= 0.999 then
        earlyExitReason = "too close to end"
    elseif currentLapIsInvalid then
        earlyExitReason = "lap invalid"
    end
    ac.debug("earlyExitReason", earlyExitReason)

    previousLapProgressValue = car.splinePosition

    -- Track when time expires and store the lap count
    if sim.raceSessionType == ac.SessionType.Race then
        local timeLeft = (sim.sessionTimeLeft / 1000)
        if timeLeft <= 0 and session.hasAdditionalLap then
            if not timeExpired then
                timeExpired = true
                lapCountWhenTimeExpired = car.lapCount
            end
        else
            timeExpired = false
            lapCountWhenTimeExpired = 0
        end
    else
        timeExpired = false
        lapCountWhenTimeExpired = 0
    end
end
