local Config = {}

Config.WindowTitle = "Tiny Swords Tower Defense"

Config.WorldWidth = 1280
Config.WorldHeight = 768
Config.PathWidth = 54

Config.StartGold = 180
Config.StartLives = 20

Config.TileSize = 64
Config.GridWidth = 20
Config.GridHeight = 12

Config.TowerOrder = { "archer", "warrior", "monk" }

Config.BuildSlots = {
    { x = 170, y = 200 },
    { x = 320, y = 460 },
    { x = 430, y = 185 },
    { x = 610, y = 365 },
    { x = 760, y = 120 },
    { x = 890, y = 540 },
    { x = 1040, y = 290 },
    { x = 1160, y = 560 },
}

Config.StructureTypes = {
    barricade = {
        name = "路障",
        cost = 25,
        health = 100,
        maxHealth = 100,
        size = 40,
        color = { 160, 120, 80, 255 },
        outline = { 200, 170, 130, 255 },
        blocksPath = true,
    },
    wall = {
        name = "石墙",
        cost = 60,
        health = 250,
        maxHealth = 250,
        size = 40,
        color = { 100, 100, 110, 255 },
        outline = { 160, 160, 170, 255 },
        blocksPath = true,
    },
    spikeTrap = {
        name = "尖刺陷阱",
        cost = 40,
        health = 80,
        maxHealth = 80,
        size = 40,
        color = { 120, 60, 60, 255 },
        outline = { 180, 100, 100, 255 },
        blocksPath = false,
        damage = 20,
    },
}

Config.Colors = {
    background = { 24, 34, 42, 255 },
    border = { 90, 115, 130, 255 },
    grid = { 70, 90, 105, 65 },
    pathFill = { 72, 90, 60, 255 },
    pathOutline = { 190, 210, 150, 255 },
    slot = { 120, 160, 220, 220 },
    slotBlocked = { 80, 80, 80, 160 },
    slotHighlight = { 255, 225, 120, 255 },
    placementPreview = { 255, 255, 255, 120 },
}

return Config
