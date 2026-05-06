
Config = require("scripts.Config")
Utils = require("scripts.Utils")
Map = require("scripts.Map")
Camera = require("scripts.Camera")
Minimap = require("scripts.Minimap")
Particle = require("scripts.Particle")
Hero = require("scripts.Hero")
Skills = require("scripts.Skills")

Tower = require("scripts.Tower")
Projectile = require("scripts.Projectile")
WaveManager = require("scripts.WaveManager")
InputController = require("scripts.InputController")
UI = require("scripts.UI")

local gold_ = Config.INITIAL_GOLD
local lives_ = Config.INITIAL_LIVES
local nvg_ = nil
local gameState = {
    phase = "title",        -- "title" | "battle"
    isBattleFinished = false,
}

-- 领地离开提示
local territoryWarning_ = {
    active = false,
    timer = 0,           -- 显示倒计时
    DURATION = 2.5,      -- 提示持续秒数
}

local function AddBattleRewards(reward, kills)
    if reward and reward > 0 then
        gold_ = gold_ + reward
    end
    if kills and kills > 0 then
        Hero.state.killCount = Hero.state.killCount + kills
    end
end

local function ResetBattleObjects()
    Tower.list = {}
    Tower.selected = nil
    Projectile.list = {}
    Particle.list = {}
    Enemy = require("scripts.Enemy")
    Enemy.list = {}
    InputController.Reset()
end

local function EnterTitle()
    gameState.phase = "title"
    gameState.isBattleFinished = false
    gold_ = Config.INITIAL_GOLD
    lives_ = Config.INITIAL_LIVES
    ResetBattleObjects()
end

local function StartGame()
    gameState.phase = "battle"
    gameState.isBattleFinished = false

    gold_ = Config.INITIAL_GOLD
    lives_ = Config.INITIAL_LIVES

    ResetBattleObjects()
    Skills.Reset()
    Hero.Init({ x = Config.HERO_SPAWN.x, y = Config.HERO_SPAWN.y })
    Minimap.Init()

    -- 初始化相机
    local dpr = graphics:GetDPR()
    local screenW = graphics:GetWidth() / dpr
    local screenH = graphics:GetHeight() / dpr
    Camera.Init(Config.WORLD_WIDTH, Config.WORLD_HEIGHT, screenW, screenH)
    Camera.JumpTo(Config.HERO_SPAWN.x, Config.HERO_SPAWN.y)

    -- 禁用敌人波次（大地图模式暂不使用）
    WaveManager.Init(nil)
    WaveManager.allComplete = true
    WaveManager.waveActive = false

    print("[Game] Battle started (world map mode)")
end

function Start()
    nvg_ = nvgCreate(1)
    if not nvg_ then
        print("[ERROR] Failed to create NanoVG context")
        return
    end

    nvgCreateFont(nvg_, "sans", "Fonts/MiSans-Regular.ttf")

    UI.DetectPlatform()
    Map.Init(nvg_)

    Hero.LoadSprite(nvg_)
    Tower.LoadSprites(nvg_)
    Projectile.LoadSprites(nvg_)

    gold_ = Config.INITIAL_GOLD
    lives_ = Config.INITIAL_LIVES
    Skills.Reset()
    Hero.Init({ x = Config.HERO_SPAWN.x, y = Config.HERO_SPAWN.y })

    -- 初始化相机
    local dpr = graphics:GetDPR()
    local screenW = graphics:GetWidth() / dpr
    local screenH = graphics:GetHeight() / dpr
    Camera.Init(Config.WORLD_WIDTH, Config.WORLD_HEIGHT, screenW, screenH)
    Camera.JumpTo(Config.HERO_SPAWN.x, Config.HERO_SPAWN.y)
    Minimap.Init()

    WaveManager.Init(nil)
    WaveManager.allComplete = true
    WaveManager.waveActive = false

    EnterTitle()

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent(nvg_, "NanoVGRender", "HandleNanoVGRender")

    -- 触屏事件
    SubscribeToEvent("TouchBegin", "HandleTouchBegin")
    SubscribeToEvent("TouchMove", "HandleTouchMove")
    SubscribeToEvent("TouchEnd", "HandleTouchEnd")

    print("[Game] Started!")
end

function HandleTouchBegin(eventType, eventData)
    local dpr = graphics:GetDPR()
    local x = eventData["X"]:GetInt() / dpr
    local y = eventData["Y"]:GetInt() / dpr
    local touchID = eventData["TouchID"]:GetInt()
    local screenWidth = graphics:GetWidth() / dpr
    local screenHeight = graphics:GetHeight() / dpr

    if gameState.phase == "title" then
        -- 标题页：点击按钮区域开始游戏
        if UI.GetTitleButtonAt(x, y, screenWidth, screenHeight) == "start" then
            StartGame()
        end
        return
    end

    InputController.HandleTouchBegin(touchID, x, y, screenWidth, screenHeight, gameState.phase)
end

function HandleTouchMove(eventType, eventData)
    local dpr = graphics:GetDPR()
    local x = eventData["X"]:GetInt() / dpr
    local y = eventData["Y"]:GetInt() / dpr
    local touchID = eventData["TouchID"]:GetInt()
    InputController.HandleTouchMove(touchID, x, y)
end

function HandleTouchEnd(eventType, eventData)
    local touchID = eventData["TouchID"]:GetInt()
    InputController.HandleTouchEnd(touchID)
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    local actions = InputController.HandleInput(dt, gameState)

    if actions.startGame then
        StartGame()
        return
    end

    if actions.restartBattle then
        StartGame()
        return
    end

    if actions.returnToMenu then
        EnterTitle()
        return
    end

    if gameState.phase ~= "battle" then
        return
    end

    -- 更新视口尺寸（适配窗口变化）
    local dpr = graphics:GetDPR()
    local screenW = graphics:GetWidth() / dpr
    local screenH = graphics:GetHeight() / dpr
    Camera.SetViewSize(screenW, screenH)

    -- 放塔（世界坐标）
    if actions.placeTower then
        local newTower
        newTower, gold_ = Tower.Create(actions.placeTower, actions.placeX, actions.placeY, gold_)
        if newTower then
            print("[Tower] Placed " .. actions.placeTower .. " at " .. math.floor(actions.placeX) .. "," .. math.floor(actions.placeY))
        end
    end

    if actions.upgradeSelectedTower and Tower.selected then
        local upgraded
        upgraded, gold_ = Tower.Upgrade(Tower.selected, gold_)
        if upgraded then
            print("[Tower] Upgraded selected tower to Lv" .. Tower.selected.level)
        end
    end

    if actions.upgradeSkill then
        local upgraded
        upgraded, gold_ = Skills.Upgrade(actions.upgradeSkill, gold_)
        if upgraded then
            print("[Skill] Upgraded slot " .. actions.upgradeSkill)
        end
    end

    -- 英雄移动与攻击
    Hero.state.vx = InputController.state.moveX
    Hero.state.vy = InputController.state.moveY
    Hero.Update(dt)

    -- 领地边界检测
    local wasInTerritory = Map.IsInTerritory(Hero.state.x - Hero.state.vx * dt * 200, Hero.state.y - Hero.state.vy * dt * 200)
    local isInTerritory = Map.IsInTerritory(Hero.state.x, Hero.state.y)
    if wasInTerritory and not isInTerritory then
        territoryWarning_.active = true
        territoryWarning_.timer = territoryWarning_.DURATION
    end
    if territoryWarning_.timer > 0 then
        territoryWarning_.timer = territoryWarning_.timer - dt
        if territoryWarning_.timer <= 0 then
            territoryWarning_.active = false
            territoryWarning_.timer = 0
        end
    end

    if InputController.state.attacking then
        -- 暂无敌人，但攻击动画仍可播放
        local reward, kills = Hero.Attack(Enemy and Enemy.list or {})
        AddBattleRewards(reward, kills)
    end

    if actions.castSkill then
        local casted, reward, kills = Skills.Cast(
            actions.castSkill, actions.castX, actions.castY,
            Enemy and Enemy.list or {}, Tower.list)
        if casted then
            AddBattleRewards(reward, kills)
        end
    end

    Skills.Update(dt)

    -- 敌人更新（暂无敌人，保留接口）
    if Enemy and Enemy.list then
        for i = #Enemy.list, 1, -1 do
            local enemy = Enemy.list[i]
            if not enemy.alive then
                table.remove(Enemy.list, i)
            end
        end
    end

    local towerReward, towerKills = Tower.UpdateAll(dt)
    AddBattleRewards(towerReward, towerKills)

    local projectileReward, projectileKills = Projectile.UpdateAll(dt)
    AddBattleRewards(projectileReward, projectileKills)

    Particle.UpdateAll(dt)

    -- 更新地图动画
    Map.Update(dt)

    -- 相机跟随英雄
    Camera.Follow(Hero.state.x, Hero.state.y, dt)
end

function HandleNanoVGRender(eventType, eventData)
    if not nvg_ then return end

    local dpr = graphics:GetDPR()
    local screenWidth = graphics:GetWidth() / dpr
    local screenHeight = graphics:GetHeight() / dpr

    nvgBeginFrame(nvg_, screenWidth, screenHeight, dpr)
    nvgFontFace(nvg_, "sans")

    if gameState.phase == "battle" then
        local camOX, camOY = Camera.GetOffset()

        -- ======== 世界层（相机变换） ========
        nvgSave(nvg_)
        nvgTranslate(nvg_, -camOX, -camOY)

        -- 地图背景层（草地、群落色调、地标、边界）
        Map.DrawBackground(nvg_, screenWidth, screenHeight)

        -- 收集所有可绘制物体（装饰物 + 营地 + 角色 + 塔），按 Y 排序
        local drawables = {}

        -- 装饰物（树木、岩石等）
        local decos = Map.GetDecorations()
        for i, deco in ipairs(decos) do
            if Camera.IsVisible(deco.x, deco.y, 150) then
                table.insert(drawables, { y = deco.y, kind = "deco", obj = deco, index = i })
            end
        end

        -- 营地建筑
        local campPos = Map.GetCampPos()
        if Camera.IsVisible(campPos.x, campPos.y, 200) then
            table.insert(drawables, { y = campPos.y, kind = "camp" })
        end

        -- 仓库建筑
        local whPos = Map.GetWarehousePos()
        if Camera.IsVisible(whPos.x, whPos.y, 200) then
            table.insert(drawables, { y = whPos.y, kind = "warehouse" })
        end

        for _, tower in ipairs(Tower.list) do
            table.insert(drawables, { y = tower.y, kind = "tower", obj = tower })
        end
        if Enemy and Enemy.list then
            for _, enemy in ipairs(Enemy.list) do
                if enemy.alive then
                    table.insert(drawables, { y = enemy.y, kind = "enemy", obj = enemy })
                end
            end
        end
        if Hero.state.alive or Hero.state.animState == "die" then
            table.insert(drawables, { y = Hero.state.y, kind = "hero" })
        end

        table.sort(drawables, function(a, b) return a.y < b.y end)

        for _, d in ipairs(drawables) do
            if d.kind == "deco" then
                Map.DrawDecoration(nvg_, d.obj, d.index)
            elseif d.kind == "camp" then
                Map.DrawCampSprite(nvg_)
            elseif d.kind == "warehouse" then
                Map.DrawWarehouseSprite(nvg_)
            elseif d.kind == "hero" then
                Hero.Draw(nvg_)
            elseif d.kind == "enemy" then
                Enemy.Draw(nvg_, d.obj)
            elseif d.kind == "tower" then
                Tower.Draw(nvg_, d.obj)
            end
        end

        Projectile.DrawAll(nvg_)
        Particle.DrawAll(nvg_)

        nvgRestore(nvg_)
        -- ======== 世界层结束 ========

        -- ======== UI 层（屏幕空间） ========
        UI.Render(nvg_, {
            phase = gameState.phase,
            gold = gold_,
            lives = lives_,
            heroState = Hero.state,
            screenWidth = screenWidth,
            screenHeight = screenHeight,
        })

        -- 领地离开警告
        if territoryWarning_.active and territoryWarning_.timer > 0 then
            local alpha = math.min(1.0, territoryWarning_.timer / 0.5) * 255
            -- 背景条
            nvgBeginPath(nvg_)
            nvgRoundedRect(nvg_, screenWidth / 2 - 180, 80, 360, 44, 8)
            nvgFillColor(nvg_, nvgRGBA(180, 50, 30, math.floor(alpha * 0.7)))
            nvgFill(nvg_)
            -- 文字
            nvgFontSize(nvg_, 20)
            nvgTextAlign(nvg_, 1) -- NVG_ALIGN_CENTER
            nvgFillColor(nvg_, nvgRGBA(255, 255, 200, math.floor(alpha)))
            nvgText(nvg_, screenWidth / 2, 107, "你已离开领地范围，注意安全！")
        end

        -- 移动端虚拟控件
        UI.DrawTouchControls(nvg_, screenWidth, screenHeight)

        -- 小地图（屏幕空间）
        Minimap.Draw(nvg_, screenWidth, screenHeight, Hero.state)
        -- ======== UI 层结束 ========
    else
        -- 标题画面（纯屏幕空间）
        nvgBeginPath(nvg_)
        nvgRect(nvg_, 0, 0, screenWidth, screenHeight)
        nvgFillColor(nvg_, nvgRGBA(30, 40, 30, 255))
        nvgFill(nvg_)

        UI.Render(nvg_, {
            phase = gameState.phase,
            gold = gold_,
            lives = lives_,
            heroState = Hero.state,
            screenWidth = screenWidth,
            screenHeight = screenHeight,
        })
    end

    nvgEndFrame(nvg_)
end

function Stop()
    Projectile.CleanupSprites(nvg_)
    Tower.CleanupSprites(nvg_)
    Hero.CleanupSprite(nvg_)
    Map.Cleanup()
    if nvg_ then
        nvgDelete(nvg_)
        nvg_ = nil
    end
    print("[Game] Stopped!")
end
