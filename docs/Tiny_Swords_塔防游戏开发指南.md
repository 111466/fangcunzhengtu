# Tiny Swords 塔防游戏开发指南

**UrhoX 2D + Lua + NanoVG**
基于 Pixel Frog 素材包的完整实现方案

2026 年 5 月

---

## 目录

- [一、塔防游戏核心机制拆解](#一塔防游戏核心机制拆解)
- [二、项目结构设计](#二项目结构设计)
- [三、核心代码实现](#三核心代码实现)
  - [3.1 入口文件 Main.lua](#31-入口文件-mainlua)
  - [3.2 路径系统 Path.lua](#32-路径系统-pathlua)
  - [3.3 敌人系统 Enemy.lua](#33-敌人系统-enemylua)
  - [3.4 防御塔系统 Tower.lua](#34-防御塔系统-towerlua)
  - [3.5 子弹系统 Projectile.lua](#35-子弹系统-projectilelua)
  - [3.6 波次管理器 WaveManager.lua](#36-波次管理器-wavemanagerlua)
  - [3.7 UI 渲染 UI.lua](#37-ui-渲染-uilua)
- [四、Tiny Swords 素材映射方案](#四tiny-swords-素材映射方案)
- [五、开发路线图（分 5 个阶段）](#五开发路线图分-5-个阶段)
- [六、UrhoX 开发注意事项](#六urhox-开发注意事项)

---

## 一、塔防游戏核心机制拆解

任何塔防游戏都由以下 **5 个核心系统** 组成：

| 系统 | 作用 | UrhoX 实现方式 |
|------|------|---------------|
| **路径系统** | 敌人沿固定路线行进 | 路径点数组 + 插值移动 |
| **敌人系统** | 沿路径移动，有血量/速度 | Node + NanoVG 绘制 |
| **防御塔系统** | 放置在路径旁，自动攻击范围内敌人 | Node + 范围检测 + 攻击逻辑 |
| **波次系统** | 按波次生成敌人，逐步加难 | 计时器 + 配置表驱动 |
| **经济系统** | 金币用于建造/升级塔 | 击杀奖励 + 初始金币 |

**核心游戏循环**：玩家在路径旁放置防御塔 → 敌人沿路径行进 → 塔自动攻击范围内敌人 → 击杀获得金币 → 用金币建造/升级更多塔 → 阻止敌人到达终点。

---

## 二、项目结构设计

推荐的模块化项目结构如下，将不同系统拆分为独立文件，便于维护和调试：

```
tower-defense/
├── game.json              # 游戏元信息
├── README.md
├── preview/
│   └── icon.png           # 256×256 图标
├── assets/                # Tiny Swords 素材
│   ├── units/             # 战士、弓箭手等精灵图
│   ├── buildings/         # 防御塔、建筑精灵图
│   ├── enemies/           # 敌人精灵图
│   ├── terrain/           # 地形瓦片
│   ├── effects/           # 粒子特效
│   └── ui/                # UI 元素
└── scripts/
    ├── Main.lua           # 入口文件
    ├── Config.lua         # 游戏配置
    ├── Path.lua           # 路径系统
    ├── Enemy.lua          # 敌人逻辑
    ├── Tower.lua          # 防御塔逻辑
    ├── Projectile.lua     # 子弹/投射物
    ├── WaveManager.lua    # 波次管理
    ├── Economy.lua        # 经济系统
    ├── UI.lua             # UI 渲染（NanoVG）
    └── Utils.lua          # 工具函数
```

> ⚠️ **重要**：UrhoX 对单文件脚本有长度限制，因此必须将复杂功能拆分为多个 .lua 文件，避免代码过长无法运行。

---

## 三、核心代码实现

### 3.1 入口文件 Main.lua

入口文件负责初始化场景、NanoVG 上下文、游戏状态管理和主循环。

```lua
require "LuaScripts/Utilities/Sample"

local app = {}
---@type Scene
local scene_ = nil
---@type userdata|nil  -- NanoVG 上下文
local nvg_ = nil

-- 游戏状态枚举
local GameState = {
    MENU = "menu",
    PLAYING = "playing",
    PAUSED = "paused",
    GAME_OVER = "game_over",
    VICTORY = "victory",
}
local currentState_ = GameState.MENU

-- 游戏数据
local gold_ = 200
local lives_ = 20
local currentWave_ = 0
local enemies_ = {}       -- 存活敌人列表
local towers_ = {}        -- 已放置的塔列表
local projectiles_ = {}   -- 飞行中的子弹

function Start()
    -- 创建场景
    scene_ = Scene()

    -- 创建 NanoVG 上下文用于 2D 渲染
    nvg_ = nvgCreate(1)
    if nvg_ == nil then
        print("[ERROR] Failed to create NanoVG context")
        return
    end

    -- 加载配置
    Config = require("scripts/Config")

    -- 初始化子系统
    Path = require("scripts/Path")
    WaveManager = require("scripts/WaveManager")
    UI = require("scripts/UI")

    -- 设置 Update 事件
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("ScreenMode", "HandleScreenMode")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    if currentState_ == GameState.PLAYING then
        -- 更新敌人
        UpdateEnemies(dt)
        -- 更新防御塔（寻找目标、攻击）
        UpdateTowers(dt)
        -- 更新子弹
        UpdateProjectiles(dt)
        -- 更新波次管理器
        WaveManager.Update(dt)
        -- 检查胜负
        CheckWinLose()
    end

    -- 渲染（NanoVG）
    if nvg_ then
        nvgBeginFrame(nvg_, graphics.width, graphics.height, 1.0)
        RenderGame()
        UI.Render(nvg_, currentState_, gold_, lives_, currentWave_)
        nvgEndFrame(nvg_)
    end
end

function Stop()
    if nvg_ then
        nvgDelete(nvg_)
        nvg_ = nil
    end
end
```

---

### 3.2 路径系统 Path.lua

路径系统通过路径点数组定义敌人行进路线，支持根据进度 (0~1) 获取位置。

```lua
local Path = {}

-- 定义敌人行进路径（屏幕坐标点序列）
-- 对应 Tiny Swords 地形瓦片上的可行走路线
Path.waypoints = {
    { x = -50,  y = 300 },   -- 起点（屏幕外）
    { x = 200,  y = 300 },
    { x = 200,  y = 500 },
    { x = 500,  y = 500 },
    { x = 500,  y = 200 },
    { x = 800,  y = 200 },
    { x = 800,  y = 600 },
    { x = 1100, y = 600 },
    { x = 1100, y = 400 },
    { x = 1400, y = 400 },   -- 终点
}

-- 获取路径总长度
function Path.GetTotalLength()
    local total = 0
    for i = 2, #Path.waypoints do
        local dx = Path.waypoints[i].x - Path.waypoints[i-1].x
        local dy = Path.waypoints[i].y - Path.waypoints[i-1].y
        total = total + math.sqrt(dx*dx + dy*dy)
    end
    return total
end

-- 根据进度 (0~1) 获取路径上的位置
function Path.GetPosition(progress)
    if progress <= 0 then
        return Path.waypoints[1].x, Path.waypoints[1].y
    end
    if progress >= 1 then
        return Path.waypoints[#Path.waypoints].x, Path.waypoints[#Path.waypoints].y
    end

    local targetDist = progress * Path.GetTotalLength()
    local accumulated = 0

    for i = 2, #Path.waypoints do
        local dx = Path.waypoints[i].x - Path.waypoints[i-1].x
        local dy = Path.waypoints[i].y - Path.waypoints[i-1].y
        local segLen = math.sqrt(dx*dx + dy*dy)

        if accumulated + segLen >= targetDist then
            local t = (targetDist - accumulated) / segLen
            return Path.waypoints[i-1].x + dx * t,
                   Path.waypoints[i-1].y + dy * t
        end
        accumulated = accumulated + segLen
    end

    local last = Path.waypoints[#Path.waypoints]
    return last.x, last.y
end

return Path
```

---

### 3.3 敌人系统 Enemy.lua

敌人系统管理所有敌人的创建、移动、受伤和死亡逻辑。每种敌人有不同的属性（血量、速度、奖励金币）。

```lua
local Enemy = {}
Enemy.list = {}

-- 敌人类型配置（使用 Tiny Swords 素材）
Enemy.types = {
    -- 普通小兵（对应 Tiny Swords 基础敌人）
    grunt = {
        name = "哥布林小兵",
        health = 100,
        speed = 80,          -- 像素/秒
        reward = 10,
        damage = 1,          -- 到达终点扣血
        size = 24,
        color = { r=200, g=50, b=50 },  -- 红色阵营
    },
    -- 快速单位
    scout = {
        name = "暗影斥候",
        health = 60,
        speed = 150,
        reward = 15,
        damage = 1,
        size = 20,
        color = { r=150, g=50, b=200 }, -- 紫色阵营
    },
    -- 重型单位
    tank = {
        name = "装甲战士",
        health = 400,
        speed = 40,
        reward = 30,
        damage = 3,
        size = 32,
        color = { r=50, g=50, b=50 },   -- 黑色阵营
    },
}

-- 创建一个敌人
function Enemy.Create(typeName)
    local config = Enemy.types[typeName]
    if not config then return nil end

    local enemy = {
        type = typeName,
        config = config,
        health = config.health,
        maxHealth = config.health,
        progress = 0,        -- 路径进度 0~1
        x = 0, y = 0,
        alive = true,
        slowed = false,
        slowTimer = 0,
    }

    -- 初始位置
    enemy.x, enemy.y = Path.GetPosition(0)

    table.insert(Enemy.list, enemy)
    return enemy
end

-- 更新所有敌人
function Enemy.UpdateAll(dt)
    for i = #Enemy.list, 1, -1 do
        local e = Enemy.list[i]
        if not e.alive then
            table.remove(Enemy.list, i)
        else
            Enemy.Update(e, dt)
        end
    end
end

-- 更新单个敌人
function Enemy.Update(enemy, dt)
    -- 计算速度（考虑减速）
    local speed = enemy.config.speed
    if enemy.slowed then
        speed = speed * 0.5
        enemy.slowTimer = enemy.slowTimer - dt
        if enemy.slowTimer <= 0 then
            enemy.slowed = false
        end
    end

    -- 沿路径移动
    local totalLen = Path.GetTotalLength()
    enemy.progress = enemy.progress + (speed * dt) / totalLen

    -- 更新位置
    enemy.x, enemy.y = Path.GetPosition(enemy.progress)

    -- 到达终点
    if enemy.progress >= 1.0 then
        enemy.alive = false
        -- 扣除生命值
        lives_ = lives_ - enemy.config.damage
    end
end

-- 敌人受伤
function Enemy.Damage(enemy, amount)
    enemy.health = enemy.health - amount
    if enemy.health <= 0 then
        enemy.alive = false
        gold_ = gold_ + enemy.config.reward
    end
end

return Enemy
```

---

### 3.4 防御塔系统 Tower.lua

防御塔系统负责塔的创建、目标搜索、攻击和升级。三种塔类型分别映射到 Tiny Swords 的弓箭手、战士和僧侣。

```lua
local Tower = {}
Tower.list = {}

-- 防御塔类型配置（映射到 Tiny Swords 单位）
Tower.types = {
    -- 弓箭塔（对应 Tiny Swords Archer）
    archer = {
        name = "弓箭塔",
        cost = 50,
        damage = 25,
        range = 150,         -- 攻击范围（像素）
        fireRate = 1.0,      -- 每秒攻击次数
        color = { r=100, g=150, b=255 },  -- 蓝色阵营
        projectileSpeed = 300,
        projectileColor = { r=200, g=180, b=100 },
        size = 28,
    },
    -- 战士塔（对应 Tiny Swords Warrior，近战范围伤害）
    warrior = {
        name = "战士塔",
        cost = 80,
        damage = 50,
        range = 60,          -- 近战范围
        fireRate = 0.8,
        color = { r=100, g=200, b=100 },
        projectileSpeed = 0,  -- 无弹道，即时伤害
        projectileColor = nil,
        size = 32,
        splash = 40,         -- 溅射范围
    },
    -- 僧侣塔（对应 Tiny Swords Monk，减速效果）
    monk = {
        name = "僧侣塔",
        cost = 100,
        damage = 10,
        range = 120,
        fireRate = 0.5,
        color = { r=255, g=220, b=100 },  -- 黄色阵营
        projectileSpeed = 200,
        projectileColor = { r=255, g=255, b=200 },
        size = 26,
        slow = true,         -- 减速效果
        slowDuration = 2.0,
    },
}

function Tower.Create(typeName, x, y)
    local config = Tower.types[typeName]
    if not config then return nil end
    if gold_ < config.cost then return nil end  -- 金币不足

    gold_ = gold_ - config.cost

    local tower = {
        type = typeName,
        config = config,
        x = x,
        y = y,
        cooldown = 0,        -- 攻击冷却
        level = 1,
        target = nil,
    }

    table.insert(Tower.list, tower)
    return tower
end

-- 更新所有塔
function Tower.UpdateAll(dt)
    for _, tower in ipairs(Tower.list) do
        Tower.Update(tower, dt)
    end
end

-- 更新单个塔
function Tower.Update(tower, dt)
    tower.cooldown = tower.cooldown - dt

    -- 寻找范围内最近的敌人
    local closestEnemy = nil
    local closestDist = tower.config.range

    for _, enemy in ipairs(Enemy.list) do
        if enemy.alive then
            local dx = enemy.x - tower.x
            local dy = enemy.y - tower.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < closestDist then
                closestDist = dist
                closestEnemy = enemy
            end
        end
    end

    tower.target = closestEnemy

    -- 攻击
    if closestEnemy and tower.cooldown <= 0 then
        tower.cooldown = 1.0 / tower.config.fireRate

        if tower.config.projectileSpeed > 0 then
            -- 发射子弹
            Projectile.Create(
                tower.x, tower.y,
                closestEnemy,
                tower.config.damage,
                tower.config.projectileSpeed,
                tower.config.projectileColor,
                tower.config.slow,
                tower.config.slowDuration or 0,
                tower.config.splash or 0
            )
        else
            -- 即时伤害（近战）
            Enemy.Damage(closestEnemy, tower.config.damage)
            -- 溅射伤害
            if tower.config.splash then
                for _, enemy in ipairs(Enemy.list) do
                    if enemy ~= closestEnemy and enemy.alive then
                        local dx = enemy.x - closestEnemy.x
                        local dy = enemy.y - closestEnemy.y
                        if math.sqrt(dx*dx + dy*dy) < tower.config.splash then
                            Enemy.Damage(enemy, tower.config.damage * 0.5)
                        end
                    end
                end
            end
        end
    end
end

-- 升级塔
function Tower.Upgrade(tower)
    local cost = tower.config.cost * tower.level
    if gold_ < cost then return false end
    if tower.level >= 3 then return false end  -- 最高3级

    gold_ = gold_ - cost
    tower.level = tower.level + 1
    tower.config.damage = tower.config.damage * 1.5
    tower.config.range = tower.config.range * 1.15
    return true
end

return Tower
```

---

### 3.5 子弹系统 Projectile.lua

子弹系统管理所有飞行中的投射物，包括追踪目标、命中判定、溅射伤害和减速效果。

```lua
local Projectile = {}
Projectile.list = {}

function Projectile.Create(x, y, target, damage, speed, color, slow, slowDuration, splash)
    local p = {
        x = x, y = y,
        target = target,
        damage = damage,
        speed = speed,
        color = color or { r=255, g=255, b=255 },
        slow = slow or false,
        slowDuration = slowDuration or 0,
        splash = splash or 0,
        alive = true,
    }
    table.insert(Projectile.list, p)
    return p
end

function Projectile.UpdateAll(dt)
    for i = #Projectile.list, 1, -1 do
        local p = Projectile.list[i]

        -- 目标已死亡，子弹消失
        if not p.target or not p.target.alive then
            table.remove(Projectile.list, i)
        else
            -- 朝目标移动
            local dx = p.target.x - p.x
            local dy = p.target.y - p.y
            local dist = math.sqrt(dx*dx + dy*dy)

            if dist < 10 then
                -- 命中
                Enemy.Damage(p.target, p.damage)

                -- 减速效果
                if p.slow then
                    p.target.slowed = true
                    p.target.slowTimer = p.slowDuration
                end

                -- 溅射伤害
                if p.splash > 0 then
                    for _, enemy in ipairs(Enemy.list) do
                        if enemy ~= p.target and enemy.alive then
                            local sdx = enemy.x - p.target.x
                            local sdy = enemy.y - p.target.y
                            if math.sqrt(sdx*sdx + sdy*sdy) < p.splash then
                                Enemy.Damage(enemy, p.damage * 0.5)
                            end
                        end
                    end
                end

                table.remove(Projectile.list, i)
            else
                -- 移动子弹
                p.x = p.x + (dx / dist) * p.speed * dt
                p.y = p.y + (dy / dist) * p.speed * dt
            end
        end
    end
end

return Projectile
```

---

### 3.6 波次管理器 WaveManager.lua

波次管理器通过配置表驱动敌人生成，支持波次间准备时间和多种敌人混合生成。

```lua
local WaveManager = {}

-- 波次配置：每波生成哪些敌人
WaveManager.waves = {
    { -- 第1波：简单
        enemies = {
            { type = "grunt", count = 5, interval = 1.0 },
        },
        prepTime = 5.0,  -- 开局准备时间
    },
    { -- 第2波
        enemies = {
            { type = "grunt", count = 8, interval = 0.8 },
            { type = "scout", count = 3, interval = 1.2 },
        },
        prepTime = 10.0,
    },
    { -- 第3波
        enemies = {
            { type = "grunt", count = 10, interval = 0.6 },
            { type = "scout", count = 5, interval = 0.8 },
        },
        prepTime = 15.0,
    },
    { -- 第4波：引入坦克
        enemies = {
            { type = "grunt", count = 8, interval = 0.5 },
            { type = "tank", count = 2, interval = 3.0 },
        },
        prepTime = 15.0,
    },
    { -- 第5波：Boss 波
        enemies = {
            { type = "grunt", count = 15, interval = 0.4 },
            { type = "scout", count = 8, interval = 0.6 },
            { type = "tank", count = 4, interval = 2.0 },
        },
        prepTime = 20.0,
    },
}

WaveManager.currentWave = 0
WaveManager.spawnQueue = {}   -- 待生成的敌人队列
WaveManager.spawnTimer = 0
WaveManager.waveActive = false
WaveManager.prepTimer = 0
WaveManager.allWavesComplete = false

function WaveManager.StartNextWave()
    WaveManager.currentWave = WaveManager.currentWave + 1
    local wave = WaveManager.waves[WaveManager.currentWave]

    if not wave then
        WaveManager.allWavesComplete = true
        return
    end

    currentWave_ = WaveManager.currentWave

    -- 构建生成队列
    WaveManager.spawnQueue = {}
    for _, group in ipairs(wave.enemies) do
        for j = 1, group.count do
            table.insert(WaveManager.spawnQueue, {
                type = group.type,
                delay = group.interval,
            })
        end
    end

    WaveManager.spawnTimer = 0
    WaveManager.waveActive = true
end

function WaveManager.Update(dt)
    if WaveManager.allWavesComplete then return end

    -- 波次间准备时间
    if not WaveManager.waveActive then
        WaveManager.prepTimer = WaveManager.prepTimer - dt
        if WaveManager.prepTimer <= 0 then
            WaveManager.StartNextWave()
        end
        return
    end

    -- 生成敌人
    WaveManager.spawnTimer = WaveManager.spawnTimer - dt
    if WaveManager.spawnTimer <= 0 and #WaveManager.spawnQueue > 0 then
        local nextEnemy = table.remove(WaveManager.spawnQueue, 1)
        Enemy.Create(nextEnemy.type)
        WaveManager.spawnTimer = nextEnemy.delay
    end

    -- 检查当前波是否结束
    if #WaveManager.spawnQueue == 0 and #Enemy.list == 0 then
        WaveManager.waveActive = false
        -- 设置下一波准备时间
        local nextWave = WaveManager.waves[WaveManager.currentWave + 1]
        if nextWave then
            WaveManager.prepTimer = nextWave.prepTime
        else
            WaveManager.allWavesComplete = true
        end
    end
end

-- 初始化第一波
function WaveManager.Init()
    local firstWave = WaveManager.waves[1]
    WaveManager.prepTimer = firstWave.prepTime
end

return WaveManager
```

---

### 3.7 UI 渲染 UI.lua

使用 NanoVG 进行 2D 渲染，包括顶部 HUD（金币、生命、波次）和底部塔选择面板。所有绘制必须在 `nvgBeginFrame` 和 `nvgEndFrame` 之间完成。

```lua
local UI = {}

function UI.Render(nvg, state, gold, lives, wave)
    if state == "menu" then
        UI.RenderMenu(nvg)
        return
    end

    -- ===== 顶部 HUD =====
    nvgSave(nvg)

    -- 金币
    nvgFillColor(nvg, 255, 215, 0, 255)  -- 金色
    nvgFontSize(nvg, 24)
    nvgText(nvg, 20, 30, "金币: " .. gold)

    -- 生命值
    nvgFillColor(nvg, 255, 80, 80, 255)
    nvgText(nvg, 200, 30, "生命: " .. lives)

    -- 波次
    nvgFillColor(nvg, 255, 255, 255, 255)
    nvgText(nvg, 400, 30, "波次: " .. wave)

    -- ===== 底部塔选择栏 =====
    UI.RenderTowerPanel(nvg, gold)

    nvgRestore(nvg)
end

function UI.RenderTowerPanel(nvg, gold)
    local panelY = graphics.height - 100
    local startX = 20
    local towerTypes = { "archer", "warrior", "monk" }

    for i, typeName in ipairs(towerTypes) do
        local config = Tower.types[typeName]
        local x = startX + (i - 1) * 120

        -- 背景
        local canAfford = gold >= config.cost
        if canAfford then
            nvgFillColor(nvg, 60, 60, 80, 200)
        else
            nvgFillColor(nvg, 40, 40, 40, 150)
        end
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x, panelY, 100, 80, 8)
        nvgFill(nvg)

        -- 塔图标（用颜色方块代替精灵图）
        nvgFillColor(nvg, config.color.r, config.color.g, config.color.b, 255)
        nvgBeginPath(nvg)
        nvgCircle(nvg, x + 50, panelY + 30, 18)
        nvgFill(nvg)

        -- 名称和价格
        nvgFillColor(nvg, 255, 255, 255, 255)
        nvgFontSize(nvg, 14)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER)
        nvgText(nvg, x + 50, panelY + 58, config.name)
        nvgFillColor(nvg, 255, 215, 0, 255)
        nvgFontSize(nvg, 12)
        nvgText(nvg, x + 50, panelY + 73, config.cost .. "G")
    end
end

function UI.RenderMenu(nvg)
    nvgSave(nvg)
    nvgFillColor(nvg, 0, 0, 0, 180)
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, graphics.width, graphics.height)
    nvgFill(nvg)

    nvgFillColor(nvg, 255, 255, 255, 255)
    nvgFontSize(nvg, 48)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER)
    nvgText(nvg, graphics.width/2, graphics.height/2 - 40, "Tiny Swords 塔防")

    nvgFontSize(nvg, 24)
    nvgFillColor(nvg, 200, 200, 200, 255)
    nvgText(nvg, graphics.width/2, graphics.height/2 + 20, "点击屏幕开始游戏")

    nvgRestore(nvg)
end

return UI
```

---

## 四、Tiny Swords 素材映射方案

以下是将 Tiny Swords 素材包中的各类资源映射到塔防游戏各元素的方案：

| 游戏元素 | 使用的 Tiny Swords 素材 | 说明 |
|---------|----------------------|------|
| **弓箭塔** | Archer（蓝/黄/黑阵营） | 远程攻击，不同颜色区分等级 |
| **战士塔** | Warrior（蓝/黄/黑阵营） | 近战范围伤害 |
| **僧侣塔** | Monk（蓝/黄/黑阵营） | 减速+治疗光环 |
| **普通敌人** | Enemy Pack 基础敌人 | 红色/紫色阵营 |
| **快速敌人** | Enemy Pack 小型敌人 | 紫色阵营 |
| **Boss 敌人** | Enemy Pack 大型敌人 | 黑色阵营 |
| **地形** | Terrain Tiles | 草地、水面、高差 |
| **路径** | Terrain Tiles 平地 | 浅色瓦片铺设路径 |
| **UI** | UI Elements | 血条、按钮、横幅、图标 |
| **特效** | Particle FX | 火焰爆炸、灰尘、水花 |
| **放置点** | Buildings | 用建筑底座表示可建造位置 |

---

## 五、开发路线图（分 5 个阶段）

建议分 5 个阶段逐步开发，每个阶段完成后进行测试再进入下一阶段：

### 阶段 1：基础框架（1-2 天）

- 搭建项目结构，创建各模块文件
- 实现 Main.lua 入口 + NanoVG 初始化
- 绘制路径线 + 路径系统
- 用色块代替精灵图验证逻辑

### 阶段 2：核心玩法（2-3 天）

- 敌人沿路径移动
- 防御塔放置 + 范围攻击
- 子弹飞行 + 命中判定
- 经济系统（金币/建造/击杀奖励）

### 阶段 3：游戏内容（2 天）

- 波次系统（5-10 波）
- 3 种塔类型 + 升级机制
- 3 种敌人类型
- 胜负判定 + 游戏结束界面

### 阶段 4：素材替换 + 美化（2 天）

- 替换 Tiny Swords 精灵图
- 添加粒子特效
- UI 美化（Tiny Swords UI 素材）
- 音效（可选）

### 阶段 5：打磨发布（1-2 天）

- 数值平衡调整
- 移动端触屏适配
- game.json + README 完善
- 提交到 awesome-urhox-games

---

## 六、UrhoX 开发注意事项

1. **脚本长度限制**：UrhoX 对单文件脚本有长度限制，复杂功能务必拆分多个 `.lua` 文件
2. **NanoVG 渲染**：所有 2D 绘制在 `nvgBeginFrame` 和 `nvgEndFrame` 之间完成
3. **移动端适配**：使用 `graphics.width / graphics.height` 获取动态分辨率，不要硬编码
4. **触屏操作**：塔防游戏主要靠点击，需要处理 `Touch` 事件替代鼠标
5. **对象池**：敌人和子弹频繁创建/销毁，建议使用对象池优化性能
6. **参考项目**：GitHub 上已有 [UrhoX 塔防 PR](https://github.com/taptap/awesome-urhox-games/pull/5) 可参考其架构

### 参考资源

- UrhoX 塔防示例：https://github.com/taptap/awesome-urhox-games/pull/5
- UrhoX AI Dev Kit：https://urhox-demo-platform.spark.xd.com
- Tiny Swords 素材包：https://pixelfrog-assets.itch.io/tiny-swords
- Urho3D Lua 文档：https://urho3d.io/documentation/HEAD/_lua_script_a_p_i.html
