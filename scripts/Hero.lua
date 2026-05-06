
local Config = require("scripts.Config")

local Hero = {}

-- 精灵图配置
Hero.sprite = {
    image = nil,       -- nvg 图片句柄
    cols = 6,          -- 6 列
    rows = 10,         -- 10 行
    frameW = 32,       -- 每帧宽度
    frameH = 32,       -- 每帧高度
    sheetW = 192,      -- 总宽度
    sheetH = 320,      -- 总高度
    scale = 2.0,       -- 显示放大倍数（32*2=64像素）
    frameTime = 0.15,  -- 每帧播放间隔
    currentFrame = 0,  -- 当前帧索引 (0-5)
    frameTimer = 0,    -- 帧计时器
    -- 行映射: 方向 + 动作 → 精灵图行号 (0-based)
    rows_map = {
        idle_down  = 0,
        idle_right = 1,
        idle_up    = 2,
        walk_down  = 3,
        walk_right = 4,
        walk_up    = 5,
        attack_down  = 6,
        attack_right = 7,
        attack_up    = 8,
        die = 9,
    },
    -- 每行有效帧数（默认6，攻击和死亡只有前4帧）
    frameCounts = {
        attack_down  = 4,
        attack_right = 4,
        attack_up    = 4,
        die = 4,
    },
}

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
    direction = "down", -- "down","right","up","left"
    skills = {},
    skillSlots = { nil, nil, nil, nil },
    attackCooldown = 0,
    burnOnHit = false,
    lifesteal = 0,
    manaRegenMul = 1.0,
    thorns = 0,
}

--- 加载精灵图（需要在 Start 中 nvg 创建后调用）
---@param nvg NVGContextWrapper
function Hero.LoadSprite(nvg)
    if not Hero.sprite.image or Hero.sprite.image <= 0 then
        Hero.sprite.image = nvgCreateImage(nvg, "image/hero_spritesheet.png", 0)
        if Hero.sprite.image and Hero.sprite.image > 0 then
            print("[Hero] Sprite sheet loaded (handle=" .. Hero.sprite.image .. ")")
        else
            print("[Hero] WARNING: Failed to load sprite sheet")
        end
    end
end

function Hero.Init(spawnConfig)
    local s = Hero.state
    s.x = spawnConfig and spawnConfig.x or Config.HERO_SPAWN.x
    s.y = spawnConfig and spawnConfig.y or Config.HERO_SPAWN.y
    s.mana = 0
    s.alive = true
    s.killCount = 0
    s.totalDamage = 0
    s.invincibleTimer = 0
    s.vx = 0
    s.vy = 0
    s.attackCooldown = 0
    s.animState = "idle"
    s.animTimer = 0
    s.direction = "down"
    Hero.sprite.currentFrame = 0
    Hero.sprite.frameTimer = 0
    s.bonusATK = 0
    s.bonusDEF = 0
    s.bonusHP = 0
    s.bonusSpeed = 0
    s.burnOnHit = false
    s.lifesteal = 0
    s.manaRegenMul = 1.0
    s.thorns = 0
    s._warCryATK = 0
    s._warCryDEF = 0
    s._warCryTimer = 0
    Hero.RecalcStats()
    s.hp = s.maxHP
end

--- 根据当前动画状态和朝向，返回精灵图行键名
function Hero._getCurrentRowKey()
    local s = Hero.state
    local dir = s.direction
    if dir == "left" then dir = "right" end

    if s.animState == "die" then
        return "die"
    elseif s.animState == "attack" then
        return "attack_" .. dir
    elseif s.animState == "run" then
        return "walk_" .. dir
    else
        return "idle_" .. dir
    end
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

    s.x = math.max(20, math.min(s.x, Config.WORLD_WIDTH - 20))
    s.y = math.max(20, math.min(s.y, Config.WORLD_HEIGHT - 20))

    if math.abs(s.vx) > 0.01 or math.abs(s.vy) > 0.01 then
        -- 攻击/受击/死亡动画播放中不被移动覆盖
        if s.animState ~= "attack" and s.animState ~= "hit" and s.animState ~= "die" then
            s.animState = "run"
        end
        -- 根据移动方向确定朝向（优先水平方向）
        if math.abs(s.vx) >= math.abs(s.vy) then
            if s.vx > 0.01 then
                s.direction = "right"
                s.facing = 1
            elseif s.vx < -0.01 then
                s.direction = "left"
                s.facing = -1
            end
        else
            if s.vy > 0.01 then
                s.direction = "down"
            elseif s.vy < -0.01 then
                s.direction = "up"
            end
        end
    elseif s.animState == "run" then
        s.animState = "idle"
    end

    -- 更新精灵帧动画
    local sp = Hero.sprite
    sp.frameTimer = sp.frameTimer + dt
    if sp.frameTimer >= sp.frameTime then
        sp.frameTimer = sp.frameTimer - sp.frameTime
        -- 根据当前动画行确定有效帧数
        local rowKey = Hero._getCurrentRowKey()
        local maxFrames = sp.frameCounts[rowKey] or sp.cols
        sp.currentFrame = (sp.currentFrame + 1) % maxFrames
    end
end

function Hero.Attack(enemies)
    local s = Hero.state
    if not s.alive or s.attackCooldown > 0 then return 0, 0 end

    local baseATK = Hero.config.baseATK + s.bonusATK
    local totalATK = math.floor(baseATK * (1 + (s._warCryATK or 0)))

    -- 无论是否命中敌人，都播放攻击动画并进入冷却
    s.attackCooldown = 1.0 / Hero.config.attackSpeed
    s.animState = "attack"
    s.animTimer = 0.25

    -- 查找范围内最近的敌人
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
        s.totalDamage = s.totalDamage + totalATK

        -- 更新朝向：面朝敌人
        local adx = closest.x - s.x
        local ady = closest.y - s.y
        if math.abs(adx) >= math.abs(ady) then
            if adx > 0 then
                s.direction = "right"
                s.facing = 1
            else
                s.direction = "left"
                s.facing = -1
            end
        else
            if ady > 0 then
                s.direction = "down"
            else
                s.direction = "up"
            end
        end

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
    local sp = Hero.sprite

    -- 死亡动画播完后不渲染
    if not s.alive and s.animState ~= "die" then return end

    -- 无敌闪烁：跳帧不渲染
    if s.invincibleTimer > 0 and math.floor(s.invincibleTimer * 10) % 2 == 0 then
        return
    end

    -- 确定精灵图行号
    local rowKey = Hero._getCurrentRowKey()
    local row = sp.rows_map[rowKey] or 0
    local maxFrames = sp.frameCounts[rowKey] or sp.cols
    local col = sp.currentFrame % maxFrames

    -- 计算精灵图中的源区域
    local sx = col * sp.frameW
    local sy = row * sp.frameH

    -- 显示大小
    local drawW = sp.frameW * sp.scale
    local drawH = sp.frameH * sp.scale
    local drawX = s.x - drawW / 2
    local drawY = s.y - drawH / 2

    -- 是否需要水平镜像（向左时）
    local mirror = (s.direction == "left")

    nvgSave(nvg)

    if sp.image and sp.image > 0 then
        if mirror then
            -- 镜像绘制：先平移到目标位置中心，水平翻转，再偏移回来
            nvgTranslate(nvg, s.x, s.y)
            nvgScale(nvg, -1, 1)
            nvgTranslate(nvg, -s.x, -s.y)
        end

        -- nvgImagePattern: 将整张精灵图映射到一个虚拟矩形上
        -- 通过偏移让目标帧对齐到绘制位置
        local patternX = drawX - sx * sp.scale
        local patternY = drawY - sy * sp.scale
        local patternW = sp.sheetW * sp.scale
        local patternH = sp.sheetH * sp.scale

        local paint = nvgImagePattern(nvg, patternX, patternY, patternW, patternH, 0, sp.image, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, drawX, drawY, drawW, drawH)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        -- 回退：精灵图加载失败时画圆形
        nvgFillColor(nvg, nvgRGBA(50, 100, 200, 255))
        nvgBeginPath(nvg)
        nvgCircle(nvg, s.x, s.y, Hero.config.size)
        nvgFill(nvg)
    end

    nvgRestore(nvg)
end

--- 清理精灵图资源
---@param nvg NVGContextWrapper
function Hero.CleanupSprite(nvg)
    if Hero.sprite.image and Hero.sprite.image > 0 and nvg then
        nvgDeleteImage(nvg, Hero.sprite.image)
        Hero.sprite.image = nil
        print("[Hero] Sprite cleaned up")
    end
end

return Hero
