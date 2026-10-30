local Fuel = require("modules.fuel")

local COL_WHITE = rgbm.colors.white
local COL_BLACK = rgbm.colors.black
local COL_TRANSPARENT = rgbm.colors.transparent
local COL_FRAME = rgbm(0, 0, 0, 0.3)
local COL_BAR_BG = rgbm(0.2, 0.2, 0.2, 0.9)
local COL_BOOST_BG = rgbm(0.15, 0.15, 0.15, 0.9)
local COL_LINE = rgbm(1, 1, 1, 0.2)
local COL_INVALID = rgbm(0.8, 0, 0, 0.5)
local COL_PB = rgbm(0.3, 0.3, 0.8, 0.5)
local COL_SB = rgbm(0.3, 0.8, 0.3, 0.5)
local COL_MODE = rgbm(0, 0, 0, 0.3)
local COL_WHITE_DIM = rgbm(1, 1, 1, 0.5)
local COL_GOLD = rgbm(1, 0.85, 0, 0.65)
local COL_SILVER = rgbm(0.75, 0.75, 0.75, 0.65)
local COL_BRONZE = rgbm(0.8, 0.5, 0.2, 0.65)
local COL_HOVER_SWAP = rgbm(0, 0, 0, 0.1)
local COL_HOVER_LGT = rgbm(0, 0, 0, 0.3)
local COL_SHIFT_LIMITER_YELLOW = rgbm(1, 1, 0, 1)
local COL_SHIFT_LIMITER_RED = rgbm(1, 0, 0, 1)
local COL_SHIFT_BLUE = rgbm(0, 0.4, 1, 1)
local COL_SHIFT_GREEN = rgbm(0.2, 0.8, 0.2, 1)
local COL_SHIFT_YELLOW = rgbm(0.8, 0.8, 0.2, 1)
local COL_SHIFT_RED = rgbm(0.8, 0.2, 0.2, 1)

local origin = vec2(0, 0)
local dashBR = vec2(700, 150)
local rpmTextP1, rpmTextP2 = vec2(32, 9), vec2(132, 43)
local rpmBgP1, rpmBgP2 = vec2(140, 11), vec2(560, 38)
local rpmFillP1, rpmFillP2 = vec2(142, 13), vec2(142, 36)
local speedTextP1, speedTextP2 = vec2(590, 9), vec2(690, 43)
local boostBgP1, boostBgP2 = vec2(140, 3), vec2(560, 9)
local boostFillP1, boostFillP2 = vec2(142, 5), vec2(142, 7)
local drsP1, drsP2 = vec2(570, 11), vec2(610, 38)
local iconP1, iconP2 = vec2(566, 1), vec2(607, 42)
local lineTopP1, lineTopP2 = vec2(5, 45), vec2(695, 45)
local estP1, estP2 = vec2(9, 52), vec2(150, 68)
local lstP1, lstP2 = vec2(9, 75), vec2(150, 91)
local lineLstP1, lineLstP2 = vec2(5, 95), vec2(148, 95)
local sepTimeP1, sepTimeP2 = vec2(152, 49), vec2(152, 147)
local sepTireP1, sepTireP2 = vec2(273, 49), vec2(273, 147)
local sepAssistP1, sepAssistP2 = vec2(427, 49), vec2(427, 147)
local sepEnvP1, sepEnvP2 = vec2(530, 49), vec2(530, 147)
local sepFuelP1, sepFuelP2 = vec2(575, 49), vec2(575, 147)
local swapHoverP1, swapHoverP2 = vec2(4, 98), vec2(150, 146)
local swapCursor, swapSize = vec2(4, 98), vec2(146, 48)
local lgtTL, lgtBR = vec2(145, 16), vec2(208, 33)
local lgtText, lgtSize = vec2(148, 20), vec2(63, 17)

local colRpmFill = rgbm(0.8, 0.8, 0.8, 1)
local colBoost = rgbm()
local colTimeLeft = rgbm(1, 1, 1, 1)
local colSessionFade = rgbm()
local colPbFade = rgbm()

local boostStops = {
    { percent = 0.0, color = rgbm(0.5, 0.5, 0.5, 1) },
    { percent = 0.3, color = rgbm(1.0, 0.5, 0.0, 1) },
    { percent = 0.4, color = rgbm(1.0, 1.0, 0.0, 1) },
    { percent = 0.8, color = rgbm(0.0, 1.0, 0.5, 1) }
}

local shiftLights = {}
do
    local numSections = 6
    local sectionStartX, sectionEndX = 144, 556
    local sectionWidth = (sectionEndX - sectionStartX) / numSections
    for i = 0, numSections - 1 do
        local x1 = sectionStartX + (sectionWidth * i)
        local x2 = sectionStartX + (sectionWidth * (i + 1))
        if i < numSections - 1 then x2 = x2 - 4 end
        shiftLights[i + 1] = { vec2(x1, 15), vec2(x2, 34) }
    end
end

local tireCoreRects, tireStripeRects = {}, {}
do
    local w, stripe, h, coreH = 30, 10, 40, 15
    local gap, vGap, y, cx = 10, 10, 52, 350
    local leftX, rightX = cx - w - gap / 2, cx + gap / 2
    local flY, rlY = y, y + h + vGap
    local xs = { leftX, rightX, leftX, rightX }
    local ys = { flY, flY, rlY, rlY }
    for wheel = 1, 4 do
        local x, ty = xs[wheel], ys[wheel]
        tireCoreRects[wheel] = { vec2(x, ty), vec2(x + w - 1, ty + coreH) }
        tireStripeRects[wheel] = {}
        for i = 0, 2 do
            tireStripeRects[wheel][i + 1] = {
                vec2(x + i * stripe, ty + coreH + 1),
                vec2(x + i * stripe + stripe - 1, ty + h)
            }
        end
    end
end

local dash = {}

function dash.draw()
    ui.pushDWriteFont(Font_whiteRabbit)
    ui.beginScale()

    ui.drawRectFilled(origin, dashBR, COL_FRAME, 10, ui.CornerFlags.All)
    ui.drawRect(origin, dashBR, COL_FRAME, 10, ui.CornerFlags.All)

    if AllTimeBestLap == 0 and TrackRecords[GetTrackIdentifier()] then
        AllTimeBestLap = TrackRecords[GetTrackIdentifier()].time
    end

    -- MARK: Top

    DrawTextWithBackground(
        Car.gear == -1 and "R" or (Car.gear == 0 and "N" or tostring(Car.gear)),
        40, 13, 9, 27, 29, COL_BLACK, COL_WHITE, ui.Alignment.Start
    )

    ui.dwriteDrawTextClipped(string.format("%d", Car.rpm), 32, rpmTextP1, rpmTextP2, ui.Alignment.End, ui.Alignment.Center, false, COL_WHITE)

    local rpmBarStartX = 140
    local rpmBarPadding = 2
    local rpmBarWidth = 420

    ui.drawRectFilled(rpmBgP1, rpmBgP2, COL_BAR_BG, 4, ui.CornerFlags.All)
    local progressWidth = MapRange(math.clamp(Car.rpm, 0, Car.rpmLimiter * Config.rpm.lightsStart), 0, Car.rpmLimiter * Config.rpm.lightsStart, 0, rpmBarWidth - rpmBarPadding * 2, true)
    colRpmFill.mult = MapRange(Car.rpm, Car.rpmLimiter * Config.rpm.fadeStart, Car.rpmLimiter * Config.rpm.lightsStart, 0.5, 0.1, true)
    rpmFillP2.x = rpmBarStartX + rpmBarPadding + progressWidth
    ui.drawRectFilled(rpmFillP1, rpmFillP2, colRpmFill, 3, ui.CornerFlags.All)

    if Config.rpm.shiftLightsEnabled then
        local numSections = 6
        local rpmStart = Car.rpmLimiter * Config.rpm.lightsStart
        local rpmRange = (Car.rpmLimiter * Config.rpm.shiftPoint) - rpmStart
        local isOverShiftPoint = Car.rpm >= (Car.rpmLimiter * Config.rpm.shiftPoint)
        local isOverRedline = Car.rpm >= (Car.rpmLimiter - 50)
        local flashState = isOverRedline and math.floor(Sim.time * 0.02) % 2 == 0
        for i = 0, numSections - 1 do
            local sectionRpmThreshold = rpmStart + (rpmRange * (i / numSections))
            if Car.rpm >= sectionRpmThreshold then
                local color
                if isOverRedline then
                    color = ((i % 2 == 0) == flashState) and COL_SHIFT_LIMITER_YELLOW or COL_SHIFT_LIMITER_RED
                elseif isOverShiftPoint and (Car.gear ~= Car.gearCount) then
                    color = COL_SHIFT_BLUE
                elseif i < (numSections / 3) then
                    color = COL_SHIFT_GREEN
                elseif i < ((numSections / 3) * 2) then
                    color = COL_SHIFT_YELLOW
                else
                    color = COL_SHIFT_RED
                end
                local s = shiftLights[i + 1]
                ui.drawRectFilled(s[1], s[2], color, 2, ui.CornerFlags.All)
            end
        end
    end

    ui.dwriteDrawTextClipped(string.format("%d", Car.speedKmh), 32, speedTextP1, speedTextP2, ui.Alignment.End, ui.Alignment.Center, false, COL_WHITE)

    if Car.turboCount > 0 then
        local boostBarStartX = 140
        local boostBarWidth = 420

        ui.drawRectFilled(boostBgP1, boostBgP2, COL_BOOST_BG, 2)
        local boostPercent = math.clamp(Car.turboBoost / MaxSeenBoost, 0.0, 1.0)
        local boostWidth = boostBarWidth * boostPercent

        local stop1, stop2
        for i = 1, #boostStops do
            if boostPercent <= boostStops[i].percent or i == #boostStops then
                stop2 = boostStops[i]
                stop1 = boostStops[i - 1] or stop2
                break
            end
        end

        local t = 0
        if stop1.percent ~= stop2.percent then
            t = (boostPercent - stop1.percent) / (stop2.percent - stop1.percent)
        end
        colBoost:setLerp(stop1.color, stop2.color, t)

        boostFillP2.x = MapRange(boostPercent, 0, 1, boostBarStartX + 2, boostBarStartX - 2 + boostWidth, true)
        ui.drawRectFilled(boostFillP1, boostFillP2, colBoost, 2)
    end

    if Car.drsPresent then
        local drsColor = DRSColors.inactive
        if Car.drsActive then
            drsColor = DRSColors.active
        elseif Car.drsAvailable then
            drsColor = DRSColors.available
        end
        ui.drawRectFilled(drsP1, drsP2, drsColor, 4, ui.CornerFlags.All)
        ui.dwriteDrawTextClipped("DRS", 16, drsP1, drsP2, ui.Alignment.Center, ui.Alignment.Center, false, COL_BLACK)
    else
        ui.drawImage("icon.png", iconP1, iconP2)
    end

    ui.drawLine(lineTopP1, lineTopP2, COL_LINE, 1)

    -- MARK: Timing

    ui.dwriteDrawTextClipped("EST", 14, estP1, estP2, ui.Alignment.Start, ui.Alignment.Start, false, COL_WHITE)
    local delta = Delta.currentDelta
    local timeText
    local bgColor = nil
    if delta == nil then
        timeText = "-:--.---"
    else
        local comparisonValue = Config.delta.compareMode == "SESSION" and BestLapValue or PersonalBestLapValue
        if not comparisonValue or comparisonValue <= 0 then
            timeText = "-:--.---"
        else
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
                bgColor = COL_INVALID
            elseif predictiveLapValue < PersonalBestLapValue or (PersonalBestLapValue == 0 and predictiveLapValue < BestLapValue) then
                bgColor = COL_PB
            elseif predictiveLapValue < BestLapValue then
                bgColor = COL_SB
            end
        end
    end
    DrawTextWithBackground(timeText, 24, 35, 52, 115, 16, bgColor)

    ui.dwriteDrawTextClipped("LST", 14, lstP1, lstP2, ui.Alignment.Start, ui.Alignment.Start, false, COL_WHITE)
    local lastLapBg = PreviousLapValidityValue and COL_INVALID or
        LastLapWasPersonalBest and COL_PB or
        LastLapWasSessionBest and COL_SB or nil

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
        LastLapValue > 0 and timeText or "-:--.---",
        24, 35, 52 + 23, 115, 16, lastLapBg
    )

    ui.drawLine(lineLstP1, lineLstP2, COL_LINE, 1)

    DrawTextWithBackground(
        "BST", 14, 9, 52 + 49, 27, 9,
        Config.delta.compareMode == "SESSION" and COL_MODE or nil, COL_WHITE
    )
    local sessionBestBg = nil
    local sessionBestColor = COL_WHITE
    if LastLapWasSessionBest then
        local alpha = FadeBackground(SessionBestWasSetTime)
        if alpha > 0 then
            colSessionFade:set(LastLapWasPersonalBest and COL_PB or COL_SB)
            colSessionFade.mult = alpha
            sessionBestBg = colSessionFade
            if not GetFlashState(SessionBestWasSetTime) then
                sessionBestColor = COL_WHITE_DIM
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
        BestLapValue > 0 and timeText or "-:--.---",
        24, 35, 52 + 49, 115, 16, sessionBestBg, sessionBestColor
    )

    DrawTextWithBackground(
        "PB", 14, 17, 52 + 72, 19, 9,
        Config.delta.compareMode == "PERSONAL" and COL_MODE or nil, COL_WHITE
    )
    local pbBg = nil
    local pbColor = COL_WHITE
    if LastLapWasPersonalBest then
        local alpha = FadeBackground(PersonalBestWasSetTime)
        if alpha > 0 then
            colPbFade:set(COL_PB)
            colPbFade.mult = alpha
            pbBg = colPbFade
            if not GetFlashState(PersonalBestWasSetTime) then
                pbColor = COL_WHITE_DIM
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
        PersonalBestLapValue > 0 and timeText or "-:--.---",
        24, 35, 52 + 72, 115, 16, pbBg, pbColor
    )

    ui.drawLine(sepTimeP1, sepTimeP2, COL_LINE, 1)

    -- MARK: Time/Laps
    local sessionTotalTimeSec = ac.getSession(CurrentSessionIndex).durationMinutes * 60
    local timeLeftSec = Sim.sessionTimeLeft / 1000
    local isTimedRace = timeLeftSec > 0
    local timeLeftFade = timeLeftSec <= 0 and 1 or math.smoothstep(MapRange(math.abs(timeLeftSec - sessionTotalTimeSec), 5.5, 10, 0, 1, true) ^ 0.5)

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

    DrawTextWithBackground("TIME", 14, 159, 53, 40, 16, nil, COL_WHITE, ui.Alignment.Start)
    if timeLeftSec > 0 then
        colTimeLeft.mult = timeLeftFade
    else
        colTimeLeft.mult = 0.5
    end
    DrawTextWithBackground(timeRemainingText, 24, 200, 52, 100, 16, nil, colTimeLeft, ui.Alignment.Start)

    local remainingLaps = EstimateRemainingLaps()
    local lapsRemainingText = (remainingLaps and remainingLaps > 0) and string.format(remainingLaps >= 100 and "%.0f" or remainingLaps >= 10 and "%.1f" or "%.2f", remainingLaps) or "--.-"

    DrawTextWithBackground("LAPS", 14, 160, 76, 40, 16, nil, COL_WHITE, ui.Alignment.Start)
    DrawTextWithBackground(
        lapsRemainingText, 24, 200, 76, 100, 16, nil,
        timeLeftSec > 0 and COL_WHITE_DIM or COL_WHITE, ui.Alignment.Start
    )

    local position = ac.getCarLeaderboardPosition(0)
    local totalCars = ac.getSim().carsCount
    local positionText = string.format("%02d/%02d", position, totalCars)
    local posColor = COL_TRANSPARENT
    if (totalCars > 4) and (position < 4) then
        if position == 1 then
            posColor = COL_GOLD
        elseif position == 2 then
            posColor = COL_SILVER
        else
            posColor = COL_BRONZE
        end
    end

    DrawTextWithBackground("POS", 14, 160, 100, 40, 16, nil, COL_WHITE, ui.Alignment.Start)
    DrawTextWithBackground(positionText, 24, 200, 100, 72, 16, posColor, COL_WHITE, ui.Alignment.Start)
    DrawTextWithBackground("IRL", 14, 160, 124, 40, 16, nil, COL_WHITE, ui.Alignment.Start)
    DrawTextWithBackground(os.date("%H:%M"), 24, 200, 124, 72, 16, nil, COL_WHITE, ui.Alignment.Start)

    ui.drawLine(sepTireP1, sepTireP2, COL_LINE, 1)

    -- MARK: Tires
    local tireBlockWidth = 30
    local tireBlockHeight = 40
    local tireBlockSpacing = 10
    local tireVerticalSpacing = 10
    local tireBlockY = 52
    local centerX = 350
    local leftBlocksX = centerX - tireBlockWidth - (tireBlockSpacing / 2)
    local rightBlocksX = centerX + (tireBlockSpacing / 2)

    local tireCoreTemps = { Car.wheels[ac.Wheel.FrontLeft].tyreCoreTemperature, Car.wheels[ac.Wheel.FrontRight].tyreCoreTemperature, Car.wheels[ac.Wheel.RearLeft].tyreCoreTemperature, Car.wheels[ac.Wheel.RearRight].tyreCoreTemperature }
    local tireInnerTemps = { Car.wheels[ac.Wheel.FrontLeft].tyreInsideTemperature, Car.wheels[ac.Wheel.FrontRight].tyreInsideTemperature, Car.wheels[ac.Wheel.RearLeft].tyreInsideTemperature, Car.wheels[ac.Wheel.RearRight].tyreInsideTemperature }
    local tireMiddleTemps = { Car.wheels[ac.Wheel.FrontLeft].tyreMiddleTemperature, Car.wheels[ac.Wheel.FrontRight].tyreMiddleTemperature, Car.wheels[ac.Wheel.RearLeft].tyreMiddleTemperature, Car.wheels[ac.Wheel.RearRight].tyreMiddleTemperature }
    local tireOuterTemps = { Car.wheels[ac.Wheel.FrontLeft].tyreOutsideTemperature, Car.wheels[ac.Wheel.FrontRight].tyreOutsideTemperature, Car.wheels[ac.Wheel.RearLeft].tyreOutsideTemperature, Car.wheels[ac.Wheel.RearRight].tyreOutsideTemperature }
    local tireOptimumTemps = {
        Car.wheels[ac.Wheel.FrontLeft].tyreOptimumTemperature or 80,
        Car.wheels[ac.Wheel.FrontRight].tyreOptimumTemperature or 80,
        Car.wheels[ac.Wheel.RearLeft].tyreOptimumTemperature or 80,
        Car.wheels[ac.Wheel.RearRight].tyreOptimumTemperature or 80
    }
    local tirePressures = { Car.wheels[ac.Wheel.FrontLeft].tyrePressure, Car.wheels[ac.Wheel.FrontRight].tyrePressure, Car.wheels[ac.Wheel.RearLeft].tyrePressure, Car.wheels[ac.Wheel.RearRight].tyrePressure }
    local tireFL_grip = GetTireGripFromWear(0)
    local tireFR_grip = GetTireGripFromWear(1)
    local tireRL_grip = GetTireGripFromWear(2)
    local tireRR_grip = GetTireGripFromWear(3)

    local tireData = ac.INIConfig.carData(0, "tyres.ini")
    local tireOptimumPressures = {
        tonumber(tireData:get(Car.compoundIndex == 0 and "FRONT" or "FRONT_" .. (Car.compoundIndex + 1), "PRESSURE_IDEAL", 26)),
        tonumber(tireData:get(Car.compoundIndex == 0 and "FRONT" or "FRONT_" .. (Car.compoundIndex + 1), "PRESSURE_IDEAL", 26)),
        tonumber(tireData:get(Car.compoundIndex == 0 and "REAR" or "REAR_" .. (Car.compoundIndex + 1), "PRESSURE_IDEAL", 26)),
        tonumber(tireData:get(Car.compoundIndex == 0 and "REAR" or "REAR_" .. (Car.compoundIndex + 1), "PRESSURE_IDEAL", 26))
    }
    local tireExplosionTemp = tonumber(tireData:get("EXPLOSION", "TEMPERATURE", (tireOptimumTemps[1] * 3)))
    TireTempThresholds.explosion = (tireExplosionTemp - 20) / tireOptimumTemps[1]

    local flCore = tireCoreRects[1]
    ui.drawRectFilled(flCore[1], flCore[2], GetTempColor(tireCoreTemps[1], tireOptimumTemps[1]), 0, 0)
    for i = 0, 2 do
        local stripeIndex = 2 - i
        local temp = stripeIndex == 0 and tireOuterTemps[1] or stripeIndex == 1 and tireMiddleTemps[1] or tireInnerTemps[1]
        local r = tireStripeRects[1][i + 1]
        ui.drawRectFilled(
            r[1], r[2], GetTempColor(temp, tireOptimumTemps[1]),
            (i == 0 or i == 2) and 3 or 0,
            (i == 0 and ui.CornerFlags.BottomLeft) or (i == 2 and ui.CornerFlags.BottomRight) or 0
        )
    end

    local frCore = tireCoreRects[2]
    ui.drawRectFilled(frCore[1], frCore[2], GetTempColor(tireCoreTemps[2], tireOptimumTemps[2]), 0, 0)
    for i = 0, 2 do
        local stripeIndex = i
        local temp = stripeIndex == 0 and tireInnerTemps[2] or stripeIndex == 1 and tireMiddleTemps[2] or tireOuterTemps[2]
        local r = tireStripeRects[2][i + 1]
        ui.drawRectFilled(
            r[1], r[2], GetTempColor(temp, tireOptimumTemps[2]),
            (i == 0 or i == 2) and 3 or 0,
            (i == 0 and ui.CornerFlags.BottomLeft) or (i == 2 and ui.CornerFlags.BottomRight) or 0
        )
    end

    local rlCore = tireCoreRects[3]
    ui.drawRectFilled(rlCore[1], rlCore[2], GetTempColor(tireCoreTemps[3], tireOptimumTemps[3]), 0, 0)
    for i = 0, 2 do
        local stripeIndex = 2 - i
        local temp = stripeIndex == 0 and tireOuterTemps[3] or stripeIndex == 1 and tireMiddleTemps[3] or tireInnerTemps[3]
        local r = tireStripeRects[3][i + 1]
        ui.drawRectFilled(
            r[1], r[2], GetTempColor(temp, tireOptimumTemps[3]),
            (i == 0 or i == 2) and 3 or 0,
            (i == 0 and ui.CornerFlags.BottomLeft) or (i == 2 and ui.CornerFlags.BottomRight) or 0
        )
    end

    local rrCore = tireCoreRects[4]
    ui.drawRectFilled(rrCore[1], rrCore[2], GetTempColor(tireCoreTemps[4], tireOptimumTemps[4]), 0, 0)
    for i = 0, 2 do
        local stripeIndex = i
        local temp = stripeIndex == 0 and tireInnerTemps[4] or stripeIndex == 1 and tireMiddleTemps[4] or tireOuterTemps[4]
        local r = tireStripeRects[4][stripeIndex + 1]
        ui.drawRectFilled(
            r[1], r[2], GetTempColor(temp, tireOptimumTemps[4]),
            (stripeIndex == 0 or stripeIndex == 2) and 3 or 0,
            (stripeIndex == 0 and ui.CornerFlags.BottomLeft) or (stripeIndex == 2 and ui.CornerFlags.BottomRight) or 0
        )
    end

    local pressureDelta = tirePressures[1] - tireOptimumPressures[1]
    DrawTextWithBackground(
        string.format((pressureDelta > 0 and "+" or "") .. (math.abs(pressureDelta) < 10 and "%.1f" or "%.0f"), pressureDelta),
        13, leftBlocksX - 35, tireBlockY + 5, 34, 10,
        GetPressureColor(tirePressures[1], tireOptimumPressures[1]), COL_WHITE
    )
    DrawTextWithBackground(
        string.format(tireFL_grip < 0.999 and "%.1f%%" or "%.0f%%", tireFL_grip * 100),
        11, leftBlocksX - 5, tireBlockY + tireBlockHeight - 15, 31, 7,
        GetTireWearColor(1 - tireFL_grip), COL_WHITE, ui.Alignment.End
    )

    pressureDelta = tirePressures[2] - tireOptimumPressures[2]
    DrawTextWithBackground(
        string.format((pressureDelta > 0 and "+" or "") .. (math.abs(pressureDelta) < 10 and "%.1f" or "%.0f"), pressureDelta),
        13, rightBlocksX + tireBlockWidth + 5, tireBlockY + 5, 34, 10,
        GetPressureColor(tirePressures[2], tireOptimumPressures[2]), COL_WHITE
    )
    DrawTextWithBackground(
        string.format(tireFR_grip < 0.999 and "%.1f%%" or "%.0f%%", tireFR_grip * 100),
        11, rightBlocksX + tireBlockWidth + 5, tireBlockY + tireBlockHeight - 15, 37, 7,
        GetTireWearColor(1 - tireFR_grip), COL_WHITE, ui.Alignment.Start
    )

    pressureDelta = tirePressures[3] - tireOptimumPressures[3]
    DrawTextWithBackground(
        string.format((pressureDelta > 0 and "+" or "") .. (math.abs(pressureDelta) < 10 and "%.1f" or "%.0f"), pressureDelta),
        13, leftBlocksX - 35, tireBlockY + tireBlockHeight + tireVerticalSpacing + 5, 34, 10,
        GetPressureColor(tirePressures[3], tireOptimumPressures[3]), COL_WHITE
    )
    DrawTextWithBackground(
        string.format(tireRL_grip < 0.999 and "%.1f%%" or "%.0f%%", tireRL_grip * 100),
        11, leftBlocksX - 5, tireBlockY + tireBlockHeight + tireVerticalSpacing + tireBlockHeight - 15, 31, 7,
        GetTireWearColor(1 - tireRL_grip), COL_WHITE, ui.Alignment.End
    )

    pressureDelta = tirePressures[4] - tireOptimumPressures[4]
    DrawTextWithBackground(
        string.format((pressureDelta > 0 and "+" or "") .. (math.abs(pressureDelta) < 10 and "%.1f" or "%.0f"), pressureDelta),
        13, rightBlocksX + tireBlockWidth + 5, tireBlockY + tireBlockHeight + tireVerticalSpacing + 5, 34, 10,
        GetPressureColor(tirePressures[4], tireOptimumPressures[4]), COL_WHITE
    )
    DrawTextWithBackground(
        string.format(tireRR_grip < 0.999 and "%.1f%%" or "%.0f%%", tireRR_grip * 100),
        11, rightBlocksX + tireBlockWidth + 5, tireBlockY + tireBlockHeight + tireVerticalSpacing + tireBlockHeight - 15, 37, 7,
        GetTireWearColor(1 - tireRR_grip), COL_WHITE, ui.Alignment.Start
    )

    ui.drawLine(sepAssistP1, sepAssistP2, COL_LINE, 1)

    -- MARK: Assists
    local assistsX = rightBlocksX + tireBlockWidth + 50
    local assistsY = tireBlockY + 2

    local tcText = Car.tractionControlModes > 0
        and string.format("%2d/%d", Car.tractionControlMode, Car.tractionControlModes)
        or " N/A"
    DrawTextWithBackground("TC1", 14, assistsX, assistsY, 29, 9, Car.tractionControlInAction and AssistColors.tc or nil, COL_WHITE)
    DrawTextWithBackground(tcText, 22, assistsX + 28, assistsY, 65, 22, nil, COL_WHITE)

    local tc2Text = Car.tractionControl2 > 0
        and string.format("%2d/%d", Car.tractionControl2, Car.tractionControl2Modes)
        or " N/A"
    DrawTextWithBackground("TC2", 14, assistsX, assistsY + 23, 29, 9, Car.tractionControlInAction and AssistColors.tc or nil, COL_WHITE)
    DrawTextWithBackground(tc2Text, 22, assistsX + 28, assistsY + 23, 65, 22, nil, COL_WHITE)

    local absText = Car.absModes > 0
        and string.format("%2d/%d", Car.absMode, Car.absModes)
        or " N/A"
    DrawTextWithBackground("ABS", 14, assistsX, assistsY + 46, 29, 9, Car.absInAction and AssistColors.abs or nil, COL_WHITE)
    DrawTextWithBackground(absText, 22, assistsX + 28, assistsY + 46, 65, 22, nil, COL_WHITE)

    DrawTextWithBackground("BB", 14, assistsX, assistsY + 69, 40, 22, nil, COL_WHITE)
    DrawTextWithBackground(string.format("%.1f%%", Car.brakeBias * 100), 22, assistsX + 28, assistsY + 69, 65, 22, nil, COL_WHITE)

    ui.drawLine(sepEnvP1, sepEnvP2, COL_LINE, 1)

    -- MARK: Enviro
    DrawTextWithBackground(string.format("%s", GetWindDirectionText(Sim.windDirectionDeg)), 22, assistsX + 100, assistsY, 35, 22, nil, COL_WHITE, ui.Alignment.Center)
    DrawTextWithBackground(string.format("%.0f", Sim.windSpeedKmh), 22, assistsX + 100, assistsY + 23, 35, 22, nil, COL_WHITE, ui.Alignment.Center)
    DrawTextWithBackground(string.format("%.0fA", Sim.ambientTemperature), 16, assistsX + 100, assistsY + 47, 35, 18, nil, COL_WHITE, ui.Alignment.Center)
    DrawTextWithBackground(string.format("%.0fT", Sim.roadTemperature), 16, assistsX + 100, assistsY + 63, 35, 18, nil, COL_WHITE, ui.Alignment.Center)
    DrawTextWithBackground(string.format(Sim.roadGrip == 1.0 and "100%%" or "%.1f%%", Sim.roadGrip * 100), 13, assistsX + 99, assistsY + 80, 40, 18, nil, COL_WHITE, ui.Alignment.Center)

    ui.drawLine(sepFuelP1, sepFuelP2, COL_LINE, 1)

    -- MARK: Fuel
    DrawTextWithBackground(string.format("LVL %6.2f L", Car.fuel):gsub("^%s+", ""), 16, 690, 54, 110, 12, COL_TRANSPARENT, COL_WHITE, ui.Alignment.End)

    local lastLapFuel = FuelTracking and FuelTracking.lastLapFuelUsed or 0
    DrawTextWithBackground(
        lastLapFuel > 0 and string.format("LST %6.2f L", lastLapFuel):gsub("^%s+", "") or "LST  --.-- L",
        16, 690, 73, 110, 12, COL_TRANSPARENT, COL_WHITE, ui.Alignment.End
    )

    local avgFuelPerLap = Fuel.getAverageFuelPerLap(FuelTracking or { fuelUsageHistory = {} })
    DrawTextWithBackground(
        (avgFuelPerLap > 0) and string.format("AVG %6.2f L", avgFuelPerLap):gsub("^%s+", "") or "AVG  --.-- L",
        16, 690, 92, 110, 12, COL_TRANSPARENT, COL_WHITE, ui.Alignment.End
    )

    local possibleLaps = "--.-"
    local possibleLapsColor, possibleLapsBg = COL_WHITE, COL_TRANSPARENT
    if avgFuelPerLap > 0 then
        local lapsLeft = Car.fuel / avgFuelPerLap
        possibleLaps = string.format("%.1f", lapsLeft)
        possibleLapsColor, possibleLapsBg = Fuel.getLapFuelColors(lapsLeft)
    end
    DrawTextWithBackground(
        string.format("LPS%6s LP", possibleLaps):gsub("^%s+", ""),
        16, 690, 111, 110, 12, possibleLapsBg, possibleLapsColor, ui.Alignment.End
    )

    remainingLaps = EstimateRemainingLaps()
    local fuelRemaining = Fuel.calculateRaceEndFuel(Car, avgFuelPerLap, remainingLaps)
    local fuelRemainingText = fuelRemaining and string.format("END %6.2f L", fuelRemaining):gsub("^%s+", "") or "END  --.-- L"
    local fuelTextColor, fuelBgColor = Fuel.getEndFuelColors(fuelRemaining)
    DrawTextWithBackground(fuelRemainingText, 16, 690, 130, 110, 12, fuelBgColor, fuelTextColor, ui.Alignment.End)

    -- MARK: Buttons
    if ui.rectHovered(origin, dashBR, false) then
        ui.drawRectFilled(swapHoverP1, swapHoverP2, COL_HOVER_SWAP)
    end
    ui.setCursor(swapCursor)
    if ui.invisibleButton("Swap SB and PB", swapSize) then
        Config.delta.compareMode = Config.delta.compareMode == "SESSION" and "PERSONAL" or "SESSION"
    end

    if ui.rectHovered(origin, dashBR, false) then
        ui.drawRectFilled(lgtTL, lgtBR, COL_HOVER_LGT, 2, ui.CornerFlags.All)
        ui.dwriteDrawText("LGT " .. (Config.rpm.shiftLightsEnabled and "ON" or "OFF"), 14, lgtText, COL_WHITE)
    end
    ui.setCursor(lgtTL)
    if ui.invisibleButton("Shift Lights", lgtSize) then
        Config.rpm.shiftLightsEnabled = not Config.rpm.shiftLightsEnabled
    end

    ui.endPivotScale(Config.appScaleFactor, origin)
    ui.popDWriteFont()
end

return dash
