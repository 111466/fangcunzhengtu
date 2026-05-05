local Utils = {}

function Utils.Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function Utils.DistanceSquared(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx * dx + dy * dy
end

function Utils.Distance(x1, y1, x2, y2)
    return math.sqrt(Utils.DistanceSquared(x1, y1, x2, y2))
end

function Utils.DeepCopy(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = Utils.DeepCopy(value)
    end
    return copy
end

function Utils.ToScreen(transform, x, y)
    return transform.ox + x * transform.scale, transform.oy + y * transform.scale
end

function Utils.ToScreenSize(transform, value)
    return value * transform.scale
end

function Utils.PointInCircle(px, py, cx, cy, radius)
    return Utils.DistanceSquared(px, py, cx, cy) <= radius * radius
end

function Utils.PointInRect(px, py, x, y, width, height)
    return px >= x and px <= x + width and py >= y and py <= y + height
end

function Utils.Round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

return Utils
