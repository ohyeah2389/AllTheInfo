local car = ac.getCar(0)
local sim = ac.getSim()

local state = {
    lastAngle = 0,
    angleDeltas = {0, 0, 0, 0, 0}, -- Circular buffer for last 5 angle changes
    deltaIndex = 1, -- Current index in the circular buffer
}

local deltabar = {}

function deltabar.draw()
    ui.pushDWriteFont(Font_whiteRabbit)

    ui.beginScale()

    ui.drawRectFilled(vec2(0, 0), vec2(424, 31), rgbm(0, 0, 0, 0.25), 5, ui.CornerFlags.All)
    ui.drawRect(vec2(0, 0), vec2(424, 31), rgbm(0, 0, 0, 0.5), 5, ui.CornerFlags.All)

    -- Delta bar settings
    local barWidth = 419 -- Window width (424) - 2px padding
    local barHeight = 29 -- Window height (31) - 2px padding
    local centerX = 212  -- Center point of the window (424/2)
    local startY = 1     -- 1px padding from top
    local maxAngle = 180.0 -- Maximum angle to show
    local detailArea = 60.0 -- More detailed range near center
    local progressWidth
    local smallTickHeight = 5
    local tickColor = 0.2 -- Constant opacity for ticks

    local speedFadeout = MapRange(car.speedKmh, 2, 10, 0, 1, true)
    local currentAngle = (math.atan2(car.localVelocity.x, car.localVelocity.z) * 180 / math.pi) * speedFadeout

    -- Store the raw angle change in circular buffer
    local rawAngleChange = (currentAngle - state.lastAngle) * ac.getScriptDeltaT()
    state.angleDeltas[state.deltaIndex] = rawAngleChange
    state.deltaIndex = (state.deltaIndex % 5) + 1

    -- Calculate smoothed angleChangeRate by averaging the last 5 values
    local angleChangeRate = 0
    for i = 1, 5 do
        angleChangeRate = angleChangeRate + state.angleDeltas[i]
    end
    angleChangeRate = angleChangeRate / 5

    -- Background bar
    ui.drawRectFilled(vec2(1, startY), vec2(423, startY + barHeight), rgbm(0.2, 0.2, 0.2, 0.9), 3)

    -- Draw horizontal line across the bar
    ui.drawRectFilled(vec2(2, startY + barHeight / 2), vec2(422, startY + barHeight / 2 + 1), rgbm(1, 1, 1, tickColor), 0)

    -- Draw center line
    ui.drawRectFilled(vec2(centerX, startY), vec2(centerX + 1, startY + barHeight), rgbm(1, 1, 1, tickColor), 0)

    -- Draw small ticks at 10 degree intervals
    for i = 1, 5 do
        local smallTickDelta = (i * 10)
        local smallTickWidth = (smallTickDelta / detailArea) * (barWidth / 3)

        -- Left side small ticks
        ui.drawRectFilled(vec2(centerX - smallTickWidth, startY + (barHeight - smallTickHeight) / 2),
            vec2(centerX - smallTickWidth + 1, startY + (barHeight + smallTickHeight) / 2),
            rgbm(1, 1, 1, tickColor), 0)

        -- Right side small ticks
        ui.drawRectFilled(vec2(centerX + smallTickWidth, startY + (barHeight - smallTickHeight) / 2),
            vec2(centerX + smallTickWidth + 1, startY + (barHeight + smallTickHeight) / 2),
            rgbm(1, 1, 1, tickColor), 0)
    end

    -- Draw outer range ticks
    for i = 1, 3 do
        local tickDelta = i * 60
        local remainingDelta = tickDelta - detailArea
        local remainingRange = maxAngle - detailArea
        local tickWidth = (barWidth / 3) + (remainingDelta / remainingRange) * (barWidth / 6)

        -- Left side ticks
        ui.drawRectFilled(vec2(centerX - tickWidth, startY + 1), vec2(centerX - tickWidth + 1, startY + barHeight - 1), rgbm(1, 1, 1, tickColor), 0)

        -- Right side ticks
        ui.drawRectFilled(vec2(centerX + tickWidth, startY + 1), vec2(centerX + tickWidth + 1, startY + barHeight - 1), rgbm(1, 1, 1, tickColor), 0)
    end

    if math.abs(currentAngle) <= detailArea then
        -- First portion of the bar's width represents detailed area
        progressWidth = math.abs(currentAngle) / detailArea * (barWidth / 3)
    else
        -- Second portion represents remaining range up to maxDelta
        local remainingDelta = math.abs(currentAngle) - detailArea
        local remainingRange = maxAngle - detailArea
        local detailedWidth = barWidth / 3
        local extraWidth = (remainingDelta / remainingRange) * (barWidth / 6)
        progressWidth = detailedWidth + extraWidth
    end

    progressWidth = math.min(progressWidth, barWidth / 2) -- Ensure we don't exceed half the bar

    -- Draw the colored bar
    local deltaBarEnd
    if currentAngle > 0 then
        -- Positive value - Blue bar to the left (center moves right 1px)
        deltaBarEnd = centerX - progressWidth
        ui.drawRectFilled(vec2(deltaBarEnd, startY + 2),
            vec2(centerX + 1, startY + barHeight - 2),
            rgbm(0.2, 0.5, 0.8, 1), 2)
    else
        -- Negative value - Blue bar to the right (center moves left 1px)
        deltaBarEnd = centerX + progressWidth
        ui.drawRectFilled(vec2(centerX - 1, startY + 2),
            vec2(deltaBarEnd, startY + barHeight - 2),
            rgbm(0.2, 0.5, 0.8, 1), 2)
    end

    -- Draw trend bar
    if (angleChangeRate) and (angleChangeRate > 0) then
        ui.drawRectFilled(vec2(deltaBarEnd - (angleChangeRate * 5000), startY + 3),
            vec2(deltaBarEnd + 1, startY + barHeight - 3),
            rgbm(1, 1, 0, 0.5))
    elseif angleChangeRate < 0 then
        ui.drawRectFilled(vec2(deltaBarEnd - 1, startY + 3),
            vec2(deltaBarEnd + (angleChangeRate * -5000), startY + barHeight - 3),
            rgbm(1, 1, 0, 0.5))
    end

    if Config.drift.numberShown then
        -- Draw delta text with background
        local deltaText = string.format(
        "%+." ..
        (math.abs(currentAngle) >= 100 and "1" or math.abs(currentAngle) >= 10 and "2" or math.abs(currentAngle) >= 1 and "3" or "3") ..
        "f", currentAngle)
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

    local buttonShowNumberPos = vec2(350, 10)
    local buttonShowNumberSize = vec2(63, 12)

    -- Hover buttons
    if ui.rectHovered(vec2(0, 0), vec2(424, 31), false) then
        ui.drawRectFilled(buttonShowNumberPos - 2, buttonShowNumberPos + buttonShowNumberSize + 2, rgbm(0.1, 0.1, 0.1, 1),
            3)
        ui.dwriteDrawText(Config.drift.numberShown and "Hide DA" or "Show DA", 16, buttonShowNumberPos, rgbm(1, 1, 1, 1))
    end

    ui.setCursor(buttonShowNumberPos)
    if ui.invisibleButton("showHideDA", buttonShowNumberSize) then
        Config.drift.numberShown = not Config.drift.numberShown
        SaveSettings()
    end

    state.lastAngle = currentAngle

    ui.endPivotScale(Config.appScaleFactor, vec2(0, 0))

    ui.popDWriteFont()
end

return deltabar