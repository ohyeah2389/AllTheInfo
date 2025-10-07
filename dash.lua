local car = ac.getCar(0)
local sim = ac.getSim()

local dash = {}

function dash.draw()
    ui.pushDWriteFont(Font_whiteRabbit)

    ui.beginScale()

    ui.drawRectFilled(vec2(0, 0), vec2(700, 150), rgbm(0, 0, 0, 0.25), 10, ui.CornerFlags.All)

    -- Load all-time best for current track if not already loaded
    if AllTimeBestLap == 0 and TrackRecords[GetTrackIdentifier()] then
        AllTimeBestLap = TrackRecords[GetTrackIdentifier()].time
    end

    -- Gear
    DrawTextWithBackground(
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
    local rpmBarPadding = 2
    local rpmBarWidth = rpmBarEndX - rpmBarStartX

    ui.drawRectFilled(vec2(rpmBarStartX, 11), vec2(rpmBarEndX, 38), rgbm(0.2, 0.2, 0.2, 0.9), 4, ui.CornerFlags.All)
    local progressWidth = MapRange(math.clamp(car.rpm, 0, car.rpmLimiter * Config.rpm.lightsStart), 0, car.rpmLimiter * Config.rpm.lightsStart, 0, rpmBarWidth - rpmBarPadding * 2, true)
    local greyBarProgress = MapRange(car.rpm, car.rpmLimiter * Config.rpm.fadeStart, car.rpmLimiter * Config.rpm.lightsStart, 0.5, 0.1, true)
    ui.drawRectFilled(vec2(rpmBarStartX + rpmBarPadding, 13), vec2(rpmBarStartX + rpmBarPadding + progressWidth, 36), rgbm(0.8, 0.8, 0.8, greyBarProgress), 3, ui.CornerFlags.All)

    -- RPM light sections
    if Config.rpm.shiftLightsEnabled then
        local numSections = 6 -- Can be configured
        local sectionStartX = rpmBarStartX + 4
        local sectionEndX = rpmBarEndX - 4
        local totalWidth = sectionEndX - sectionStartX -- Total available width
        local sectionWidth = totalWidth / numSections  -- Each section exactly same size
        local rpmStart = car.rpmLimiter * Config.rpm.lightsStart
        local rpmRange = (car.rpmLimiter * Config.rpm.shiftPoint) - rpmStart
        local isOverShiftPoint = car.rpm >= (car.rpmLimiter * Config.rpm.shiftPoint)
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
        local boostPercent = math.clamp(car.turboBoost / MaxSeenBoost, 0.0, 1.0) -- Normalize to max seen boost
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
            vec2(MapRange(boostPercent, 0, 1, boostBarStartX + 2, boostBarStartX - 2 + boostWidth, true), boostBarY2 - 2),
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
    local delta, deltaChangeRate = Delta.currentDelta, Delta.currentDeltaChangeRate
    local timeText
    local bgColor = nil
    if delta == nil then
        timeText = "-:--.---"
    else
        local comparisonValue = Config.delta.compareMode == "SESSION" and BestLapValue or PersonalBestLapValue
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

        if CurrentLapIsInvalid then
            bgColor = rgbm(0.8, 0, 0, 0.5)     -- Brighter red background for invalid lap
        elseif predictiveLapValue < PersonalBestLapValue or (PersonalBestLapValue == 0 and predictiveLapValue < BestLapValue) then
            bgColor = rgbm(0.3, 0.3, 0.8, 0.5) -- Brighter blue background for beating personal best
        elseif predictiveLapValue < BestLapValue then
            bgColor = rgbm(0.3, 0.8, 0.3, 0.5) -- Brighter green background for beating session best
        end
    end
    DrawTextWithBackground(timeText, 24, 35, 52, 115, 16, bgColor)

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
    local lastLapBg = PreviousLapValidityValue and rgbm(0.8, 0, 0, 0.5) or     -- Brighter red for invalid lap
        LastLapWasPersonalBest and rgbm(0.3, 0.3, 0.8, 0.5) or                 -- Brighter blue for personal best
        LastLapWasSessionBest and rgbm(0.3, 0.8, 0.3, 0.5) or nil              -- Brighter green for session best

    if math.floor(LastLapValue / 60000) >= 100 then
        timeText = string.format("%01d:%02d.%0d", math.floor(LastLapValue / 60000), math.floor(LastLapValue / 1000) % 60,
            LastLapValue % 1000)
    elseif math.floor(LastLapValue / 60000) >= 10 then
        timeText = string.format("%01d:%02d.%02d", math.floor(LastLapValue / 60000), math.floor(LastLapValue / 1000) % 60,
            math.floor(LastLapValue % 1000 / 10))
    else
        timeText = string.format("%01d:%02d.%03d", math.floor(LastLapValue / 60000), math.floor(LastLapValue / 1000) % 60,
            LastLapValue % 1000)
    end
    DrawTextWithBackground(
        LastLapValue > 0
        and timeText
        or "-:--.---",
        24, 35, 52 + 23, 115, 16, lastLapBg
    )

    -- Separator line between lap times
    ui.drawLine(vec2(5, 95), vec2(148, 95), rgbm(1, 1, 1, 0.2), 1)

    -- Session best laptime
    DrawTextWithBackground(
        "BST",
        14,
        9,
        52 + 49,
        27,
        9,
        Config.delta.compareMode == "SESSION" and rgbm(0, 0, 0, 0.3) or nil,
        rgbm(1, 1, 1, 1)
    )
    local sessionBestBg = nil
    local sessionBestColor = rgbm(1, 1, 1, 1) -- Default white
    if LastLapWasSessionBest then
        local alpha = FadeBackground(SessionBestWasSetTime)
        if alpha > 0 then
            sessionBestBg = LastLapWasPersonalBest and
                rgbm(0.3, 0.3, 0.8, alpha) or -- Blue if both
                rgbm(0.3, 0.8, 0.3, alpha) -- Green if just session best

            -- Flash the text instead of hiding background
            if not GetFlashState(SessionBestWasSetTime) then
                sessionBestColor = rgbm(1, 1, 1, 0.5) -- Half-transparent white during flash off
            end
        end
    end
    if math.floor(BestLapValue / 60000) >= 100 then
        timeText = string.format("%01d:%02d.%0d", math.floor(BestLapValue / 60000), math.floor(BestLapValue / 1000) % 60,
            BestLapValue % 1000)
    elseif math.floor(BestLapValue / 60000) >= 10 then
        timeText = string.format("%01d:%02d.%02d", math.floor(BestLapValue / 60000), math.floor(BestLapValue / 1000) % 60,
            math.floor(BestLapValue % 1000 / 10))
    else
        timeText = string.format("%01d:%02d.%03d", math.floor(BestLapValue / 60000), math.floor(BestLapValue / 1000) % 60,
            BestLapValue % 1000)
    end
    DrawTextWithBackground(
        BestLapValue > 0
        and timeText
        or "-:--.---",
        24, 35, 52 + 49, 115, 16, sessionBestBg,
        sessionBestColor
    )

    -- All-time best
    DrawTextWithBackground(
        "PB",
        14,
        17,
        52 + 72,
        19,
        9,
        Config.delta.compareMode == "PERSONAL" and rgbm(0, 0, 0, 0.3) or nil,
        rgbm(1, 1, 1, 1)
    )
    local pbBg = nil
    local pbColor = rgbm(1, 1, 1, 1) -- Default white
    if LastLapWasPersonalBest then
        local alpha = FadeBackground(PersonalBestWasSetTime)
        if alpha > 0 then
            pbBg = rgbm(0.3, 0.3, 0.8, alpha) -- Blue with fade

            -- Flash the text instead of hiding background
            if not GetFlashState(PersonalBestWasSetTime) then
                pbColor = rgbm(1, 1, 1, 0.5) -- Half-transparent white during flash off
            end
        end
    end
    if math.floor(PersonalBestLapValue / 60000) >= 100 then
        timeText = string.format("%01d:%02d.%0d", math.floor(PersonalBestLapValue / 60000),
            math.floor(PersonalBestLapValue / 1000) % 60, PersonalBestLapValue % 1000)
    elseif math.floor(PersonalBestLapValue / 60000) >= 10 then
        timeText = string.format("%01d:%02d.%02d", math.floor(PersonalBestLapValue / 60000),
            math.floor(PersonalBestLapValue / 1000) % 60, math.floor(PersonalBestLapValue % 1000 / 10))
    else
        timeText = string.format("%01d:%02d.%03d", math.floor(PersonalBestLapValue / 60000),
            math.floor(PersonalBestLapValue / 1000) % 60, PersonalBestLapValue % 1000)
    end
    DrawTextWithBackground(
        PersonalBestLapValue > 0
        and timeText
        or "-:--.---",
        24, 35, 52 + 72, 115, 16, pbBg, -- Changed from 69 to 71
        pbColor
    )

    -- Session time and laps remaining display
    local timeLeftSec = sim.sessionTimeLeft / 1000
    local isTimedRace = timeLeftSec > 0
    local timeLeftFade = timeLeftSec <= 0 and 1 or math.smoothstep(MapRange(math.abs(timeLeftSec), 5.5, 10, 0, 1, true) ^ 0.5)

    -- Time remaining display
    local timeRemainingText
    if isTimedRace then
        local hours = math.floor(timeLeftSec / 3600)
        local minutes = math.floor((timeLeftSec % 3600) / 60)
        local seconds = math.floor(timeLeftSec % 60)

        if hours > 0 then
            timeRemainingText = string.format("%d:%02d", hours, minutes)
        else
            timeRemainingText = string.format("%02d:%02d", minutes, seconds)
        end
    else
        timeRemainingText = "--:--"
    end

    -- Draw time remaining
    DrawTextWithBackground(
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
    DrawTextWithBackground(
        timeRemainingText,
        24,
        200, -- Position after "TIME" label
        52,  -- Same Y as label
        100, -- width
        16,  -- height
        nil, -- No background
        timeLeftSec > 0 and rgbm(1, 1, 1, 1 * timeLeftFade) or rgbm(1, 1, 1, 0.5),
        ui.Alignment.Start
    )

    -- Laps remaining display
    local remainingLaps = EstimateRemainingLaps()
    local lapsRemainingText = remainingLaps and string.format(remainingLaps >= 100 and "%.0f" or remainingLaps >= 10 and "%.1f" or "%.2f", remainingLaps) or "--.-"

    -- Draw laps remaining
    DrawTextWithBackground(
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
    DrawTextWithBackground(
        lapsRemainingText,
        24,
        200, -- Same X as time value
        75,  -- Same Y as "LAPS" label
        100, -- width
        16,  -- height
        nil, -- No background
        timeLeftSec > 0 and rgbm(1, 1, 1, 0.5) or rgbm(1, 1, 1, 1),
        ui.Alignment.Start
    )

    -- Position display
    local position = ac.getCarLeaderboardPosition(0)
    local totalCars = ac.getSim().carsCount
    local positionText = string.format("%02d/%02d", position, totalCars)
    local posColor = rgbm(0, 0, 0, 0)
    if (totalCars > 4) and (position < 4) then
        if position == 1 then
            posColor = rgbm(1, 0.85, 0, 0.65) -- Gold
        elseif position == 2 then
            posColor = rgbm(0.75, 0.75, 0.75, 0.65) -- Silver
        else
            posColor = rgbm(0.8, 0.5, 0.2, 0.65) -- Bronze
        end
    end

    -- Draw position
    DrawTextWithBackground(
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
    DrawTextWithBackground(
        positionText,
        24,
        200, -- Same X as time and laps values
        98,  -- Same Y as "POS" label
        72, -- width
        16,  -- height
        posColor, -- No background
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
    local tireBlockWidth = 30 -- Width of each tire block
    local tireStripeWidth = 10 -- Width of each stripe within a block
    local tireBlockHeight = 40 -- Total height of tire block
    local tireCoreSectionHeight = 15 -- Height of the core temperature section
    local tireBlockSpacing = 10 -- Space between left/right blocks
    local tireVerticalSpacing = 10 -- Space between front/rear tires
    local tireBlockY = 52 -- Y position to match with other elements

    -- Calculate center position and block positions
    local centerX = 350 -- Approximate center position
    local leftBlocksX = centerX - tireBlockWidth - (tireBlockSpacing / 2)
    local rightBlocksX = centerX + (tireBlockSpacing / 2)

    local tireCoreTemps = { car.wheels[ac.Wheel.FrontLeft].tyreCoreTemperature, car.wheels[ac.Wheel.FrontRight].tyreCoreTemperature, car.wheels[ac.Wheel.RearLeft].tyreCoreTemperature, car.wheels[ac.Wheel.RearRight].tyreCoreTemperature }
    local tireInnerTemps = { car.wheels[ac.Wheel.FrontLeft].tyreInsideTemperature, car.wheels[ac.Wheel.FrontRight].tyreInsideTemperature, car.wheels[ac.Wheel.RearLeft].tyreInsideTemperature, car.wheels[ac.Wheel.RearRight].tyreInsideTemperature }
    local tireMiddleTemps = { car.wheels[ac.Wheel.FrontLeft].tyreMiddleTemperature, car.wheels[ac.Wheel.FrontRight].tyreMiddleTemperature, car.wheels[ac.Wheel.RearLeft].tyreMiddleTemperature, car.wheels[ac.Wheel.RearRight].tyreMiddleTemperature }
    local tireOuterTemps = { car.wheels[ac.Wheel.FrontLeft].tyreOutsideTemperature, car.wheels[ac.Wheel.FrontRight].tyreOutsideTemperature, car.wheels[ac.Wheel.RearLeft].tyreOutsideTemperature, car.wheels[ac.Wheel.RearRight].tyreOutsideTemperature }
    local tireOptimumTemps = {
        car.wheels[ac.Wheel.FrontLeft].tyreOptimumTemperature or 80,
        car.wheels[ac.Wheel.FrontRight].tyreOptimumTemperature or 80,
        car.wheels[ac.Wheel.RearLeft].tyreOptimumTemperature or 80,
        car.wheels[ac.Wheel.RearRight].tyreOptimumTemperature or 80
    }
    local tirePressures = { car.wheels[ac.Wheel.FrontLeft].tyrePressure, car.wheels[ac.Wheel.FrontRight].tyrePressure, car.wheels[ac.Wheel.RearLeft].tyrePressure, car.wheels[ac.Wheel.RearRight].tyrePressure }
    local tireFL_grip = GetTireGripFromWear(0)
    local tireFR_grip = GetTireGripFromWear(1)
    local tireRL_grip = GetTireGripFromWear(2)
    local tireRR_grip = GetTireGripFromWear(3)

    -- Load tire data from car's data files
    local tireData = ac.INIConfig.carData(0, "tyres.ini")
    local tireOptimumPressures = {
        tonumber(tireData:get(car.compoundIndex == 0 and "FRONT" or "FRONT_" .. (car.compoundIndex + 1), "PRESSURE_IDEAL", 26)),
        tonumber(tireData:get(car.compoundIndex == 0 and "FRONT" or "FRONT_" .. (car.compoundIndex + 1), "PRESSURE_IDEAL", 26)),
        tonumber(tireData:get(car.compoundIndex == 0 and "REAR" or "REAR_" .. (car.compoundIndex + 1), "PRESSURE_IDEAL", 26)),
        tonumber(tireData:get(car.compoundIndex == 0 and "REAR" or "REAR_" .. (car.compoundIndex + 1), "PRESSURE_IDEAL", 26))
    }
    local tireExplosionTemp = tonumber(tireData:get("EXPLOSION", "TEMPERATURE", (tireOptimumTemps[1] * 3)))

    -- Update explosion threshold based on actual explosion temp
    -- We'll set it to show black when within 20°C of explosion temp
    TireTempThresholds.explosion = (tireExplosionTemp - 20) / tireOptimumTemps[1]

    -- Draw front left tire block
    -- Core temperature section
    ui.drawRectFilled(
        vec2(leftBlocksX, tireBlockY),
        vec2(leftBlocksX + tireBlockWidth - 1, tireBlockY + tireCoreSectionHeight),
        GetTempColor(tireCoreTemps[1], tireOptimumTemps[1]),
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
            GetTempColor(temp, tireOptimumTemps[1]),
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
        GetTempColor(tireCoreTemps[2], tireOptimumTemps[2]),
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
            GetTempColor(temp, tireOptimumTemps[2]),
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
        GetTempColor(tireCoreTemps[3], tireOptimumTemps[3]),
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
            GetTempColor(temp, tireOptimumTemps[3]),
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
        GetTempColor(tireCoreTemps[4], tireOptimumTemps[4]),
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
            GetTempColor(temp, tireOptimumTemps[4]),
            (stripeIndex == 0 or stripeIndex == 2) and 3 or 0,
            (stripeIndex == 0 and ui.CornerFlags.BottomLeft) or
            (stripeIndex == 2 and ui.CornerFlags.BottomRight) or 0
        )
    end

    -- Draw front left tire block
    -- Pressure delta and wear display
    local pressureDelta = tirePressures[1] - tireOptimumPressures[1]
    DrawTextWithBackground(
        string.format((pressureDelta > 0 and "+" or "") .. (math.abs(pressureDelta) < 10 and "%.1f" or "%.0f"),
            pressureDelta),
        13,
        leftBlocksX - 35,
        tireBlockY + 5,
        34,              -- width increased by 4
        10,              -- height decreased by 4
        GetPressureColor(tirePressures[1], tireOptimumPressures[1]),
        rgbm(1, 1, 1, 1) -- White text
    )
    DrawTextWithBackground(
        string.format(tireFL_grip < 0.999 and "%.1f%%" or "%.0f%%", tireFL_grip * 100),
        11,
        leftBlocksX - 5,  -- Adjusted position
        tireBlockY + tireBlockHeight - 15,
        31,               -- Width for background
        7,                -- Height for background
        GetTireWearColor(1 - tireFL_grip),
        rgbm(1, 1, 1, 1), -- White text
        ui.Alignment.End  -- Right alignment for left tires
    )

    -- Draw front right tire block
    pressureDelta = tirePressures[2] - tireOptimumPressures[2]
    DrawTextWithBackground(
        string.format((pressureDelta > 0 and "+" or "") .. (math.abs(pressureDelta) < 10 and "%.1f" or "%.0f"),
            pressureDelta),
        13,
        rightBlocksX + tireBlockWidth + 5,
        tireBlockY + 5,
        34, -- width increased by 4
        10, -- height decreased by 4
        GetPressureColor(tirePressures[2], tireOptimumPressures[2]),
        rgbm(1, 1, 1, 1)
    )
    DrawTextWithBackground(
        string.format(tireFR_grip < 0.999 and "%.1f%%" or "%.0f%%", tireFR_grip * 100),
        11,
        rightBlocksX + tireBlockWidth + 5,
        tireBlockY + tireBlockHeight - 15,
        37,                                -- Width for background
        7,                                 -- Height for background
        GetTireWearColor(1 - tireFR_grip), -- Convert grip to wear
        rgbm(1, 1, 1, 1),                  -- White text
        ui.Alignment.Start                 -- Left alignment for right tires
    )

    -- Draw rear left tire block
    pressureDelta = tirePressures[3] - tireOptimumPressures[3]
    DrawTextWithBackground(
        string.format((pressureDelta > 0 and "+" or "") .. (math.abs(pressureDelta) < 10 and "%.1f" or "%.0f"),
            pressureDelta),
        13,
        leftBlocksX - 35,
        tireBlockY + tireBlockHeight + tireVerticalSpacing + 5,
        34, -- width increased by 4
        10, -- height decreased by 4
        GetPressureColor(tirePressures[3], tireOptimumPressures[3]),
        rgbm(1, 1, 1, 1)
    )
    DrawTextWithBackground(
        string.format(tireRL_grip < 0.999 and "%.1f%%" or "%.0f%%", tireRL_grip * 100),
        11,
        leftBlocksX - 5,                   -- Adjusted position
        tireBlockY + tireBlockHeight + tireVerticalSpacing + tireBlockHeight - 15,
        31,                                -- Width for background
        7,                                 -- Height for background
        GetTireWearColor(1 - tireRL_grip), -- Convert grip to wear
        rgbm(1, 1, 1, 1),                  -- White text
        ui.Alignment.End                   -- Right alignment for left tires
    )

    -- Draw rear right tire block
    pressureDelta = tirePressures[4] - tireOptimumPressures[4]
    DrawTextWithBackground(
        string.format((pressureDelta > 0 and "+" or "") .. (math.abs(pressureDelta) < 10 and "%.1f" or "%.0f"),
            pressureDelta),
        13,
        rightBlocksX + tireBlockWidth + 5,
        tireBlockY + tireBlockHeight + tireVerticalSpacing + 5,
        34, -- width increased by 4
        10, -- height decreased by 4
        GetPressureColor(tirePressures[4], tireOptimumPressures[4]),
        rgbm(1, 1, 1, 1)
    )
    DrawTextWithBackground(
        string.format(tireRR_grip < 0.999 and "%.1f%%" or "%.0f%%", tireRR_grip * 100),
        11,
        rightBlocksX + tireBlockWidth + 5,
        tireBlockY + tireBlockHeight + tireVerticalSpacing + tireBlockHeight - 15,
        37,                                -- Width for background
        7,                                 -- Height for background
        GetTireWearColor(1 - tireRR_grip), -- Convert grip to wear
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
    DrawTextWithBackground(
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
    local lastLapFuelText = LastLapFuelUsed > 0
        and string.format("LST %6.2f L", LastLapFuelUsed):gsub("^%s+", "")
        or "LST  --.-- L"
    DrawTextWithBackground(
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
    if #FuelUsageHistory > 0 then
        local weightedSum = 0
        local totalWeight = 0
        for _, data in ipairs(FuelUsageHistory) do
            weightedSum = weightedSum + (data.usage * data.weight)
            totalWeight = totalWeight + data.weight
        end
        avgFuelPerLap = totalWeight > 0 and (weightedSum / totalWeight) or 0
    elseif PersonalBestFuelUsage then
        -- Use personal best fuel usage if no other data available
        avgFuelPerLap = PersonalBestFuelUsage
    end

    local fuelPerLapText = (avgFuelPerLap > 0)
        and string.format("AVG %6.2f L", avgFuelPerLap):gsub("^%s+", "")
        or "AVG  --.-- L"
    DrawTextWithBackground(
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
    DrawTextWithBackground(
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
    local remainingLaps = EstimateRemainingLaps()

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

    DrawTextWithBackground(
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
        local drsColor = DRSColors.inactive
        if car.drsActive then
            drsColor = DRSColors.active
        elseif car.drsAvailable then
            drsColor = DRSColors.available
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
    DrawTextWithBackground(
        "ABS",
        14, -- Small text for label
        assistsX,
        assistsY,
        29,                                          -- Width for label
        9,                                           -- Height to match other readouts
        car.absInAction and AssistColors.abs or nil, -- No background
        rgbm(1, 1, 1, 1)
    )
    DrawTextWithBackground(
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
    DrawTextWithBackground(
        "TC",
        14,
        assistsX,
        assistsY + 22, -- Stack below ABS
        21,
        9,
        car.tractionControlInAction and AssistColors.tc or nil,
        rgbm(1, 1, 1, 1)
    )
    DrawTextWithBackground(
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
    DrawTextWithBackground(
        string.format("%s", GetWindDirectionText(sim.windDirectionDeg)),
        22,
        assistsX + 100, -- Position to right of TC/ABS
        assistsY,
        35,
        22,
        nil,
        rgbm(1, 1, 1, 1),
        ui.Alignment.Center
    )
    DrawTextWithBackground(
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

    DrawTextWithBackground(
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

    DrawTextWithBackground(
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

    DrawTextWithBackground(
        string.format(sim.roadGrip == 1.0 and "100%%" or "%.1f%%", sim.roadGrip * 100),
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
    DrawTextWithBackground(
        "BB",
        14,
        assistsX,
        assistsY + 44, -- Stack below TC
        40,
        22,
        nil,
        rgbm(1, 1, 1, 1)
    )
    DrawTextWithBackground(
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
        Config.delta.compareMode = Config.delta.compareMode == "SESSION" and "PERSONAL" or "SESSION"
    end

    -- Invisible button to toggle the presence of shift lights
    local shiftLightButtonTL = vec2(145, 16)
    local shiftLightButtonBR = vec2(208, 33)
    if ui.rectHovered(vec2(0, 0), vec2(700, 150), false) then
        ui.drawRectFilled(shiftLightButtonTL, shiftLightButtonBR, rgbm(0, 0, 0, 0.3), 2, ui.CornerFlags.All)
        ui.dwriteDrawText("LGT " .. (Config.rpm.shiftLightsEnabled and "ON" or "OFF"), 14,
            shiftLightButtonTL + vec2(3, 4), rgbm(1, 1, 1, 1))
    end
    ui.setCursor(shiftLightButtonTL)
    if ui.invisibleButton("Shift Lights", shiftLightButtonBR - shiftLightButtonTL) then
        Config.rpm.shiftLightsEnabled = not Config.rpm.shiftLightsEnabled
    end

    ui.endPivotScale(Config.appScaleFactor, vec2(0, 0))

    ui.popDWriteFont()
end

return dash