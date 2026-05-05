
local Path = {}

Path.routes = {
    {
        { x = -50,  y = 200 },
        { x = 150,  y = 200 },
        { x = 150,  y = 400 },
        { x = 400,  y = 400 },
        { x = 400,  y = 250 },
        { x = 700,  y = 250 },
        { x = 700,  y = 500 },
        { x = 1000, y = 500 },
        { x = 1000, y = 350 },
        { x = 1300, y = 350 },
        { x = 1450, y = 350 },
    },
    {
        { x = 1450, y = 600 },
        { x = 1200, y = 600 },
        { x = 1200, y = 450 },
        { x = 900,  y = 450 },
        { x = 900,  y = 650 },
        { x = 600,  y = 650 },
        { x = 600,  y = 500 },
        { x = 300,  y = 500 },
        { x = 300,  y = 650 },
        { x = -50,  y = 650 },
    },
}

function Path.GetRouteLength(route)
    local total = 0
    for i = 2, #route do
        local dx = route[i].x - route[i-1].x
        local dy = route[i].y - route[i-1].y
        total = total + math.sqrt(dx*dx + dy*dy)
    end
    return total
end

function Path.GetPosition(route, progress)
    if progress <= 0 then return route[1].x, route[1].y end
    if progress >= 1 then
        local last = route[#route]
        return last.x, last.y
    end
    local totalLen = Path.GetRouteLength(route)
    local targetDist = progress * totalLen
    local accumulated = 0
    for i = 2, #route do
        local dx = route[i].x - route[i-1].x
        local dy = route[i].y - route[i-1].y
        local segLen = math.sqrt(dx*dx + dy*dy)
        if accumulated + segLen >= targetDist then
            local t = (targetDist - accumulated) / segLen
            return route[i-1].x + dx * t, route[i-1].y + dy * t
        end
        accumulated = accumulated + segLen
    end
    return route[#route].x, route[#route].y
end

function Path.RandomRoute()
    return Path.routes[math.random(#Path.routes)]
end

function Path.Draw(nvg)
    for _, route in ipairs(Path.routes) do
        nvgStrokeColor(nvg, nvgRGBA(130, 110, 90, 210))
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, route[1].x, route[1].y)
        for i = 2, #route do
            nvgLineTo(nvg, route[i].x, route[i].y)
        end
        nvgStrokeWidth(nvg, 40)
        nvgStroke(nvg)
        
        nvgStrokeColor(nvg, nvgRGBA(100, 80, 60, 255))
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, route[1].x, route[1].y)
        for i = 2, #route do
            nvgLineTo(nvg, route[i].x, route[i].y)
        end
        nvgStrokeWidth(nvg, 44)
        nvgStroke(nvg)
    end
end

return Path
