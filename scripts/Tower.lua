
local Tower = {}
Tower.list = {}
Tower.selected = nil

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

        if tower.config.chain then
            local reward, kills = Tower.ChainLightning(tower, closest, dmg)
            totalReward = totalReward + reward
            totalKills = totalKills + kills
        elseif Projectile then
            Projectile.Create(
                tower.x, tower.y, closest, dmg,
                tower.config.projectileSpeed,
                tower.config.color,
                tower.config.slow or false,
                tower.config.slowDuration or 0,
                tower.config.slowFactor or 1.0,
                tower.config.splash or 0
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

    if Tower.selected == tower then
        nvgStrokeColor(nvg, nvgRGBA(255, 240, 140, 255))
        nvgStrokeWidth(nvg, 3)
        nvgBeginPath(nvg)
        nvgCircle(nvg, tower.x, tower.y, tower.range)
        nvgStroke(nvg)
    end

    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgFontSize(nvg, 10)
    nvgTextAlign(nvg, 1)
    nvgText(nvg, tower.x, tower.y + 4, "Lv" .. tower.level)
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
