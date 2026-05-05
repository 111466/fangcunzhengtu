local Config = {}

Config.WindowTitle = "Tiny Swords Tower Defense"

Config.WorldWidth = 1280
Config.WorldHeight = 720
Config.PathWidth = 54

Config.StartGold = 180
Config.StartLives = 20

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
