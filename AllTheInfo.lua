-- AllTheInfo CSP Lua App
-- Authored by ohyeah2389

local car = ac.getCar(0)
local sim = ac.getSim()
local session = ac.getSession(sim.currentSessionIndex)
Font_whiteRabbit = ui.DWriteFont("fonts/whitrabt.ttf")

local deltabar = require("deltabar")
local dash = require("dash")
local driftbar = require("driftbar")

-- UI Settings
Config = {
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
    drift = {
        numberShown = true,
    },
    tire = {
        zeroWearState = 0.94,
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
    },
    appScaleFactor = 1.0
}


local settingsFile = ac.getFolder(ac.FolderID.ACApps) .. '/lua/AllTheInfo/settings.txt'


-- Settings configuration table
local settingsConfig = {
    deltaCompareMode = {
        path = {"delta", "compareMode"},
        type = "string"
    },
    deltaNumberShown = {
        path = {"delta", "numberShown"},
        type = "boolean"
    },
    driftNumberShown = {
        path = {"drift", "numberShown"},
        type = "boolean"
    },
    appScaleFactor = {
        path = {"appScaleFactor"},
        type = "number"
    }
}


local displaySettings = {
    positions = {
        [1680] = { -- 1050p
            dash = { offset = 1040 },
            delta = { offset = 800 },
            drift = { offset = 560 }
        },
        [2560] = { -- 1440p
            dash = { offset = 155 },
            delta = { offset = 190 },
            drift = { offset = 225 }
        },
        [7680] = { -- Triple screen
            dash = { offset = 1430 },
            delta = { offset = 1050 },
            drift = { offset = 1050 }
        },
        [1920] = { -- 1080p
            dash = { offset = 155 },
            delta = { offset = 190 },
            drift = { offset = 225 }
        },
        default = { -- Default fallback
            dash = { offset = 155 },
            delta = { offset = 190 },
            drift = { offset = 225 }
        }
    }
}

local tireTempColors = {
    ambient = rgbm(0.2, 0, 0.4, 1), -- Purple for ambient temperature
    cold = rgbm(0, 0, 1, 1), -- Blue for cold
    optimal = rgbm(0, 1, 0, 1), -- Green for optimal temperature
    hot = rgbm(1, 1, 0, 1), -- Yellow for hot
    veryhot = rgbm(1, 0, 0, 1), -- Red for very hot
    explosion = rgbm(0.1, 0.1, 0.1, 1) -- Black for explosion temperature
}

TireTempThresholds = {
    ambient = 0.4, -- Purple below this % of optimal
    cold = 0.8, -- Blue between ambient and this % of optimal
    optimal = 0.05, -- Green within this +/- % of optimal
    hot = 1.2, -- Yellow between optimal and this, Red above
    explosion = 1.4 -- Black above this (near explosion temp)
}

local tireWearConfig = {
    thresholds = {
        transparent = 10, -- Below this % wear is transparent
        yellow = 30, -- Fade from transparent to yellow up to this %
        red = 60, -- Fade from yellow to red up to this %
        black = 90 -- Fade from red to black up to this %
    },
    colors = {
        transparent = rgbm(0, 0, 0, 0),
        yellow = rgbm(1, 1, 0, 0.8),
        red = rgbm(1, 0, 0, 1),
        black = rgbm(0, 0, 0, 1)
    }
}

DRSColors = {
    inactive = rgbm(0.5, 0.5, 0.5, 1), -- Grey for out of DRS zone
    available = rgbm(1, 1, 0, 1),      -- Yellow for available but not active
    active = rgbm(0, 1, 0, 1)          -- Green for active
}

AssistColors = {
    abs = rgbm(1, 0.2, 0.2, 0.7),
    tc = rgbm(0, 0.2, 1, 0.7)
}


-- MARK: Constants
local newTimeFlashDuration = 0.15 -- Duration of each flash (on/off) - faster flashing
local newTimeFlashCount = 5 -- Number of flashes
local fuelImprovementThreshold = 0.97 -- 3% improvement is considered significant

local raceSimEnabled = false -- Default to disabled
local raceSimMode = "time" -- "time" or "laps"
local raceSimTime = 1800 -- Default 30 minutes (in seconds)
local raceSimLaps = 10 -- Default 10 laps


-- Track and car identifiers
local trackDataFile = nil
local personalBestDir = nil
AllTimeBestLap = 0


-- Delta tracking
Delta = {}
Delta.trackHasCenterline = true
local centerlineCheckTime = 0
local centerlineCheckDuration = 10
Delta.deltaCompareModes = { SESSION = "SB", PERSONAL = "PB" }
Delta.currentDelta = nil
Delta.currentDeltaChangeRate = nil
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
local prevt = 0
local prevt2 = 0
local trendBuffer = {}
local trendBufferIndex = 1 -- Current position in buffer


-- Lap tracking
local previousLapCount = 0
local previousLapProgressValue = 0
CurrentLapIsInvalid = false
LastLapValue = 0
BestLapValue = 0
PersonalBestLapValue = 0



-- Lap status flags and timing
LastLapWasSessionBest = false
LastLapWasPersonalBest = false
SessionBestWasSetTime = 0
PersonalBestWasSetTime = 0
local lapCountWhenTimeExpired = 0
local timeExpired = false


-- Fuel tracking
FuelUsageHistory = {}
local fuelUsageData = {}
local maxFuelHistorySize = 5
local lastLapFuelLevel = car.fuel
LastLapFuelUsed = 0
PersonalBestFuelUsage = nil
local FuelDataPoint = {
    usage = 0,
    weight = 0,
    lapTime = 0
}


MaxSeenBoost = 0


-- Debug variables
local debugI = 0
local debugP1 = nil
local debugP2 = nil
local debugT1 = nil
local debugT2 = nil


-- Tire wear tracking
local tireWearLUTs = {
    front = nil, -- Will be loaded on first use
    rear = nil, -- Will be loaded on first use
    frontPeak = nil, -- Cache the peak grip value
    rearPeak = nil -- Cache the peak grip value
}
local currentCompoundIndex = nil -- Track current compound to detect changes


-- UI state
UIstate = {}
UIstate.personalBestFlashStartTime = 0
UIstate.sessionBestFlashStartTime = 0

-- UI globals
PERSONAL_BEST_FLASH_DURATION = 0.1
PERSONAL_BEST_FLASH_COUNT = 8
SESSION_BEST_FLASH_DURATION = 0.1
SESSION_BEST_FLASH_COUNT = 8


local lastSessionTimeLeft = 0 -- Track previous session time
local sessionTimeJumpThreshold = 10 -- Time jump threshold in seconds


-- Helper functions


function FuelDataPoint.new(usage, weight)
    return { usage = usage, weight = weight, lapTime = 0 }
end

function GetNextMode(currentMode)
    local modes = {}
    for mode in pairs(Delta.deltaCompareModes) do
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


function GetTrackIdentifier()
    local layout = ac.getTrackLayout()
    if layout and layout ~= "" then
        return ac.getTrackID() .. '_' .. layout
    end
    return ac.getTrackID()
end


function GetWindDirectionText(degrees)
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
    local horizontalCenter = (sim.windowWidth / 2) - ((elementWidth / 2) * Config.appScaleFactor)
    local preset = displaySettings.positions[sim.windowWidth] or displaySettings.positions.default
    local verticalOffset = preset[elementType].offset * Config.appScaleFactor

    return vec2(horizontalCenter, sim.windowHeight - verticalOffset)
end

-- Math helper function, like Map Range in Blender
function MapRange(n, start, stop, newStart, newStop, clamp)
    local value = math.remap(n, start, stop, newStart, newStop)

    -- Returns basic value
    if not clamp then
        return value
    end

    -- Returns values constrained to exact range
    if newStart < newStop then
        return math.clampN(value, newStart, newStop)
    else
        return math.clampN(value, newStop, newStart)
    end
end


-- Helper function for calculating background alpha fading
function FadeBackground(setTime)
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


function GetTireGripFromWear(wheel)
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

    -- Rescale grip value
    local normalizedGrip = rawGrip / peakGrip
    local displayGrip = (normalizedGrip - Config.tire.zeroWearState) / (1 - Config.tire.zeroWearState)

    -- Clamp final value to 0-1 range
    displayGrip = math.clamp(displayGrip, 0, 1)

    -- Debug values
    ac.debug(string.format("Wheel %d raw grip", wheel), rawGrip)
    ac.debug(string.format("Wheel %d normalized", wheel), normalizedGrip)
    ac.debug(string.format("Wheel %d display", wheel), displayGrip)

    return displayGrip
end


-- Initialize paths after state variables are declared
trackDataFile = string.format("%s/lua/AllTheInfo/track_records/%s.ini", ac.getFolder(ac.FolderID.ACApps), ac.getCarID(0))
personalBestDir = string.format("%s/lua/AllTheInfo/personal_best/%s", ac.getFolder(ac.FolderID.ACApps), ac.getCarID(0))


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
TrackRecords = loadTrackRecords()


local function resetSessionData()
    -- Reset lap tracking
    previousLapCount = 0
    previousLapProgressValue = 0
    CurrentLapIsInvalid = false
    LastLapValue = 0
    BestLapValue = 0 -- Reset session best

    -- Reset current lap delta tracking but preserve comparison data
    posList = {}
    timeList = {}
    Delta.currentDelta = nil
    Delta.currentDeltaChangeRate = nil
    lastGoodDelta = nil
    lastGoodDeltaTime = 0

    -- Reset fuel tracking for new session
    FuelUsageHistory = {}
    lastLapFuelLevel = car.fuel
    LastLapFuelUsed = 0

    -- Reset trend tracking
    prevt = 0
    prevt2 = 0
    trendBuffer = {}
    trendBufferIndex = 1

    -- Reset lap status flags
    LastLapWasSessionBest = false
    LastLapWasPersonalBest = false

    -- Reset additional lap tracking
    timeExpired = false
    lapCountWhenTimeExpired = 0

    -- Reset max boost tracking
    MaxSeenBoost = 0

    -- Reset centerline detection for new session
    Delta.trackHasCenterline = true
    centerlineCheckTime = 0

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
    local filename = string.format("%s/%s.txt", fullDir, GetTrackIdentifier())

    -- Create simple text file with data
    local file = io.open(filename, "w")
    if file then
        -- Write metadata
        file:write(string.format("TIME=%d\n", PersonalBestLapValue))   -- Changed to use personalBestLapValue
        file:write(string.format("DATE=%s\n", os.date("%Y-%m-%d %H:%M:%S")))
        file:write(string.format("POINTS=%d\n", #personalBestPosList)) -- Changed to use personalBestPosList
        -- Add fuel usage data
        file:write(string.format("FUEL=%.3f\n", LastLapFuelUsed))

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
    local filename = string.format("%s/%s.txt", personalBestDir, GetTrackIdentifier())

    if io.exists(filename) then
        local file = io.open(filename, "r")
        if file then
            -- Clear existing data
            personalBestPosList = {}
            personalBestTimeList = {}
            PersonalBestFuelUsage = nil

            local section = ""
            for line in file:lines() do
                -- Check for metadata
                local time = line:match("TIME=(%d+)")
                if time then
                    PersonalBestLapValue = tonumber(time)
                end

                -- Check for fuel usage data
                local fuel = line:match("FUEL=([%d%.]+)")
                if fuel then
                    PersonalBestFuelUsage = tonumber(fuel)
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
            ac.log("Loaded personal best:" .. PersonalBestLapValue)
            ac.log("Loaded positions:" .. #personalBestPosList)
            ac.log("Loaded times:" .. #personalBestTimeList)
            ac.log("Loaded fuel usage:" .. PersonalBestFuelUsage)
        end
    end
end


local function getLapDelta()
    -- Early exit if track doesn't have a centerline
    if not Delta.trackHasCenterline then
        return nil, nil
    end

    local deltaT = ac.getGameDeltaT()
    local currentLapTime = car.lapTimeMs
    local lapProgress = car.splinePosition

    -- Combined early exits and lap reset
    if currentLapTime > 500 and currentLapTime < 1000 then
        posList, timeList = {}, {}
        previousLapProgressValue, prevt, prevt2 = 0, 0, 0
        trendBuffer, trendBufferIndex = {}, 1
        CurrentLapIsInvalid, lastGoodDelta, lastGoodDeltaTime = false, nil, 0
    end

    -- Update data collection
    deltaTimer = deltaTimer + deltaT
    if deltaTimer > Config.delta.resolution then
        deltaTimer = 0
        if lapProgress > previousLapProgressValue and lapProgress < 1 then
            table.insert(timeList, currentLapTime)
            table.insert(posList, lapProgress)
        end
        previousLapProgressValue = lapProgress
    end

    -- Combined early exit conditions
    if currentLapTime <= 500 or lapProgress <= 0.001 or lapProgress >= 0.999 or
        #(Config.delta.compareMode == "SESSION" and bestPosList or personalBestPosList) == 0 then
        return lastGoodDelta and (sim.time - lastGoodDeltaTime) < Config.delta.extrapolationTime and
            lastGoodDelta + (lastGoodDeltaChangeRate or 0) * deltaT or nil, lastGoodDeltaChangeRate
    end

    -- Get comparison data
    local compList = Config.delta.compareMode == "SESSION" and { bestPosList, bestTimeList } or
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
    return lastGoodDelta and (sim.time - lastGoodDeltaTime) < Config.delta.extrapolationTime and
        lastGoodDelta + (lastGoodDeltaChangeRate or 0) * deltaT or nil, lastGoodDeltaChangeRate
end


local function storeLap()
    ac.log("Called storeLap()")
    ac.log("#posList: " .. #posList)
    ac.log("LastLapValue: " .. LastLapValue)
    if (#posList > 10) and (not CurrentLapIsInvalid) and (LastLapValue > 0) then
        -- Create copies of the lists BEFORE clearing them
        local posListCopy = table.shallow_copy(posList)
        local timeListCopy = table.shallow_copy(timeList)

        ac.log("Storing best lap with positions:" .. #posListCopy)
        ac.log("Storing best lap with times:" .. #timeListCopy)

        -- Reset flags first
        LastLapWasSessionBest = false
        LastLapWasPersonalBest = false

        -- Update session best if this lap is faster
        if (BestLapValue == 0) or (LastLapValue < BestLapValue) then
            bestPosList = table.shallow_copy(posListCopy)
            bestTimeList = table.shallow_copy(timeListCopy)
            BestLapValue = LastLapValue
            LastLapWasSessionBest = true
            SessionBestWasSetTime = os.clock()
            UIstate.sessionBestFlashStartTime = os.clock()
        end

        -- Update personal best if this lap is faster
        if (PersonalBestLapValue == 0) or (LastLapValue < PersonalBestLapValue) then
            personalBestPosList = table.shallow_copy(posListCopy)
            personalBestTimeList = table.shallow_copy(timeListCopy)
            PersonalBestLapValue = LastLapValue
            LastLapWasPersonalBest = true
            PersonalBestWasSetTime = os.clock()
            UIstate.personalBestFlashStartTime = os.clock()
            savePersonalBest() -- Save to file
        end

        -- Update all-time best if this lap is faster
        if AllTimeBestLap == 0 or LastLapValue < AllTimeBestLap then
            AllTimeBestLap = LastLapValue
            TrackRecords[GetTrackIdentifier()] = {
                time = LastLapValue,
                date = os.date("%Y-%m-%d %H:%M:%S")
            }
            -- Save to INI file
            local success, ini = pcall(function()
                local newIni = ac.INIConfig.new()
                for track, data in pairs(TrackRecords) do
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
    end
end


function DrawTextWithBackground(text, size, x, y, width, height, bgColor, textColor, alignment)
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


function GetTireWearColor(wear)
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


function GetFlashState(setTime)
    local timeSince = os.clock() - setTime
    if timeSince < newTimeFlashDuration * newTimeFlashCount * 2 then -- Total duration = flash duration * 2 (on/off) * count
        -- Flash on/off based on time
        return math.floor(timeSince / newTimeFlashDuration) % 2 == 0
    end
    return true -- Always visible after flash sequence
end


function GetTempColor(temp, optimalTemp)
    -- Calculate temperature ratio
    local ratio = temp / optimalTemp

    -- Create color based on temperature ratio
    if ratio < TireTempThresholds.ambient then
        -- Purple (cold/ambient)
        return tireTempColors.ambient
    elseif ratio < TireTempThresholds.cold then
        -- Interpolate between purple and blue
        local t = (ratio - TireTempThresholds.ambient) / (TireTempThresholds.cold - TireTempThresholds.ambient)
        return rgbm(
            tireTempColors.ambient.r * (1 - t) + tireTempColors.cold.r * t,
            tireTempColors.ambient.g * (1 - t) + tireTempColors.cold.g * t,
            tireTempColors.ambient.b * (1 - t) + tireTempColors.cold.b * t,
            1
        )
    elseif ratio < (1 - TireTempThresholds.optimal) then
        -- Interpolate between blue and green
        local t = (ratio - TireTempThresholds.cold) / ((1 - TireTempThresholds.optimal) - TireTempThresholds.cold)
        return rgbm(
            tireTempColors.cold.r * (1 - t) + tireTempColors.optimal.r * t,
            tireTempColors.cold.g * (1 - t) + tireTempColors.optimal.g * t,
            tireTempColors.cold.b * (1 - t) + tireTempColors.optimal.b * t,
            1
        )
    elseif ratio <= (1 + TireTempThresholds.optimal) then
        -- Green (optimal)
        return tireTempColors.optimal
    elseif ratio < TireTempThresholds.hot then
        -- Interpolate between green and yellow
        local t = (ratio - (1 + TireTempThresholds.optimal)) /
        (TireTempThresholds.hot - (1 + TireTempThresholds.optimal))
        return rgbm(
            tireTempColors.optimal.r * (1 - t) + tireTempColors.hot.r * t,
            tireTempColors.optimal.g * (1 - t) + tireTempColors.hot.g * t,
            tireTempColors.optimal.b * (1 - t) + tireTempColors.hot.b * t,
            1
        )
    elseif ratio < TireTempThresholds.explosion then
        -- Interpolate between yellow and red
        local t = (ratio - TireTempThresholds.hot) / (TireTempThresholds.explosion - TireTempThresholds.hot)
        return rgbm(
            tireTempColors.hot.r * (1 - t) + tireTempColors.veryhot.r * t,
            tireTempColors.hot.g * (1 - t) + tireTempColors.veryhot.g * t,
            tireTempColors.hot.b * (1 - t) + tireTempColors.veryhot.b * t,
            1
        )
    else
        -- Interpolate from red to black for explosion temperature
        local t = math.min((ratio - TireTempThresholds.explosion) / 0.1, 1) -- Adjust 0.1 to control fade speed
        return rgbm(
            tireTempColors.veryhot.r * (1 - t) + tireTempColors.explosion.r * t,
            tireTempColors.veryhot.g * (1 - t) + tireTempColors.explosion.g * t,
            tireTempColors.veryhot.b * (1 - t) + tireTempColors.explosion.b * t,
            1
        )
    end
end


function GetPressureColor(current, optimal)
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


function EstimateRemainingLaps()
    if sim.raceSessionType == ac.SessionType.Race then
        -- Use actual session data if in a race
        local timeLeft = (sim.sessionTimeLeft / 1000)
        local isTimedRace = session.isTimedRace
        local predictiveLapValue = (Config.delta.compareMode == "SESSION" and BestLapValue or PersonalBestLapValue) +
        ((Delta.currentDelta ~= nil and Delta.currentDelta or 0) * 1000)
        local referenceLapValue = BestLapValue ~= 0 and BestLapValue or LastLapValue ~= 0 and LastLapValue or
        PersonalBestLapValue
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
            if LastLapValue <= 0 then return nil end -- No valid lap time yet
            return raceSimTime / (LastLapValue / 1000)
        else
            return raceSimLaps
        end
    end
    return nil
end


local function calculateFuelWeight(lapTime, fuelUsed)
    if not BestLapValue or BestLapValue == 0 or not lapTime or lapTime == 0 then
        return 1 -- Default weight if we don't have enough data
    end

    -- First check if this is likely a standing/rolling start lap
    -- by comparing fuel usage to the average of existing data
    if #FuelUsageHistory > 0 then
        local avgFuel = 0
        local count = 0
        for _, data in ipairs(FuelUsageHistory) do
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

    local timeRatio = lapTime / BestLapValue

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

local function getConfigValue(path)
    local value = Config
    for _, key in ipairs(path) do
        value = value[key]
        if value == nil then return nil end
    end
    return value
end

local function setConfigValue(path, value)
    local current = Config
    for i = 1, #path - 1 do
        current = current[path[i]]
        if current == nil then return false end
    end
    current[path[#path]] = value
    return true
end

local function convertValue(value, valueType)
    if valueType == "boolean" then
        return value == "true"
    elseif valueType == "number" then
        return tonumber(value)
    else
        return value
    end
end

function SaveSettings()
    -- Create directory if it doesn't exist
    local dir = ac.getFolder(ac.FolderID.ACApps) .. '/lua/AllTheInfo'
    if not io.exists(dir) then
        os.execute('mkdir "' .. dir .. '"')
    end

    local file = io.open(settingsFile, "w")
    if file then
        for key, config in pairs(settingsConfig) do
            local value = getConfigValue(config.path)
            if value ~= nil then
                file:write(string.format("%s=%s\n", key, tostring(value)))
            end
        end
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
                    local config = settingsConfig[key]
                    if config then
                        local convertedValue = convertValue(value, config.type)
                        setConfigValue(config.path, convertedValue)
                    end
                end
            end
            file:close()
        end
    end
end


loadPersonalBest()
loadSettings()

local dashPosition = getElementPosition(700, "dash")
local deltabarPosition = getElementPosition(424, "delta")
local driftbarPosition = getElementPosition(424, "drift")


-- MARK: script.window


function script.windowMain(dt)
    if not ac.isInReplayMode() then
        ui.transparentWindow("AllTheInfo_Dash", dashPosition, vec2(700, 150) * Config.appScaleFactor, true, true, function() dash.draw() end)
    end
end


function script.windowDelta()
    if not ac.isInReplayMode() then
        ui.transparentWindow("AllTheInfo_Delta", deltabarPosition, vec2(424, 31) * Config.appScaleFactor, true, true, function() deltabar.draw() end)
    end
end


function script.windowDrift()
    if not ac.isInReplayMode() then
        ui.transparentWindow("AllTheInfo_Drift", driftbarPosition, vec2(424, 31) * Config.appScaleFactor, true, true, function() driftbar.draw() end)
    end
end


function script.windowSettings(dt)
    local changed = false

    ui.text("Delta To:")
    if ui.radioButton('Session Best', Config.delta.compareMode == "SESSION") then
        Config.delta.compareMode = "SESSION"
        changed = true
    end
    if ui.radioButton('Personal Best', Config.delta.compareMode == "PERSONAL") then
        Config.delta.compareMode = "PERSONAL"
        changed = true
    end

    ui.newLine()

    ui.text("Show Delta Value:")
    if ui.checkbox("Show", Config.delta.numberShown) then
        Config.delta.numberShown = not Config.delta.numberShown
        changed = true
    end

    ui.newLine()

    ui.text("Show Drift Angle:")
    if ui.checkbox("Show", Config.drift.numberShown) then
        Config.drift.numberShown = not Config.drift.numberShown
        changed = true
    end

    ui.newLine()

    ui.text("App Scale Factor:")
    local newScale, scaleChanged = ui.slider("##appScale", Config.appScaleFactor, 1.0, 5.0, "Scale: %.1fx", 1)
    if scaleChanged then
        Config.appScaleFactor = newScale
        -- Recalculate positions when scale changes
        dashPosition = getElementPosition(700, "dash")
        deltabarPosition = getElementPosition(424, "delta")
        driftbarPosition = getElementPosition(424, "drift")
        changed = true
    end

    if changed then
        SaveSettings()
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
        LastLapFuelUsed = 0
        if fuelUsageData then
            fuelUsageData = {}
        end
        PersonalBestFuelUsage = nil
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
                local pbFile = string.format("%s/%s.txt", personalBestDir, GetTrackIdentifier())
                if io.exists(pbFile) then
                    os.remove(pbFile)
                    -- Reset all PB-related data
                    PersonalBestLapValue = 0
                    personalBestPosList = {}
                    personalBestTimeList = {}
                    PersonalBestFuelUsage = nil
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
        UIstate.personalBestFlashStartTime = os.clock()
    end
    ui.sameLine()
    if ui.button("Test SB Flash Animation") then
        UIstate.sessionBestFlashStartTime = os.clock()
    end
end
-- MARK: script.update


---@diagnostic disable: duplicate-set-field
function script.update()
    -- Check for centerline availability during the first 10 seconds
    if centerlineCheckTime < centerlineCheckDuration then
        centerlineCheckTime = centerlineCheckTime + ac.getGameDeltaT()

        -- If we're in a lap with reasonable time but splinePosition is still 0, assume no centerline
        if car.lapTimeMs > 5000 and car.splinePosition == 0 then
            if Delta.trackHasCenterline then
                ac.log("Track has no AI centerline - delta calculations disabled")
                Delta.trackHasCenterline = false
            end
        elseif car.splinePosition > 0.001 then
            -- We found a valid spline position, track has centerline
            Delta.trackHasCenterline = true
        end
    end

    -- Check for session change by looking for large time remaining jumps
    local currentSessionTime = sim.sessionTimeLeft / 1000 -- Convert to seconds
    local timeDelta = math.abs(currentSessionTime - lastSessionTimeLeft)

    if (timeDelta > sessionTimeJumpThreshold) then
        resetSessionData()
        print("Session change detected - time delta: " .. timeDelta)
    end

    -- Always update last session time, but only after checking for changes
    lastSessionTimeLeft = currentSessionTime

    -- Reset tire LUTs if compound changes
    if car.compoundIndex ~= currentCompoundIndex then
        tireWearLUTs.front = nil
        tireWearLUTs.rear = nil
        currentCompoundIndex = car.compoundIndex
    end

    local lapCount = car.lapCount

    -- Invalidate lap if car enters pits
    if car.isInPitlane then
        CurrentLapIsInvalid = true
    end

    -- Store best lap data when completing a lap
    if lapCount > previousLapCount then
        LastLapValue = car.previousLapTimeMs

        -- Calculate and store fuel usage for completed lap
        if lastLapFuelLevel > 0 then
            LastLapFuelUsed = lastLapFuelLevel - car.fuel -- Store last lap fuel usage regardless of validity

            if not CurrentLapIsInvalid and LastLapFuelUsed > 0 then
                -- Check if this lap is significantly faster than our fuel usage history
                local shouldResetHistory = false
                if #FuelUsageHistory > 0 then
                    -- Calculate average lap time from existing history
                    local avgLapTime = 0
                    local weightSum = 0
                    for _, data in ipairs(FuelUsageHistory) do
                        -- We need to store lap times with fuel usage data
                        if data.lapTime then
                            avgLapTime = avgLapTime + (data.lapTime * data.weight)
                            weightSum = weightSum + data.weight
                        end
                    end

                    if weightSum > 0 then
                        avgLapTime = avgLapTime / weightSum
                        -- If new lap is significantly faster (3% or more), reset history
                        if LastLapValue < (avgLapTime * fuelImprovementThreshold) then
                            shouldResetHistory = true
                            ac.log("Fuel history reset due to significant lap time improvement")
                            ac.log("New lap: " .. LastLapValue)
                            ac.log("Avg previous: " .. avgLapTime)
                        end
                    end
                end

                if shouldResetHistory then
                    -- Clear the history and start fresh with this lap
                    FuelUsageHistory = {}
                end

                -- Calculate weight based on both lap time and fuel usage
                local weight = calculateFuelWeight(LastLapValue, LastLapFuelUsed)

                -- Create new data point with lap time included
                local newDataPoint = FuelDataPoint.new(LastLapFuelUsed, weight)
                newDataPoint.lapTime = LastLapValue -- Add lap time to the data point

                -- Store both fuel usage and its weight
                table.insert(FuelUsageHistory, 1, newDataPoint)

                -- Keep only the last N laps, but ensure we have at least 2 representative laps
                while #FuelUsageHistory > maxFuelHistorySize do
                    -- Check if removing the last entry would leave us with enough good data
                    local goodDataCount = 0
                    for i = 1, #FuelUsageHistory - 1 do          -- Don't count the one we might remove
                        if FuelUsageHistory[i].weight > 0.5 then -- Consider laps with weight > 0.5 as "good"
                            goodDataCount = goodDataCount + 1
                        end
                    end

                    if goodDataCount >= 2 then -- Only remove if we have at least 2 good laps remaining
                        table.remove(FuelUsageHistory)
                    else
                        break -- Keep the data until we have enough good laps
                    end
                end
            end
        end

        -- Update fuel level for next lap
        lastLapFuelLevel = car.fuel

        -- Store lap information
        storeLap()
        
        -- Reset validity and update lap count for new lap
        previousLapCount = lapCount
        CurrentLapIsInvalid = false
    end

    if car.wheelsOutside > 2 then -- If more than 2 wheels are outside
        CurrentLapIsInvalid = true -- Mark lap as invalid
    end

    if car.turboBoost > MaxSeenBoost then
        MaxSeenBoost = car.turboBoost
    end

    -- Calculate delta once per update (only if track has centerline)
    if Delta.trackHasCenterline then
        Delta.currentDelta, Delta.currentDeltaChangeRate = getLapDelta()
    else
        Delta.currentDelta, Delta.currentDeltaChangeRate = nil, nil
    end

    -- Debug output for delta calculation
    ac.debug("delta", Delta.currentDelta)
    ac.debug("deltaChangeRate", Delta.currentDeltaChangeRate)
    ac.debug("currentLapTime", car.lapTimeMs)
    ac.debug("lapProgress", car.splinePosition)
    ac.debug("wheelsOutside", car.wheelsOutside)
    ac.debug("isInvalid", CurrentLapIsInvalid)
    ac.debug("comparisonPoints", Config.delta.compareMode == "SESSION" and #bestPosList or #personalBestPosList)
    ac.debug("lastGoodDelta", lastGoodDelta)
    ac.debug("timeSinceGoodDelta", sim.time - lastGoodDeltaTime)
    ac.debug("session.laps", session.laps)
    ac.debug("car.lapCount", car.lapCount)
    ac.debug("car.splinePosition", car.splinePosition)
    ac.debug("sim.sessionTimeLeft", sim.sessionTimeLeft)
    ac.debug("sim.sessionsCount", sim.sessionsCount)
    ac.debug("sim.currentSessionIndex", sim.currentSessionIndex)

    -- Tire wear debug information
    ac.debug("tireWear: FL vKM", car.wheels[ac.Wheel.FrontLeft].tyreVirtualKM)
    ac.debug("tireWear: FR vKM", car.wheels[ac.Wheel.FrontRight].tyreVirtualKM)
    ac.debug("tireWear: RL vKM", car.wheels[ac.Wheel.RearLeft].tyreVirtualKM)
    ac.debug("tireWear: RR vKM", car.wheels[ac.Wheel.RearRight].tyreVirtualKM)

    ac.debug("tireWear: FL grip%", GetTireGripFromWear(0))
    ac.debug("tireWear: FR grip%", GetTireGripFromWear(1))
    ac.debug("tireWear: RL grip%", GetTireGripFromWear(2))
    ac.debug("tireWear: RR grip%", GetTireGripFromWear(3))

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
    elseif CurrentLapIsInvalid then
        earlyExitReason = "lap invalid"
    end
    ac.debug("earlyExitReason", earlyExitReason)

    -- Only update previousLapProgressValue if we have a centerline
    if Delta.trackHasCenterline then
        previousLapProgressValue = car.splinePosition
    end

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
