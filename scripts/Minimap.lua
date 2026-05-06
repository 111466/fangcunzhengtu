local Config = require("scripts.Config")
local Camera = require("scripts.Camera")
local Map = require("scripts.Map")

local Minimap = {}

-- 状态
local expanded_ = false

-- 折叠尺寸 / 展开尺寸
local COLLAPSED_W = 200
local COLLAPSED_H = 150
local EXPANDED_W  = 600
local EXPANDED_H  = 450

-- 右上角边距
local MARGIN = 12

--- 初始化小地图
function Minimap.Init()
    expanded_ = false
    print("[Minimap] Initialized")
end

--- 是否已展开
function Minimap.IsExpanded()
    return expanded_
end

--- 切换展开/折叠
function Minimap.Toggle()
    expanded_ = not expanded_
end

--- 获取小地图在屏幕上的矩形 (x, y, w, h)
---@param screenW number
---@param screenH number
---@return number x, number y, number w, number h
local function GetRect(screenW, screenH)
    if expanded_ then
        local x = (screenW - EXPANDED_W) / 2
        local y = (screenH - EXPANDED_H) / 2
        return x, y, EXPANDED_W, EXPANDED_H
    else
        return screenW - COLLAPSED_W - MARGIN, MARGIN, COLLAPSED_W, COLLAPSED_H
    end
end

--- 判断屏幕坐标是否在小地图内
---@param mx number 屏幕鼠标 X
---@param my number 屏幕鼠标 Y
---@param screenW number
---@param screenH number
---@return boolean
function Minimap.HitTest(mx, my, screenW, screenH)
    local rx, ry, rw, rh = GetRect(screenW, screenH)
    return mx >= rx and mx <= rx + rw and my >= ry and my <= ry + rh
end

--- 处理点击事件。返回 true 表示事件已被小地图消费
---@param mx number 屏幕鼠标 X
---@param my number 屏幕鼠标 Y
---@param screenW number
---@param screenH number
---@return boolean consumed
function Minimap.HandleClick(mx, my, screenW, screenH)
    local rx, ry, rw, rh = GetRect(screenW, screenH)

    -- 不在小地图内 → 若展开则关闭
    if not Minimap.HitTest(mx, my, screenW, screenH) then
        if expanded_ then
            expanded_ = false
            return true  -- 消费点击（仅关闭，不传递）
        end
        return false
    end

    -- 折叠状态 → 点击展开
    if not expanded_ then
        expanded_ = true
        return true
    end

    -- 展开状态 → 点击跳转相机
    local relX = (mx - rx) / rw  -- 0~1
    local relY = (my - ry) / rh  -- 0~1
    local worldX = relX * Config.WORLD_WIDTH
    local worldY = relY * Config.WORLD_HEIGHT
    Camera.JumpTo(worldX, worldY)
    expanded_ = false
    return true
end

--- 绘制小地图（屏幕空间，不受相机偏移影响）
---@param nvg NVGContextWrapper
---@param screenW number
---@param screenH number
---@param heroState table
function Minimap.Draw(nvg, screenW, screenH, heroState)
    local rx, ry, rw, rh = GetRect(screenW, screenH)
    local worldW = Config.WORLD_WIDTH
    local worldH = Config.WORLD_HEIGHT
    local scaleX = rw / worldW
    local scaleY = rh / worldH

    nvgSave(nvg)

    -- 裁剪区域
    nvgScissor(nvg, rx, ry, rw, rh)

    -- 1. 背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, rx, ry, rw, rh, expanded_ and 12 or 8)
    nvgFillColor(nvg, nvgRGBA(30, 50, 30, expanded_ and 230 or 200))
    nvgFill(nvg)

    -- 2. 领地范围
    local territories = Map.GetTerritories()
    for _, t in ipairs(territories) do
        local tx = rx + t.x * scaleX
        local ty = ry + t.y * scaleY
        local tr = t.radius * math.min(scaleX, scaleY)

        -- 领地填充
        nvgBeginPath(nvg)
        nvgCircle(nvg, tx, ty, tr)
        nvgFillColor(nvg, nvgRGBA(80, 200, 80, 30))
        nvgFill(nvg)

        -- 领地边界
        nvgBeginPath(nvg)
        nvgCircle(nvg, tx, ty, tr)
        nvgStrokeColor(nvg, nvgRGBA(80, 200, 80, 150))
        nvgStrokeWidth(nvg, expanded_ and 1.5 or 1)
        nvgStroke(nvg)
    end

    -- 3. 营地标记
    local campPos = Map.GetCampPos()
    local cx = rx + campPos.x * scaleX
    local cy = ry + campPos.y * scaleY
    local cr = expanded_ and 5 or 3
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, cr)
    nvgFillColor(nvg, nvgRGBA(220, 160, 50, 240))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, 180))
    nvgStrokeWidth(nvg, 1)
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, cr)
    nvgStroke(nvg)
    if expanded_ then
        nvgFontSize(nvg, 11)
        nvgTextAlign(nvg, 1) -- NVG_ALIGN_CENTER
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 200))
        nvgText(nvg, cx, cy + cr + 10, "民房")
    end

    -- 4. 防御塔位置（如果有）
    if Tower and Tower.list then
        for _, tower in ipairs(Tower.list) do
            local tx = rx + tower.x * scaleX
            local ty = ry + tower.y * scaleY
            nvgBeginPath(nvg)
            nvgRect(nvg, tx - 2, ty - 2, 4, 4)
            nvgFillColor(nvg, nvgRGBA(100, 200, 255, 220))
            nvgFill(nvg)
        end
    end

    -- 6. 英雄标记
    if heroState and heroState.alive then
        local hx = rx + heroState.x * scaleX
        local hy = ry + heroState.y * scaleY
        local hr = expanded_ and 4 or 3
        -- 外圈白色
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, hr + 1)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
        nvgFill(nvg)
        -- 内圈黄色
        nvgBeginPath(nvg)
        nvgCircle(nvg, hx, hy, hr)
        nvgFillColor(nvg, nvgRGBA(255, 220, 50, 255))
        nvgFill(nvg)
    end

    nvgResetScissor(nvg)

    -- 8. 边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, rx, ry, rw, rh, expanded_ and 12 or 8)
    nvgStrokeColor(nvg, nvgRGBA(180, 200, 220, expanded_ and 200 or 150))
    nvgStrokeWidth(nvg, expanded_ and 2 or 1.5)
    nvgStroke(nvg)

    -- 9. 标题
    if not expanded_ then
        nvgFontSize(nvg, 11)
        nvgTextAlign(nvg, 1)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 160))
        nvgText(nvg, rx + rw / 2, ry + rh - 6, "点击展开")
    else
        nvgFontSize(nvg, 14)
        nvgTextAlign(nvg, 1)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 200))
        nvgText(nvg, rx + rw / 2, ry - 6, "世界地图 (点击跳转)")
    end

    nvgRestore(nvg)
end

return Minimap
