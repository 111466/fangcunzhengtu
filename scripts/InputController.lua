
local InputController = {}

InputController.state = {
    moveX = 0, moveY = 0,
    attacking = false,
    placingTower = nil,
}

function InputController.HandleInput(dt)
    local s = InputController.state
    local actions = {
        placeTower = nil,
        placeX = nil,
        placeY = nil,
        castSkill = nil,
        castX = nil,
        castY = nil,
        upgradeSkill = nil,
        buyEquipmentSlot = nil,
        upgradeSelectedTower = false,
    }
    s.moveX = 0
    s.moveY = 0
    s.attacking = false

    if input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT) then
        s.moveX = s.moveX - 1
    end
    if input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT) then
        s.moveX = s.moveX + 1
    end
    if input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP) then
        s.moveY = s.moveY - 1
    end
    if input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) then
        s.moveY = s.moveY + 1
    end

    if s.moveX ~= 0 and s.moveY ~= 0 then
        local len = math.sqrt(s.moveX*s.moveX + s.moveY*s.moveY)
        s.moveX = s.moveX / len
        s.moveY = s.moveY / len
    end

    if input:GetKeyPress(KEY_5) then s.placingTower = "archer_tower" end
    if input:GetKeyPress(KEY_6) then s.placingTower = "cannon_tower" end
    if input:GetKeyPress(KEY_7) then s.placingTower = "frost_tower" end
    if input:GetKeyPress(KEY_8) then s.placingTower = "lightning_tower" end

    if input:GetKeyPress(KEY_1) then
        actions.castSkill = 1
        actions.castX = Hero.state.x
        actions.castY = Hero.state.y
    end
    if input:GetKeyPress(KEY_2) then
        actions.castSkill = 2
        actions.castX = Hero.state.x
        actions.castY = Hero.state.y
    end
    if input:GetKeyPress(KEY_3) then
        actions.castSkill = 3
        actions.castX = Hero.state.x
        actions.castY = Hero.state.y
    end
    if input:GetKeyPress(KEY_4) then
        local pos = input:GetMousePosition()
        local dpr = graphics:GetDPR()
        actions.castSkill = 4
        actions.castX = pos.x / dpr
        actions.castY = pos.y / dpr
    end

    if input:GetKeyPress(KEY_F1) then actions.upgradeSkill = 1 end
    if input:GetKeyPress(KEY_F2) then actions.upgradeSkill = 2 end
    if input:GetKeyPress(KEY_F3) then actions.upgradeSkill = 3 end
    if input:GetKeyPress(KEY_F4) then actions.upgradeSkill = 4 end

    if input:GetKeyPress(KEY_Z) then actions.buyEquipmentSlot = "weapon" end
    if input:GetKeyPress(KEY_X) then actions.buyEquipmentSlot = "armor" end
    if input:GetKeyPress(KEY_C) then actions.buyEquipmentSlot = "accessory" end
    if input:GetKeyPress(KEY_U) then actions.upgradeSelectedTower = true end

    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        local pos = input:GetMousePosition()
        local dpr = graphics:GetDPR()
        local mx = pos.x / dpr
        local my = pos.y / dpr
        local screenWidth = graphics:GetWidth() / dpr
        local screenHeight = graphics:GetHeight() / dpr

        local towerType = UI.GetTowerCardAt(mx, my, screenWidth, screenHeight)
        if towerType then
            s.placingTower = towerType
        else
            local equipSlot = UI.GetEquipmentCardAt(mx, my, screenWidth, screenHeight)
            if equipSlot then
                actions.buyEquipmentSlot = equipSlot
            else
                local selectedTower = Tower.SelectAt(mx, my)
                if not selectedTower then
                    s.attacking = true
                end
            end
        end
    end

    if input:GetKeyDown(KEY_SPACE) then
        s.attacking = true
    end

    if input:GetMouseButtonDown(MOUSEB_RIGHT) then
        local pos = input:GetMousePosition()
        local dpr = graphics:GetDPR()
        local mx = pos.x / dpr
        local my = pos.y / dpr
        if s.placingTower then
            actions.placeTower = s.placingTower
            actions.placeX = mx
            actions.placeY = my
        end
    end

    return actions
end

return InputController
