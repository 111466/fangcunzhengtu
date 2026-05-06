
local Tower = {}
Tower.list = {}
Tower.selected = nil

-- 弓箭塔精灵图资源
Tower.sprites = {
    building = nil,    -- 塔建筑图 128x256
    archerIdle = nil,  -- 弓箭手待机序列 1152x192, 6帧, 每帧192x192
    archerAttack = nil, -- 弓箭手射箭序列 1536x192, 8帧, 每帧192x192
    idleCols = 6,
    attackCols = 8,
    frameW = 192,
    frameH = 192,
    sheetIdleW = 1152,
    sheetAttackW = 1536,
    sheetH = 192,
    buildingW = 128,
    buildingH = 256,
}

--- 加载弓箭塔精灵图资源
function Tower.LoadSprites(nvg)
    local sp = Tower.sprites
    if not sp.building then
        sp.building = nvgCreateImage(nvg, "image/archer_tower_building.png", 0)
        sp.archerIdle = nvgCreateImage(nvg, "image/archer_idle_sheet.png", 0)
        sp.archerAttack = nvgCreateImage(nvg, "image/archer_attack_sheet.png", 0)
        print("[Tower] Archer tower sprites loaded")
    end
end

--- 清理弓箭塔精灵图资源
function Tower.CleanupSprites(nvg)
    local sp = Tower.sprites
    if nvg then
        if sp.building and sp.building > 0 then nvgDeleteImage(nvg, sp.building) end
        if sp.archerIdle and sp.archerIdle > 0 then nvgDeleteImage(nvg, sp.archerIdle) end
        if sp.archerAttack and sp.archerAttack > 0 then nvgDeleteImage(nvg, sp.archerAttack) end
    end
    sp.building = nil
    sp.archerIdle = nil
    sp.archerAttack = nil
    print("[Tower] Archer tower sprites cleaned up")
end

Tower.types = {
    archer_tower = {
        name = "弓箭塔", cost = 50, damage = 20, range = 160,
        fireRate = 1.2, projectileSpeed = 350,
        color = {100, 150, 255}, size = 24,
    },
    cannon_tower = {
        name = "火炮塔", cost = 100, damage = 60, range = 200,
        fireRate = 0.5, projectileSpeed = 250,
        color = {200, 100, 50}, size = 28,
        splash = 50,
    },
    frost_tower = {
        name = "冰霜塔", cost = 75, damage = 10, range = 140,
        fireRate = 0.8, projectileSpeed = 200,
        color = {100, 200, 255}, size = 24,
        slow = true, slowDuration = 2.0, slowFactor = 0.4,
    },
    lightning_tower = {
        name = "闪电塔", cost = 150, damage = 35, range = 180,
        fireRate = 1.5, projectileSpeed = 999,
        color = {255, 255, 100}, size = 26,
        chain = 3,
    },
}

function Tower.Create(typeName, x, y, gold)
    local config = Tower.types[typeName]
    if not config or gold < config.cost then return nil, gold end
    gold = gold - config.cost
    local tower = {
        type = typeName, config = config,
        x = x, y = y, cooldown = 0,
        level = 1, target = nil,
        _warCryATK = 0, _warCryTimer = 0,
        damage = config.damage,
        range = config.range,
        -- 弓箭手动画状态
        archerAnim = "idle",    -- "idle" 或 "attack"
        archerFrame = 0,
        archerFrameTimer = 0,
        archerAttackTimer = 0,  -- 射击动画剩余时间
        archerFacing = 1,       -- 1=右, -1=左
    }
    table.insert(Tower.list, tower)
    return tower, gold
end

function Tower.UpdateAll(dt)
    local totalReward = 0
    local totalKills = 0
    for _, tower in ipairs(Tower.list) do
        local reward, kills = Tower.Update(tower, dt)
        totalReward = totalReward + reward
        totalKills = totalKills + kills
    end
    return totalReward, totalKills
end

function Tower.Update(tower, dt)
    local totalReward = 0
    local totalKills = 0
    tower.cooldown = tower.cooldown - dt

    if tower._warCryTimer > 0 then
        tower._warCryTimer = tower._warCryTimer - dt
    else
        tower._warCryATK = 0
    end

    -- 更新弓箭手动画帧
    if tower.type == "archer_tower" then
        local frameTime = 0.12
        tower.archerFrameTimer = tower.archerFrameTimer + dt
        if tower.archerFrameTimer >= frameTime then
            tower.archerFrameTimer = tower.archerFrameTimer - frameTime
            if tower.archerAnim == "attack" then
                tower.archerFrame = tower.archerFrame + 1
                if tower.archerFrame >= Tower.sprites.attackCols then
                    tower.archerFrame = 0
                    tower.archerAnim = "idle"
                end
            else
                tower.archerFrame = (tower.archerFrame + 1) % Tower.sprites.idleCols
            end
        end
        if tower.archerAttackTimer > 0 then
            tower.archerAttackTimer = tower.archerAttackTimer - dt
        end
    end

    local closest = nil
    local closestDist = tower.range
    for _, enemy in ipairs(Enemy.list) do
        if enemy.alive then
            local dx = enemy.x - tower.x
            local dy = enemy.y - tower.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < closestDist then
                closestDist = dist
                closest = enemy
            end
        end
    end

    if closest and tower.cooldown <= 0 then
        tower.cooldown = 1.0 / tower.config.fireRate
        local dmg = tower.damage * (1 + tower._warCryATK)

        -- 弓箭塔开火时切换射击动画和朝向
        if tower.type == "archer_tower" then
            tower.archerAnim = "attack"
            tower.archerFrame = 0
            tower.archerFrameTimer = 0
            tower.archerFacing = (closest.x >= tower.x) and 1 or -1
        end

        -- 计算发射起点（弓箭塔从弓箭手身体中心发射）
        local fireX, fireY = tower.x, tower.y
        if tower.type == "archer_tower" then
            local sp = Tower.sprites
            local bldScale = 0.45
            local bldH = sp.buildingH * bldScale
            local bldY = tower.y - bldH + bldH * 0.3
            fireY = bldY + bldH * 0.1 + 25  -- 与 DrawArcherTower 中 archerCenterY 一致
        end

        if tower.config.chain then
            local reward, kills = Tower.ChainLightning(tower, closest, dmg)
            totalReward = totalReward + reward
            totalKills = totalKills + kills
        elseif Projectile then
            Projectile.Create(
                fireX, fireY, closest, dmg,
                tower.config.projectileSpeed,
                tower.config.color,
                tower.config.slow or false,
                tower.config.slowDuration or 0,
                tower.config.slowFactor or 1.0,
                tower.config.splash or 0,
                nil,                              -- source
                tower.type == "archer_tower"       -- isArrow
            )
        end
    end
    return totalReward, totalKills
end

function Tower.ChainLightning(tower, firstTarget, damage)
    local hit = { firstTarget }
    local totalReward = 0
    local totalKills = 0
    local reward = Enemy.Damage(firstTarget, damage)
    if reward then
        totalReward = totalReward + reward
        totalKills = totalKills + 1
    end
    if Particle then
        Particle.Spawn("lightning", tower.x, tower.y, 0)
        Particle.Spawn("lightning", firstTarget.x, firstTarget.y, 0)
    end

    local current = firstTarget
    for i = 2, tower.config.chain do
        local nextTarget = nil
        local nextDist = 120
        for _, enemy in ipairs(Enemy.list) do
            if enemy.alive then
                local alreadyHit = false
                for _, h in ipairs(hit) do
                    if h == enemy then alreadyHit = true; break end
                end
                if not alreadyHit then
                    local dx = enemy.x - current.x
                    local dy = enemy.y - current.y
                    local dist = math.sqrt(dx*dx + dy*dy)
                    if dist < nextDist then
                        nextDist = dist
                        nextTarget = enemy
                    end
                end
            end
        end
        if nextTarget then
            local chainReward = Enemy.Damage(nextTarget, damage * 0.7)
            if chainReward then
                totalReward = totalReward + chainReward
                totalKills = totalKills + 1
            end
            if Particle then
                Particle.Spawn("lightning", nextTarget.x, nextTarget.y, 0)
            end
            table.insert(hit, nextTarget)
            current = nextTarget
        else
            break
        end
    end
    return totalReward, totalKills
end

function Tower.Upgrade(tower, gold)
    local cost = tower.config.cost * tower.level
    if gold < cost or tower.level >= 3 then return false, gold end
    gold = gold - cost
    tower.level = tower.level + 1
    tower.damage = math.floor(tower.damage * 1.4)
    tower.range = tower.range * 1.1
    return true, gold
end

function Tower.DrawAll(nvg)
    for _, tower in ipairs(Tower.list) do
        Tower.Draw(nvg, tower)
    end
end

function Tower.Draw(nvg, tower)
    -- 选中时显示攻击范围
    if Tower.selected == tower then
        nvgStrokeColor(nvg, nvgRGBA(255, 240, 140, 255))
        nvgStrokeWidth(nvg, 3)
        nvgBeginPath(nvg)
        nvgCircle(nvg, tower.x, tower.y, tower.range)
        nvgStroke(nvg)
    end

    -- 弓箭塔：精灵图渲染
    if tower.type == "archer_tower" then
        Tower.DrawArcherTower(nvg, tower)
    else
        -- 其他塔：保持原有圆形绘制
        local c = tower.config.color

        nvgFillColor(nvg, nvgRGBA(60, 60, 60, 255))
        nvgBeginPath(nvg)
        nvgCircle(nvg, tower.x, tower.y, tower.config.size + 6)
        nvgFill(nvg)

        nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], 255))
        nvgBeginPath(nvg)
        nvgCircle(nvg, tower.x, tower.y, tower.config.size)
        nvgFill(nvg)

        nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, 180))
        nvgStrokeWidth(nvg, 2)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, tower.x - 8, tower.y)
        nvgLineTo(nvg, tower.x + 8, tower.y)
        nvgMoveTo(nvg, tower.x, tower.y - 8)
        nvgLineTo(nvg, tower.x, tower.y + 8)
        nvgStroke(nvg)
    end

    -- 等级标签
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgFontSize(nvg, 10)
    nvgTextAlign(nvg, 1)
    nvgText(nvg, tower.x, tower.y + 4, "Lv" .. tower.level)
end

function Tower.DrawArcherTower(nvg, tower)
    local sp = Tower.sprites
    if not sp.building or sp.building <= 0 then return end

    -- 绘制塔建筑（128x256 原图，缩放到合适大小）
    local bldScale = 0.45
    local bldW = sp.buildingW * bldScale
    local bldH = sp.buildingH * bldScale
    -- tower.x/y 是塔的放置中心点，建筑底部对齐到该点
    local bldX = tower.x - bldW / 2
    local bldY = tower.y - bldH + bldH * 0.3  -- 底部略偏上，让点击点在建筑中下部

    local bldPaint = nvgImagePattern(nvg, bldX, bldY, bldW, bldH, 0, sp.building, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, bldX, bldY, bldW, bldH)
    nvgFillPaint(nvg, bldPaint)
    nvgFill(nvg)

    -- 绘制弓箭手（在塔顶部）
    local archerScale = 0.35
    local archerW = sp.frameW * archerScale
    local archerH = sp.frameH * archerScale
    -- 弓箭手居中放在塔顶部
    local archerCenterX = tower.x
    local archerCenterY = bldY + bldH * 0.1 + 25

    local isAttack = (tower.archerAnim == "attack")
    local imgHandle = isAttack and sp.archerAttack or sp.archerIdle
    local sheetW = isAttack and sp.sheetAttackW or sp.sheetIdleW
    local col = tower.archerFrame

    if not imgHandle or imgHandle <= 0 then return end

    local sx = col * sp.frameW
    local drawX = archerCenterX - archerW / 2
    local drawY = archerCenterY - archerH / 2

    nvgSave(nvg)

    -- 镜像：面朝左时翻转
    if tower.archerFacing < 0 then
        nvgTranslate(nvg, archerCenterX, archerCenterY)
        nvgScale(nvg, -1, 1)
        nvgTranslate(nvg, -archerCenterX, -archerCenterY)
    end

    local patternX = drawX - sx * archerScale
    local patternY = drawY
    local patternW = sheetW * archerScale
    local patternH = sp.sheetH * archerScale

    local paint = nvgImagePattern(nvg, patternX, patternY, patternW, patternH, 0, imgHandle, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, drawX, drawY, archerW, archerH)
    nvgFillPaint(nvg, paint)
    nvgFill(nvg)

    nvgRestore(nvg)
end

function Tower.SelectAt(x, y)
    Tower.selected = nil
    for i = #Tower.list, 1, -1 do
        local tower = Tower.list[i]
        local dx = x - tower.x
        local dy = y - tower.y
        if math.sqrt(dx * dx + dy * dy) <= tower.config.size + 10 then
            Tower.selected = tower
            return tower
        end
    end
    return nil
end

return Tower
