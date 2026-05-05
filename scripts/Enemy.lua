local Path = require("scripts/Path")
local Utils = require("scripts/Utils")

local Enemy = {}

Enemy.types = {
    grunt = {
        name = "步兵",
        health = 90,
        speed = 88,
        reward = 12,
        damage = 1,
        size = 22,
        color = { 210, 90, 90, 255 },
        outline = { 255, 210, 210, 255 },
    },
    scout = {
        name = "斥候",
        health = 60,
        speed = 145,
        reward = 16,
        damage = 1,
        size = 18,
        color = { 170, 90, 220, 255 },
        outline = { 235, 210, 255, 255 },
    },
    tank = {
        name = "重甲",
        health = 300,
        speed = 48,
        reward = 35,
        damage = 3,
        size = 30,
        color = { 80, 80, 90, 255 },
        outline = { 220, 220, 220, 255 },
    },
}

function Enemy.Spawn(typeName, path)
    local definition = Enemy.types[typeName]
    if not definition then
        return nil
    end

    local x, y = Path.GetPosition(path, 0)
    return {
        type = typeName,
        name = definition.name,
        maxHealth = definition.health,
        health = definition.health,
        speed = definition.speed,
        reward = definition.reward,
        damage = definition.damage,
        size = definition.size,
        color = definition.color,
        outline = definition.outline,
        progress = 0,
        x = x,
        y = y,
        alive = true,
        killed = false,
        escaped = false,
        slowFactor = 1.0,
        slowTimer = 0,
        hitFlash = 0,
    }
end

function Enemy.Update(enemy, dt, path)
    if not enemy.alive then
        return
    end

    if enemy.hitFlash > 0 then
        enemy.hitFlash = math.max(0, enemy.hitFlash - dt)
    end

    if enemy.slowTimer > 0 then
        enemy.slowTimer = enemy.slowTimer - dt
        if enemy.slowTimer <= 0 then
            enemy.slowTimer = 0
            enemy.slowFactor = 1.0
        end
    end

    local totalLength = Path.GetTotalLength(path)
    local speed = enemy.speed * enemy.slowFactor
    enemy.progress = enemy.progress + (speed * dt) / totalLength
    enemy.x, enemy.y = Path.GetPosition(path, enemy.progress)

    if enemy.progress >= 1.0 then
        enemy.alive = false
        enemy.escaped = true
    end
end

function Enemy.Damage(enemy, amount)
    if not enemy.alive then
        return false
    end

    enemy.health = enemy.health - amount
    enemy.hitFlash = 0.12

    if enemy.health <= 0 then
        enemy.health = 0
        enemy.alive = false
        enemy.killed = true
        return true
    end

    return false
end

function Enemy.ApplySlow(enemy, factor, duration)
    if not enemy.alive then
        return
    end

    enemy.slowFactor = math.min(enemy.slowFactor, factor)
    enemy.slowTimer = math.max(enemy.slowTimer, duration)
end

function Enemy.IsInRange(enemy, x, y, radius)
    if not enemy.alive then
        return false
    end
    return Utils.DistanceSquared(enemy.x, enemy.y, x, y) <= radius * radius
end

function Enemy.Draw(nvg, enemy, transform)
    if enemy.alive == false then
        return
    end

    local x, y = Utils.ToScreen(transform, enemy.x, enemy.y)
    local size = Utils.ToScreenSize(transform, enemy.size)
    local flash = enemy.hitFlash > 0 and 45 or 0

    nvgBeginPath(nvg)
    nvgRect(nvg, x - size * 0.5, y - size * 0.5, size, size)
    nvgFillColor(nvg, nvgRGBA(
        math.min(255, enemy.color[1] + flash),
        math.min(255, enemy.color[2] + flash),
        math.min(255, enemy.color[3] + flash),
        enemy.color[4]
    ))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(enemy.outline[1], enemy.outline[2], enemy.outline[3], enemy.outline[4]))
    nvgStrokeWidth(nvg, math.max(2, size * 0.12))
    nvgStroke(nvg)

    if enemy.slowTimer > 0 then
        nvgBeginPath(nvg)
        nvgCircle(nvg, x, y, size * 0.72)
        nvgStrokeColor(nvg, nvgRGBA(150, 220, 255, 180))
        nvgStrokeWidth(nvg, math.max(1, size * 0.08))
        nvgStroke(nvg)
    end

    local barWidth = size * 1.4
    local barHeight = math.max(4, size * 0.16)
    local ratio = enemy.health / enemy.maxHealth

    nvgBeginPath(nvg)
    nvgRect(nvg, x - barWidth * 0.5, y - size * 0.9, barWidth, barHeight)
    nvgFillColor(nvg, nvgRGBA(20, 20, 20, 180))
    nvgFill(nvg)

    nvgBeginPath(nvg)
    nvgRect(nvg, x - barWidth * 0.5, y - size * 0.9, barWidth * ratio, barHeight)
    nvgFillColor(nvg, nvgRGBA(110, 230, 120, 220))
    nvgFill(nvg)
end

return Enemy
