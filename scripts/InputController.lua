
local InputController = {}

InputController.state = {
    moveX = 0, moveY = 0,
    attacking = false,
    placingTower = nil,
    skillTarget = nil,
}

function InputController.HandleKeyboard(dt)
    local s = InputController.state
    s.moveX = 0
    s.moveY = 0

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

    s.attacking = input:GetKeyDown(KEY_SPACE) or input:GetMouseButtonDown(MOUSEB_LEFT)

    if input:GetKeyPress(KEY_1) then
        Skills.Cast(1, Hero.state.x, Hero.state.y, Enemy.list, Tower.list)
    end
    if input:GetKeyPress(KEY_2) then
        Skills.Cast(2, Hero.state.x, Hero.state.y, Enemy.list, Tower.list)
    end
    if input:GetKeyPress(KEY_3) then
        Skills.Cast(3, Hero.state.x, Hero.state.y, Enemy.list, Tower.list)
    end
    if input:GetKeyPress(KEY_4) then
        local mx, my = input:GetMousePosition()
        Skills.Cast(4, mx, my, Enemy.list, Tower.list)
    end

    if input:GetMouseButtonDown(MOUSEB_RIGHT) then
        local mx, my = input:GetMousePosition()
        if InputController.state.placingTower then
            return InputController.state.placingTower, mx, my
        end
    end
    return nil, nil, nil
end

return InputController
