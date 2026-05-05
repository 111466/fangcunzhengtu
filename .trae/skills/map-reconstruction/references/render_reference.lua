-- ============================================================================
-- 等距/正视地图渲染核心算法参考
-- 包含：坐标转换公式、瓦片对齐锚定逻辑、多层深度排序(Y-Sorting)算法
-- 此文件独立于具体的地图编辑器，可在任何 Lua 引擎(Urho3D/Love2D等)中参考复用
-- ============================================================================

-- 1. 基础视口常量
local viewMode = "iso" -- 或 "topdown"
local BASE_TILE_W_HALF = 32
local BASE_TILE_H_HALF = 16
local BASE_TD_TILE_W = 40
local BASE_TD_TILE_H = 40
local zoom = 1.0
local tileWH = BASE_TILE_W_HALF * zoom
local tileHH = BASE_TILE_H_HALF * zoom
local tdTileW = BASE_TD_TILE_W * zoom
local tdTileH = BASE_TD_TILE_H * zoom

-- 2. 地图坐标 (1-based) 转屏幕坐标
local function mapToScreen(mx, my, camX, camY)
    local ix = mx - 1
    local iy = my - 1
    if viewMode == "topdown" then
        return ix * tdTileW + camX, iy * tdTileH + camY
    else
        local sx = (ix - iy) * tileWH + camX
        local sy = (ix + iy) * tileHH + camY
        return sx, sy
    end
end

-- 3. 渲染图片瓦片的核心思路 (需适配具体引擎 API)
local function drawImageTile(cx, cy, imgInfo, tileType, flipH)
    -- 处理动画瓦片 (Animated Tiles) 的 sourceRect 逻辑
    local sourceRect = nil
    if tileType.frames and #tileType.frames > 0 then
        -- 假设 time 为引擎全局时间获取接口
        local fps = tileType.fps or 10
        local frameCount = #tileType.frames
        local t = time and time:GetElapsedTime() or 0
        local frameIndex = math.floor(t * fps) % frameCount + 1
        sourceRect = tileType.frames[frameIndex]
    else
        sourceRect = tileType.rect
    end

    local scaleFactor = tileType.scale or 1.0
    local renderMode = tileType.renderMode or "vertical"
    
    -- 针对地面铺设的瓦片（未手动配置 scale 的情况），增加极小的重叠（1.5%）以消除抗锯齿缝隙
    if (renderMode == "flat" or renderMode == "floor") and not tileType.scale then
        scaleFactor = scaleFactor * 1.015
    end

    -- 64为基准像素比，将瓦片素材统一缩放到网格大小
    local pxScale
    if viewMode == "topdown" then
        pxScale = (tdTileW / 64) * scaleFactor 
    else
        pxScale = (tileWH * 2 / 64) * scaleFactor 
    end
    
    local drawW = (sourceRect and sourceRect.w or imgInfo.w) * pxScale
    local drawH = (sourceRect and sourceRect.h or imgInfo.h) * pxScale

    if renderMode == "flat" and viewMode == "iso" then
        -- 贴地瓦片：如果原图是正视视角的方块，需要拍扁、旋转并映射在等距菱形上
        -- 项目代码中确实存在此矩阵变换逻辑，复刻时需按以下顺序应用变换：
        -- graphics.Push()
        -- graphics.Translate(cx, cy)
        -- graphics.Scale(1, 0.5)                   -- 压扁一半
        -- graphics.Scale(0.70710678, 0.70710678)   -- 补偿旋转带来的对角线放大
        -- graphics.Rotate(-math.pi / 4)            -- 旋转-45度
        -- if flipH then graphics.Scale(-1, 1) end  -- 水平翻转
        -- graphics.Draw(texture, -drawW / 2, -drawH / 2, sourceRect)
        -- graphics.Pop()
        return
    end

    -- 默认垂直模式 (立在地面上的物体)
    local drawX = cx - drawW / 2
    local drawY
    if renderMode == "floor" or (renderMode == "flat" and viewMode == "topdown") then
        -- 铺地图片，中心对齐（正视模式下 flat 也直接中心对齐即可）
        drawY = cy - drawH / 2
    else
        -- 底部锚定到网格底边
        if viewMode == "topdown" then
            drawY = (cy + tdTileH / 2) - drawH
        else
            drawY = (cy + tileHH) - drawH
        end
    end

    -- 水平翻转：在渲染时，以图形中心为轴执行 Scale(-1, 1)

    -- 具体渲染提交：
    -- graphics.Draw(texture, drawX, drawY, sourceRect, flipH)
end

-- 4. 深度排序 (Y-Sorting) 与分层渲染核心逻辑
local function renderMap(mapData, camX, camY, ox, oy)
    local width = mapData.width
    local height = mapData.height

    -- ============================================================
    -- Pass 1: 渲染地面层 (最底层) - 使用简单的对角线迭代
    -- mapData.layers[1] 通常是纯地面层，没有高度，不需要复杂遮挡计算
    -- ============================================================
    for diag = 0, width + height - 2 do
        for ix = 0, diag do
            local iy = diag - ix
            if ix < width and iy < height then
                local mx, my = ix + 1, iy + 1
                -- 根据坐标查找并绘制地面瓦片
            end
        end
    end

    -- ============================================================
    -- Pass 2: 渲染物体层 (带深度排序)
    -- ============================================================
    local sortList = {}
    
    -- 将 imageRegistry 转换为以 id 为 key 的字典，方便快速查找
    local tileDict = {}
    if mapData.imageRegistry then
        for _, reg in ipairs(mapData.imageRegistry) do
            tileDict[reg.id] = reg
        end
    end
    
    -- 遍历 layer 2 到 layer N (物体层)
    for li = 2, #mapData.layers do
        for _, tile in ipairs(mapData.layers[li].tiles) do
            local sx, sy = mapToScreen(tile.x, tile.y, camX, camY)
            local cx, cy = sx + ox, sy + oy -- ox, oy 为画布原点偏移
            
            -- 从注册表中获取瓦片的附加属性 (如 renderMode)
            local tileType = tileDict[tile.id] or {}
            local renderMode = tileType.renderMode or "vertical"

            -- 计算脚底点 (footY)：用于深度排序的绝对依据
            local footYVal
            if viewMode == "topdown" then
                if renderMode == "flat" or renderMode == "floor" then
                    -- 正视模式下，flat/floor 贴图使用其渲染底边 (cy + drawH / 2) 作为排序依据
                    -- 这能确保同一图层内，Y坐标较大的大尺寸铺地图片能正确覆盖上方的小尺寸图片
                    -- 伪代码演示获取 drawH：local drawH = 瓦片高度 * (tdTileW / 64) * scale
                    -- footYVal = cy + drawH / 2
                    footYVal = cy -- （此处为简化写法，实际项目中请获取真实高度计算底边）
                else
                    footYVal = cy + tdTileH / 2 
                end
            else
                -- 等距模式：锚定到菱形最底部的顶点
                footYVal = cy + tileHH
            end

            -- 识别是否为铺地瓦片 (不应该遮挡立体物体)
            local isFlat = (renderMode == "flat" or renderMode == "floor")

            table.insert(sortList, {
                cx = cx, cy = cy,
                footY = footYVal,
                footX = cx,
                li = li,
                tile = tile,
                tileType = tileType,
                isFlat = isFlat,
                pri = 0
            })
        end
    end

    -- 包含玩家角色或其他动态实体的排序
    -- local charFootY = viewMode == "topdown" and (charScreenY + tdTileH / 2) or (charScreenY + tileHH)
    -- table.insert(sortList, { footY = charFootY, footX = charScreenX, pri = 1, isFlat = false, t = "char", li = 0 })

    -- 稳定排序算法：
    -- 1. 优先绘制贴地瓦片 (isFlat)
    -- 2. 若均为 flat：先比较图层顺序；同图层的比较 footY (确保底部覆盖顶部)
    -- 3. 其他按深度(footY) -> X轴(footX) -> 优先级(pri) -> 图层顺序(li) 排列
    table.sort(sortList, function(a, b)
        if a.isFlat ~= b.isFlat then return a.isFlat end
        if a.isFlat and b.isFlat then
            if a.li ~= b.li then return a.li < b.li end
            if viewMode == "topdown" and a.footY ~= b.footY then return a.footY < b.footY end
        end
        if a.footY ~= b.footY then return a.footY < b.footY end
        if a.footX ~= b.footX then return a.footX < b.footX end
        if a.pri and b.pri and a.pri ~= b.pri then return a.pri < b.pri end
        return a.li < b.li
    end)

    -- 最后遍历 sortList 依次绘制所有物体和角色
    for _, item in ipairs(sortList) do
        if item.t == "char" then
            -- 绘制角色
        else
            -- 绘制物体瓦片 (注意传入从字典中查找到的 tileType)
            -- 纯色瓦片兜底：如果 JSON 导出了无图片的纯色占位瓦片 (tt.color)，需走绘制图形逻辑
            if item.tileType and item.tileType.imagePath then
                -- drawImageTile(item.cx, item.cy, imgInfo, item.tileType, item.tile.flipH)
            elseif item.tileType and item.tileType.color then
                -- local c = item.tileType.color
                -- drawTileShape(item.cx, item.cy, c[1], c[2], c[3], c[4])
            end
        end
    end
end
