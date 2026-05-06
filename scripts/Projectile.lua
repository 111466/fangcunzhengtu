
local Projectile = {}
Projectile.list = {}

-- 箭矢精灵图
Projectile.sprites = {
    arrow = nil,       -- 箭矢图 64x64
    arrowSize = 64,
}

function Projectile.LoadSprites(nvg)
    local sp = Projectile.sprites
    if not sp.arrow then
        sp.arrow = nvgCreateImage(nvg, "image/arrow_projectile.png", 0)
        print("[Projectile] Arrow sprite loaded")
    end
end

function Projectile.CleanupSprites(nvg)
    local sp = Projectile.sprites
    if nvg and sp.arrow and sp.arrow > 0 then
        nvgDeleteImage(nvg, sp.arrow)
    end
    sp.arrow = nil
    print("[Projectile] Arrow sprite cleaned up")
end

function Projectile.Create(x, y, target, damage, speed, color,
                            slow, slowDuration, slowFactor, splash, source, isArrow)
    -- 箭矢弧形轨迹：预计算起点和目标距离
    local isArr = isArrow or false
    local startDist = 0
    local arcH = 0
    if isArr and target then
        local ddx = target.x - x
        local ddy = target.y - y
        startDist = math.sqrt(ddx * ddx + ddy * ddy)
        -- 弧度高度与距离成正比，近距离几乎无弧度，远距离最高60像素
        arcH = math.min(60, math.max(0, startDist * 0.3 - 10))
    end

    local p = {
        x = x, y = y, target = target,
        damage = damage, speed = speed,
        color = color or {255, 255, 255},
        slow = slow or false,
        slowDuration = slowDuration or 0,
        slowFactor = slowFactor or 1.0,
        splash = splash or 0,
        alive = true,
        source = source,
        isArrow = isArr,
        angle = 0,
        -- 弧形轨迹参数
        startX = x,
        startY = y,
        progress = 0,          -- 0→1 飞行进度
        totalDist = startDist, -- 起点到目标的初始距离
        arcHeight = arcH,      -- 抛物线最高点偏移
    }
    table.insert(Projectile.list, p)
    return p
end

function Projectile.UpdateAll(dt)
    local totalReward = 0
    local totalKills = 0
    for i = #Projectile.list, 1, -1 do
        local p = Projectile.list[i]
        if not p.target or not p.target.alive then
            table.remove(Projectile.list, i)
        else
            -- 箭矢：弧形轨迹
            if p.isArrow and p.totalDist > 0 then
                -- 用速度推进 progress
                local step = p.speed * dt / p.totalDist
                p.progress = p.progress + step

                if p.progress >= 1.0 then
                    p.progress = 1.0
                end

                -- 线性插值基础位置（起点→目标当前位置）
                local t = p.progress
                local baseX = p.startX + (p.target.x - p.startX) * t
                local baseY = p.startY + (p.target.y - p.startY) * t
                -- 抛物线偏移：-4*h*t*(1-t)，向上为负
                local arcOffset = -p.arcHeight * 4 * t * (1 - t)

                local prevX, prevY = p.x, p.y
                p.x = baseX
                p.y = baseY + arcOffset

                -- 箭矢角度沿切线方向
                local adx = p.x - prevX
                local ady = p.y - prevY
                if math.abs(adx) > 0.01 or math.abs(ady) > 0.01 then
                    p.angle = math.atan(ady, adx)
                end

                -- 命中检测
                local hitDx = p.target.x - p.x
                local hitDy = p.target.y - p.y
                local hitDist = math.sqrt(hitDx * hitDx + hitDy * hitDy)
                if p.progress >= 1.0 or hitDist < 14 then
                    if p.target.config then
                        local reward = Enemy.Damage(p.target, p.damage)
                        if reward then
                            totalReward = totalReward + reward
                            totalKills = totalKills + 1
                        end
                        if p.slow then
                            p.target._slowFactor = p.slowFactor
                            p.target._slowTimer = p.slowDuration
                        end
                    else
                        Hero.TakeDamage(p.damage, p.source)
                    end
                    table.remove(Projectile.list, i)
                end
            else
                -- 非箭矢：直线轨迹（保持原有逻辑）
                local dx = p.target.x - p.x
                local dy = p.target.y - p.y
                local dist = math.sqrt(dx*dx + dy*dy)

                if dist < 12 then
                    if p.target.config then
                        local reward = Enemy.Damage(p.target, p.damage)
                        if reward then
                            totalReward = totalReward + reward
                            totalKills = totalKills + 1
                        end
                        if p.slow then
                            p.target._slowFactor = p.slowFactor
                            p.target._slowTimer = p.slowDuration
                        end
                    else
                        Hero.TakeDamage(p.damage, p.source)
                    end

                    if p.splash > 0 then
                        for _, enemy in ipairs(Enemy.list) do
                            if enemy ~= p.target and enemy.alive then
                                local sdx = enemy.x - p.target.x
                                local sdy = enemy.y - p.target.y
                                if math.sqrt(sdx*sdx + sdy*sdy) < p.splash then
                                    local splashReward = Enemy.Damage(enemy, p.damage * 0.5)
                                    if splashReward then
                                        totalReward = totalReward + splashReward
                                        totalKills = totalKills + 1
                                    end
                                end
                            end
                        end
                        if Particle then
                            Particle.Spawn("explosion", p.target.x, p.target.y, 0)
                        end
                    end

                    table.remove(Projectile.list, i)
                else
                    p.x = p.x + (dx / dist) * p.speed * dt
                    p.y = p.y + (dy / dist) * p.speed * dt
                    p.angle = math.atan(dy, dx)
                end
            end
        end
    end
    return totalReward, totalKills
end

function Projectile.DrawAll(nvg)
    for _, p in ipairs(Projectile.list) do
        Projectile.Draw(nvg, p)
    end
end

function Projectile.Draw(nvg, p)
    if p.isArrow and Projectile.sprites.arrow and Projectile.sprites.arrow > 0 then
        -- 箭矢精灵图渲染（带旋转）
        local drawSize = 28
        nvgSave(nvg)
        nvgTranslate(nvg, p.x, p.y)
        nvgRotate(nvg, p.angle)
        nvgTranslate(nvg, -p.x, -p.y)

        local sp = Projectile.sprites
        local drawX = p.x - drawSize / 2
        local drawY = p.y - drawSize / 2
        local paint = nvgImagePattern(nvg, drawX, drawY, drawSize, drawSize, 0, sp.arrow, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, drawX, drawY, drawSize, drawSize)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
        nvgRestore(nvg)
    else
        -- 其他投射物：保持圆形绘制
        nvgFillColor(nvg, nvgRGBA(p.color[1], p.color[2], p.color[3], 255))
        nvgBeginPath(nvg)
        nvgCircle(nvg, p.x, p.y, 5)
        nvgFill(nvg)

        nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, 150))
        nvgStrokeWidth(nvg, 2)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, p.x - 5, p.y)
        nvgLineTo(nvg, p.x + 5, p.y)
        nvgStroke(nvg)
    end
end

return Projectile
