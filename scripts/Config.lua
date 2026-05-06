local Config = {}

Config.SCREEN_WIDTH = 1280
Config.SCREEN_HEIGHT = 720

Config.WORLD_WIDTH = 4000
Config.WORLD_HEIGHT = 3000

Config.HERO_SPAWN = { x = 3500, y = 2500 }

-- 领地系统
Config.CAMP_OFFSET = { x = 0, y = 0 }    -- 城堡位于领地中心
Config.HERO_SPAWN_OFFSET_Y = 120         -- 英雄出生在城堡下方的偏移
Config.TERRITORY_RADIUS = 500             -- 初始领地半径

-- 敌方势力
Config.ENEMY_BASE = { x = 500, y = 500 }       -- 敌方城堡位置（左上角）
Config.ENEMY_TERRITORY_RADIUS = 500             -- 敌方领地半径
Config.ENEMY_BARRACKS_OFFSET = { x = 160, y = 100 }  -- 兵营相对敌方城堡的偏移

Config.INITIAL_GOLD = 200
Config.INITIAL_LIVES = 20

return Config
