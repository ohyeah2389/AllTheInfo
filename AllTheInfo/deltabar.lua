local COL_WHITE = rgbm.colors.white
local COL_BLACK = rgbm.colors.black
local COL_FRAME_FILL = rgbm(0, 0, 0, 0.25)
local COL_FRAME_LINE = rgbm(0, 0, 0, 0.5)
local COL_BAR_BG = rgbm(0.2, 0.2, 0.2, 0.9)
local COL_TICK = rgbm(1, 1, 1, 0.2)
local COL_LOSE = rgbm(0.8, 0.2, 0.2, 1)
local COL_GAIN = rgbm(0.2, 0.8, 0.2, 1)
local COL_TREND = rgbm(1, 1, 0, 0.5)
local COL_TEXT_BG = rgbm(0.15, 0.15, 0.15, 1)
local COL_TEXT = rgbm(1, 1, 1, 0.8)
local COL_HOVER = rgbm(0.1, 0.1, 0.1, 1)
local COL_PB_FLASH = rgbm(0.2, 0.5, 1, 1)
local COL_SB_FLASH = rgbm(0.2, 0.5, 0.2, 1)
local colNoDelta = rgbm(1, 1, 1, 1)
local colFlashFg = rgbm(1, 1, 1, 1)
local colFlashShadow = rgbm(0, 0, 0, 1)

local origin = vec2(0, 0)
local frameBR = vec2(424, 31)
local barBgP1, barBgP2 = vec2(1, 1), vec2(423, 30)
local hLineP1, hLineP2 = vec2(2, 15.5), vec2(422, 16.5)
local centerP1, centerP2 = vec2(212, 1), vec2(213, 30)
local numBgP1, numBgP2 = vec2(177, 6), vec2(247, 25)
local numTextP1, numTextP2 = vec2(112, 2), vec2(312, 30)
local noDeltaP1, noDeltaP2 = vec2(0, 1), vec2(426, 30)
local flashBgP1, flashBgP2 = vec2(120, 6), vec2(304, 25)
local flashSh1P1, flashSh1P2 = vec2(112, 0), vec2(310, 30)
local flashSh2P1, flashSh2P2 = vec2(112, 3), vec2(314, 30)
local fillP1, fillP2 = vec2(0, 3), vec2(0, 28)
local trendP1, trendP2 = vec2(0, 4), vec2(0, 26)

local btnShowPos, btnShowSize = vec2(350, 10), vec2(63, 12)
local btnShowHoverP1, btnShowHoverP2 = vec2(348, 8), vec2(415, 24)
local btnCmpPos, btnCmpSize = vec2(10, 10), vec2(54, 12)
local btnCmpHoverP1, btnCmpHoverP2 = vec2(8, 8), vec2(66, 24)

local ticks = {}
do
    local barWidth, barHeight, centerX, startY = 419, 29, 212, 1
    local smallTickHeight, maxDelta, detailedDelta = 5, 2.0, 0.5
    for i = 1, 9 do
        local w = (i * 0.05 / detailedDelta) * (barWidth / 4)
        local y1 = startY + (barHeight - smallTickHeight) / 2
        local y2 = startY + (barHeight + smallTickHeight) / 2
        ticks[#ticks + 1] = { vec2(centerX - w, y1), vec2(centerX - w + 1, y2) }
        ticks[#ticks + 1] = { vec2(centerX + w, y1), vec2(centerX + w + 1, y2) }
    end
    for i = 1, 4 do
        local tickDelta = i * 0.5
        local w = (barWidth / 4) + ((tickDelta - detailedDelta) / (maxDelta - detailedDelta)) * (barWidth / 4)
        ticks[#ticks + 1] = { vec2(centerX - w, startY + 1), vec2(centerX - w + 1, startY + barHeight - 1) }
        ticks[#ticks + 1] = { vec2(centerX + w, startY + 1), vec2(centerX + w + 1, startY + barHeight - 1) }
    end
end

local deltabar = {}

function deltabar.draw()
    ui.pushDWriteFont(Font_whiteRabbit)
    ui.beginScale()

    ui.drawRectFilled(origin, frameBR, COL_FRAME_FILL, 5, ui.CornerFlags.All)
    ui.drawRect(origin, frameBR, COL_FRAME_LINE, 5, ui.CornerFlags.All)

    local barWidth = 419
    local centerX = 212
    local maxDelta = 2.0
    local detailedDelta = 0.5
    local progressWidth

    ui.drawRectFilled(barBgP1, barBgP2, COL_BAR_BG, 3)
    ui.drawRectFilled(hLineP1, hLineP2, COL_TICK, 0)
    ui.drawRectFilled(centerP1, centerP2, COL_TICK, 0)
    for i = 1, #ticks do
        ui.drawRectFilled(ticks[i][1], ticks[i][2], COL_TICK, 0)
    end

    if Delta.currentDelta then
        if math.abs(Delta.currentDelta) <= detailedDelta then
            progressWidth = math.abs(Delta.currentDelta) / detailedDelta * (barWidth / 4)
        else
            local remainingDelta = math.abs(Delta.currentDelta) - detailedDelta
            local remainingRange = maxDelta - detailedDelta
            progressWidth = (barWidth / 4) + (remainingDelta / remainingRange) * (barWidth / 4)
        end
        progressWidth = math.min(progressWidth, barWidth / 2)

        local deltaBarEnd
        if Delta.currentDelta > 0 then
            deltaBarEnd = centerX - progressWidth
            fillP1.x = deltaBarEnd
            fillP2.x = centerX + 1
            ui.drawRectFilled(fillP1, fillP2, COL_LOSE, 2)
        else
            deltaBarEnd = centerX + progressWidth
            fillP1.x = centerX - 1
            fillP2.x = deltaBarEnd
            ui.drawRectFilled(fillP1, fillP2, COL_GAIN, 2)
        end

        if Delta.currentDeltaChangeRate ~= nil then
            if Delta.currentDeltaChangeRate > 0 then
                trendP1.x = deltaBarEnd - (Delta.currentDeltaChangeRate * 5000)
                trendP2.x = deltaBarEnd + 1
                ui.drawRectFilled(trendP1, trendP2, COL_TREND)
            elseif Delta.currentDeltaChangeRate < 0 then
                trendP1.x = deltaBarEnd - 1
                trendP2.x = deltaBarEnd + (Delta.currentDeltaChangeRate * -5000)
                ui.drawRectFilled(trendP1, trendP2, COL_TREND)
            end
        end

        if Config.delta.numberShown then
            local deltaText = string.format(
                "%+." ..
                (math.abs(Delta.currentDelta) >= 100 and "1" or math.abs(Delta.currentDelta) >= 10 and "2" or math.abs(Delta.currentDelta) >= 1 and "3" or "3") ..
                "f", Delta.currentDelta)
            ui.drawRectFilled(numBgP1, numBgP2, COL_TEXT_BG, 3)
            ui.dwriteDrawTextClipped(deltaText, 18, numTextP1, numTextP2, ui.Alignment.Center, ui.Alignment.Center, false, COL_TEXT)
        end
    else
        if Config.delta.numberShown then
            local message = Delta.trackHasCenterline and "NO DELTA AVAILABLE" or "NO CENTERLINE - DELTA DISABLED"
            colNoDelta.mult = Delta.trackHasCenterline and (math.sin(Sim.time * 0.003) + 2) / 3 or 0.6
            ui.dwriteDrawTextClipped(message, 18, noDeltaP1, noDeltaP2, ui.Alignment.Center, ui.Alignment.Center, false, colNoDelta)
        end
    end

    if ui.rectHovered(origin, frameBR, false) then
        ui.drawRectFilled(btnShowHoverP1, btnShowHoverP2, COL_HOVER, 3)
        ui.dwriteDrawText(Config.delta.numberShown and "Hide DT" or "Show DT", 16, btnShowPos, COL_WHITE)

        ui.drawRectFilled(btnCmpHoverP1, btnCmpHoverP2, COL_HOVER, 3)
        ui.dwriteDrawText("Use " .. Delta.deltaCompareModes[GetNextMode(Config.delta.compareMode)], 16, btnCmpPos, COL_WHITE)
    end

    ui.setCursor(btnShowPos)
    if ui.invisibleButton("showHideDT", btnShowSize) then
        Config.delta.numberShown = not Config.delta.numberShown
        SaveSettings()
    end

    ui.setCursor(btnCmpPos)
    if ui.invisibleButton("compareMode", btnCmpSize) then
        Config.delta.compareMode = GetNextMode(Config.delta.compareMode)
        SaveSettings()
    end

    local timeSincePersonalBest = os.clock() - UIstate.personalBestFlashStartTime
    local totalFlashDuration = PERSONAL_BEST_FLASH_DURATION * PERSONAL_BEST_FLASH_COUNT * 2
    local timeSinceSessionBest = os.clock() - UIstate.sessionBestFlashStartTime
    local totalSessionFlashDuration = SESSION_BEST_FLASH_DURATION * SESSION_BEST_FLASH_COUNT * 2

    if timeSincePersonalBest < totalFlashDuration then
        local textOpacity = (math.floor(timeSincePersonalBest / PERSONAL_BEST_FLASH_DURATION) % 2 == 0) and 1 or 0.5
        colFlashFg.mult = textOpacity
        colFlashShadow.mult = textOpacity
        ui.drawRectFilled(flashBgP1, flashBgP2, COL_PB_FLASH, 3)
        ui.dwriteDrawTextClipped("NEW PERSONAL BEST", 18, flashSh1P1, flashSh1P2, ui.Alignment.Center, ui.Alignment.Center, false, colFlashShadow)
        ui.dwriteDrawTextClipped("NEW PERSONAL BEST", 18, flashSh2P1, flashSh2P2, ui.Alignment.Center, ui.Alignment.Center, false, colFlashShadow)
        ui.dwriteDrawTextClipped("NEW PERSONAL BEST", 18, numTextP1, numTextP2, ui.Alignment.Center, ui.Alignment.Center, false, colFlashFg)
    elseif timeSinceSessionBest < totalSessionFlashDuration then
        local textOpacity = (math.floor(timeSinceSessionBest / SESSION_BEST_FLASH_DURATION) % 2 == 0) and 1 or 0.5
        colFlashFg.mult = textOpacity
        colFlashShadow.mult = textOpacity
        ui.drawRectFilled(flashBgP1, flashBgP2, COL_SB_FLASH, 3)
        ui.dwriteDrawTextClipped("NEW SESSION BEST", 18, flashSh1P1, flashSh1P2, ui.Alignment.Center, ui.Alignment.Center, false, colFlashShadow)
        ui.dwriteDrawTextClipped("NEW SESSION BEST", 18, flashSh2P1, flashSh2P2, ui.Alignment.Center, ui.Alignment.Center, false, colFlashShadow)
        ui.dwriteDrawTextClipped("NEW SESSION BEST", 18, numTextP1, numTextP2, ui.Alignment.Center, ui.Alignment.Center, false, colFlashFg)
    end

    ui.endPivotScale(Config.appScaleFactor, origin)
    ui.popDWriteFont()
end

return deltabar
