local state = {
    lastAngle = 0,
    angleDeltas = { 0, 0, 0, 0, 0 },
    deltaIndex = 1,
}

local COL_WHITE = rgbm.colors.white
local COL_FRAME_FILL = rgbm(0, 0, 0, 0.25)
local COL_FRAME_LINE = rgbm(0, 0, 0, 0.5)
local COL_BAR_BG = rgbm(0.2, 0.2, 0.2, 0.9)
local COL_TICK = rgbm(1, 1, 1, 0.2)
local COL_FILL = rgbm(0.2, 0.5, 0.8, 1)
local COL_TREND = rgbm(1, 1, 0, 0.5)
local COL_TEXT_BG = rgbm(0.15, 0.15, 0.15, 1)
local COL_TEXT = rgbm(1, 1, 1, 0.8)
local COL_HOVER = rgbm(0.1, 0.1, 0.1, 1)

local origin = vec2(0, 0)
local frameBR = vec2(424, 31)
local barBgP1, barBgP2 = vec2(1, 1), vec2(423, 30)
local hLineP1, hLineP2 = vec2(2, 15.5), vec2(422, 16.5)
local centerP1, centerP2 = vec2(212, 1), vec2(213, 30)
local numBgP1, numBgP2 = vec2(177, 6), vec2(247, 25)
local numTextP1, numTextP2 = vec2(112, 2), vec2(312, 30)
local fillP1, fillP2 = vec2(0, 3), vec2(0, 28)
local trendP1, trendP2 = vec2(0, 4), vec2(0, 26)

local btnShowPos, btnShowSize = vec2(350, 10), vec2(63, 12)
local btnShowHoverP1, btnShowHoverP2 = vec2(348, 8), vec2(415, 24)

local ticks = {}
do
    local barWidth, barHeight, centerX, startY = 419, 29, 212, 1
    local smallTickHeight, maxAngle, detailArea = 5, 180.0, 60.0
    for i = 1, 5 do
        local w = ((i * 10) / detailArea) * (barWidth / 3)
        local y1 = startY + (barHeight - smallTickHeight) / 2
        local y2 = startY + (barHeight + smallTickHeight) / 2
        ticks[#ticks + 1] = { vec2(centerX - w, y1), vec2(centerX - w + 1, y2) }
        ticks[#ticks + 1] = { vec2(centerX + w, y1), vec2(centerX + w + 1, y2) }
    end
    for i = 1, 3 do
        local tickDelta = i * 60
        local w = (barWidth / 3) + ((tickDelta - detailArea) / (maxAngle - detailArea)) * (barWidth / 6)
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
    local maxAngle = 180.0
    local detailArea = 60.0
    local progressWidth

    local speedFadeout = MapRange(Car.speedKmh, 2, 10, 0, 1, true)
    local currentAngle = (math.atan2(Car.localVelocity.x, Car.localVelocity.z) * 180 / math.pi) * speedFadeout

    local rawAngleChange = (currentAngle - state.lastAngle) * ac.getScriptDeltaT()
    state.angleDeltas[state.deltaIndex] = rawAngleChange
    state.deltaIndex = (state.deltaIndex % 5) + 1

    local angleChangeRate = 0
    for i = 1, 5 do
        angleChangeRate = angleChangeRate + state.angleDeltas[i]
    end
    angleChangeRate = angleChangeRate / 5

    ui.drawRectFilled(barBgP1, barBgP2, COL_BAR_BG, 3)
    ui.drawRectFilled(hLineP1, hLineP2, COL_TICK, 0)
    ui.drawRectFilled(centerP1, centerP2, COL_TICK, 0)
    for i = 1, #ticks do
        ui.drawRectFilled(ticks[i][1], ticks[i][2], COL_TICK, 0)
    end

    if math.abs(currentAngle) <= detailArea then
        progressWidth = math.abs(currentAngle) / detailArea * (barWidth / 3)
    else
        local remainingDelta = math.abs(currentAngle) - detailArea
        progressWidth = (barWidth / 3) + (remainingDelta / (maxAngle - detailArea)) * (barWidth / 6)
    end
    progressWidth = math.min(progressWidth, barWidth / 2)

    local deltaBarEnd
    if currentAngle > 0 then
        deltaBarEnd = centerX - progressWidth
        fillP1.x = deltaBarEnd
        fillP2.x = centerX + 1
        ui.drawRectFilled(fillP1, fillP2, COL_FILL, 2)
    else
        deltaBarEnd = centerX + progressWidth
        fillP1.x = centerX - 1
        fillP2.x = deltaBarEnd
        ui.drawRectFilled(fillP1, fillP2, COL_FILL, 2)
    end

    if angleChangeRate and angleChangeRate > 0 then
        trendP1.x = deltaBarEnd - (angleChangeRate * 5000)
        trendP2.x = deltaBarEnd + 1
        ui.drawRectFilled(trendP1, trendP2, COL_TREND)
    elseif angleChangeRate < 0 then
        trendP1.x = deltaBarEnd - 1
        trendP2.x = deltaBarEnd + (angleChangeRate * -5000)
        ui.drawRectFilled(trendP1, trendP2, COL_TREND)
    end

    if Config.drift.numberShown then
        local deltaText = string.format(
            "%+." ..
            (math.abs(currentAngle) >= 100 and "1" or math.abs(currentAngle) >= 10 and "2" or math.abs(currentAngle) >= 1 and "3" or "3") ..
            "f", currentAngle)
        ui.drawRectFilled(numBgP1, numBgP2, COL_TEXT_BG, 3)
        ui.dwriteDrawTextClipped(deltaText, 18, numTextP1, numTextP2, ui.Alignment.Center, ui.Alignment.Center, false, COL_TEXT)
    end

    if ui.rectHovered(origin, frameBR, false) then
        ui.drawRectFilled(btnShowHoverP1, btnShowHoverP2, COL_HOVER, 3)
        ui.dwriteDrawText(Config.drift.numberShown and "Hide DA" or "Show DA", 16, btnShowPos, COL_WHITE)
    end

    ui.setCursor(btnShowPos)
    if ui.invisibleButton("showHideDA", btnShowSize) then
        Config.drift.numberShown = not Config.drift.numberShown
        SaveSettings()
    end

    state.lastAngle = currentAngle

    ui.endPivotScale(Config.appScaleFactor, origin)
    ui.popDWriteFont()
end

return deltabar
