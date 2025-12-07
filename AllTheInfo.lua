-- AllTheInfo CSP Lua App
-- Authored by ohyeah2389

local car = ac.getCar(0)
local sim = ac.getSim()
local session = ac.getSession(sim.currentSessionIndex)
CurrentSessionIndex = sim.currentSessionIndex
Font_whiteRabbit = ui.DWriteFont("fonts/whitrabt.ttf")

local deltabar = require("deltabar")
local dash = require("dash")
local driftbar = require("driftbar")
local fuel = require("modules.fuel")

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
        path = { "delta", "compareMode" },
        type = "string"
    },
    deltaNumberShown = {
        path = { "delta", "numberShown" },
        type = "boolean"
    },
    driftNumberShown = {
        path = { "drift", "numberShown" },
        type = "boolean"
    },
    appScaleFactor = {
        path = { "appScaleFactor" },
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
        [7680] = { -- Triple 1440p
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

TireTempColors = {
    ambient = rgbm(0.2, 0, 0.4, 1),    -- Purple
    cold = rgbm(0.2, 0.2, 1, 1),       -- Blue
    optimal = rgbm(0, 1, 0, 1),        -- Green
    hot = rgbm(1, 1, 0, 1),            -- Yellow
    veryhot = rgbm(1, 0, 0, 1),        -- Red
    explosion = rgbm(0.1, 0.1, 0.1, 1) -- Black
}

TireTempThresholds = {
    ambient = 0.4,
    cold = 0.8,
    optimal = 0.05,
    hot = 1.2,
    explosion = 1.4
}

PressureColors = {
    low = rgbm(0.15, 0, 0.4, 1),  -- Purple for too low
    optimal = rgbm(0, 0.5, 0, 1), -- Deep green for optimal
    high = rgbm(0.8, 0, 0, 1)     -- Dark red for too high
}

local optimalPressureRange = 0.5    -- Within 0.5 PSI is considered optimal
local pressureTransitionRange = 2.0 -- Range over which colors blend

TireWearConfig = {
    thresholds = {
        transparent = 10, -- Below this % wear is transparent
        yellow = 30,      -- Fade from transparent to yellow up to this %
        red = 60,         -- Fade from yellow to red up to this %
        black = 90        -- Fade from red to black up to this %
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
local newTimeFlashCount = 5       -- Number of flashes

local raceSimEnabled = false      -- Default to disabled
local raceSimMode = "time"        -- "time" or "laps"
local raceSimTime = 1800          -- Default 30 minutes (in seconds)
local raceSimLaps = 10            -- Default 10 laps


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
PreviousLapValidityValue = false
local sessionJustReset = false
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
FuelTracking = {
    fuelUsageHistory = {},
    lastLapFuelLevel = car.fuel,
    lastLapFuelUsed = 0,
    personalBestFuelUsage = nil,
    lapCountWhenTimeExpired = 0,
    lastLapValue = 0,
    bestLapValue = 0,
    personalBestLapValue = 0,
    currentDelta = nil,
    currentLapIsInvalid = false
}

local fuelConstants = {
    maxFuelHistorySize = Config.fuel.maxHistorySize,
    fuelImprovementThreshold = Config.fuel.improvementThreshold
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
    front = nil,                 -- Will be loaded on first use
    rear = nil,                  -- Will be loaded on first use
    frontPeak = nil,             -- Cache the peak grip value
    rearPeak = nil               -- Cache the peak grip value
}
local currentCompoundIndex = nil -- Track current compound to detect changes


UIstate = {}
UIstate.personalBestFlashStartTime = 0
UIstate.sessionBestFlashStartTime = 0

-- UI globals
PERSONAL_BEST_FLASH_DURATION = 0.1
PERSONAL_BEST_FLASH_COUNT = 8
SESSION_BEST_FLASH_DURATION = 0.1
SESSION_BEST_FLASH_COUNT = 8

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
    for entry in serialized:gmatch("|([^|]+)") do
        -- Split on equals sign
        local input, output = entry:match("([^=]+)=([^=]+)")
        if input and output then
            local value = tonumber(output)
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


local function resetSessionData(guardFirstLap)
    local guardLap = guardFirstLap ~= false

    -- Reset lap tracking
    previousLapCount = 0
    previousLapProgressValue = 0
    CurrentLapIsInvalid = false
    LastLapValue = 0
    BestLapValue = 0 -- Reset session best
    sessionJustReset = guardLap

    -- Reset current lap delta tracking but preserve comparison data
    posList = {}
    timeList = {}
    Delta.currentDelta = nil
    Delta.currentDeltaChangeRate = nil
    lastGoodDelta = nil
    lastGoodDeltaTime = 0

    -- Reset fuel tracking for new session
    FuelTracking.fuelUsageHistory = {}
    FuelTracking.lastLapFuelLevel = car.fuel
    FuelTracking.lastLapFuelUsed = 0
    FuelTracking.currentLapIsInvalid = false
    FuelTracking.bestLapValue = 0
    FuelTracking.personalBestLapValue = 0
    FuelTracking.lastLapValue = 0
    FuelTracking.currentDelta = nil
    FuelTracking.lapCountWhenTimeExpired = 0

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


local function handleSessionStart(sessionIndex, guardFirstLap)
    CurrentSessionIndex = sessionIndex or sim.currentSessionIndex
    session = ac.getSession(CurrentSessionIndex)
    resetSessionData(guardFirstLap)
end

ac.onSessionStart(function(sessionIndex, restarted)
    handleSessionStart(sessionIndex, true)
end)

handleSessionStart(CurrentSessionIndex, false)


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
        file:write(string.format("FUEL=%.3f\n", FuelTracking.lastLapFuelUsed))

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
            FuelTracking.personalBestFuelUsage = nil

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
                    FuelTracking.personalBestFuelUsage = tonumber(fuel)
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
            ac.log("Loaded fuel usage:" .. (FuelTracking.personalBestFuelUsage or 0))
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
    local compList = Config.delta.compareMode == "SESSION" and { bestPosList, bestTimeList } or { personalBestPosList, personalBestTimeList }

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
    local lapIsValid = (not CurrentLapIsInvalid) and (LastLapValue > 0)
    local hasLapData = #posList > 10

    local posListCopy = hasLapData and table.shallow_copy(posList) or nil
    local timeListCopy = hasLapData and table.shallow_copy(timeList) or nil

    if lapIsValid then
        ac.log("Lap valid, storing data (hasLapData=" .. tostring(hasLapData) .. ")")

        -- Reset flags first
        LastLapWasSessionBest = false
        LastLapWasPersonalBest = false

        -- Update session best if this lap is faster
        if (BestLapValue == 0) or (LastLapValue < BestLapValue) then
            bestPosList = posListCopy or {}
            bestTimeList = timeListCopy or {}
            BestLapValue = LastLapValue
            LastLapWasSessionBest = true
            SessionBestWasSetTime = os.clock()
            UIstate.sessionBestFlashStartTime = os.clock()
        end

        -- Update personal best if this lap is faster
        if (PersonalBestLapValue == 0) or (LastLapValue < PersonalBestLapValue) then
            personalBestPosList = posListCopy or {}
            personalBestTimeList = timeListCopy or {}
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
    end

    -- Always reset current lap data to avoid cross-lap contamination
    posList = {}
    timeList = {}
    previousLapProgressValue = 0
    prevt = 0
    prevt2 = 0
    trendBuffer = {}
    trendBufferIndex = 1
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
    if wearPercent < TireWearConfig.thresholds.transparent then
        return TireWearConfig.colors.transparent
        -- Fade from transparent to yellow between thresholds
    elseif wearPercent < TireWearConfig.thresholds.yellow then
        local t = (wearPercent - TireWearConfig.thresholds.transparent) /
            (TireWearConfig.thresholds.yellow - TireWearConfig.thresholds.transparent)
        return rgbm(1, 1, 0, t * 0.5)
        -- Fade from yellow to red between thresholds
    elseif wearPercent < TireWearConfig.thresholds.red then
        local t = (wearPercent - TireWearConfig.thresholds.yellow) /
            (TireWearConfig.thresholds.red - TireWearConfig.thresholds.yellow)
        return rgbm(1, 1 - t, 0, 0.5)
        -- Fade from red to black between thresholds
    elseif wearPercent < TireWearConfig.thresholds.black then
        local t = (wearPercent - TireWearConfig.thresholds.red) /
            (TireWearConfig.thresholds.black - TireWearConfig.thresholds.red)
        return rgbm(1 - t, 0, 0, 0.5 + (t * 0.5))
        -- Full black above threshold
    else
        return TireWearConfig.colors.black
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
        return TireTempColors.ambient
    elseif ratio < TireTempThresholds.cold then
        -- Interpolate between purple and blue
        local t = (ratio - TireTempThresholds.ambient) / (TireTempThresholds.cold - TireTempThresholds.ambient)
        return rgbm(
            TireTempColors.ambient.r * (1 - t) + TireTempColors.cold.r * t,
            TireTempColors.ambient.g * (1 - t) + TireTempColors.cold.g * t,
            TireTempColors.ambient.b * (1 - t) + TireTempColors.cold.b * t,
            1
        )
    elseif ratio < (1 - TireTempThresholds.optimal) then
        -- Interpolate between blue and green
        local t = (ratio - TireTempThresholds.cold) / ((1 - TireTempThresholds.optimal) - TireTempThresholds.cold)
        return rgbm(
            TireTempColors.cold.r * (1 - t) + TireTempColors.optimal.r * t,
            TireTempColors.cold.g * (1 - t) + TireTempColors.optimal.g * t,
            TireTempColors.cold.b * (1 - t) + TireTempColors.optimal.b * t,
            1
        )
    elseif ratio <= (1 + TireTempThresholds.optimal) then
        -- Green (optimal)
        return TireTempColors.optimal
    elseif ratio < TireTempThresholds.hot then
        -- Interpolate between green and yellow
        local t = (ratio - (1 + TireTempThresholds.optimal)) / (TireTempThresholds.hot - (1 + TireTempThresholds.optimal))
        return rgbm(
            TireTempColors.optimal.r * (1 - t) + TireTempColors.hot.r * t,
            TireTempColors.optimal.g * (1 - t) + TireTempColors.hot.g * t,
            TireTempColors.optimal.b * (1 - t) + TireTempColors.hot.b * t,
            1
        )
    elseif ratio < TireTempThresholds.explosion then
        -- Interpolate between yellow and red
        local t = (ratio - TireTempThresholds.hot) / (TireTempThresholds.explosion - TireTempThresholds.hot)
        return rgbm(
            TireTempColors.hot.r * (1 - t) + TireTempColors.veryhot.r * t,
            TireTempColors.hot.g * (1 - t) + TireTempColors.veryhot.g * t,
            TireTempColors.hot.b * (1 - t) + TireTempColors.veryhot.b * t,
            1
        )
    else
        -- Interpolate from red to black for explosion temperature
        local t = math.min((ratio - TireTempThresholds.explosion) / 0.1, 1) -- Adjust 0.1 to control fade speed
        return rgbm(
            TireTempColors.veryhot.r * (1 - t) + TireTempColors.explosion.r * t,
            TireTempColors.veryhot.g * (1 - t) + TireTempColors.explosion.g * t,
            TireTempColors.veryhot.b * (1 - t) + TireTempColors.explosion.b * t,
            1
        )
    end
end

function GetPressureColor(current, optimal)
    local delta = current - optimal

    if math.abs(delta) < optimalPressureRange then
        return PressureColors.optimal
    elseif delta < 0 then
        -- Interpolate between purple and green
        local t = math.min(math.abs(delta) - optimalPressureRange, pressureTransitionRange) / pressureTransitionRange
        t = math.smoothstep(t)
        return rgbm(
            PressureColors.low.r * t + PressureColors.optimal.r * (1 - t),
            PressureColors.low.g * t + PressureColors.optimal.g * (1 - t),
            PressureColors.low.b * t + PressureColors.optimal.b * (1 - t),
            1
        )
    else
        -- Interpolate between green and red
        local t = math.min(delta - optimalPressureRange, pressureTransitionRange) / pressureTransitionRange
        t = math.smoothstep(t)
        return rgbm(
            PressureColors.optimal.r * (1 - t) + PressureColors.high.r * t,
            PressureColors.optimal.g * (1 - t) + PressureColors.high.g * (1 - t),
            PressureColors.optimal.b * (1 - t) + PressureColors.high.b * t,
            1
        )
    end
end

function EstimateRemainingLaps()
    FuelTracking.currentDelta = Delta.currentDelta
    FuelTracking.bestLapValue = BestLapValue
    FuelTracking.personalBestLapValue = PersonalBestLapValue
    FuelTracking.lastLapValue = LastLapValue
    FuelTracking.lapCountWhenTimeExpired = lapCountWhenTimeExpired

    return fuel.estimateRemainingLaps(
        sim,
        session,
        car,
        { deltaCompareMode = Config.delta.compareMode },
        FuelTracking,
        {
            enabled = raceSimEnabled,
            mode = raceSimMode,
            time = raceSimTime,
            laps = raceSimLaps
        }
    )
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
        FuelTracking.lastLapFuelUsed = 0
        FuelTracking.fuelUsageHistory = {}
        FuelTracking.personalBestFuelUsage = nil
    end

    ui.newLine()
    ui.text("Personal Best Records:")
    if ui.button("Delete PB for Current Car/Track") then
        ui.modalDialog("Confirm Delete", function()
            ui.text("Are you sure you want to delete the personal best record\nfor the current car and track combination?")
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
                    FuelTracking.personalBestFuelUsage = nil
                    ui.toast(ui.Icons.Warning, "Personal best record deleted")
                end
                return true
            end
            ui.sameLine()
            if ui.button("No") then
                return true
            end
            return false
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
    local sessionActive = sim.isSessionStarted and not sim.isSessionFinished
    if not sessionActive then
        Delta.currentDelta, Delta.currentDeltaChangeRate = nil, nil
        return
    end

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
        -- Skip the first lapCount bump after a session reset to avoid false lap completion at race start
        if sessionJustReset then
            previousLapCount = lapCount
            FuelTracking.lastLapFuelLevel = car.fuel
            CurrentLapIsInvalid = false
            sessionJustReset = false
        else
            LastLapValue = car.previousLapTimeMs

            -- Remember validity state of the lap that just finished
            PreviousLapValidityValue = CurrentLapIsInvalid

            -- Calculate and store fuel usage for completed lap via module
            FuelTracking.currentLapIsInvalid = CurrentLapIsInvalid
            FuelTracking.lastLapValue = LastLapValue
            FuelTracking.bestLapValue = BestLapValue
            FuelTracking.personalBestLapValue = PersonalBestLapValue
            FuelTracking.currentDelta = Delta.currentDelta
            FuelTracking.lapCountWhenTimeExpired = lapCountWhenTimeExpired

            if FuelTracking.lastLapFuelLevel > 0 then
                fuel.processLapFuelUsage(car, FuelTracking, fuelConstants)
            end

            -- Store lap information
            storeLap()

            -- Reset validity and update lap count for new lap
            previousLapCount = lapCount
            CurrentLapIsInvalid = false
        end
    end

    if car.wheelsOutside > 2 then  -- If more than 2 wheels are outside
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

    -- Keep fuel tracking state in sync for consumers (dash/module)
    FuelTracking.bestLapValue = BestLapValue
    FuelTracking.personalBestLapValue = PersonalBestLapValue
    FuelTracking.lastLapValue = LastLapValue
    FuelTracking.currentDelta = Delta.currentDelta
    FuelTracking.currentLapIsInvalid = CurrentLapIsInvalid
    FuelTracking.lapCountWhenTimeExpired = lapCountWhenTimeExpired
end
