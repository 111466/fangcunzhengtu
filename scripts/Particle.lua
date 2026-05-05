
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

    local data = nil
    if type(facing) == "table" then
        data = facing
        facing = data.facing
    end

    local p = {
        type = typeName,
        x = x, y = y,
        facing = facing or 1,
        life = def.life,
        maxLife = def.life,
        size = def.size,
        color = def.color,
        data = data,
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
    local color = nvgRGBA(p.color[1], p.color[2], p.color[3], math.floor(alpha * 220))

    if p.type == "slash" then
        local data = p.data or {}
        local x1 = data.startX or (p.x - p.facing * size)
        local y1 = data.startY or (p.y - size * 0.4)
        local x2 = data.endX or (p.x + p.facing * size)
        local y2 = data.endY or (p.y + size * 0.4)

        nvgStrokeColor(nvg, color)
        nvgStrokeWidth(nvg, 5)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x1, y1)
        nvgLineTo(nvg, x2, y2)
        nvgStroke(nvg)

        nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, math.floor(alpha * 140)))
        nvgStrokeWidth(nvg, 2)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x1 + p.facing * 8, y1 - 4)
        nvgLineTo(nvg, x2 + p.facing * 8, y2 - 4)
        nvgStroke(nvg)
        return
    end

    if p.type == "charge" then
        nvgStrokeColor(nvg, color)
        nvgStrokeWidth(nvg, 4)
        for i = 0, 2 do
            local offset = (i - 1) * 8
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, p.x - p.facing * size * 1.2, p.y + offset)
            nvgLineTo(nvg, p.x + p.facing * size * 1.2, p.y + offset * 0.5)
            nvgStroke(nvg)
        end
        return
    end

    if p.type == "whirlwind" then
        nvgStrokeColor(nvg, color)
        nvgStrokeWidth(nvg, 4)
        nvgBeginPath(nvg)
        nvgArc(nvg, p.x, p.y, size * 0.7, -1.8 + (1 - alpha), 1.2 + (1 - alpha), 1)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgArc(nvg, p.x, p.y, size, 1.0 - (1 - alpha), 3.4 - (1 - alpha), 1)
        nvgStroke(nvg)
        return
    end

    if p.type == "buff" then
        nvgStrokeColor(nvg, color)
        nvgStrokeWidth(nvg, 3)
        nvgBeginPath(nvg)
        nvgCircle(nvg, p.x, p.y, size * 0.7)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, p.x, p.y - size)
        nvgLineTo(nvg, p.x, p.y + size)
        nvgMoveTo(nvg, p.x - size, p.y)
        nvgLineTo(nvg, p.x + size, p.y)
        nvgStroke(nvg)
        return
    end

    if p.type == "lightning" then
        nvgStrokeColor(nvg, color)
        nvgStrokeWidth(nvg, 3)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, p.x - size * 0.5, p.y - size)
        nvgLineTo(nvg, p.x + size * 0.1, p.y - size * 0.2)
        nvgLineTo(nvg, p.x - size * 0.1, p.y - size * 0.2)
        nvgLineTo(nvg, p.x + size * 0.5, p.y + size)
        nvgStroke(nvg)
        return
    end

    if p.type == "meteor" then
        nvgStrokeColor(nvg, color)
        nvgStrokeWidth(nvg, 4)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, p.x - size * 0.6, p.y - size * 0.6)
        nvgLineTo(nvg, p.x + size * 0.6, p.y + size * 0.6)
        nvgMoveTo(nvg, p.x + size * 0.1, p.y - size)
        nvgLineTo(nvg, p.x - size * 0.2, p.y - size * 0.1)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, p.x, p.y, size * 0.35)
        nvgStroke(nvg)
        return
    end

    if p.type == "explosion" or p.type == "death" or p.type == "hit" then
        nvgStrokeColor(nvg, color)
        nvgStrokeWidth(nvg, p.type == "hit" and 3 or 4)
        nvgBeginPath(nvg)
        nvgCircle(nvg, p.x, p.y, size * 0.7)
        nvgStroke(nvg)
        if p.type ~= "hit" then
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, p.x - size, p.y)
            nvgLineTo(nvg, p.x + size, p.y)
            nvgMoveTo(nvg, p.x, p.y - size)
            nvgLineTo(nvg, p.x, p.y + size)
            nvgStroke(nvg)
        end
        return
    end

    nvgFillColor(nvg, color)
    nvgBeginPath(nvg)
    nvgCircle(nvg, p.x, p.y, size)
    nvgFill(nvg)
end

return Particle
