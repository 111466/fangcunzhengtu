local Camera = {}

local worldW_ = 4000
local worldH_ = 3000
local viewW_ = 1280
local viewH_ = 720

-- 相机偏移量（世界坐标，左上角）
local ox_ = 0
local oy_ = 0

-- 平滑跟随参数
local lerpSpeed_ = 5.0

--- 初始化相机
---@param worldW number 世界宽度
---@param worldH number 世界高度
---@param viewW number 视口宽度
---@param viewH number 视口高度
function Camera.Init(worldW, worldH, viewW, viewH)
    worldW_ = worldW
    worldH_ = worldH
    viewW_ = viewW
    viewH_ = viewH
    ox_ = 0
    oy_ = 0
end

--- 更新视口尺寸（窗口大小变化时）
---@param w number
---@param h number
function Camera.SetViewSize(w, h)
    viewW_ = w
    viewH_ = h
end

--- 平滑跟随目标（英雄）
---@param targetX number 目标世界 X
---@param targetY number 目标世界 Y
---@param dt number 帧间隔
function Camera.Follow(targetX, targetY, dt)
    -- 目标偏移：让目标处于屏幕中心
    local desiredOX = targetX - viewW_ / 2
    local desiredOY = targetY - viewH_ / 2

    -- 钳制到世界边界
    local maxOX = math.max(0, worldW_ - viewW_)
    local maxOY = math.max(0, worldH_ - viewH_)
    desiredOX = math.max(0, math.min(desiredOX, maxOX))
    desiredOY = math.max(0, math.min(desiredOY, maxOY))

    -- lerp 平滑插值
    local t = 1 - math.exp(-lerpSpeed_ * dt)
    ox_ = ox_ + (desiredOX - ox_) * t
    oy_ = oy_ + (desiredOY - oy_) * t
end

--- 立即跳转到目标位置（无平滑）
---@param targetX number
---@param targetY number
function Camera.JumpTo(targetX, targetY)
    ox_ = targetX - viewW_ / 2
    oy_ = targetY - viewH_ / 2

    local maxOX = math.max(0, worldW_ - viewW_)
    local maxOY = math.max(0, worldH_ - viewH_)
    ox_ = math.max(0, math.min(ox_, maxOX))
    oy_ = math.max(0, math.min(oy_, maxOY))
end

--- 获取相机偏移量（用于 nvgTranslate(-ox, -oy)）
---@return number ox
---@return number oy
function Camera.GetOffset()
    return ox_, oy_
end

--- 获取视口尺寸
---@return number viewW
---@return number viewH
function Camera.GetViewSize()
    return viewW_, viewH_
end

--- 屏幕坐标 → 世界坐标
---@param sx number 屏幕 X
---@param sy number 屏幕 Y
---@return number worldX
---@return number worldY
function Camera.ScreenToWorld(sx, sy)
    return sx + ox_, sy + oy_
end

--- 世界坐标 → 屏幕坐标
---@param wx number 世界 X
---@param wy number 世界 Y
---@return number screenX
---@return number screenY
function Camera.WorldToScreen(wx, wy)
    return wx - ox_, wy - oy_
end

--- 判断世界坐标是否在视口内（带裕量）
---@param x number 世界 X
---@param y number 世界 Y
---@param margin number|nil 额外裕量（默认 100）
---@return boolean
function Camera.IsVisible(x, y, margin)
    margin = margin or 100
    return x >= ox_ - margin and x <= ox_ + viewW_ + margin
       and y >= oy_ - margin and y <= oy_ + viewH_ + margin
end

return Camera
