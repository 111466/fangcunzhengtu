
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"

local UI = {}

-- 平台检测缓存
UI.isMobile = false

function UI.DetectPlatform()
    UI.isMobile = PlatformUtils.IsMobilePlatform() or PlatformUtils.IsWebPlatform()
end

local function PointInRect(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function UI.Render(nvg, view)
    nvgSave(nvg)

    if view.phase == "title" then
        UI.DrawTitleScreen(nvg, view.screenWidth, view.screenHeight)
    else
        UI.DrawBattleHUD(
            nvg,
            view.gold,
            view.lives,
            view.heroState,
            view.screenWidth,
            view.screenHeight
        )
    end

    nvgRestore(nvg)
end

function UI.DrawTitleScreen(nvg, screenWidth, screenHeight)
    local cx = screenWidth / 2
    local cy = screenHeight / 2
    local isMobile = UI.isMobile
    local sf = math.max(0.55, math.min(1.0, screenWidth / 1280))

    -- ===== 背景层 =====
    -- 多层渐变背景（深蓝到紫蓝）
    local bgGrad = nvgLinearGradient(nvg, 0, 0, 0, screenHeight,
        nvgRGBA(12, 18, 35, 255), nvgRGBA(25, 35, 65, 255),
        nvgRGBA(35, 45, 85, 255), nvgRGBA(20, 30, 55, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, screenWidth, screenHeight)
    nvgFillPaint(nvg, bgGrad)
    nvgFill(nvg)

    -- 动态粒子星星（带闪烁效果）
    local time = os.clock()
    math.randomseed(42)
    for i = 1, 60 do
        local sx = math.random() * screenWidth
        local sy = math.random() * screenHeight * 0.8
        local sr = 0.5 + math.random() * 2
        local twinkle = math.sin(time * 2 + i * 0.5) * 0.5 + 0.5
        local sa = math.floor((40 + math.random() * 80) * twinkle)
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, sr)
        nvgFillColor(nvg, nvgRGBA(220, 240, 255, sa))
        nvgFill(nvg)
    end

    -- 远处山脉轮廓
    nvgStrokeColor(nvg, nvgRGBA(60, 80, 120, 40))
    nvgStrokeWidth(nvg, 2)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, 0, screenHeight * 0.6)
    local peakCount = 8
    for i = 0, peakCount do
        local px = (i / peakCount) * screenWidth
        local py = screenHeight * (0.55 + math.sin(i * 1.5) * 0.08 + math.random() * 0.03)
        nvgLineTo(nvg, px, py)
    end
    nvgLineTo(nvg, screenWidth, screenHeight)
    nvgLineTo(nvg, 0, screenHeight)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(30, 45, 75, 60))
    nvgFill(nvg)

    -- ===== 中心装饰圆环 =====
    local ringRadius = math.min(screenWidth, screenHeight) * 0.22
    local ringX = cx
    local ringY = cy - 30 * sf

    -- 外层光环
    nvgStrokeColor(nvg, nvgRGBA(100, 150, 255, 30))
    nvgStrokeWidth(nvg, 2)
    nvgBeginPath(nvg)
    nvgCircle(nvg, ringX, ringY, ringRadius)
    nvgStroke(nvg)

    -- 内层光环
    nvgStrokeColor(nvg, nvgRGBA(150, 180, 255, 40))
    nvgStrokeWidth(nvg, 1)
    nvgBeginPath(nvg)
    nvgCircle(nvg, ringX, ringY, ringRadius * 0.85)
    nvgStroke(nvg)

    -- 四角装饰星点
    local starAngle = time * 0.2
    for i = 0, 3 do
        local angle = starAngle + i * math.pi / 2
        local px = ringX + math.cos(angle) * ringRadius * 0.92
        local py = ringY + math.sin(angle) * ringRadius * 0.92
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 4 * sf)
        nvgFillColor(nvg, nvgRGBA(255, 220, 150, 180))
        nvgFill(nvg)
    end

    -- ===== 标题文字 =====
    nvgTextAlign(nvg, 2) -- NVG_ALIGN_CENTER

    -- 主标题：方寸征途
    local titleSize = math.floor(52 * sf)
    nvgFontSize(nvg, titleSize)
    -- 金色渐变文字
    local titleGrad = nvgLinearGradient(nvg, cx - 150, ringY - 30, cx + 150, ringY + 30,
        nvgRGBA(255, 230, 150, 255), nvgRGBA(255, 210, 100, 255), nvgRGBA(255, 230, 150, 255))
    nvgFillPaint(nvg, titleGrad)
    nvgText(nvg, cx, ringY + 15 * sf, "方寸征途")

    -- 标题光晕效果
    nvgFillColor(nvg, nvgRGBA(255, 220, 100, 30))
    nvgFontSize(nvg, titleSize + 8)
    nvgText(nvg, cx, ringY + 15 * sf, "方寸征途")

    -- 副标题
    local subSize = math.floor(18 * sf)
    nvgFontSize(nvg, subSize)
    nvgFillColor(nvg, nvgRGBA(160, 195, 240, 220))
    nvgText(nvg, cx, ringY + 55 * sf, "战略征途 · 征战四方")

    -- 描述文字
    local descSize = math.floor(13 * sf)
    nvgFontSize(nvg, descSize)
    nvgFillColor(nvg, nvgRGBA(150, 180, 215, 180))
    nvgText(nvg, cx, ringY + 85 * sf, "策略布局，征战天下，成就一方霸业")

    -- ===== 开始按钮 =====
    local btnW = math.floor(240 * sf)
    local btnH = math.floor(60 * sf)
    if isMobile then
        btnW = math.floor(280 * sf)
        btnH = math.floor(70 * sf)
    end
    local btnX = cx - btnW / 2
    local btnY = ringY + 130 * sf

    UI._titleBtnRect = { x = btnX, y = btnY, w = btnW, h = btnH }

    -- 按钮发光效果
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, btnX - 5, btnY - 5, btnW + 10, btnH + 10, 16 * sf)
    local glowGrad = nvgRadialGradient(nvg, cx, btnY + btnH / 2, 0, btnW * 0.8,
        nvgRGBA(100, 160, 255, 60), nvgRGBA(100, 160, 255, 0))
    nvgFillPaint(nvg, glowGrad)
    nvgFill(nvg)

    -- 按钮主体渐变
    local btnGrad = nvgLinearGradient(nvg, btnX, btnY, btnX, btnY + btnH,
        nvgRGBA(95, 155, 255, 255), nvgRGBA(65, 115, 220, 255))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, btnX, btnY, btnW, btnH, 14 * sf)
    nvgFillPaint(nvg, btnGrad)
    nvgFill(nvg)

    -- 按钮高光层
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, btnX + 2, btnY + 2, btnW - 4, btnH / 2.5, 12 * sf)
    local highlightGrad = nvgLinearGradient(nvg, btnX, btnY, btnX, btnY + btnH / 2,
        nvgRGBA(255, 255, 255, 35), nvgRGBA(255, 255, 255, 0))
    nvgFillPaint(nvg, highlightGrad)
    nvgFill(nvg)

    -- 按钮边框
    nvgStrokeColor(nvg, nvgRGBA(180, 210, 255, 200))
    nvgStrokeWidth(nvg, 2)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, btnX, btnY, btnW, btnH, 14 * sf)
    nvgStroke(nvg)

    -- 按钮文字
    nvgTextAlign(nvg, 2) -- NVG_ALIGN_CENTER
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgFontSize(nvg, math.floor(22 * sf))
    nvgText(nvg, cx, btnY + btnH / 2 + 8 * sf, "开始征程")



    -- ===== 操作提示 =====
    local hintY = btnY + btnH + 35 * sf
    nvgFontSize(nvg, math.floor(12 * sf))
    nvgFillColor(nvg, nvgRGBA(140, 170, 210, 170))
    if isMobile then
        nvgText(nvg, cx, hintY, "触屏点击开始  ·  虚拟摇杆移动  ·  按钮攻击")
    else
        nvgText(nvg, cx, hintY, "点击按钮或按 空格/回车 开始")
        nvgText(nvg, cx, hintY + 18 * sf, "WASD 移动  ·  空格/左键攻击  ·  M 地图")
    end

    -- ===== 底部版本号 =====
    nvgFontSize(nvg, math.floor(11 * sf))
    nvgFillColor(nvg, nvgRGBA(90, 120, 160, 110))
    nvgText(nvg, cx, screenHeight - 14, "方寸征途 v1.0")
end

function UI.DrawBattleHUD(nvg, gold, lives, heroState, screenWidth, screenHeight)
    local isMobile = UI.isMobile
    local sf = math.max(0.6, math.min(1.0, screenWidth / 1280))

    -- 顶部信息栏（响应式宽度）
    local colCount = isMobile and 4 or 5
    local barW = isMobile and math.min(screenWidth - 20, 440) or 680
    local barH = math.floor(48 * sf)
    nvgFillColor(nvg, nvgRGBA(235, 244, 255, 235))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, 10, 10, barW, barH, 14 * sf)
    nvgFill(nvg)

    nvgStrokeColor(nvg, nvgRGBA(150, 188, 235, 255))
    nvgStrokeWidth(nvg, 2)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, 10, 10, barW, barH, 14 * sf)
    nvgStroke(nvg)

    local fontSize = math.floor(isMobile and 14 or 18)
    local textY = 10 + barH / 2 + 5
    local padX = 16
    local colW = (barW - padX * 2) / colCount

    nvgTextAlign(nvg, 2) -- NVG_ALIGN_CENTER
    nvgFontSize(nvg, fontSize)
    nvgFillColor(nvg, nvgRGBA(255, 215, 0, 255))
    nvgText(nvg, 10 + padX + colW * 0.5, textY, "金币:" .. gold)
    nvgFillColor(nvg, nvgRGBA(255, 80, 80, 255))
    nvgText(nvg, 10 + padX + colW * 1.5, textY, "据点:" .. lives)
    nvgFillColor(nvg, nvgRGBA(80, 180, 120, 255))
    nvgText(nvg, 10 + padX + colW * 2.5, textY, "击杀:" .. heroState.killCount)

    -- 木头资源（使用 Follower 模块的 woodCount）
    local woodCount = Follower and Follower.woodCount or 0
    nvgFillColor(nvg, nvgRGBA(180, 130, 60, 255))
    nvgText(nvg, 10 + padX + colW * 3.5, textY, "木头:" .. woodCount)

    if not isMobile then
        nvgFillColor(nvg, nvgRGBA(90, 110, 155, 255))
        nvgText(nvg, 10 + padX + colW * 4.5, textY, "建塔 5-8  地图 M")
    end

    UI.DrawHeroBars(nvg, heroState)

    -- 移动端不显示技能栏和塔栏（用触屏按钮代替）
    if not isMobile then
        UI.DrawSkillBar(nvg, screenWidth, screenHeight)
        UI.DrawTowerBar(nvg, gold, screenWidth, screenHeight)
        UI.DrawSelectionHint(nvg, screenWidth, screenHeight)
    end
end

function UI.DrawHeroBars(nvg, heroState)
    local bx = 15
    local by = 72

    nvgFillColor(nvg, nvgRGBA(238, 243, 250, 220))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bx, by, 180, 16, 4)
    nvgFill(nvg)

    local hpRatio = heroState.hp / heroState.maxHP
    local hpColor = hpRatio > 0.5 and {80, 200, 80}
        or (hpRatio > 0.25 and {220, 180, 40} or {220, 50, 50})
    nvgFillColor(nvg, nvgRGBA(hpColor[1], hpColor[2], hpColor[3], 255))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bx, by, 180 * hpRatio, 16, 4)
    nvgFill(nvg)

    nvgFillColor(nvg, nvgRGBA(35, 40, 55, 255))
    nvgFontSize(nvg, 12)
    nvgTextAlign(nvg, 2) -- NVG_ALIGN_CENTER
    nvgText(nvg, bx + 90, by + 12, math.floor(heroState.hp) .. "/" .. heroState.maxHP)

    nvgFillColor(nvg, nvgRGBA(225, 233, 250, 220))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bx, by + 20, 180, 10, 3)
    nvgFill(nvg)
    nvgFillColor(nvg, nvgRGBA(80, 120, 255, 255))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bx, by + 20, 180 * (heroState.mana / Hero.config.maxMana), 10, 3)
    nvgFill(nvg)
end

function UI.DrawSkillBar(nvg, screenWidth, screenHeight)
    local startX = screenWidth / 2 - 120
    local sy = screenHeight - 70

    for i = 1, 4 do
        local slot = Skills.slots[i]
        local sx = startX + (i - 1) * 65

        local unlocked = slot.level > 0
        local ready = unlocked and slot.cooldownTimer <= 0
            and Hero.state.mana >= Skills.definitions[slot.id].manaCost

        if ready then
            nvgFillColor(nvg, nvgRGBA(214, 235, 255, 240))
        elseif unlocked then
            nvgFillColor(nvg, nvgRGBA(228, 232, 242, 220))
        else
            nvgFillColor(nvg, nvgRGBA(210, 214, 224, 170))
        end
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, sx, sy, 55, 55, 8)
        nvgFill(nvg)

        nvgStrokeColor(nvg, nvgRGBA(115, 145, 195, 255))
        nvgStrokeWidth(nvg, 2)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, sx, sy, 55, 55, 8)
        nvgStroke(nvg)

        if unlocked and slot.cooldownTimer > 0 then
            local cdRatio = slot.cooldownTimer / Skills.definitions[slot.id].cooldown
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 150))
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, sx, sy, 55, 55 * cdRatio, 8)
            nvgFill(nvg)
        end

        if unlocked then
            UI.DrawSkillIcon(nvg, slot.id, sx, sy)
            nvgFillColor(nvg, nvgRGBA(70, 88, 120, 255))
            nvgFontSize(nvg, 10)
            nvgTextAlign(nvg, 1)
            nvgText(nvg, sx + 27, sy + 45, "Lv." .. slot.level)
        else
            nvgFillColor(nvg, nvgRGBA(110, 118, 132, 220))
            nvgFontSize(nvg, 11)
            nvgTextAlign(nvg, 1)
            nvgText(nvg, sx + 27, sy + 30, "未解锁")
        end

        nvgFillColor(nvg, nvgRGBA(180, 180, 180, 200))
        nvgFontSize(nvg, 10)
        nvgText(nvg, sx + 20, sy - 5, tostring(i))
    end
end

function UI.DrawTowerBar(nvg, gold, screenWidth, screenHeight)
    local startX = screenWidth - 350
    local ty = screenHeight - 70

    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
    nvgFontSize(nvg, 14)
    nvgTextAlign(nvg, 0)
    nvgText(nvg, startX, ty - 8, "防御塔 5/6/7/8 选择, 右键放置")

    local towerTypes = { "archer_tower", "cannon_tower", "frost_tower", "lightning_tower" }
    for i, typeName in ipairs(towerTypes) do
        local config = Tower.types[typeName]
        local tx = startX + (i - 1) * 85

        local canAfford = gold >= config.cost
        nvgFillColor(nvg, nvgRGBA(
            canAfford and 230 or 205,
            canAfford and 238 or 215,
            canAfford and 250 or 225, 235))
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tx, ty, 75, 55, 6)
        nvgFill(nvg)

        nvgStrokeColor(nvg, nvgRGBA(120, 150, 205, 255))
        nvgStrokeWidth(nvg, InputController.state.placingTower == typeName and 3 or 2)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tx, ty, 75, 55, 6)
        nvgStroke(nvg)

        nvgFillColor(nvg, nvgRGBA(config.color[1], config.color[2], config.color[3], 255))
        nvgBeginPath(nvg)
        nvgCircle(nvg, tx + 37, ty + 18, 12)
        nvgFill(nvg)

        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        nvgFontSize(nvg, 12)
        nvgTextAlign(nvg, 1)
        nvgText(nvg, tx + 37, ty + 40, config.name)
        nvgFillColor(nvg, nvgRGBA(255, 215, 0, 255))
        nvgFontSize(nvg, 10)
        nvgText(nvg, tx + 37, ty + 52, config.cost .. "G")
    end
end

function UI.DrawSelectionHint(nvg, screenWidth, screenHeight)
    if not InputController.state.placingTower then return end
    nvgFillColor(nvg, nvgRGBA(255, 245, 200, 255))
    nvgFontSize(nvg, 16)
    nvgTextAlign(nvg, 1)
    nvgText(nvg, screenWidth / 2, screenHeight - 92,
        "已选择 " .. Tower.types[InputController.state.placingTower].name .. "，右键放置")
end

function UI.DrawButton(nvg, x, y, w, h, label, primary)
    if primary then
        nvgFillColor(nvg, nvgRGBA(93, 144, 255, 235))
        nvgStrokeColor(nvg, nvgRGBA(190, 220, 255, 255))
    else
        nvgFillColor(nvg, nvgRGBA(70, 88, 120, 220))
        nvgStrokeColor(nvg, nvgRGBA(160, 188, 235, 240))
    end

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, 12)
    nvgFill(nvg)

    nvgStrokeWidth(nvg, 2)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, 12)
    nvgStroke(nvg)

    nvgTextAlign(nvg, 1)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgFontSize(nvg, 22)
    nvgText(nvg, x + w / 2, y + h / 2 + 7, label)
end

function UI.DrawSkillIcon(nvg, skillId, sx, sy)
    local cx = sx + 27
    local cy = sy + 20
    nvgStrokeColor(nvg, nvgRGBA(70, 95, 145, 255))
    nvgStrokeWidth(nvg, 3)

    if skillId == "whirlwind" then
        nvgBeginPath(nvg)
        nvgArc(nvg, cx, cy, 12, -2.2, 0.8, 1)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgArc(nvg, cx, cy, 7, 0.4, 2.9, 1)
        nvgStroke(nvg)
    elseif skillId == "charge" then
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - 14, cy + 6)
        nvgLineTo(nvg, cx + 12, cy - 2)
        nvgLineTo(nvg, cx + 2, cy - 8)
        nvgStroke(nvg)
    elseif skillId == "war_cry" then
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - 10, cy + 10)
        nvgLineTo(nvg, cx - 2, cy + 2)
        nvgLineTo(nvg, cx - 2, cy - 8)
        nvgLineTo(nvg, cx + 12, cy - 12)
        nvgLineTo(nvg, cx + 12, cy + 12)
        nvgLineTo(nvg, cx - 2, cy + 8)
        nvgLineTo(nvg, cx - 2, cy + 2)
        nvgStroke(nvg)
    elseif skillId == "meteor" then
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy - 2, 8)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - 10, cy - 12)
        nvgLineTo(nvg, cx + 10, cy + 8)
        nvgStroke(nvg)
    end
end

-- ========== 移动端虚拟控件绘制 ==========

function UI.DrawTouchControls(nvg, screenWidth, screenHeight)
    if not UI.isMobile then return end
    local t = InputController.touch

    -- ---- 虚拟摇杆 ----
    local baseX, baseY = InputController.GetJoystickBasePos(screenWidth, screenHeight)
    local jRadius = t.JOYSTICK_RADIUS
    local knobRadius = 22

    if t.joystickActive then
        -- 激活时：以触摸起始点为中心
        baseX = t.joystickCenterX
        baseY = t.joystickCenterY
    end

    -- 外圈底盘
    nvgBeginPath(nvg)
    nvgCircle(nvg, baseX, baseY, jRadius)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, t.joystickActive and 40 or 25))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, t.joystickActive and 80 or 45))
    nvgStrokeWidth(nvg, 2)
    nvgBeginPath(nvg)
    nvgCircle(nvg, baseX, baseY, jRadius)
    nvgStroke(nvg)

    -- 摇杆手柄（小圆点）
    local knobX = baseX + t.joystickDirX * t.JOYSTICK_MAX
    local knobY = baseY + t.joystickDirY * t.JOYSTICK_MAX
    nvgBeginPath(nvg)
    nvgCircle(nvg, knobX, knobY, knobRadius)
    local knobGrad = nvgRadialGradient(nvg, knobX, knobY, 0, knobRadius,
        nvgRGBA(255, 255, 255, t.joystickActive and 160 or 90),
        nvgRGBA(200, 220, 255, t.joystickActive and 100 or 50))
    nvgFillPaint(nvg, knobGrad)
    nvgFill(nvg)

    -- 不活跃时显示方向箭头提示
    if not t.joystickActive then
        nvgFontSize(nvg, 18)
        nvgTextAlign(nvg, 1) -- center
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 40))
        nvgText(nvg, baseX, baseY - jRadius + 20, "^")
        nvgText(nvg, baseX, baseY + jRadius - 8, "v")
        nvgFontSize(nvg, 14)
        nvgText(nvg, baseX - jRadius + 14, baseY + 5, "<")
        nvgText(nvg, baseX + jRadius - 14, baseY + 5, ">")
    end

    -- ---- 攻击按钮 ----
    local atkX, atkY = InputController.GetAttackButtonPos(screenWidth, screenHeight)
    local atkR = t.ATTACK_BTN_RADIUS

    -- 按钮背景
    nvgBeginPath(nvg)
    nvgCircle(nvg, atkX, atkY, atkR)
    if t.attackActive then
        local pressGrad = nvgRadialGradient(nvg, atkX, atkY, 0, atkR,
            nvgRGBA(255, 100, 80, 180), nvgRGBA(220, 60, 40, 120))
        nvgFillPaint(nvg, pressGrad)
    else
        local idleGrad = nvgRadialGradient(nvg, atkX, atkY, 0, atkR,
            nvgRGBA(255, 80, 60, 130), nvgRGBA(200, 50, 30, 80))
        nvgFillPaint(nvg, idleGrad)
    end
    nvgFill(nvg)

    -- 按钮边框
    nvgStrokeColor(nvg, nvgRGBA(255, 150, 130, t.attackActive and 200 or 100))
    nvgStrokeWidth(nvg, 2.5)
    nvgBeginPath(nvg)
    nvgCircle(nvg, atkX, atkY, atkR)
    nvgStroke(nvg)

    -- 剑图标（两条交叉线）
    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, t.attackActive and 255 or 180))
    nvgStrokeWidth(nvg, 3)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, atkX - 12, atkY - 12)
    nvgLineTo(nvg, atkX + 12, atkY + 12)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, atkX + 12, atkY - 12)
    nvgLineTo(nvg, atkX - 12, atkY + 12)
    nvgStroke(nvg)

    -- "攻击" 文字
    nvgFontSize(nvg, 12)
    nvgTextAlign(nvg, 1)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, t.attackActive and 255 or 150))
    nvgText(nvg, atkX, atkY + atkR + 16, "攻击")
end

function UI.GetTowerCardAt(mx, my, screenWidth, screenHeight)
    local startX = screenWidth - 350
    local ty = screenHeight - 70
    local towerTypes = { "archer_tower", "cannon_tower", "frost_tower", "lightning_tower" }
    for i, typeName in ipairs(towerTypes) do
        local tx = startX + (i - 1) * 85
        if mx >= tx and mx <= tx + 75 and my >= ty and my <= ty + 55 then
            return typeName
        end
    end
    return nil
end

function UI.GetTitleButtonAt(mx, my, screenWidth, screenHeight)
    local r = UI._titleBtnRect
    if r and PointInRect(mx, my, r.x, r.y, r.w, r.h) then
        return "start"
    end
    return nil
end

function UI.GetBattleEndButtonAt(mx, my, screenWidth, screenHeight)
    local panelY = screenHeight / 2 - 120
    if PointInRect(mx, my, screenWidth / 2 - 170, panelY + 150, 150, 52) then
        return "restart"
    end
    if PointInRect(mx, my, screenWidth / 2 + 20, panelY + 150, 150, 52) then
        return "menu"
    end
    return nil
end

return UI
