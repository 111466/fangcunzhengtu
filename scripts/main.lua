-- ============================================================================
-- map.json driven top-down map renderer
-- ============================================================================

local CONFIG = {
    Title = "Map Viewer",
    BaseTileWidth = 40,
    BaseTileHeight = 40,
    MapPadding = 120,
    BackgroundColor = { 20, 28, 34, 255 },
    GridColor = { 255, 255, 255, 36 },
    MissingTileColor = { 255, 64, 96, 180 },
}

---@type integer
local vg_ = nil

local mapState = {
    data = nil,
    width = 0,
    height = 0,
    tileDict = {},
    imageCatalog = {},
    imageCache = {},
    showGrid = false,
    loadError = nil,
}

local function copyFields(dst, src)
    if not src then
        return dst
    end
    for key, value in pairs(src) do
        dst[key] = value
    end
    return dst
end

local function buildTileDict(registry)
    local dict = {}
    if not registry then
        return dict
    end
    for _, entry in ipairs(registry) do
        if entry.id ~= nil then
            dict[entry.id] = entry
        end
    end
    return dict
end

local function updateImageBounds(catalog, imagePath, source)
    if not imagePath or imagePath == "" or not source then
        return
    end

    local entry = catalog[imagePath]
    if not entry then
        entry = { width = 64, height = 64 }
        catalog[imagePath] = entry
    end

    local function considerRect(rect)
        if not rect then
            return
        end
        local maxX = (rect.x or 0) + (rect.w or 0)
        local maxY = (rect.y or 0) + (rect.h or 0)
        if maxX > entry.width then
            entry.width = maxX
        end
        if maxY > entry.height then
            entry.height = maxY
        end
    end

    considerRect(source.rect)
    if source.frames then
        for _, frame in ipairs(source.frames) do
            considerRect(frame)
        end
    end
end

local function buildImageCatalog(data)
    local catalog = {}

    for _, entry in ipairs(data.imageRegistry or {}) do
        updateImageBounds(catalog, entry.imagePath or entry.path, entry)
    end

    for _, layer in ipairs(data.layers or {}) do
        for _, tile in ipairs(layer.tiles or {}) do
            updateImageBounds(catalog, tile.imagePath or tile.path, tile)
        end
    end

    return catalog
end

local function inferMapSize(data)
    local width = tonumber(data.width) or 0
    local height = tonumber(data.height) or 0

    for _, layer in ipairs(data.layers or {}) do
        for _, tile in ipairs(layer.tiles or {}) do
            if (tile.x or 0) > width then
                width = tile.x
            end
            if (tile.y or 0) > height then
                height = tile.y
            end
        end
    end

    return width, height
end

local function getDPR(gfx)
    local dpr = 1.0
    if gfx.GetDPR then
        dpr = gfx:GetDPR()
    end
    if not dpr or dpr <= 0 then
        dpr = 1.0
    end
    return dpr
end

local function mapToScreen(mx, my, originX, originY, tileW, tileH)
    local ix = (mx or 1) - 1
    local iy = (my or 1) - 1
    return ix * tileW + originX, iy * tileH + originY
end

local function getCurrentSourceRect(tileType)
    if tileType.frames and #tileType.frames > 0 then
        local fps = tileType.fps or 10
        local elapsed = time and time:GetElapsedTime() or 0
        local frameIndex = math.floor(elapsed * fps) % #tileType.frames + 1
        return tileType.frames[frameIndex]
    end
    return tileType.rect
end

local function getMaxSourceHeight(tileType)
    local maxHeight = 0
    if tileType.rect and tileType.rect.h and tileType.rect.h > maxHeight then
        maxHeight = tileType.rect.h
    end
    if tileType.frames then
        for _, frame in ipairs(tileType.frames) do
            if frame.h and frame.h > maxHeight then
                maxHeight = frame.h
            end
        end
    end
    return maxHeight
end

local function getViewportForMap(data, viewW, viewH)
    local width = math.max(mapState.width, 1)
    local height = math.max(mapState.height, 1)

    local maxTallDrawH = CONFIG.BaseTileHeight
    for _, entry in pairs(mapState.tileDict) do
        local renderMode = entry.renderMode or "vertical"
        if renderMode ~= "flat" and renderMode ~= "floor" then
            local srcH = getMaxSourceHeight(entry)
            if srcH > 0 then
                local scaleFactor = entry.scale or 1.0
                local drawH = srcH * (CONFIG.BaseTileWidth / 64) * scaleFactor
                if drawH > maxTallDrawH then
                    maxTallDrawH = drawH
                end
            end
        end
    end

    local extraTop = math.max(0, maxTallDrawH - CONFIG.BaseTileHeight)
    local fitW = math.max(1, viewW - CONFIG.MapPadding * 2)
    local fitH = math.max(1, viewH - CONFIG.MapPadding * 2)
    local zoomX = fitW / (width * CONFIG.BaseTileWidth)
    local zoomY = fitH / (height * CONFIG.BaseTileHeight + extraTop)
    local zoom = math.min(zoomX, zoomY, 1.0)
    if zoom <= 0 then
        zoom = 1.0
    end

    local tileW = CONFIG.BaseTileWidth * zoom
    local tileH = CONFIG.BaseTileHeight * zoom
    local mapPixelW = width * tileW
    local mapPixelH = height * tileH
    local extraTopPx = extraTop * zoom
    local left = (viewW - mapPixelW) * 0.5
    local top = (viewH - (mapPixelH + extraTopPx)) * 0.5

    return {
        zoom = zoom,
        tileW = tileW,
        tileH = tileH,
        originX = left + tileW * 0.5,
        originY = top + extraTopPx + tileH * 0.5,
        left = left,
        top = top + extraTopPx,
        width = mapPixelW,
        height = mapPixelH,
    }
end

local function resolveTileType(tile)
    local resolved = {}
    local registryEntry = nil
    if tile.id ~= nil then
        registryEntry = mapState.tileDict[tile.id]
    end

    copyFields(resolved, registryEntry)
    copyFields(resolved, tile)

    if resolved.imagePath == nil and resolved.path ~= nil then
        resolved.imagePath = resolved.path
    end

    return resolved
end

local function ensureImageInfo(imagePath)
    if not imagePath or imagePath == "" then
        return nil
    end

    local cached = mapState.imageCache[imagePath]
    if cached then
        return cached
    end

    local bounds = mapState.imageCatalog[imagePath] or { width = 64, height = 64 }
    local handle = nvgCreateImage(vg_, imagePath, 0)
    local info = {
        path = imagePath,
        handle = handle,
        width = bounds.width or 64,
        height = bounds.height or 64,
        failed = (handle == nil or handle <= 0),
    }

    if info.failed then
        print("WARN: Failed to create NanoVG image for " .. imagePath)
    end

    mapState.imageCache[imagePath] = info
    return info
end

local function buildDrawItem(tile, layerIndex, layerOpacity, viewport)
    local tileType = resolveTileType(tile)
    local imagePath = tileType.imagePath or tileType.path
    local imageInfo = ensureImageInfo(imagePath)
    local sourceRect = getCurrentSourceRect(tileType)
    local renderMode = tileType.renderMode or "vertical"
    local scaleFactor = tileType.scale or 1.0

    if (renderMode == "flat" or renderMode == "floor") and tileType.scale == nil then
        scaleFactor = scaleFactor * 1.015
    end

    local pxScale = (viewport.tileW / 64) * scaleFactor
    local srcW = sourceRect and sourceRect.w or (imageInfo and imageInfo.width or 64)
    local srcH = sourceRect and sourceRect.h or (imageInfo and imageInfo.height or 64)
    local drawW = srcW * pxScale
    local drawH = srcH * pxScale

    local cx, cy = mapToScreen(tile.x, tile.y, viewport.originX, viewport.originY, viewport.tileW, viewport.tileH)
    local drawX = cx - drawW * 0.5
    local drawY
    if renderMode == "flat" or renderMode == "floor" then
        drawY = cy - drawH * 0.5
    else
        drawY = (cy + viewport.tileH * 0.5) - drawH
    end

    local footY
    if renderMode == "flat" or renderMode == "floor" then
        footY = drawY + drawH
    else
        footY = cy + viewport.tileH * 0.5
    end

    return {
        tile = tile,
        tileType = tileType,
        imageInfo = imageInfo,
        sourceRect = sourceRect,
        layerIndex = layerIndex,
        opacity = layerOpacity or 1.0,
        cx = cx,
        cy = cy,
        drawX = drawX,
        drawY = drawY,
        drawW = drawW,
        drawH = drawH,
        footX = cx,
        footY = footY,
        isFlat = (renderMode == "flat" or renderMode == "floor"),
        pxScale = pxScale,
    }
end

local function drawMissingTile(item)
    nvgBeginPath(vg_)
    nvgRect(vg_, item.drawX, item.drawY, item.drawW, item.drawH)
    nvgFillColor(vg_, nvgRGBA(
        CONFIG.MissingTileColor[1],
        CONFIG.MissingTileColor[2],
        CONFIG.MissingTileColor[3],
        CONFIG.MissingTileColor[4]))
    nvgFill(vg_)
end

local function drawImageTile(item)
    if not item.imageInfo or item.imageInfo.failed then
        drawMissingTile(item)
        return
    end

    local src = item.sourceRect or { x = 0, y = 0 }
    local alpha = item.opacity or 1.0

    nvgSave(vg_)
    if item.tile.flipH then
        nvgTranslate(vg_, item.drawX + item.drawW, item.drawY)
        nvgScale(vg_, -1, 1)
    else
        nvgTranslate(vg_, item.drawX, item.drawY)
    end

    local paint = nvgImagePattern(
        vg_,
        -(src.x or 0) * item.pxScale,
        -(src.y or 0) * item.pxScale,
        item.imageInfo.width * item.pxScale,
        item.imageInfo.height * item.pxScale,
        0,
        item.imageInfo.handle,
        alpha
    )

    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, item.drawW, item.drawH)
    nvgFillPaint(vg_, paint)
    nvgFill(vg_)
    nvgRestore(vg_)
end

local function drawGrid(viewport)
    if not mapState.showGrid then
        return
    end

    nvgBeginPath(vg_)
    nvgStrokeColor(vg_, nvgRGBA(
        CONFIG.GridColor[1],
        CONFIG.GridColor[2],
        CONFIG.GridColor[3],
        CONFIG.GridColor[4]))
    nvgStrokeWidth(vg_, 1)

    for col = 0, mapState.width do
        local x = viewport.left + col * viewport.tileW
        nvgMoveTo(vg_, x, viewport.top)
        nvgLineTo(vg_, x, viewport.top + viewport.height)
    end

    for row = 0, mapState.height do
        local y = viewport.top + row * viewport.tileH
        nvgMoveTo(vg_, viewport.left, y)
        nvgLineTo(vg_, viewport.left + viewport.width, y)
    end

    nvgStroke(vg_)
end

local function drawBackground(viewW, viewH)
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, viewW, viewH)
    nvgFillColor(vg_, nvgRGBA(
        CONFIG.BackgroundColor[1],
        CONFIG.BackgroundColor[2],
        CONFIG.BackgroundColor[3],
        CONFIG.BackgroundColor[4]))
    nvgFill(vg_)
end

local function loadMap()
    local path = "map.json"
    local f = cache:GetFile(path)
    if not f then
        mapState.loadError = "Failed to open " .. path .. " from ResourceCache"
        print("ERROR: " .. mapState.loadError)
        return
    end

    local jsonStr = f:ReadString()
    f:Close()

    local ok, decoded = pcall(cjson.decode, jsonStr)
    if not ok or type(decoded) ~= "table" then
        mapState.loadError = "Failed to decode map.json"
        print("ERROR: " .. mapState.loadError)
        return
    end

    mapState.data = decoded
    mapState.tileDict = buildTileDict(decoded.imageRegistry)
    mapState.imageCatalog = buildImageCatalog(decoded)
    mapState.imageCache = {}
    mapState.width, mapState.height = inferMapSize(decoded)
    mapState.showGrid = decoded.showGrid == true
    mapState.loadError = nil

    print(string.format(
        "Loaded map.json (%dx%d, %d layers)",
        mapState.width,
        mapState.height,
        #(decoded.layers or {})
    ))
end

local function subscribeToEvents()
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent(vg_, "NanoVGRender", "HandleNanoVGRender")
end

function Start()
    graphics.windowTitle = CONFIG.Title

    vg_ = nvgCreate(1)
    if vg_ == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    loadMap()
    subscribeToEvents()

    print("=== Game Started: " .. CONFIG.Title .. " ===")
    print("Controls: G toggle grid, R reload map.json")
end

function Stop()
    if vg_ ~= nil then
        nvgDelete(vg_)
        vg_ = nil
    end
end

---@param eventType string
---@param eventData table
function HandleNanoVGRender(eventType, eventData)
    if vg_ == nil then
        return
    end

    local gfx = GetGraphics()
    local dpr = getDPR(gfx)
    local viewW = gfx:GetWidth() / dpr
    local viewH = gfx:GetHeight() / dpr

    nvgBeginFrame(vg_, viewW, viewH, dpr)
    drawBackground(viewW, viewH)

    if not mapState.data or mapState.loadError ~= nil then
        nvgEndFrame(vg_)
        return
    end

    local viewport = getViewportForMap(mapState.data, viewW, viewH)
    local drawList = {}

    for layerIndex, layer in ipairs(mapState.data.layers or {}) do
        if layer.visible ~= false and (layer.opacity == nil or layer.opacity > 0) then
            local layerOpacity = layer.opacity or 1.0
            for _, tile in ipairs(layer.tiles or {}) do
                drawList[#drawList + 1] = buildDrawItem(tile, layerIndex, layerOpacity, viewport)
            end
        end
    end

    table.sort(drawList, function(a, b)
        if a.isFlat ~= b.isFlat then
            return a.isFlat
        end
        if a.isFlat and b.isFlat then
            if a.layerIndex ~= b.layerIndex then
                return a.layerIndex < b.layerIndex
            end
            if a.footY ~= b.footY then
                return a.footY < b.footY
            end
        end
        if a.footY ~= b.footY then
            return a.footY < b.footY
        end
        if a.footX ~= b.footX then
            return a.footX < b.footX
        end
        return a.layerIndex < b.layerIndex
    end)

    for _, item in ipairs(drawList) do
        drawImageTile(item)
    end

    drawGrid(viewport)
    nvgEndFrame(vg_)
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    if key == KEY_G then
        mapState.showGrid = not mapState.showGrid
        print("Grid: " .. (mapState.showGrid and "ON" or "OFF"))
    elseif key == KEY_R then
        loadMap()
        print("Map reloaded from assets/map.json")
    end
end
