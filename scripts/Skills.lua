
local Skills = {}

Skills.definitions = {
    whirlwind = {
        name = "旋风斩",
        icon = "ui/skill_whirlwind",
        manaCost = 30,
        cooldown = 6.0,
        maxLevel = 5,
        range = 80,
        desc = "对周围敌人造成伤害",
        levelDesc = {
            "80% 攻击力伤害",
            "100% 攻击力伤害",
            "120% 攻击力伤害",
            "150% 攻击力伤害 + 击退",
            "200% 攻击力伤害 + 击退",
        },
        damageMultiplier = { 0.8, 1.0, 1.2, 1.5, 2.0 },
        knockback = { 0, 0, 0, 30, 50 },
    },
    charge = {
        name = "冲锋",
        icon = "ui/skill_charge",
        manaCost = 25,
        cooldown = 8.0,
        maxLevel = 5,
        range = 200,
        desc = "向前冲刺，撞击敌人",
        levelDesc = {
            "150% 伤害，冲刺 120px",
            "175% 伤害，冲刺 140px",
            "200% 伤害，冲刺 160px",
            "225% 伤害，冲刺 180px",
            "300% 伤害，冲刺 200px + 眩晕",
        },
        damageMultiplier = { 1.5, 1.75, 2.0, 2.25, 3.0 },
        chargeDist = { 120, 140, 160, 180, 200 },
        stunDuration = { 0, 0, 0, 0, 1.0 },
    },
    war_cry = {
        name = "战吼",
        icon = "ui/skill_warcry",
        manaCost = 40,
        cooldown = 15.0,
        maxLevel = 5,
        range = 0,
        desc = "提升自身和附近防御塔属性",
        levelDesc = {
            "攻击+20%，持续5秒",
            "攻击+25%，持续6秒",
            "攻击+30%，持续7秒",
            "攻击+35%，防御+20%，持续8秒",
            "攻击+50%，防御+30%，持续10秒",
        },
        atkBonus = { 0.20, 0.25, 0.30, 0.35, 0.50 },
        defBonus = { 0, 0, 0, 0.20, 0.30 },
        duration = { 5, 6, 7, 8, 10 },
    },
    meteor = {
        name = "陨石",
        icon = "ui/skill_meteor",
        manaCost = 60,
        cooldown = 20.0,
        maxLevel = 5,
        range = 150,
        desc = "在目标区域召唤陨石",
        levelDesc = {
            "200% 伤害，范围 60px",
            "250% 伤害，范围 70px",
            "300% 伤害，范围 80px",
            "400% 伤害，范围 90px",
            "500% 伤害，范围 100px + 灼烧",
        },
        damageMultiplier = { 2.0, 2.5, 3.0, 4.0, 5.0 },
        aoeRadius = { 60, 70, 80, 90, 100 },
        burn = { false, false, false, false, true },
    },
}

Skills.slots = {
    { id = "whirlwind", level = 1, cooldownTimer = 0 },
    { id = "charge", level = 1, cooldownTimer = 0 },
    { id = "war_cry", level = 0, cooldownTimer = 0 },
    { id = "meteor", level = 0, cooldownTimer = 0 },
}

function Skills.Update(dt)
    for i, slot in ipairs(Skills.slots) do
        if slot.level > 0 and slot.cooldownTimer > 0 then
            slot.cooldownTimer = slot.cooldownTimer - dt
        end
    end
end

function Skills.Cast(slotIndex, targetX, targetY, enemies, towers)
    local slot = Skills.slots[slotIndex]
    if not slot or slot.level <= 0 then return false, 0, 0 end
    if slot.cooldownTimer > 0 then return false, 0, 0 end

    local def = Skills.definitions[slot.id]
    if Hero.state.mana < def.manaCost then return false, 0, 0 end

    Hero.state.mana = Hero.state.mana - def.manaCost
    slot.cooldownTimer = def.cooldown

    local level = slot.level
    local baseATK = Hero.config.baseATK + Hero.state.bonusATK
    local heroATK = math.floor(baseATK * (1 + (Hero.state._warCryATK or 0)))
    local reward = 0
    local kills = 0

    if slot.id == "whirlwind" then
        reward, kills = Skills.Whirlwind(heroATK, def, level, enemies)
    elseif slot.id == "charge" then
        reward, kills = Skills.Charge(heroATK, def, level, enemies)
    elseif slot.id == "war_cry" then
        Skills.WarCry(def, level, towers)
    elseif slot.id == "meteor" then
        reward, kills = Skills.Meteor(heroATK, def, level, targetX, targetY, enemies)
    end

    return true, reward, kills
end

function Skills.Whirlwind(heroATK, def, level, enemies)
    local mult = def.damageMultiplier[level]
    local damage = math.floor(heroATK * mult)
    local range = def.range
    local knockback = def.knockback[level]

    local reward = 0
    local kills = 0
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            local dx = enemy.x - Hero.state.x
            local dy = enemy.y - Hero.state.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < range then
                local enemyReward = Enemy.Damage(enemy, damage)
                Hero.state.totalDamage = Hero.state.totalDamage + damage
                Hero.ApplyDamageEffects(enemy, damage)
                if enemyReward then
                    reward = reward + enemyReward
                    kills = kills + 1
                end
                if knockback > 0 and dist > 0 then
                    enemy.x = enemy.x + (dx / dist) * knockback
                    enemy.y = enemy.y + (dy / dist) * knockback
                end
            end
        end
    end

    if Particle then
        Particle.Spawn("whirlwind", Hero.state.x, Hero.state.y, Hero.state.facing)
    end
    Hero.state.animState = "skill"
    Hero.state.animTimer = 0.5
    return reward, kills
end

function Skills.Charge(heroATK, def, level, enemies)
    local mult = def.damageMultiplier[level]
    local damage = math.floor(heroATK * mult)
    local dist = def.chargeDist[level]
    local stun = def.stunDuration[level]

    local reward = 0
    local kills = 0
    local startX = Hero.state.x
    Hero.state.x = math.max(20, math.min(Hero.state.x + Hero.state.facing * dist, 1430))

    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            local minX = math.min(startX, Hero.state.x) - 30
            local maxX = math.max(startX, Hero.state.x) + 30
            if enemy.x >= minX and enemy.x <= maxX
                and math.abs(enemy.y - Hero.state.y) < 40 then
                local enemyReward = Enemy.Damage(enemy, damage)
                Hero.state.totalDamage = Hero.state.totalDamage + damage
                Hero.ApplyDamageEffects(enemy, damage)
                if enemyReward then
                    reward = reward + enemyReward
                    kills = kills + 1
                end
                if stun > 0 then
                    enemy.stunTimer = stun
                end
            end
        end
    end

    if Particle then
        Particle.Spawn("charge", (startX + Hero.state.x) * 0.5, Hero.state.y, {
            facing = Hero.state.facing,
        })
    end
    Hero.state.animState = "skill"
    Hero.state.animTimer = 0.4
    return reward, kills
end

function Skills.WarCry(def, level, towers)
    local atkBonus = def.atkBonus[level]
    local defBonus = def.defBonus[level]
    local duration = def.duration[level]

    Hero.state._warCryATK = atkBonus
    Hero.state._warCryDEF = defBonus
    Hero.state._warCryTimer = duration

    for _, tower in ipairs(towers) do
        tower._warCryATK = atkBonus
        tower._warCryTimer = duration
    end

    if Particle then
        Particle.Spawn("buff", Hero.state.x, Hero.state.y, 0)
    end
    Hero.state.animState = "skill"
    Hero.state.animTimer = 0.6
end

function Skills.Meteor(heroATK, def, level, targetX, targetY, enemies)
    local mult = def.damageMultiplier[level]
    local damage = math.floor(heroATK * mult)
    local radius = def.aoeRadius[level]
    local burn = def.burn[level]

    local reward = 0
    local kills = 0
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            local dx = enemy.x - targetX
            local dy = enemy.y - targetY
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < radius then
                local enemyReward = Enemy.Damage(enemy, damage)
                Hero.state.totalDamage = Hero.state.totalDamage + damage
                Hero.ApplyDamageEffects(enemy, damage)
                if enemyReward then
                    reward = reward + enemyReward
                    kills = kills + 1
                end
                if burn then
                    enemy.burnTimer = 3.0
                    enemy.burnDamage = math.floor(heroATK * 0.3)
                end
            end
        end
    end

    if Particle then
        Particle.Spawn("meteor", targetX, targetY, 0)
    end
    return reward, kills
end

function Skills.Upgrade(slotIndex, gold)
    local slot = Skills.slots[slotIndex]
    if not slot then return false, gold end
    local def = Skills.definitions[slot.id]
    if slot.level >= def.maxLevel then return false, gold end
    local cost = 50 + slot.level * 30
    if gold < cost then return false, gold end
    gold = gold - cost
    slot.level = slot.level + 1
    return true, gold
end

return Skills
