local Utils = require("scripts/Utils")

local Path = {}

local function makePoint(x, y)
    return { x = x, y = y }
end

function Path.Create(config)
    local path = {
        width = config.PathWidth,
        waypoints = {
            makePoint(-60, 140),
            makePoint(220, 140),
            makePoint(220, 520),
            makePoint(520, 520),
            makePoint(520, 240),
            makePoint(820, 240),
            makePoint(820, 620),
            makePoint(1140, 620),
            makePoint(1140, 360),
            makePoint(1340, 360),
        },
        segments = {},
        totalLength = 0,
    }

    for index = 2, #path.waypoints do
        local from = path.waypoints[index - 1]
        local to = path.waypoints[index]
        local length = Utils.Distance(from.x, from.y, to.x, to.y)

        path.segments[#path.segments + 1] = {
            from = from,
            to = to,
            length = length,
        }
        path.totalLength = path.totalLength + length
    end

    return path
end

function Path.GetTotalLength(path)
    return path.totalLength
end

function Path.GetPosition(path, progress)
    if progress <= 0 then
        local startPoint = path.waypoints[1]
        return startPoint.x, startPoint.y
    end

    if progress >= 1 then
        local endPoint = path.waypoints[#path.waypoints]
        return endPoint.x, endPoint.y
    end

    local remainingDistance = path.totalLength * progress
    for _, segment in ipairs(path.segments) do
        if remainingDistance <= segment.length then
            local t = remainingDistance / segment.length
            return segment.from.x + (segment.to.x - segment.from.x) * t,
                segment.from.y + (segment.to.y - segment.from.y) * t
        end
        remainingDistance = remainingDistance - segment.length
    end

    local fallback = path.waypoints[#path.waypoints]
    return fallback.x, fallback.y
end

function Path.Draw(nvg, path, transform, colors)
    local halfWidth = Utils.ToScreenSize(transform, path.width * 0.5)

    for _, segment in ipairs(path.segments) do
        local x1, y1 = Utils.ToScreen(transform, segment.from.x, segment.from.y)
        local x2, y2 = Utils.ToScreen(transform, segment.to.x, segment.to.y)

        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x1, y1)
        nvgLineTo(nvg, x2, y2)
        nvgStrokeColor(nvg, nvgRGBA(colors.pathFill[1], colors.pathFill[2], colors.pathFill[3], colors.pathFill[4]))
        nvgStrokeWidth(nvg, halfWidth * 2.0)
        nvgLineCap(nvg, NVG_ROUND)
        nvgLineJoin(nvg, NVG_ROUND)
        nvgStroke(nvg)

        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x1, y1)
        nvgLineTo(nvg, x2, y2)
        nvgStrokeColor(nvg, nvgRGBA(colors.pathOutline[1], colors.pathOutline[2], colors.pathOutline[3], colors.pathOutline[4]))
        nvgStrokeWidth(nvg, math.max(2, halfWidth * 0.25))
        nvgLineCap(nvg, NVG_ROUND)
        nvgLineJoin(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end
end

return Path
