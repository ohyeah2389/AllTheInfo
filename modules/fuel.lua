-- AllTheInfo Fuel Module
-- Handles fuel consumption tracking and calculations

local fuel = {}

-- Fuel data point constructor
local FuelDataPoint = {}
function FuelDataPoint.new(usage, weight)
    return { usage = usage, weight = weight, lapTime = 0 }
end

-- Calculate fuel weight based on lap time performance
function fuel.calculateFuelWeight(lapTime, fuelUsed, bestLapValue, fuelUsageHistory, fuelImprovementThreshold)
    if not bestLapValue or bestLapValue == 0 or not lapTime or lapTime == 0 then
        return 1  -- Default weight if we don't have enough data
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
            return 0.1  -- Drastically reduce weight for standing/rolling start laps
        end
    end

    local timeRatio = lapTime / bestLapValue

    -- Faster than best lap (rare, but possible)
    if timeRatio < 1 then
        return 2  -- 100% higher weight for faster laps
    end

    -- Normal racing laps (within 102% of best)
    if timeRatio <= 1.02 then
        return 1
    end

    -- More aggressive reduction for slower laps
    -- At 105% of best time, weight should be 0.25 (changed from 110%)
    if timeRatio <= 1.05 then
        return math.max(0,
            1 - ((timeRatio - 1.02) * (0.75 / 0.03))  -- 0.03 is the range (1.05 - 1.02)
        )
    end

    -- Beyond 105% of best time, weight drops even more rapidly
    -- At 110% it should reach 0 (changed from 120%)
    if timeRatio <= 1.10 then
        return math.max(0,
            0.25 * (1 - ((timeRatio - 1.05) / 0.05))  -- 0.05 is the range (1.10 - 1.05)
        )
    end

    return 0  -- Any lap more than 10% slower gets zero weight
end

-- Estimate remaining laps for race
function fuel.estimateRemainingLaps(sim, session, car, settings, tracking, raceSim)
    if sim.raceSessionType == ac.SessionType.Race then
        -- Use actual session data if in a race
        local timeLeft = (sim.sessionTimeLeft / 1000)
        local isTimedRace = (timeLeft ~= 0)
        local predictiveLapValue = (settings.deltaCompareMode == "SESSION" and tracking.bestLapValue or tracking.personalBestLapValue) + ((tracking.currentDelta ~= nil and tracking.currentDelta or 0) * 1000)
        local referenceLapValue = tracking.bestLapValue ~= 0 and tracking.bestLapValue or tracking.lastLapValue ~= 0 and tracking.lastLapValue or tracking.personalBestLapValue
        referenceLapValue = predictiveLapValue > 0 and predictiveLapValue < referenceLapValue and predictiveLapValue or referenceLapValue

        if isTimedRace then
            if timeLeft <= 0 and session.hasAdditionalLap then
                -- If we're still on the same lap as when time expired
                if car.lapCount == tracking.lapCountWhenTimeExpired then
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
    elseif raceSim.enabled then  -- Only use simulation if enabled
        -- Use simulation settings when not in race
        if raceSim.mode == "time" then
            if tracking.lastLapValue <= 0 then return nil end  -- No valid lap time yet
            return raceSim.time / (tracking.lastLapValue / 1000)
        else
            return raceSim.laps
        end
    end
    return nil
end

-- Process fuel usage for completed lap
function fuel.processLapFuelUsage(tracking, constants)
    -- Calculate and store fuel usage for completed lap
    if tracking.lastLapFuelLevel > 0 then
        tracking.lastLapFuelUsed = tracking.lastLapFuelLevel - car.fuel  -- Use global car, not tracking.car

        if not tracking.currentLapIsInvalid and tracking.lastLapFuelUsed > 0 then
            -- Check if this lap is significantly faster than our fuel usage history
            local shouldResetHistory = false
            if #tracking.fuelUsageHistory > 0 then
                -- Calculate average lap time from existing history
                local avgLapTime = 0
                local weightSum = 0
                for _, data in ipairs(tracking.fuelUsageHistory) do
                    -- We need to store lap times with fuel usage data
                    if data.lapTime then
                        avgLapTime = avgLapTime + (data.lapTime * data.weight)
                        weightSum = weightSum + data.weight
                    end
                end

                if weightSum > 0 then
                    avgLapTime = avgLapTime / weightSum
                    -- If new lap is significantly faster (3% or more), reset history
                    if tracking.lastLapValue < (avgLapTime * constants.fuelImprovementThreshold) then
                        shouldResetHistory = true
                        ac.debug("Resetting fuel history due to significant lap time improvement")
                        ac.debug("New lap:", tracking.lastLapValue)
                        ac.debug("Avg previous:", avgLapTime)
                    end
                end
            end

            if shouldResetHistory then
                -- Clear the history and start fresh with this lap
                tracking.fuelUsageHistory = {}
            end

            -- Calculate weight based on both lap time and fuel usage
            local weight = fuel.calculateFuelWeight(tracking.lastLapValue, tracking.lastLapFuelUsed, tracking.bestLapValue, tracking.fuelUsageHistory, constants.fuelImprovementThreshold)

            -- Create new data point with lap time included
            local newDataPoint = FuelDataPoint.new(tracking.lastLapFuelUsed, weight)
            newDataPoint.lapTime = tracking.lastLapValue  -- Add lap time to the data point

            -- Store both fuel usage and its weight
            table.insert(tracking.fuelUsageHistory, 1, newDataPoint)

            -- Keep only the last N laps, but ensure we have at least 2 representative laps
            while #tracking.fuelUsageHistory > constants.maxFuelHistorySize do
                -- Check if removing the last entry would leave us with enough good data
                local goodDataCount = 0
                for i = 1, #tracking.fuelUsageHistory - 1 do  -- Don't count the one we might remove
                    if tracking.fuelUsageHistory[i].weight > 0.5 then  -- Consider laps with weight > 0.5 as "good"
                        goodDataCount = goodDataCount + 1
                    end
                end

                if goodDataCount >= 2 then  -- Only remove if we have at least 2 good laps remaining
                    table.remove(tracking.fuelUsageHistory)
                else
                    break  -- Keep the data until we have enough good laps
                end
            end
        end
    end

    -- Update fuel level for next lap
    tracking.lastLapFuelLevel = car.fuel  -- Use global car, not tracking.car
end

-- Get average fuel consumption per lap (weighted)
function fuel.getAverageFuelPerLap(tracking)
    local avgFuelPerLap = 0
    if #tracking.fuelUsageHistory > 0 then
        local weightedSum = 0
        local totalWeight = 0
        for _, data in ipairs(tracking.fuelUsageHistory) do
            weightedSum = weightedSum + (data.usage * data.weight)
            totalWeight = totalWeight + data.weight
        end
        avgFuelPerLap = totalWeight > 0 and (weightedSum / totalWeight) or 0
    elseif tracking.personalBestFuelUsage then
        -- Use personal best fuel usage if no other data available
        avgFuelPerLap = tracking.personalBestFuelUsage
    end
    return avgFuelPerLap
end

-- Calculate fuel remaining at race end
function fuel.calculateRaceEndFuel(car, avgFuelPerLap, remainingLaps)
    if not remainingLaps or not avgFuelPerLap or avgFuelPerLap <= 0 then
        return nil
    end
    
    -- Calculate fuel needed more precisely
    local fullLaps = math.floor(remainingLaps)
    local partialLap = remainingLaps - fullLaps
    local fuelNeeded = fullLaps * avgFuelPerLap + (partialLap * avgFuelPerLap)
    local fuelRemaining = car.fuel - fuelNeeded
    
    return fuelRemaining
end

-- Get fuel status colors
function fuel.getFuelStatusColors(fuelRemaining, lapsLeft)
    local textColor = rgbm(1, 1, 1, 1)  -- Default white text
    local bgColor = rgbm(0, 0, 0, 0)    -- Default transparent background
    
    if fuelRemaining ~= nil and fuelRemaining < 0 then
        textColor = rgbm(0, 0, 0, 1)      -- Black text
        bgColor = rgbm(1, 0, 0, 0.8)      -- Bright red background
    elseif lapsLeft ~= nil then
        if lapsLeft < 1 then
            textColor = rgbm(0, 0, 0, 1)      -- Black text
            bgColor = rgbm(1, 0, 0, 0.8)       -- Red background
        elseif lapsLeft < 2 then
            textColor = rgbm(0, 0, 0, 1)      -- Black text
            bgColor = rgbm(1, 1, 0, 0.8)       -- Yellow background
        end
    end
    
    return textColor, bgColor
end

return fuel 