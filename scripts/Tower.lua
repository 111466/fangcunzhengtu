local Utils = require("scripts/Utils")

local Tower = {}

Tower.types = {
    archer = {
        name = "弓箭塔",
        cost = 50,
        damage = 22,
        range = 155,
        fireRate = 1.1,
        projectileSpeed = 340,
        projectileRadius = 5,
        projectileColor = { 220, 215, 150, 255 },
        size = 28,
        color = { 90, 150, 250, 255 },
        outline = { 220, 235, 255, 255 },
    },
    warrior = {
        name = "战士塔",
        cost = 80,
        damage = 42,
        range = 72,
        fireRate = 0.9,
        projectileSpeed = 0,
        splash = 48,
        size = 32,
        color = { 100, 205, 120, 255 },
        outline = { 225, 255, 225, 255 },
    },
    monk = {
        name = "僧侣塔",
        cost = 95,
        damage = 12,
        range = 140,
        fireRate = 0.65,
        projectileSpeed = 220,
        projectileRadius = 6,
        projectileColor = { 255, 235, 180, 255 },
        slowFactor = 0.55,
        slowDuration = 1.8,
        size = 26,
        color = { 245, 205, 90, 255 },
        outline = { 255, 245, 210, 255 },
    },
}

local function selectTarget(tower, enemies)
    local bestEnemy = nil
    local bestProgress = -1
    local rangeSquared = tower.range * tower.range

    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            local distanceSquared = Utils.DistanceSquared(tower.x, tower.y, enemy.x, enemy.y)
            if distanceSquared <= rangeSquared and enemy.progress > bestProgress then
                bestEnemy = enemy
                bestProgress = enemy.progress
            end
        end
    end

    return bestEnemy
end

local function dealSplashDamage(centerEnemy, enemies, radius, damage, enemyApi)
    local splashRadiusSquared = radius * radius
    for _, enemy in ipairs(enemies) do
        if enemy ~= centerEnemy and enemy.alive then
            local distanceSquared = Utils.DistanceSquared(centerEnemy.x, centerEnemy.y, enemy.x, enemy.y)
            if distanceSquared <= splashRadiusSquared then
                enemyApi.Damage(enemy, damage)
            end
        end
    end
end

function Tower.Create(typeName, x, y)
    local definition = Tower.types[typeName]
    if not definition then
        return nil
    end

    return {
        type = typeName,
        name = definition.name,
        x = x,
        y = y,
        level = 1,
        cooldown = 0,
        damage = definition.damage,
        range = definition.range,
        fireRate = definition.fireRate,
        projectileSpeed = definition.projectileSpeed,
        projectileRadius = definition.projectileRadius or 0,
        projectileColor = definition.projectileColor,
        splash = definition.splash or 0,
        slowFactor = definition.slowFactor,
        slowDuration = definition.slowDuration,
        size = definition.size,
        color = definition.color,
        outline = definition.outline,
        baseCost = definition.cost,
        target = nil,
        pulseTimer = 0,
    }
end

function Tower.GetCost(typeName)
    local definition = Tower.types[typeName]
    if definition then
        return definition.cost
    end
    return 0
end

function Tower.GetUpgradeCost(tower)
    return math.floor(tower.baseCost * (0.9 + tower.level * 0.85))
end

function Tower.CanUpgrade(tower)
    return tower.level < 3
end

function Tower.Upgrade(tower)
    if not Tower.CanUpgrade(tower) then
        return false
    end

    tower.level = tower.level + 1
    tower.damage = math.floor(tower.damage * 1.45)
    tower.range = tower.range * 1.12
    tower.fireRate = tower.fireRate * 1.08
    tower.pulseTimer = 0.18
    return true
end

function Tower.Update(tower, dt, enemies, spawnProjectile, enemyApi)
    if tower.pulseTimer > 0 then
        tower.pulseTimer = math.max(0, tower.pulseTimer - dt)
    end

    tower.cooldown = tower.cooldown - dt
    tower.target = selectTarget(tower, enemies)

    if not tower.target or tower.cooldown > 0 then
        return
    end

    tower.cooldown = 1.0 / tower.fireRate
    tower.pulseTimer = 0.12

    if tower.projectileSpeed > 0 then
        spawnProjectile({
            x = tower.x,
            y = tower.y,
            target = tower.target,
            damage = tower.damage,
            speed = tower.projectileSpeed,
            radius = tower.projectileRadius,
            color = tower.projectileColor,
            splash = tower.splash,
            slowFactor = tower.slowFactor,
            slowDuration = tower.slowDuration,
        })
        return
    end

    enemyApi.Damage(tower.target, tower.damage)
    if tower.splash > 0 then
        dealSplashDamage(tower.target, enemies, tower.splash, tower.damage * 0.5, enemyApi)
    end
end

function Tower.ContainsPoint(tower, x, y)
    return Utils.PointInCircle(x, y, tower.x, tower.y, tower.size * 0.8)
end

function Tower.Draw(nvg, tower, transform, selected)
    local x, y = Utils.ToScreen(transform, tower.x, tower.y)
    local size = Utils.ToScreenSize(transform, tower.size)
    local pulseScale = 1.0 + tower.pulseTimer * 0.45
    local half = size * 0.5 * pulseScale

    nvgBeginPath(nvg)
    nvgRect(nvg, x - half, y - half, half * 2, half * 2)
    nvgFillColor(nvg, nvgRGBA(tower.color[1], tower.color[2], tower.color[3], tower.color[4]))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(tower.outline[1], tower.outline[2], tower.outline[3], tower.outline[4]))
    nvgStrokeWidth(nvg, math.max(2, size * 0.12))
    nvgStroke(nvg)

    nvgBeginPath(nvg)
    nvgMoveTo(nvg, x, y - half * 0.9)
    nvgLineTo(nvg, x + half * 0.9, y)
    nvgLineTo(nvg, x, y + half * 0.9)
    nvgLineTo(nvg, x - half * 0.9, y)
    nvgClosePath(nvg)
    nvgStrokeColor(nvg, nvgRGBA(18, 24, 28, 160))
    nvgStrokeWidth(nvg, math.max(1, size * 0.07))
    nvgStroke(nvg)

    if selected then
        nvgBeginPath(nvg)
        nvgCircle(nvg, x, y, Utils.ToScreenSize(transform, tower.range))
        nvgStrokeColor(nvg, nvgRGBA(255, 235, 140, 180))
        nvgStrokeWidth(nvg, math.max(2, size * 0.08))
        nvgStroke(nvg)
    end
end

return Tower
