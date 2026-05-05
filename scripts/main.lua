
local Config = require("scripts/Config")
local Utils = require("scripts/Utils")
local Path = require("scripts/Path")
local Enemy = require("scripts/Enemy")
local Tower = require("scripts/Tower")
local Projectile = require("scripts/Projectile")
local WaveManager = require("scripts/WaveManager")
local GameUI = require("scripts/UI")
local GridMap = require("scripts/GridMap")
local RoutePlanner = require("scripts/RoutePlanner")
local Structure = require("scripts/Structure")
local BuildValidator = require("scripts/BuildValidator")

local vg_ = nil

local game_ = {}
local pointer_ = {
    x = 0,
    y = 0,
}
local debugMode_ = true

local function getGraphicsSize()
    local graphicsSubsystem = GetGraphics()
    return graphicsSubsystem:GetWidth(), graphicsSubsystem:GetHeight()
end

local function readVariantNumber(variant)
    if not variant then
        return nil
    end

    local okInt, intValue = pcall(function()
        return variant:GetInt()
    end)
    if okInt then
        return intValue
    end

    local okFloat, floatValue = pcall(function()
        return variant:GetFloat()
    end)
    if okFloat then
        return floatValue
    end

    return nil
end

local function resolveEventCoordinates(eventData, xKeys, yKeys)
    local x = nil
    local y = nil

    for _, key in ipairs(xKeys) do
        x = readVariantNumber(eventData[key])
        if x ~= nil then
            break
        end
    end

    for _, key in ipairs(yKeys) do
        y = readVariantNumber(eventData[key])
        if y ~= nil then
            break
        end
    end

    if x == nil or y == nil then
        return nil, nil
    end

    return x, y
end

local function getTransform()
    local screenWidth, screenHeight = getGraphicsSize()
    local scale = math.min(screenWidth / Config.WorldWidth, screenHeight / Config.WorldHeight)
    if scale <= 0 then
        scale = 1
    end

    return {
        scale = scale,
        ox = (screenWidth - Config.WorldWidth * scale) * 0.5,
        oy = (screenHeight - Config.WorldHeight * scale) * 0.5,
        screenWidth = screenWidth,
        screenHeight = screenHeight,
    }
end

local function screenToWorld(screenX, screenY)
    local transform = getTransform()
    return (screenX - transform.ox) / transform.scale, (screenY - transform.oy) / transform.scale
end

local function isInsideWorld(x, y)
    return x >= 0 and x <= Config.WorldWidth and y >= 0 and y <= Config.WorldHeight
end

local function resetGame()
    game_.state = "menu"
    game_.gold = Config.StartGold
    game_.lives = Config.StartLives
    game_.path = Path.Create(Config)
    game_.gridMap = GridMap.Create(Config)
    game_.currentRoute = nil
    game_.enemies = {}
    game_.towers = {}
    game_.projectiles = {}
    game_.structures = {}
    game_.waveManager = WaveManager.Create()
    game_.selectedTowerType = Config.TowerOrder[1]
    game_.selectedStructureType = "barricade"
    game_.selectedTower = nil
    game_.hoverSlotIndex = nil
    game_.hoverGridX = nil
    game_.hoverGridY = nil
    game_.buildMode = "tower"
    game_.message = nil
    game_.messageTimer = 0

    if #game_.gridMap.spawnPoints > 0 and #game_.gridMap.goalPoints > 0 then
        local spawn = game_.gridMap.spawnPoints[1]
        local goal = game_.gridMap.goalPoints[1]
        game_.currentRoute = RoutePlanner.FindPath(game_.gridMap, spawn.x, spawn.y, goal.x, goal.y)
    end
end

local function startRun()
    resetGame()
    game_.state = "playing"
end

local function getTowerOnSlot(slotIndex)
    for _, tower in ipairs(game_.towers) do
        if tower.slotIndex == slotIndex then
            return tower
        end
    end
    return nil
end

local function findSlotAt(x, y)
    for index, slot in ipairs(Config.BuildSlots) do
        if Utils.PointInCircle(x, y, slot.x, slot.y, 32) then
            return index
        end
    end
    return nil
end

local function findTowerAt(x, y)
    for index = #game_.towers, 1, -1 do
        local tower = game_.towers[index]
        if Tower.ContainsPoint(tower, x, y) then
            return tower
        end
    end
    return nil
end

local function spawnEnemy(typeName)
    local enemy = Enemy.Spawn(typeName, game_.path, game_.gridMap, game_.currentRoute)
    if enemy then
        game_.enemies[#game_.enemies + 1] = enemy
    end
end

local function spawnProjectile(data)
    game_.projectiles[#game_.projectiles + 1] = Projectile.Create(data)
end

local function countAliveEnemies()
    local count = 0
    for _, enemy in ipairs(game_.enemies) do
        if enemy.alive then
            count = count + 1
        end
    end
    return count
end

local function tryPlaceTower(slotIndex)
    local existingTower = getTowerOnSlot(slotIndex)
    if existingTower then
        game_.selectedTower = existingTower
        return
    end

    local cost = Tower.GetCost(game_.selectedTowerType)
    if game_.gold < cost then
        return
    end

    local slot = Config.BuildSlots[slotIndex]
    local tower = Tower.Create(game_.selectedTowerType, slot.x, slot.y)
    if not tower then
        return
    end

    tower.slotIndex = slotIndex
    game_.gold = game_.gold - cost
    game_.towers[#game_.towers + 1] = tower
    game_.selectedTower = tower
end

local function tryUpgradeSelectedTower()
    if not game_.selectedTower or not Tower.CanUpgrade(game_.selectedTower) then
        return
    end

    local cost = Tower.GetUpgradeCost(game_.selectedTower)
    if game_.gold < cost then
        return
    end

    if Tower.Upgrade(game_.selectedTower) then
        game_.gold = game_.gold - cost
    end
end

local function cleanupProjectiles()
    for index = #game_.projectiles, 1, -1 do
        if not game_.projectiles[index].alive then
            table.remove(game_.projectiles, index)
        end
    end
end

local function cleanupEnemies()
    for index = #game_.enemies, 1, -1 do
        local enemy = game_.enemies[index]
        if not enemy.alive then
            if enemy.killed then
                game_.gold = game_.gold + enemy.reward
            elseif enemy.escaped then
                game_.lives = game_.lives - enemy.damage
            end
            table.remove(game_.enemies, index)
        end
    end
end

local function showMessage(text, duration)
    game_.message = text
    game_.messageTimer = duration or 2.0
end

local function refreshHoverState()
    local worldX, worldY = screenToWorld(pointer_.x, pointer_.y)
    if game_.state ~= "playing" or not isInsideWorld(worldX, worldY) then
        game_.hoverSlotIndex = nil
        game_.hoverGridX = nil
        game_.hoverGridY = nil
        return
    end

    game_.hoverSlotIndex = findSlotAt(worldX, worldY)

    if game_.gridMap then
        local gx, gy = GridMap.WorldToGrid(game_.gridMap, worldX, worldY)
        game_.hoverGridX = gx
        game_.hoverGridY = gy
    end
end

local function recalculateRoute()
    if not game_.gridMap or #game_.gridMap.spawnPoints == 0 or #game_.gridMap.goalPoints == 0 then
        return
    end
    local spawn = game_.gridMap.spawnPoints[1]
    local goal = game_.gridMap.goalPoints[1]
    game_.currentRoute = RoutePlanner.FindPath(game_.gridMap, spawn.x, spawn.y, goal.x, goal.y)
end

local function tryPlaceStructure(gridX, gridY)
    local canPlace, reason = BuildValidator.CanPlaceStructure(game_.gridMap, game_.structures, gridX, gridY)
    if not canPlace then
        showMessage(reason, 1.5)
        return false
    end

    if BuildValidator.WouldBlockPathCompletely(game_.gridMap, game_.structures, gridX, gridY) then
        showMessage("会完全封死敌人路线", 1.5)
        return false
    end

    local definition = Config.StructureTypes[game_.selectedStructureType]
    if game_.gold < definition.cost then
        showMessage("金币不足", 1.5)
        return false
    end

    local worldX, worldY = GridMap.GridToWorld(game_.gridMap, gridX, gridY)
    local structure = Structure.Create(game_.selectedStructureType, gridX, gridY, worldX, worldY)
    if not structure then
        return false
    end

    game_.structures[#game_.structures + 1] = structure
    game_.gold = game_.gold - definition.cost

    local tile = GridMap.GetTile(game_.gridMap, gridX, gridY)
    if tile then
        tile.blocked = true
        tile.occupantType = "structure"
        tile.structureId = structure.id
    end

    recalculateRoute()
    return true
end

local function updateGameUI()
    local selectedTowerDefinition = Tower.types[game_.selectedTowerType]
    local selectedStructureDefinition = Config.StructureTypes[game_.selectedStructureType]
    local selectedTower = game_.selectedTower
    local upgradeText = "选中塔后按 U 升级"

    if selectedTower then
        if Tower.CanUpgrade(selectedTower) then
            upgradeText = "已选中 L" .. selectedTower.level .. "，升级费用: " .. Tower.GetUpgradeCost(selectedTower)
        else
            upgradeText = "已选中 L" .. selectedTower.level .. "，已满级"
        end
    end

    GameUI.Update({
        state = game_.state,
        gold = game_.gold,
        lives = game_.lives,
        wave = game_.waveManager.currentWave,
        maxWave = WaveManager.GetWaveCount(),
        statusText = game_.state == "paused" and "已暂停" or WaveManager.GetStatusText(game_.waveManager),
        selectedTowerName = selectedTowerDefinition.name,
        selectedTowerCost = selectedTowerDefinition.cost,
        selectedStructureName = selectedStructureDefinition.name,
        selectedStructureCost = selectedStructureDefinition.cost,
        buildMode = game_.buildMode,
        upgradeText = upgradeText,
    })
end

local function updatePlaying(dt)
    for _, structure in ipairs(game_.structures) do
        Structure.Update(structure, dt)
    end

    for _, enemy in ipairs(game_.enemies) do
        Enemy.Update(enemy, dt, game_.path, game_.gridMap, game_.currentRoute, game_.structures, Structure)
    end

    local structuresDestroyed = 0
    for i = #game_.structures, 1, -1 do
        local structure = game_.structures[i]
        if structure and structure.health &lt;= 0 then
            local tile = GridMap.GetTile(game_.gridMap, structure.gridX, structure.gridY)
            if tile then
                tile.blocked = false
                tile.occupantType = nil
                tile.structureId = nil
            end
            table.remove(game_.structures, i)
            structuresDestroyed = structuresDestroyed + 1
        end
    end

    if structuresDestroyed &gt; 0 then
        recalculateRoute()
        if structuresDestroyed == 1 then
            showMessage("路障被摧毁！", 1.2)
        else
            showMessage(string.format("%d 个路障被摧毁！", structuresDestroyed), 1.2)
        end
    end

    for _, tower in ipairs(game_.towers) do
        Tower.Update(tower, dt, game_.enemies, spawnProjectile, Enemy)
    end

    for _, projectile in ipairs(game_.projectiles) do
        Projectile.Update(projectile, dt, game_.enemies, Enemy)
    end

    if game_.messageTimer > 0 then
        game_.messageTimer = game_.messageTimer - dt
        if game_.messageTimer <= 0 then
            game_.message = nil
        end
    end

    cleanupProjectiles()
    cleanupEnemies()
    WaveManager.Update(game_.waveManager, dt, spawnEnemy, countAliveEnemies)

    if game_.lives <= 0 then
        game_.state = "game_over"
        game_.selectedTower = nil
    elseif WaveManager.IsFinished(game_.waveManager) and countAliveEnemies() == 0 and #game_.projectiles == 0 then
        game_.state = "victory"
    end
end

local function drawWorldBackground(nvg, transform)
    local colors = Config.Colors
    local x = transform.ox
    local y = transform.oy
    local width = Config.WorldWidth * transform.scale
    local height = Config.WorldHeight * transform.scale
    local gridSize = 40

    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, width, height)
    nvgFillColor(nvg, nvgRGBA(colors.background[1], colors.background[2], colors.background[3], colors.background[4]))
    nvgFill(nvg)

    if game_.gridMap then
        GridMap.Draw(nvg, game_.gridMap, transform, colors)
    else
        nvgBeginPath(nvg)
        for gridX = gridSize, Config.WorldWidth - 1, gridSize do
            local sx1, sy1 = Utils.ToScreen(transform, gridX, 0)
            local sx2, sy2 = Utils.ToScreen(transform, gridX, Config.WorldHeight)
            nvgMoveTo(nvg, sx1, sy1)
            nvgLineTo(nvg, sx2, sy2)
        end
        for gridY = gridSize, Config.WorldHeight - 1, gridSize do
            local sx1, sy1 = Utils.ToScreen(transform, 0, gridY)
            local sx2, sy2 = Utils.ToScreen(transform, Config.WorldWidth, gridY)
            nvgMoveTo(nvg, sx1, sy1)
            nvgLineTo(nvg, sx2, sy2)
        end
        nvgStrokeColor(nvg, nvgRGBA(colors.grid[1], colors.grid[2], colors.grid[3], colors.grid[4]))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
    end

    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, width, height)
    nvgStrokeColor(nvg, nvgRGBA(colors.border[1], colors.border[2], colors.border[3], colors.border[4]))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
end

local function drawBuildSlots(nvg, transform)
    local colors = Config.Colors
    for index, slot in ipairs(Config.BuildSlots) do
        local screenX, screenY = Utils.ToScreen(transform, slot.x, slot.y)
        local occupied = getTowerOnSlot(index) ~= nil
        local hovered = game_.hoverSlotIndex == index
        local radius = Utils.ToScreenSize(transform, 22)
        local color = occupied and colors.slotBlocked or colors.slot

        if hovered then
            color = colors.slotHighlight
        end

        nvgBeginPath(nvg)
        nvgCircle(nvg, screenX, screenY, radius)
        nvgStrokeColor(nvg, nvgRGBA(color[1], color[2], color[3], color[4]))
        nvgStrokeWidth(nvg, math.max(2, radius * 0.14))
        nvgStroke(nvg)

        nvgBeginPath(nvg)
        nvgMoveTo(nvg, screenX - radius * 0.55, screenY)
        nvgLineTo(nvg, screenX + radius * 0.55, screenY)
        nvgMoveTo(nvg, screenX, screenY - radius * 0.55)
        nvgLineTo(nvg, screenX, screenY + radius * 0.55)
        nvgStrokeColor(nvg, nvgRGBA(color[1], color[2], color[3], 180))
        nvgStrokeWidth(nvg, math.max(1, radius * 0.08))
        nvgStroke(nvg)
    end
end

local function drawPlacementPreview(nvg, transform)
    if game_.state ~= "playing" or not game_.hoverSlotIndex then
        return
    end

    if getTowerOnSlot(game_.hoverSlotIndex) then
        return
    end

    local definition = Tower.types[game_.selectedTowerType]
    local slot = Config.BuildSlots[game_.hoverSlotIndex]
    local x, y = Utils.ToScreen(transform, slot.x, slot.y)
    local size = Utils.ToScreenSize(transform, definition.size)
    local range = Utils.ToScreenSize(transform, definition.range)
    local affordable = game_.gold >= definition.cost
    local alpha = affordable and 180 or 80

    nvgBeginPath(nvg)
    nvgCircle(nvg, x, y, range)
    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, 80))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    nvgBeginPath(nvg)
    nvgRect(nvg, x - size * 0.5, y - size * 0.5, size, size)
    nvgStrokeColor(nvg, nvgRGBA(definition.color[1], definition.color[2], definition.color[3], alpha))
    nvgStrokeWidth(nvg, math.max(2, size * 0.12))
    nvgStroke(nvg)
end

local function drawStructurePlacementPreview(nvg, transform)
    if game_.state ~= "playing" or not game_.hoverGridX or not game_.hoverGridY then
        return
    end

    if not game_.gridMap then
        return
    end

    local tile = GridMap.GetTile(game_.gridMap, game_.hoverGridX, game_.hoverGridY)
    if not tile or not tile.fortifiable then
        return
    end

    local definition = Config.StructureTypes[game_.selectedStructureType]
    local worldX, worldY = GridMap.GridToWorld(game_.gridMap, game_.hoverGridX, game_.hoverGridY)
    local x, y = Utils.ToScreen(transform, worldX, worldY)
    local size = Utils.ToScreenSize(transform, definition.size)
    local affordable = game_.gold >= definition.cost
    local alpha = affordable and 150 or 60

    nvgBeginPath(nvg)
    nvgRect(nvg, x - size * 0.5, y - size * 0.5, size, size)
    nvgFillColor(nvg, nvgRGBA(definition.color[1], definition.color[2], definition.color[3], alpha))
    nvgStrokeColor(nvg, nvgRGBA(definition.outline[1], definition.outline[2], definition.outline[3], alpha))
    nvgStrokeWidth(nvg, math.max(2, size * 0.12))
    nvgFill(nvg)
    nvgStroke(nvg)
end

local function drawPausedOverlay(nvg, transform)
    if game_.state ~= "paused" then
        return
    end

    nvgBeginPath(nvg)
    nvgRect(nvg, transform.ox, transform.oy, Config.WorldWidth * transform.scale, Config.WorldHeight * transform.scale)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 110))
    nvgFill(nvg)
end

local function drawMessage(nvg, transform)
    if not game_.message or game_.messageTimer <= 0 then
        return
    end

    local centerX = transform.ox + (Config.WorldWidth * transform.scale) * 0.5
    local centerY = transform.oy + (Config.WorldHeight * transform.scale) * 0.15

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, centerX - 200, centerY - 30, 400, 60, 12)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
    nvgFill(nvg)

    nvgFontSize(nvg, 20)
    nvgFontFace(nvg, "sans")
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 200, 100, 255))
    nvgText(nvg, centerX, centerY, game_.message)
end

local function handlePointerPressed(screenX, screenY)
    pointer_.x = screenX
    pointer_.y = screenY

    if game_.state == "menu" then
        startRun()
        return
    end

    if game_.state == "victory" or game_.state == "game_over" then
        startRun()
        return
    end

    if game_.state ~= "playing" then
        return
    end

    local worldX, worldY = screenToWorld(screenX, screenY)
    if not isInsideWorld(worldX, worldY) then
        return
    end

    local tower = findTowerAt(worldX, worldY)
    if tower then
        game_.selectedTower = tower
        return
    end

    local slotIndex = findSlotAt(worldX, worldY)
    if slotIndex then
        tryPlaceTower(slotIndex)
        return
    end

    if game_.gridMap and game_.hoverGridX and game_.hoverGridY then
        if tryPlaceStructure(game_.hoverGridX, game_.hoverGridY) then
            return
        end
    end

    game_.selectedTower = nil
end

function Start()
    graphics.windowTitle = Config.WindowTitle
    vg_ = nvgCreate(1)
    if vg_ == nil then
        print("[ERROR] Failed to create NanoVG context")
        return
    end

    if input and input.SetMouseVisible then
        input:SetMouseVisible(true)
    end

    GameUI.Init()
    resetGame()
    updateGameUI()

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("MouseMove", "HandleMouseMove")
    SubscribeToEvent("MouseButtonDown", "HandleMouseButtonDown")
    SubscribeToEvent("TouchBegin", "HandleTouchBegin")
    SubscribeToEvent("TouchMove", "HandleTouchMove")
    SubscribeToEvent(vg_, "NanoVGRender", "HandleNanoVGRender")
end

function Stop()
    if vg_ ~= nil then
        nvgDelete(vg_)
        vg_ = nil
    end
    GameUI.Shutdown()
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    refreshHoverState()
    if game_.state == "playing" then
        updatePlaying(dt)
    end
    updateGameUI()
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    if key == KEY_RETURN or key == KEY_RETURN2 or key == KEY_SPACE then
        if game_.state == "menu" then
            startRun()
        end
        return
    end

    if key == KEY_R then
        startRun()
        return
    end

    if key == KEY_P and (game_.state == "playing" or game_.state == "paused") then
        game_.state = game_.state == "playing" and "paused" or "playing"
        return
    end

    if key == KEY_U then
        tryUpgradeSelectedTower()
        return
    end

    if key == KEY_ESCAPE then
        resetGame()
        return
    end

    if key == KEY_1 then
        game_.selectedTowerType = Config.TowerOrder[1]
        game_.buildMode = "tower"
        showMessage("切换到：弓箭塔", 0.8)
    elseif key == KEY_2 then
        game_.selectedTowerType = Config.TowerOrder[2]
        game_.buildMode = "tower"
        showMessage("切换到：战士塔", 0.8)
    elseif key == KEY_3 then
        game_.selectedTowerType = Config.TowerOrder[3]
        game_.buildMode = "tower"
        showMessage("切换到：僧侣塔", 0.8)
    elseif key == KEY_4 then
        game_.selectedStructureType = "barricade"
        game_.buildMode = "structure"
        showMessage("切换到：路障", 0.8)
    elseif key == KEY_5 then
        game_.selectedStructureType = "wall"
        game_.buildMode = "structure"
        showMessage("切换到：石墙", 0.8)
    elseif key == KEY_6 then
        game_.selectedStructureType = "spikeTrap"
        game_.buildMode = "structure"
        showMessage("切换到：尖刺陷阱", 0.8)
    elseif key == KEY_TAB then
        game_.buildMode = game_.buildMode == "tower" and "structure" or "tower"
        showMessage(game_.buildMode == "tower" and "建造模式：塔" or "建造模式：工事", 0.8)
    end
end

function HandleMouseMove(eventType, eventData)
    local x, y = resolveEventCoordinates(eventData, { "X", "ScreenX" }, { "Y", "ScreenY" })
    if x ~= nil and y ~= nil then
        pointer_.x = x
        pointer_.y = y
    end
end

function HandleMouseButtonDown(eventType, eventData)
    local button = readVariantNumber(eventData["Button"])
    if button ~= nil and button ~= MOUSEB_LEFT then
        return
    end

    local x, y = resolveEventCoordinates(eventData, { "X", "ScreenX" }, { "Y", "ScreenY" })
    if x ~= nil and y ~= nil then
        handlePointerPressed(x, y)
    end
end

function HandleTouchBegin(eventType, eventData)
    local x, y = resolveEventCoordinates(
        eventData,
        { "X", "ScreenX", "ElementX", "PositionX" },
        { "Y", "ScreenY", "ElementY", "PositionY" }
    )
    if x ~= nil and y ~= nil then
        handlePointerPressed(x, y)
    end
end

function HandleTouchMove(eventType, eventData)
    local x, y = resolveEventCoordinates(
        eventData,
        { "X", "ScreenX", "ElementX", "PositionX" },
        { "Y", "ScreenY", "ElementY", "PositionY" }
    )
    if x ~= nil and y ~= nil then
        pointer_.x = x
        pointer_.y = y
    end
end

function HandleNanoVGRender(eventType, eventData)
    if vg_ == nil then
        return
    end

    local transform = getTransform()
    nvgBeginFrame(vg_, transform.screenWidth, transform.screenHeight, 1.0)

    drawWorldBackground(vg_, transform)
    
    if game_.currentRoute and debugMode_ then
        RoutePlanner.Draw(vg_, game_.currentRoute, game_.gridMap, transform, Config.Colors)
    end
    
    Path.Draw(vg_, game_.path, transform, Config.Colors)
    drawBuildSlots(vg_, transform)

    for _, structure in ipairs(game_.structures) do
        Structure.Draw(vg_, structure, transform)
    end

    for _, projectile in ipairs(game_.projectiles) do
        Projectile.Draw(vg_, projectile, transform)
    end

    for _, tower in ipairs(game_.towers) do
        Tower.Draw(vg_, tower, transform, game_.selectedTower == tower)
    end

    for _, enemy in ipairs(game_.enemies) do
        Enemy.Draw(vg_, enemy, transform)
    end

    drawPlacementPreview(vg_, transform)
    drawStructurePlacementPreview(vg_, transform)
    drawPausedOverlay(vg_, transform)
    drawMessage(vg_, transform)

    nvgEndFrame(vg_)
end

