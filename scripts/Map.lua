local Config = require("scripts.Config")
local Camera = require("scripts.Camera")

local Map = {}

-- 图片句柄
local images_ = {}
-- NVG 上下文
local nvg_ = nil

-- 动画树精灵图元数据
local treeMeta_ = {
    tree_autumn    = { file = "image/tree_autumn_anim.png",     frames = 8, frameW = 192, frameH = 192 },
    tree_pine_dark = { file = "image/tree_pine_dark_anim.png",  frames = 8, frameW = 192, frameH = 256 },
    tree_pine_green= { file = "image/tree_pine_green_anim.png", frames = 8, frameW = 192, frameH = 256 },
    tree_leaf      = { file = "image/tree_leaf_anim.png",       frames = 8, frameW = 192, frameH = 192 },
}

-- 动画计时器
local animTime_ = 0
local ANIM_FPS = 6  -- 每秒帧数

-- 世界尺寸
local WORLD_W = Config.WORLD_WIDTH   -- 4000
local WORLD_H = Config.WORLD_HEIGHT  -- 3000

----------------------------------------------------------------------
-- 领地系统
----------------------------------------------------------------------
local territories_ = {}  -- { {x, y, radius} }
local campPos_ = { x = 0, y = 0 }  -- 营地位置
local warehousePos_ = { x = 0, y = 0 } -- 仓库位置（营地右侧）



----------------------------------------------------------------------
-- 程序化装饰物
----------------------------------------------------------------------
local decorations_ = {}

--- 伪随机数生成器（固定种子保证一致性）
local function PseudoRandom(seed)
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed, (seed % 10000) / 10000.0
end

--- 判断点是否靠近营地或仓库
local function IsNearCamp(x, y, threshold)
    threshold = threshold or 120
    local dx = x - campPos_.x
    local dy = y - campPos_.y
    if dx*dx + dy*dy < threshold * threshold then return true end
    -- 也检查仓库区域
    local wx = x - warehousePos_.x
    local wy = y - warehousePos_.y
    return wx*wx + wy*wy < threshold * threshold
end

--- 判断生物群落类型
---@return string "grassland"|"forest"|"desert"|"tundra"
local function GetBiome(x, y)
    local midX = WORLD_W / 2
    local midY = WORLD_H / 2
    if x < midX then
        return y < midY and "grassland" or "desert"
    else
        return y < midY and "forest" or "tundra"
    end
end

--- 根据生物群落选择装饰类型
--- 树类型: tree_autumn(秋叶), tree_pine_dark(深松), tree_pine_green(绿松), tree_leaf(阔叶)
local function GetDecoType(biome, rand)
    if biome == "grassland" then
        -- 草地：阔叶树为主，秋叶树点缀
        if rand < 0.35 then return "tree_leaf"
        elseif rand < 0.6 then return "tree_autumn"
        elseif rand < 0.8 then return "tree_pine_green"
        else return "rock" end
    elseif biome == "forest" then
        -- 森林：松树为主，混合阔叶
        if rand < 0.3 then return "tree_pine_dark"
        elseif rand < 0.55 then return "tree_pine_green"
        elseif rand < 0.8 then return "tree_leaf"
        else return "rock" end
    elseif biome == "desert" then
        -- 沙漠：岩石为主，少量耐旱树
        if rand < 0.5 then return "rock"
        elseif rand < 0.75 then return "tree_autumn"
        else return "tree_leaf" end
    else -- tundra
        -- 冻土：深色松树为主，岩石多
        if rand < 0.35 then return "rock"
        elseif rand < 0.6 then return "tree_pine_dark"
        elseif rand < 0.85 then return "tree_pine_green"
        else return "tree_autumn" end
    end
end

--- 生成程序化装饰物
local function GenerateDecorations()
    decorations_ = {}
    local gridSize = 200
    local seed = 42

    for gx = 0, math.floor(WORLD_W / gridSize) - 1 do
        for gy = 0, math.floor(WORLD_H / gridSize) - 1 do
            -- 每个格子有 60% 概率生成装饰
            seed = (seed * 1103515245 + 12345) % 2147483648
            if (seed % 100) < 60 then
                -- 在格子内随机偏移
                local rx, ry
                seed, rx = PseudoRandom(seed)
                seed, ry = PseudoRandom(seed)
                local x = gx * gridSize + rx * gridSize
                local y = gy * gridSize + ry * gridSize

                -- 避开边界
                if x > 30 and x < WORLD_W - 30 and y > 30 and y < WORLD_H - 30 then
                    -- 避开道路和地标
                    if not IsNearCamp(x, y, 120) then
                        local biome = GetBiome(x, y)
                        local typeRand
                        seed, typeRand = PseudoRandom(seed)
                        local decoType = GetDecoType(biome, typeRand)

                        local scaleRand
                        seed, scaleRand = PseudoRandom(seed)
                        local scale = 1.0 + scaleRand * 0.2

                        table.insert(decorations_, {
                            type = decoType,
                            x = x,
                            y = y,
                            scale = scale,
                            biome = biome,
                        })
                    end
                end
            end
        end
    end

    print("[Map] Generated " .. #decorations_ .. " decorations")
end

----------------------------------------------------------------------
-- 初始化
----------------------------------------------------------------------

--- 初始化地图
---@param nvg NVGContextWrapper
function Map.Init(nvg)
    nvg_ = nvg

    -- 初始化营地位置和领地
    campPos_.x = Config.HERO_SPAWN.x + Config.CAMP_OFFSET.x
    campPos_.y = Config.HERO_SPAWN.y + Config.CAMP_OFFSET.y
    territories_ = {
        { x = campPos_.x, y = campPos_.y, radius = Config.TERRITORY_RADIUS }
    }
    print("[Map] Camp at (" .. campPos_.x .. ", " .. campPos_.y .. "), territory radius=" .. Config.TERRITORY_RADIUS)

    local repeatFlags = NVG_IMAGE_REPEATX | NVG_IMAGE_REPEATY
    images_.grass = nvgCreateImage(nvg, "image/grass_tile_20260505161428.png", repeatFlags)

    -- 仓库位置：营地右侧偏移
    warehousePos_.x = campPos_.x + 140
    warehousePos_.y = campPos_.y + 30

    -- 加载营地建筑图片
    images_.camp = nvgCreateImage(nvg, "image/house_building.png", 0)
    images_.warehouse = nvgCreateImage(nvg, "image/warehouse_building.png", 0)

    -- 加载动画树精灵图
    for name, meta in pairs(treeMeta_) do
        images_[name] = nvgCreateImage(nvg, meta.file, 0)
    end

    images_.rock = nvgCreateImage(nvg, "image/rock_20260505155324.png", 0)

    for name, handle in pairs(images_) do
        if not handle or handle <= 0 then
            print("[Map] WARNING: Failed to load image: " .. name)
        else
            print("[Map] Loaded: " .. name .. " (handle=" .. handle .. ")")
        end
    end

    GenerateDecorations()
    print("[Map] Initialized (world " .. WORLD_W .. "x" .. WORLD_H .. ")")
end

----------------------------------------------------------------------
-- 绘制函数
----------------------------------------------------------------------

--- 绘制草地背景（只绘制视口范围内的平铺纹理）
local function DrawGrassBackground(nvg, screenW, screenH, camOX, camOY)
    if not images_.grass or images_.grass <= 0 then
        nvgBeginPath(nvg)
        nvgRect(nvg, 0, 0, WORLD_W, WORLD_H)
        nvgFillColor(nvg, nvgRGBA(60, 120, 40, 255))
        nvgFill(nvg)
        return
    end

    -- 草地平铺覆盖整个世界
    local paint = nvgImagePattern(nvg, 0, 0, 512, 512, 0, images_.grass, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, WORLD_W, WORLD_H)
    nvgFillPaint(nvg, paint)
    nvgFill(nvg)
end

--- 绘制单个静态精灵图（岩石）
local function DrawSprite(nvg, imgHandle, x, y, w, h)
    if not imgHandle or imgHandle <= 0 then return end
    local drawX = x - w / 2
    local drawY = y - h / 2
    local paint = nvgImagePattern(nvg, drawX, drawY, w, h, 0, imgHandle, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, drawX, drawY, w, h)
    nvgFillPaint(nvg, paint)
    nvgFill(nvg)
end

--- 绘制动画树精灵（从水平精灵图条中裁剪当前帧）
---@param nvg NVGContextWrapper
---@param treeName string 树类型名称（对应 treeMeta_ 的 key）
---@param x number 世界坐标 X（中心）
---@param y number 世界坐标 Y（中心）
---@param drawW number 绘制宽度
---@param drawH number 绘制高度
---@param frameOffset number 帧偏移（让不同树有不同动画相位）
local function DrawAnimatedTree(nvg, treeName, x, y, drawW, drawH, frameOffset)
    local meta = treeMeta_[treeName]
    if not meta then return end
    local img = images_[treeName]
    if not img or img <= 0 then return end

    -- 计算当前帧（加上偏移使不同树不同步）
    local totalFrames = meta.frames
    local frameIndex = math.floor((animTime_ * ANIM_FPS + frameOffset) % totalFrames)

    -- 精灵图条的尺寸映射到绘制尺寸
    -- 精灵图条总宽 = frameW * frames，单帧宽 = frameW
    -- 绘制时：将整条图缩放到 drawW * frames 宽，drawH 高
    local stripDrawW = drawW * totalFrames  -- 整条精灵图的绘制宽度
    local stripDrawH = drawH                -- 整条精灵图的绘制高度

    -- 当前帧在绘制空间中的起始 X
    local frameDrawX = frameIndex * drawW

    -- 绘制区域（屏幕上的矩形）
    local destX = x - drawW / 2
    local destY = y - drawH / 2

    -- 用 nvgScissor 裁剪到一帧大小，nvgImagePattern 绘制整条
    nvgSave(nvg)
    nvgScissor(nvg, destX, destY, drawW, drawH)

    -- ImagePattern 起点需要偏移，使当前帧对齐到 destX
    local patternX = destX - frameDrawX
    local patternY = destY

    local paint = nvgImagePattern(nvg, patternX, patternY, stripDrawW, stripDrawH, 0, img, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, patternX, patternY, stripDrawW, stripDrawH)
    nvgFillPaint(nvg, paint)
    nvgFill(nvg)

    nvgResetScissor(nvg)
    nvgRestore(nvg)
end

--- 绘制世界边界
local function DrawWorldBorder(nvg)
    nvgStrokeColor(nvg, nvgRGBA(100, 80, 60, 180))
    nvgStrokeWidth(nvg, 4)
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, WORLD_W, WORLD_H)
    nvgStroke(nvg)
end

----------------------------------------------------------------------
-- 公共接口
----------------------------------------------------------------------

--- 更新动画计时器
---@param dt number 帧间隔时间
function Map.Update(dt)
    animTime_ = animTime_ + dt
end

--- 绘制领地边界圆圈（世界坐标，半透明虚线风格）
local function DrawTerritoryBorders(nvg)
    for _, t in ipairs(territories_) do
        -- 领地范围填充（极淡绿色）
        nvgBeginPath(nvg)
        nvgCircle(nvg, t.x, t.y, t.radius)
        nvgFillColor(nvg, nvgRGBA(80, 200, 80, 18))
        nvgFill(nvg)

        -- 领地边界线（绿色虚线效果用双圈模拟）
        nvgBeginPath(nvg)
        nvgCircle(nvg, t.x, t.y, t.radius)
        nvgStrokeColor(nvg, nvgRGBA(80, 200, 80, 100))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)

        nvgBeginPath(nvg)
        nvgCircle(nvg, t.x, t.y, t.radius - 3)
        nvgStrokeColor(nvg, nvgRGBA(80, 200, 80, 40))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
    end
end

--- 绘制营地建筑精灵
local function DrawCamp(nvg)
    local img = images_.camp
    if not img or img <= 0 then return end
    if not Camera.IsVisible(campPos_.x, campPos_.y, 200) then return end

    local drawW = 120
    local drawH = 120
    local destX = campPos_.x - drawW / 2
    local destY = campPos_.y - drawH / 2

    local paint = nvgImagePattern(nvg, destX, destY, drawW, drawH, 0, img, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, destX, destY, drawW, drawH)
    nvgFillPaint(nvg, paint)
    nvgFill(nvg)
end

--- 绘制仓库建筑精灵
local function DrawWarehouse(nvg)
    local img = images_.warehouse
    if not img or img <= 0 then return end
    if not Camera.IsVisible(warehousePos_.x, warehousePos_.y, 200) then return end

    local drawW = 100
    local drawH = 125  -- 4:5 比例
    local destX = warehousePos_.x - drawW / 2
    local destY = warehousePos_.y - drawH / 2

    local paint = nvgImagePattern(nvg, destX, destY, drawW, drawH, 0, img, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, destX, destY, drawW, drawH)
    nvgFillPaint(nvg, paint)
    nvgFill(nvg)
end

--- 绘制地图背景层（草地、边界、领地范围 —— 不含装饰物和营地）
---@param nvg NVGContextWrapper
---@param screenW number 屏幕宽度
---@param screenH number 屏幕高度
function Map.DrawBackground(nvg, screenW, screenH)
    local camOX, camOY = Camera.GetOffset()

    -- 1. 草地背景
    DrawGrassBackground(nvg, screenW, screenH, camOX, camOY)

    -- 2. 领地范围显示
    DrawTerritoryBorders(nvg)

    -- 3. 世界边界
    DrawWorldBorder(nvg)
end

--- 获取装饰物列表（供外部 Y 排序）
---@return table[] decorations_ 数组，每项含 {type, x, y, scale, biome}
function Map.GetDecorations()
    return decorations_
end

--- 绘制单个装饰物（供外部 Y 排序后逐个调用）
---@param nvg NVGContextWrapper
---@param deco table 装饰物数据 {type, x, y, scale}
---@param index number 装饰物索引（用于动画帧偏移）
function Map.DrawDecoration(nvg, deco, index)
    local meta = treeMeta_[deco.type]
    if meta then
        local baseW = 100
        local baseH = baseW * (meta.frameH / meta.frameW)
        local drawW = baseW * deco.scale
        local drawH = baseH * deco.scale
        DrawAnimatedTree(nvg, deco.type, deco.x, deco.y, drawW, drawH, index * 0.7)
    else
        -- 石头
        local img = images_[deco.type]
        if img and img > 0 then
            local size = 24 * deco.scale
            DrawSprite(nvg, img, deco.x, deco.y, size, size)
        end
    end
end



--- 获取营地位置
---@return table {x, y}
function Map.GetCampPos()
    return campPos_
end

--- 获取领地列表
---@return table[] { {x, y, radius}, ... }
function Map.GetTerritories()
    return territories_
end

--- 判断点是否在任何领地范围内
---@param x number 世界坐标 X
---@param y number 世界坐标 Y
---@return boolean
function Map.IsInTerritory(x, y)
    for _, t in ipairs(territories_) do
        local dx = x - t.x
        local dy = y - t.y
        if dx*dx + dy*dy <= t.radius * t.radius then
            return true
        end
    end
    return false
end

--- 绘制营地（供外部 Y 排序调用）
---@param nvg NVGContextWrapper
function Map.DrawCampSprite(nvg)
    DrawCamp(nvg)
end

--- 获取仓库位置
---@return table {x, y}
function Map.GetWarehousePos()
    return warehousePos_
end

--- 绘制仓库（供外部 Y 排序调用）
---@param nvg NVGContextWrapper
function Map.DrawWarehouseSprite(nvg)
    DrawWarehouse(nvg)
end

--- 清理资源
function Map.Cleanup()
    if nvg_ then
        for name, handle in pairs(images_) do
            if handle and handle > 0 then
                nvgDeleteImage(nvg_, handle)
                print("[Map] Deleted image: " .. name)
            end
        end
    end
    images_ = {}
    decorations_ = {}
    nvg_ = nil
    print("[Map] Cleanup done")
end

return Map
