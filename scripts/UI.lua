
local UI = {}

function UI.Render(nvg, phase, gold, lives, wave, heroState, screenWidth, screenHeight)
    nvgSave(nvg)

    nvgFillColor(nvg, nvgRGBA(20, 25, 35, 220))
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, screenWidth, 45)
    nvgFill(nvg)

    nvgFontSize(nvg, 18)
    nvgFillColor(nvg, nvgRGBA(255, 215, 0, 255))
    nvgText(nvg, 15, 28, "金币: " .. gold)
    nvgFillColor(nvg, nvgRGBA(255, 80, 80, 255))
    nvgText(nvg, 160, 28, "生命: " .. lives)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg, 300, 28, "波次: " .. wave .. "/8")
    nvgFillColor(nvg, nvgRGBA(100, 255, 100, 255))
    nvgText(nvg, 450, 28, "击杀: " .. heroState.killCount)

    UI.DrawHeroBars(nvg, heroState)
    UI.DrawSkillBar(nvg, screenWidth, screenHeight)
    UI.DrawTowerBar(nvg, gold, screenWidth, screenHeight)

    if not WaveManager.waveActive and not WaveManager.allComplete then
        local remaining = math.ceil(WaveManager.prepTimer)
        nvgFillColor(nvg, nvgRGBA(255, 200, 50, 255))
        nvgFontSize(nvg, 28)
        nvgTextAlign(nvg, 1)
        nvgText(nvg, screenWidth / 2, 80,
            "下一波: " .. remaining .. "秒")
    end

    if WaveManager.allComplete then
        nvgFillColor(nvg, nvgRGBA(100, 255, 100, 255))
        nvgFontSize(nvg, 36)
        nvgTextAlign(nvg, 1)
        nvgText(nvg, screenWidth / 2, screenHeight / 2,
            "胜利！")
    end

    if not heroState.alive then
        nvgFillColor(nvg, nvgRGBA(255, 50, 50, 200))
        nvgFontSize(nvg, 36)
        nvgTextAlign(nvg, 1)
        nvgText(nvg, screenWidth / 2, screenHeight / 2,
            "游戏结束！")
    end

    nvgRestore(nvg)
end

function UI.DrawHeroBars(nvg, heroState)
    local bx = 15
    local by = 55

    nvgFillColor(nvg, nvgRGBA(40, 40, 40, 200))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bx, by, 180, 16, 4)
    nvgFill(nvg)

    local hpRatio = heroState.hp / heroState.maxHP
    local hpColor = hpRatio > 0.5 and {80, 200, 80}
        or (hpRatio > 0.25 and {220, 180, 40} or {220, 50, 50})
    nvgFillColor(nvg, hpColor[1], hpColor[2], hpColor[3], 255)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bx, by, 180 * hpRatio, 16, 4)
    nvgFill(nvg)

    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgFontSize(nvg, 12)
    nvgTextAlign(nvg, 1)
    nvgText(nvg, bx + 90, by + 12, math.floor(heroState.hp) .. "/" .. heroState.maxHP)

    nvgFillColor(nvg, nvgRGBA(30, 30, 60, 200))
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
            nvgFillColor(nvg, nvgRGBA(60, 80, 120, 230))
        elseif unlocked then
            nvgFillColor(nvg, nvgRGBA(40, 40, 50, 200))
        else
            nvgFillColor(nvg, nvgRGBA(25, 25, 30, 150))
        end
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, sx, sy, 55, 55, 8)
        nvgFill(nvg)

        if unlocked and slot.cooldownTimer > 0 then
            local cdRatio = slot.cooldownTimer / Skills.definitions[slot.id].cooldown
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 150))
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, sx, sy, 55, 55 * cdRatio, 8)
            nvgFill(nvg)
        end

        if unlocked then
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
            nvgFontSize(nvg, 11)
            nvgTextAlign(nvg, 1)
            nvgText(nvg, sx + 27, sy + 25, Skills.definitions[slot.id].name)
            nvgFillColor(nvg, nvgRGBA(150, 180, 255, 255))
            nvgFontSize(nvg, 10)
            nvgText(nvg, sx + 27, sy + 42, "Lv." .. slot.level)
        else
            nvgFillColor(nvg, nvgRGBA(100, 100, 100, 200))
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

    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 200))
    nvgFontSize(nvg, 14)
    nvgTextAlign(nvg, 0)
    nvgText(nvg, startX, ty - 8, "防御塔 (右键放置):")

    local towerTypes = { "archer_tower", "cannon_tower", "frost_tower", "lightning_tower" }
    for i, typeName in ipairs(towerTypes) do
        local config = Tower.types[typeName]
        local tx = startX + (i - 1) * 85

        local canAfford = gold >= config.cost
        nvgFillColor(nvg, canAfford and 50 or 30,
                     canAfford and 60 or 30,
                     canAfford and 80 or 40, 220)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tx, ty, 75, 55, 6)
        nvgFill(nvg)

        nvgFillColor(nvg, config.color[1], config.color[2], config.color[3], 255)
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

return UI
