local Config = require("scripts/Config")
local Utils = require("scripts/Utils")
local Path = require("scripts/Path")
local Enemy = require("scripts/Enemy")
local Tower = require("scripts/Tower")
local Projectile = require("scripts/Projectile")
local WaveManager = require("scripts/WaveManager")
local GameUI = require("scripts/UI")

local vg_ = nil

local game_ = {}
local pointer_ = {
    x = 0,
    y = 0,
}

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
    game_.enemies = {}
    game_.towers = {}
    game_.projectiles = {}
    game_.waveManager = WaveManager.Create()
    game_.selectedTowerType = Config.TowerOrder[1]
    game_.selectedTower = nil
    game_.hoverSlotIndex = nil
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
    local enemy = Enemy.Spawn(typeName, game_.path)
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

local function refreshHoverState()
    local worldX, worldY = screenToWorld(pointer_.x, pointer_.y)
    if game_.state ~= "playing" or not isInsideWorld(worldX, worldY) then
        game_.hoverSlotIndex = nil
        return
    end

    game_.hoverSlotIndex = findSlotAt(worldX, worldY)
end

local function updateGameUI()
    local selectedDefinition = Tower.types[game_.selectedTowerType]
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
        selectedTowerName = selectedDefinition.name,
        selectedTowerCost = selectedDefinition.cost,
        upgradeText = upgradeText,
    })
end

local function updatePlaying(dt)
    for _, enemy in ipairs(game_.enemies) do
        Enemy.Update(enemy, dt, game_.path)
    end

    for _, tower in ipairs(game_.towers) do
        Tower.Update(tower, dt, game_.enemies, spawnProjectile, Enemy)
    end

    for _, projectile in ipairs(game_.projectiles) do
        Projectile.Update(projectile, dt, game_.enemies, Enemy)
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

local function drawPausedOverlay(nvg, transform)
    if game_.state ~= "paused" then
        return
    end

    nvgBeginPath(nvg)
    nvgRect(nvg, transform.ox, transform.oy, Config.WorldWidth * transform.scale, Config.WorldHeight * transform.scale)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 110))
    nvgFill(nvg)
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
    elseif key == KEY_2 then
        game_.selectedTowerType = Config.TowerOrder[2]
    elseif key == KEY_3 then
        game_.selectedTowerType = Config.TowerOrder[3]
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
    Path.Draw(vg_, game_.path, transform, Config.Colors)
    drawBuildSlots(vg_, transform)

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
    drawPausedOverlay(vg_, transform)

    nvgEndFrame(vg_)
end
