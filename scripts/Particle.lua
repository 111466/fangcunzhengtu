
local Particle = {}
Particle.list = {}

Particle.types = {
    slash = { life = 0.3, size = 20, color = {255, 255, 200} },
    hit = { life = 0.2, size = 12, color = {255, 100, 100} },
    death = { life = 0.5, size = 30, color = {100, 100, 100} },
    whirlwind = { life = 0.5, size = 40, color = {100, 200, 255} },
    charge = { life = 0.4, size = 25, color = {200, 150, 100} },
    buff = { life = 0.6, size = 35, color = {255, 200, 50} },
    meteor = { life = 0.8, size = 50, color = {255, 100, 30} },
    lightning = { life = 0.2, size = 15, color = {255, 255, 100} },
    explosion = { life = 0.4, size = 40, color = {255, 150, 50} },
}

function Particle.Spawn(typeName, x, y, facing)
    local def = Particle.types[typeName]
    if not def then return end

    local p = {
        type = typeName,
        x = x, y = y,
        facing = facing or 1,
        life = def.life,
        maxLife = def.life,
        size = def.size,
        color = def.color,
    }
    table.insert(Particle.list, p)
end

function Particle.UpdateAll(dt)
    for i = #Particle.list, 1, -1 do
        local p = Particle.list[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(Particle.list, i)
        end
    end
end

function Particle.DrawAll(nvg)
    for _, p in ipairs(Particle.list) do
        Particle.Draw(nvg, p)
    end
end

function Particle.Draw(nvg, p)
    local alpha = p.life / p.maxLife
    local size = p.size * (0.5 + alpha * 0.5)
    
    nvgFillColor(nvg, p.color[1], p.color[2], p.color[3], math.floor(alpha * 200))
    nvgBeginPath(nvg)
    nvgCircle(nvg, p.x, p.y, size)
    nvgFill(nvg)
end

return Particle
