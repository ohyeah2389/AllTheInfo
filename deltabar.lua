local sim = ac.getSim()

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

    if Delta.currentDelta then
        if math.abs(Delta.currentDelta) <= detailedDelta then
            -- First half of the bar's width represents ±0.5s
            progressWidth = math.abs(Delta.currentDelta) / detailedDelta * (barWidth / 4)
        else
            -- Second half represents remaining range up to maxDelta
            local remainingDelta = math.abs(Delta.currentDelta) - detailedDelta
            local remainingRange = maxDelta - detailedDelta
            local detailedWidth = barWidth / 4 -- Width for first 0.5s
            local extraWidth = (remainingDelta / remainingRange) * (barWidth / 4)
            progressWidth = detailedWidth + extraWidth
        end
        progressWidth = math.min(progressWidth, barWidth / 2) -- Ensure we don't exceed half the bar

        -- Draw the colored bar
        local deltaBarEnd
        if Delta.currentDelta > 0 then
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
        -- Changed condition to check if Delta.currentDeltaChangeRate is not nil (zero is valid)
        if Delta.currentDeltaChangeRate ~= nil then
            if Delta.currentDeltaChangeRate > 0 then
                -- Trending towards positive (losing more time) - point right
                ui.drawRectFilled(vec2(deltaBarEnd - (Delta.currentDeltaChangeRate * 5000), startY + 3),
                    vec2(deltaBarEnd + 1, startY + barHeight - 3),
                    rgbm(1, 1, 0, 0.5))
            elseif Delta.currentDeltaChangeRate < 0 then -- Explicit check for negative
                -- Trending towards negative (gaining more time) - point left
                ui.drawRectFilled(vec2(deltaBarEnd - 1, startY + 3),
                    vec2(deltaBarEnd + (Delta.currentDeltaChangeRate * -5000), startY + barHeight - 3),
                    rgbm(1, 1, 0, 0.5))
            end
            -- When Delta.currentDeltaChangeRate is exactly 0, we don't draw a trend bar
        end

        if Config.delta.numberShown then
            -- Draw delta text with background
            local deltaText = string.format(
            "%+." ..
            (math.abs(Delta.currentDelta) >= 100 and "1" or math.abs(Delta.currentDelta) >= 10 and "2" or math.abs(Delta.currentDelta) >= 1 and "3" or "3") ..
            "f", Delta.currentDelta)
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
        if Config.delta.numberShown then
            -- No delta available
            local message = Delta.trackHasCenterline and "NO DELTA AVAILABLE" or "NO CENTERLINE - DELTA DISABLED"
            ui.dwriteDrawTextClipped(
                message,
                18,
                vec2(0, 1),
                vec2(426, 30),
                ui.Alignment.Center,
                ui.Alignment.Center,
                false,
                rgbm(1, 1, 1, Delta.trackHasCenterline and (math.sin(sim.time * 0.003) + 2) / 3 or 0.6)
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
        ui.dwriteDrawText(Config.delta.numberShown and "Hide DT" or "Show DT", 16, buttonShowNumberPos, rgbm(1, 1, 1, 1))

        ui.drawRectFilled(buttonComparePos - 2, buttonComparePos + buttonCompareSize + 2, rgbm(0.1, 0.1, 0.1, 1), 3)
        local nextMode = GetNextMode(Config.delta.compareMode)
        ui.dwriteDrawText("Use " .. Delta.deltaCompareModes[nextMode], 16, buttonComparePos, rgbm(1, 1, 1, 1))
    end

    ui.setCursor(buttonShowNumberPos)
    if ui.invisibleButton("showHideDT", buttonShowNumberSize) then
        Config.delta.numberShown = not Config.delta.numberShown
        SaveSettings()
    end

    ui.setCursor(buttonComparePos)
    if ui.invisibleButton("compareMode", buttonCompareSize) then
        Config.delta.compareMode = GetNextMode(Config.delta.compareMode)
        SaveSettings()
    end

    -- Draw flashing "NEW BEST" text if needed
    local timeSincePersonalBest = os.clock() - UIstate.personalBestFlashStartTime
    local totalFlashDuration = PERSONAL_BEST_FLASH_DURATION * PERSONAL_BEST_FLASH_COUNT * 2
    local timeSinceSessionBest = os.clock() - UIstate.sessionBestFlashStartTime
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

    ui.endPivotScale(Config.appScaleFactor, vec2(0, 0))

    ui.popDWriteFont()
end

return deltabar