
local Path = require("scripts/Path")
local Utils = require("scripts/Utils")
local GridMap = require("scripts/GridMap")

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
    engineer = {
        name = "工兵",
        health = 70,
        speed = 95,
        reward = 20,
        damage = 1,
        size = 20,
        color = { 90, 160, 210, 255 },
        outline = { 200, 230, 255, 255 },
        isEngineer = true,
        attackRange = 50,
        attackDamage = 15,
        attackInterval = 0.8,
    },
    demolition = {
        name = "爆破兵",
        health = 120,
        speed = 65,
        reward = 28,
        damage = 2,
        size = 26,
        color = { 220, 130, 60, 255 },
        outline = { 255, 200, 150, 255 },
        isDemolition = true,
        attackRange = 60,
        attackDamage = 40,
        attackInterval = 1.5,
    },
}

function Enemy.Spawn(typeName, path, gridMap, currentRoute)
    local definition = Enemy.types[typeName]
    if not definition then
        return nil
    end

    local x, y
    if currentRoute and #currentRoute.nodes &gt; 0 then
        x, y = GridMap.GridToWorld(gridMap, currentRoute.nodes[1].x, currentRoute.nodes[1].y)
    else
        x, y = Path.GetPosition(path, 0)
    end

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
        routeIndex = 1,
        isEngineer = definition.isEngineer or false,
        isDemolition = definition.isDemolition or false,
        attackRange = definition.attackRange or 0,
        attackDamage = definition.attackDamage or 0,
        attackInterval = definition.attackInterval or 1.0,
        attackCooldown = 0,
        targetStructure = nil,
    }
end

function Enemy.Update(enemy, dt, path, gridMap, currentRoute, structures, Structure)
    if not enemy.alive then
        return
    end

    if enemy.hitFlash &gt; 0 then
        enemy.hitFlash = math.max(0, enemy.hitFlash - dt)
    end

    if enemy.slowTimer &gt; 0 then
        enemy.slowTimer = enemy.slowTimer - dt
        if enemy.slowTimer &lt;= 0 then
            enemy.slowTimer = 0
            enemy.slowFactor = 1.0
        end
    end

    if enemy.attackCooldown &gt; 0 then
        enemy.attackCooldown = enemy.attackCooldown - dt
    end

    if (enemy.isEngineer or enemy.isDemolition) and structures and Structure and #structures &gt; 0 then
        local nearestStructure = nil
        local nearestDist = math.huge
        local searchRadius = 300

        for _, structure in ipairs(structures) do
            if structure and structure.health &gt; 0 then
                local dist = Utils.DistanceSquared(enemy.x, enemy.y, structure.x, structure.y)
                if dist &lt; searchRadius * searchRadius and dist &lt; nearestDist then
                    nearestDist = dist
                    nearestStructure = structure
                end
            end
        end

        enemy.targetStructure = nearestStructure

        if nearestStructure then
            local dist = math.sqrt(Utils.DistanceSquared(enemy.x, enemy.y, nearestStructure.x, nearestStructure.y))
            if dist &lt;= enemy.attackRange then
                if enemy.attackCooldown &lt;= 0 then
                    Structure.Damage(nearestStructure, enemy.attackDamage)
                    enemy.attackCooldown = enemy.attackInterval
                    enemy.hitFlash = 0.1
                end
                return
            end
        end
    end

    if currentRoute and currentRoute.valid and #currentRoute.nodes &gt; 0 then
        local speed = enemy.speed * enemy.slowFactor
        local targetNode = currentRoute.nodes[enemy.routeIndex]

        if targetNode then
            local targetX, targetY = GridMap.GridToWorld(gridMap, targetNode.x, targetNode.y)
            local dx = targetX - enemy.x
            local dy = targetY - enemy.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist &lt; 5 then
                enemy.routeIndex = enemy.routeIndex + 1
                if enemy.routeIndex &gt; #currentRoute.nodes then
                    enemy.alive = false
                    enemy.escaped = true
                end
            else
                local moveDist = speed * dt
                if moveDist &gt; dist then
                    moveDist = dist
                end
                enemy.x = enemy.x + (dx / dist) * moveDist
                enemy.y = enemy.y + (dy / dist) * moveDist
            end
        end
    else
        local totalLength = Path.GetTotalLength(path)
        local speed = enemy.speed * enemy.slowFactor
        enemy.progress = enemy.progress + (speed * dt) / totalLength
        enemy.x, enemy.y = Path.GetPosition(path, enemy.progress)

        if enemy.progress &gt;= 1.0 then
            enemy.alive = false
            enemy.escaped = true
        end
    end
end

function Enemy.Damage(enemy, amount)
    if not enemy.alive then
        return false
    end

    enemy.health = enemy.health - amount
    enemy.hitFlash = 0.12

    if enemy.health &lt;= 0 then
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
    return Utils.DistanceSquared(enemy.x, enemy.y, x, y) &lt;= radius * radius
end

function Enemy.Draw(nvg, enemy, transform)
    if enemy.alive == false then
        return
    end

    local x, y = Utils.ToScreen(transform, enemy.x, enemy.y)
    local size = Utils.ToScreenSize(transform, enemy.size)
    local flash = enemy.hitFlash &gt; 0 and 45 or 0

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

    if enemy.slowTimer &gt; 0 then
        nvgBeginPath(nvg)
        nvgCircle(nvg, x, y, size * 0.72)
        nvgStrokeColor(nvg, nvgRGBA(150, 220, 255, 180))
        nvgStrokeWidth(nvg, math.max(1, size * 0.08))
        nvgStroke(nvg)
    end

    if enemy.isEngineer or enemy.isDemolition then
        nvgBeginPath(nvg)
        local iconSize = size * 0.4
        if enemy.isEngineer then
            nvgMoveTo(nvg, x - iconSize, y)
            nvgLineTo(nvg, x + iconSize, y)
            nvgMoveTo(nvg, x, y - iconSize)
            nvgLineTo(nvg, x, y + iconSize)
        else
            nvgCircle(nvg, x, y, iconSize * 0.5)
        end
        nvgStrokeColor(nvg, nvgRGBA(255, 255, 100, 200))
        nvgStrokeWidth(nvg, math.max(2, size * 0.1))
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
