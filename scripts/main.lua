
Config = require("scripts.Config")
Utils = require("scripts.Utils")
Path = require("scripts.Path")
Particle = require("scripts.Particle")
Hero = require("scripts.Hero")
Skills = require("scripts.Skills")
Equipment = require("scripts.Equipment")
Enemy = require("scripts.Enemy")
Tower = require("scripts.Tower")
Projectile = require("scripts.Projectile")
WaveManager = require("scripts.WaveManager")
InputController = require("scripts.InputController")
UI = require("scripts.UI")

local gold_ = Config.INITIAL_GOLD
local lives_ = Config.INITIAL_LIVES
local nvg_ = nil

function Start()
    nvg_ = nvgCreate(1)
    if not nvg_ then
        print("[ERROR] Failed to create NanoVG context")
        return
    end

    Hero.Init()
    WaveManager.Init()

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent(nvg_, "NanoVGRender", "HandleNanoVGRender")
    print("[Game] Started!")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    local screenWidth = graphics.width
    local screenHeight = graphics.height

    local placeTower, placeX, placeY = InputController.HandleKeyboard(dt)
    if placeTower then
        local newTower
        newTower, gold_ = Tower.Create(placeTower, placeX, placeY, gold_)
        if newTower then
            print("[Tower] Placed " .. placeTower .. " at " .. placeX .. "," .. placeY)
        end
    end

    Hero.state.vx = InputController.state.moveX
    Hero.state.vy = InputController.state.moveY
    Hero.Update(dt)

    if InputController.state.attacking then
        Hero.Attack(Enemy.list)
    end

    Skills.Update(dt)

    for i = #Enemy.list, 1, -1 do
        local enemy = Enemy.list[i]
        if enemy.alive then
            local result = Enemy.Update(enemy, dt, Hero.state)
            if result then
                if result == -1 then
                    lives_ = lives_ - 1
                    print("[Enemy] Reached end! Lives: " .. lives_)
                    enemy.alive = false
                else
                    gold_ = gold_ + result
                    Hero.state.killCount = Hero.state.killCount + 1
                end
            end
        end
        if not enemy.alive then
            table.remove(Enemy.list, i)
        end
    end

    Tower.UpdateAll(dt)
    Projectile.UpdateAll(dt)
    gold_ = WaveManager.Update(dt, gold_)
    Particle.UpdateAll(dt)

    if lives_ <= 0 then
        lives_ = 0
    end

end

function HandleNanoVGRender(eventType, eventData)
    if not nvg_ then return end

    local dpr = graphics:GetDPR()
    local screenWidth = graphics:GetWidth() / dpr
    local screenHeight = graphics:GetHeight() / dpr

    nvgBeginFrame(nvg_, screenWidth, screenHeight, dpr)

    nvgBeginPath(nvg_)
    nvgRect(nvg_, 0, 0, screenWidth, screenHeight)
    nvgFillColor(nvg_, nvgRGBA(30, 40, 30, 255))
    nvgFill(nvg_)

    Path.Draw(nvg_)
    Tower.DrawAll(nvg_)
    Enemy.DrawAll(nvg_)
    Hero.Draw(nvg_)
    Projectile.DrawAll(nvg_)
    Particle.DrawAll(nvg_)
    UI.Render(nvg_, "battle", gold_, lives_,
              WaveManager.currentWave, Hero.state, screenWidth, screenHeight)

    nvgEndFrame(nvg_)
end

function Stop()
    if nvg_ then
        nvgDelete(nvg_)
        nvg_ = nil
    end
    print("[Game] Stopped!")
end
