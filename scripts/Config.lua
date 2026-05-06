local Config = {}

Config.SCREEN_WIDTH = 1280
Config.SCREEN_HEIGHT = 720

Config.WORLD_WIDTH = 4000
Config.WORLD_HEIGHT = 3000

Config.HERO_SPAWN = { x = 3500, y = 2500 }

-- 领地系统
Config.CAMP_OFFSET = { x = 0, y = -60 }  -- 营地相对出生点偏移
Config.TERRITORY_RADIUS = 500             -- 初始领地半径

Config.INITIAL_GOLD = 200
Config.INITIAL_LIVES = 20

return Config
