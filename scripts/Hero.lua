
local Hero = {}

Hero.config = {
    moveSpeed = 200,
    baseHP = 500,
    baseATK = 40,
    baseDEF = 15,
    attackRange = 60,
    attackSpeed = 1.5,
    attackCooldown = 0,
    maxMana = 100,
    manaRegen = 5,
    invincibleTime = 0.5,
    size = 28,
}

Hero.state = {
    x = 640,
    y = 360,
    vx = 0, vy = 0,
    hp = Hero.config.baseHP,
    maxHP = Hero.config.baseHP,
    mana = 0,
    alive = true,
    facing = 1,
    animState = "idle",
    animTimer = 0,
    invincibleTimer = 0,
    bonusATK = 0,
    bonusDEF = 0,
    bonusHP = 0,
    bonusSpeed = 0,
    killCount = 0,
    totalDamage = 0,
    skills = {},
    skillSlots = { nil, nil, nil, nil },
    equipment = {},
    attackCooldown = 0,
    burnOnHit = false,
    lifesteal = 0,
    manaRegenMul = 1.0,
    thorns = 0,
}

function Hero.Init()
    local s = Hero.state
    s.x = 640
    s.y = 360
    s.hp = s.maxHP
    s.mana = 0
    s.alive = true
    s.killCount = 0
    s.totalDamage = 0
    s.invincibleTimer = 0
    s.vx = 0
    s.vy = 0
    s.attackCooldown = 0
    s.animState = "idle"
    s.bonusATK = 0
    s.bonusDEF = 0
    s.bonusHP = 0
    s.bonusSpeed = 0
    s.burnOnHit = false
    s.lifesteal = 0
    s.manaRegenMul = 1.0
    s.thorns = 0
    Hero.RecalcStats()
end

function Hero.Update(dt)
    local s = Hero.state
    if not s.alive then return end

    if s.invincibleTimer > 0 then
        s.invincibleTimer = s.invincibleTimer - dt
    end

    if s._warCryTimer and s._warCryTimer > 0 then
        s._warCryTimer = s._warCryTimer - dt
        if s._warCryTimer <= 0 then
            s._warCryATK = 0
            s._warCryDEF = 0
        end
    end

    s.mana = math.min(Hero.config.maxMana, s.mana + Hero.config.manaRegen * (s.manaRegenMul or 1.0) * dt)

    s.attackCooldown = s.attackCooldown - dt

    s.animTimer = s.animTimer - dt
    if s.animTimer <= 0 and s.animState ~= "idle" and s.animState ~= "run" then
        s.animState = "idle"
    end

    local speed = Hero.config.moveSpeed + s.bonusSpeed
    s.x = s.x + s.vx * speed * dt
    s.y = s.y + s.vy * speed * dt

    s.x = math.max(20, math.min(s.x, 1430))
    s.y = math.max(20, math.min(s.y, 700))

    if math.abs(s.vx) > 0.01 or math.abs(s.vy) > 0.01 then
        s.animState = "run"
        if s.vx > 0.1 then s.facing = 1
        elseif s.vx < -0.1 then s.facing = -1
        end
    elseif s.animState == "run" then
        s.animState = "idle"
    end
end

function Hero.Attack(enemies)
    local s = Hero.state
    if not s.alive or s.attackCooldown > 0 then return 0, 0 end

    local baseATK = Hero.config.baseATK + s.bonusATK
    local totalATK = math.floor(baseATK * (1 + (s._warCryATK or 0)))

    local closest = nil
    local closestDist = Hero.config.attackRange
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            local dx = enemy.x - s.x
            local dy = enemy.y - s.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < closestDist then
                closestDist = dist
                closest = enemy
            end
        end
    end

    if closest then
        local reward = Enemy.Damage(closest, totalATK)
        s.attackCooldown = 1.0 / Hero.config.attackSpeed
        s.animState = "attack"
        s.animTimer = 0.25
        s.totalDamage = s.totalDamage + totalATK

        if closest.x > s.x then s.facing = 1
        else s.facing = -1 end

        if Particle then
            Particle.Spawn("slash", (s.x + closest.x) * 0.5, (s.y + closest.y) * 0.5, {
                facing = s.facing,
                startX = s.x + s.facing * 18,
                startY = s.y - 14,
                endX = closest.x,
                endY = closest.y - 8,
            })
        end

        Hero.ApplyDamageEffects(closest, totalATK)
        return reward or 0, reward and 1 or 0
    end
    return 0, 0
end

function Hero.TakeDamage(amount, source)
    local s = Hero.state
    if not s.alive or s.invincibleTimer > 0 then return 0 end

    local baseDEF = Hero.config.baseDEF + s.bonusDEF
    local totalDEF = math.floor(baseDEF * (1 + (s._warCryDEF or 0)))
    local reduction = totalDEF / (totalDEF + 80)
    local damage = math.floor(amount * (1 - reduction))

    s.hp = s.hp - damage
    s.invincibleTimer = Hero.config.invincibleTime
    s.animState = "hit"
    s.animTimer = 0.2

    if Particle then
        Particle.Spawn("hit", s.x, s.y - 10, 0)
    end

    if source and source.alive and s.thorns and s.thorns > 0 then
        Enemy.Damage(source, math.max(1, math.floor(damage * s.thorns)))
    end

    if s.hp <= 0 then
        s.hp = 0
        s.alive = false
        s.animState = "die"
        s.animTimer = 1.0
        if Particle then
            Particle.Spawn("death", s.x, s.y, 0)
        end
    end
    return damage
end

function Hero.Heal(amount)
    local s = Hero.state
    if not s.alive then return end
    s.hp = math.min(s.maxHP, s.hp + amount)
end

function Hero.RecalcStats()
    local s = Hero.state
    s.bonusATK = 0
    s.bonusDEF = 0
    s.bonusHP = 0
    s.bonusSpeed = 0
    s.burnOnHit = false
    s.lifesteal = 0
    s.manaRegenMul = 1.0
    s.thorns = 0
    if s.equipment and Equipment then
        for _, itemId in pairs(s.equipment) do
            local item = Equipment.items[itemId]
            if item and item.stats then
                if item.stats.atk then s.bonusATK = s.bonusATK + item.stats.atk end
                if item.stats.def then s.bonusDEF = s.bonusDEF + item.stats.def end
                if item.stats.hp then s.bonusHP = s.bonusHP + item.stats.hp end
                if item.stats.speed then s.bonusSpeed = s.bonusSpeed + item.stats.speed end
                if item.special == "burn" then s.burnOnHit = true end
                if item.special == "mana_regen" then s.manaRegenMul = 1.5 end
                if item.special == "lifesteal" then s.lifesteal = 0.10 end
                if item.special == "thorns" then s.thorns = 0.25 end
            end
        end
    end
    s.maxHP = Hero.config.baseHP + s.bonusHP
    s.hp = math.min(s.hp, s.maxHP)
end

function Hero.ApplyDamageEffects(enemy, damage)
    local s = Hero.state
    if not enemy then return end
    if s.burnOnHit and enemy.alive then
        enemy.burnTimer = math.max(enemy.burnTimer or 0, 2.5)
        enemy.burnDamage = math.max(enemy.burnDamage or 0, math.max(4, math.floor(damage * 0.18)))
    end
    if s.lifesteal and s.lifesteal > 0 then
        Hero.Heal(math.max(1, math.floor(damage * s.lifesteal)))
    end
end

function Hero.Draw(nvg)
    local s = Hero.state
    if not s.alive then return end

    local flash = s.invincibleTimer > 0 and math.floor(s.invincibleTimer * 10) % 2 == 0

    nvgSave(nvg)
    nvgTranslate(nvg, s.x, s.y)

    nvgFillColor(nvg, nvgRGBA(50, 100, 200, flash and 150 or 255))
    nvgBeginPath(nvg)
    nvgCircle(nvg, 0, 0, Hero.config.size)
    nvgFill(nvg)

    nvgFillColor(nvg, nvgRGBA(200, 200, 200, flash and 150 or 255))
    nvgBeginPath(nvg)
    nvgCircle(nvg, 0, -10, 12)
    nvgFill(nvg)

    nvgFillColor(nvg, nvgRGBA(30, 30, 30, 255))
    nvgBeginPath(nvg)
    nvgCircle(nvg, s.facing * 4, -12, 3)
    nvgFill(nvg)

    nvgStrokeColor(nvg, nvgRGBA(150, 100, 50, 255))
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, s.facing * 25, -5)
    nvgLineTo(nvg, s.facing * 45, -15)
    nvgStrokeWidth(nvg, 4)
    nvgStroke(nvg)

    nvgRestore(nvg)
end

return Hero
