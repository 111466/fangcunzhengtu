
local Projectile = {}
Projectile.list = {}

function Projectile.Create(x, y, target, damage, speed, color,
                            slow, slowDuration, slowFactor, splash, source)
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

return Projectile
