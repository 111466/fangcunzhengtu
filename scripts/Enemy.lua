
local Enemy = {}
Enemy.list = {}

Enemy.types = {
    grunt = {
        name = "哥布林", hp = 80, speed = 70, reward = 5,
        damage = 5, size = 20, color = {200, 50, 50},
    },
    runner = {
        name = "暗影跑者", hp = 50, speed = 140, reward = 8,
        damage = 3, size = 18, color = {150, 50, 200},
    },
    brute = {
        name = "石巨人", hp = 400, speed = 35, reward = 20,
        damage = 15, size = 34, color = {80, 80, 80},
    },
    archer = {
        name = "暗黑弓手", hp = 60, speed = 60, reward = 10,
        damage = 8, size = 22, color = {50, 150, 50},
        ranged = true, attackRange = 150, attackSpeed = 0.8,
    },
    boss = {
        name = "魔王", hp = 2000, speed = 40, reward = 100,
        damage = 30, size = 44, color = {180, 30, 30},
        skills = {"summon", "aoe_slam"},
    },
}

function Enemy.Create(typeName, route)
    local config = Enemy.types[typeName]
    if not config then return nil end

    local enemy = {
        typeName = typeName,
        config = config,
        hp = config.hp,
        maxHP = config.hp,
        progress = 0,
        x = 0, y = 0,
        alive = true,
        route = route,
        stunTimer = 0,
        burnTimer = 0,
        burnDamage = 0,
        attackCooldown = 0,
        canAttack = config.ranged or false,
        _slowFactor = 1.0,
        _slowTimer = 0,
    }

    enemy.x, enemy.y = Path.GetPosition(route, 0)
    table.insert(Enemy.list, enemy)
    return enemy
end

function Enemy.UpdateAll(dt, heroState)
    for i = #Enemy.list, 1, -1 do
        local e = Enemy.list[i]
        if not e.alive then
            table.remove(Enemy.list, i)
        else
            Enemy.Update(e, dt, heroState)
        end
    end
end

function Enemy.Update(enemy, dt, heroState)
    if enemy._slowTimer > 0 then
        enemy._slowTimer = enemy._slowTimer - dt
    else
        enemy._slowFactor = 1.0
    end

    if enemy.stunTimer > 0 then
        enemy.stunTimer = enemy.stunTimer - dt
        return
    end

    if enemy.burnTimer > 0 then
        enemy.burnTimer = enemy.burnTimer - dt
        enemy.hp = enemy.hp - enemy.burnDamage * dt
        if enemy.hp <= 0 then
            enemy.alive = false
            if Particle then
                Particle.Spawn("death", enemy.x, enemy.y, 0)
            end
            return enemy.config.reward
        end
    end

    local reward = nil

    if enemy.canAttack then
        local dx = heroState.x - enemy.x
        local dy = heroState.y - enemy.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist < enemy.config.attackRange then
            enemy.attackCooldown = enemy.attackCooldown - dt
            if enemy.attackCooldown <= 0 then
                enemy.attackCooldown = 1.0 / enemy.config.attackSpeed
                if Projectile then
                    Projectile.Create(enemy.x, enemy.y, heroState,
                        enemy.config.damage, 200, {200, 50, 50},
                        false, 0, 1.0, 0, enemy)
                end
            end
            return
        end
    end

    local speed = enemy.config.speed * enemy._slowFactor
    local totalLen = Path.GetRouteLength(enemy.route)
    enemy.progress = enemy.progress + (speed * dt) / totalLen
    enemy.x, enemy.y = Path.GetPosition(enemy.route, enemy.progress)

    if heroState.alive then
        local dx = heroState.x - enemy.x
        local dy = heroState.y - enemy.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist < (Hero.config.size + enemy.config.size) * 0.5 then
            Hero.TakeDamage(enemy.config.damage * 0.5, enemy)
        end
    end

    if enemy.progress >= 1.0 then
        enemy.alive = false
        return -1
    end
end

function Enemy.Damage(enemy, amount)
    if not enemy.alive then return nil end
    enemy.hp = enemy.hp - amount
    if Particle then
        Particle.Spawn("hit", enemy.x, enemy.y - 5, 0)
    end
    if enemy.hp <= 0 then
        enemy.alive = false
        if Particle then
            Particle.Spawn("death", enemy.x, enemy.y, 0)
        end
        return enemy.config.reward
    end
    return nil
end

function Enemy.DrawAll(nvg)
    for _, enemy in ipairs(Enemy.list) do
        if enemy.alive then
            Enemy.Draw(nvg, enemy)
        end
    end
end

function Enemy.Draw(nvg, enemy)
    local c = enemy.config
    local size = c.size

    nvgFillColor(nvg, nvgRGBA(c.color[1], c.color[2], c.color[3], 255))
    nvgBeginPath(nvg)
    nvgCircle(nvg, enemy.x, enemy.y, size)
    nvgFill(nvg)

    nvgStrokeColor(nvg, nvgRGBA(35, 35, 35, 240))
    nvgStrokeWidth(nvg, 3)
    nvgBeginPath(nvg)
    nvgCircle(nvg, enemy.x, enemy.y, size)
    nvgStroke(nvg)

    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, 160))
    nvgStrokeWidth(nvg, 2)
    if enemy.typeName == "grunt" then
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, enemy.x - size * 0.45, enemy.y + size * 0.1)
        nvgLineTo(nvg, enemy.x + size * 0.45, enemy.y + size * 0.1)
        nvgStroke(nvg)
    elseif enemy.typeName == "runner" then
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, enemy.x - size * 0.4, enemy.y + size * 0.15)
        nvgLineTo(nvg, enemy.x + size * 0.5, enemy.y - size * 0.2)
        nvgMoveTo(nvg, enemy.x - size * 0.35, enemy.y + size * 0.35)
        nvgLineTo(nvg, enemy.x + size * 0.55, enemy.y)
        nvgStroke(nvg)
    elseif enemy.typeName == "brute" then
        nvgBeginPath(nvg)
        nvgRect(nvg, enemy.x - size * 0.4, enemy.y - size * 0.15, size * 0.8, size * 0.45)
        nvgStroke(nvg)
    elseif enemy.typeName == "archer" then
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, enemy.x - size * 0.35, enemy.y + size * 0.35)
        nvgLineTo(nvg, enemy.x + size * 0.3, enemy.y - size * 0.25)
        nvgMoveTo(nvg, enemy.x + size * 0.05, enemy.y - size * 0.2)
        nvgLineTo(nvg, enemy.x + size * 0.2, enemy.y + size * 0.25)
        nvgStroke(nvg)
    elseif enemy.typeName == "boss" then
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, enemy.x - size * 0.5, enemy.y - size * 0.6)
        nvgLineTo(nvg, enemy.x - size * 0.2, enemy.y - size * 0.2)
        nvgLineTo(nvg, enemy.x, enemy.y - size * 0.55)
        nvgLineTo(nvg, enemy.x + size * 0.2, enemy.y - size * 0.2)
        nvgLineTo(nvg, enemy.x + size * 0.5, enemy.y - size * 0.6)
        nvgStroke(nvg)
    end

    nvgFillColor(nvg, nvgRGBA(255, 245, 235, 230))
    nvgBeginPath(nvg)
    nvgCircle(nvg, enemy.x - size * 0.22, enemy.y - size * 0.15, math.max(2, size * 0.12))
    nvgCircle(nvg, enemy.x + size * 0.22, enemy.y - size * 0.15, math.max(2, size * 0.12))
    nvgFill(nvg)

    nvgFillColor(nvg, nvgRGBA(30, 30, 30, 255))
    nvgBeginPath(nvg)
    nvgCircle(nvg, enemy.x - size * 0.22, enemy.y - size * 0.15, math.max(1, size * 0.05))
    nvgCircle(nvg, enemy.x + size * 0.22, enemy.y - size * 0.15, math.max(1, size * 0.05))
    nvgFill(nvg)

    local hpRatio = enemy.hp / enemy.maxHP
    local barW = size * 2
    nvgFillColor(nvg, nvgRGBA(40, 40, 40, 200))
    nvgBeginPath(nvg)
    nvgRect(nvg, enemy.x - barW/2, enemy.y - size - 12, barW, 6)
    nvgFill(nvg)
    
    nvgFillColor(nvg, nvgRGBA(
        hpRatio > 0.5 and 80 or (hpRatio > 0.25 and 220 or 220),
        hpRatio > 0.5 and 200 or (hpRatio > 0.25 and 180 or 50),
        hpRatio > 0.5 and 80 or (hpRatio > 0.25 and 40 or 50), 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, enemy.x - barW/2, enemy.y - size - 12, barW * hpRatio, 6)
    nvgFill(nvg)

    if enemy.burnTimer > 0 then
        nvgFillColor(nvg, nvgRGBA(255, 150, 50, 150))
        nvgBeginPath(nvg)
        nvgCircle(nvg, enemy.x, enemy.y - size - 20, 5)
        nvgFill(nvg)
    end
end

return Enemy
