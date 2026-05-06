local Camera = require("scripts.Camera")
local Minimap = require("scripts.Minimap")

local InputController = {}

InputController.state = {
    moveX = 0, moveY = 0,
    attacking = false,
    placingTower = nil,
}

-- 触屏虚拟摇杆状态
InputController.touch = {
    -- 摇杆
    joystickTouchID = -1,   -- 追踪触摸ID
    joystickCenterX = 0,    -- 摇杆中心 (触摸起始点)
    joystickCenterY = 0,
    joystickDirX = 0,       -- 摇杆方向 (-1~1)
    joystickDirY = 0,
    joystickActive = false,
    -- 攻击按钮
    attackTouchID = -1,
    attackActive = false,
    -- 配置
    JOYSTICK_RADIUS = 60,       -- 摇杆圆盘半径
    JOYSTICK_DEAD_ZONE = 8,     -- 死区
    JOYSTICK_MAX = 50,          -- 最大拖拽距离
    ATTACK_BTN_RADIUS = 38,     -- 攻击按钮半径
}

function InputController.Reset()
    InputController.state.moveX = 0
    InputController.state.moveY = 0
    InputController.state.attacking = false
    InputController.state.placingTower = nil
    InputController.touch.joystickTouchID = -1
    InputController.touch.joystickActive = false
    InputController.touch.joystickDirX = 0
    InputController.touch.joystickDirY = 0
    InputController.touch.attackTouchID = -1
    InputController.touch.attackActive = false
end

-- 获取攻击按钮在屏幕上的位置（右下角）
function InputController.GetAttackButtonPos(screenWidth, screenHeight)
    return screenWidth - 90, screenHeight - 110
end

-- 获取摇杆基础位置（左下角）
function InputController.GetJoystickBasePos(screenWidth, screenHeight)
    return 110, screenHeight - 110
end

-- 处理触摸开始
function InputController.HandleTouchBegin(touchID, x, y, screenWidth, screenHeight, phase)
    local t = InputController.touch
    if phase ~= "battle" then return end

    -- 检查是否触到攻击按钮区域（右侧屏幕）
    local atkX, atkY = InputController.GetAttackButtonPos(screenWidth, screenHeight)
    local dx = x - atkX
    local dy = y - atkY
    if dx * dx + dy * dy <= (t.ATTACK_BTN_RADIUS + 15) * (t.ATTACK_BTN_RADIUS + 15) then
        t.attackTouchID = touchID
        t.attackActive = true
        return
    end

    -- 左半屏启动摇杆
    if x < screenWidth * 0.5 and t.joystickTouchID == -1 then
        t.joystickTouchID = touchID
        t.joystickCenterX = x
        t.joystickCenterY = y
        t.joystickActive = true
        t.joystickDirX = 0
        t.joystickDirY = 0
    end
end

-- 处理触摸移动
function InputController.HandleTouchMove(touchID, x, y)
    local t = InputController.touch
    if touchID == t.joystickTouchID and t.joystickActive then
        local dx = x - t.joystickCenterX
        local dy = y - t.joystickCenterY
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < t.JOYSTICK_DEAD_ZONE then
            t.joystickDirX = 0
            t.joystickDirY = 0
        else
            -- 限制最大距离
            if dist > t.JOYSTICK_MAX then
                dx = dx / dist * t.JOYSTICK_MAX
                dy = dy / dist * t.JOYSTICK_MAX
            end
            t.joystickDirX = dx / t.JOYSTICK_MAX
            t.joystickDirY = dy / t.JOYSTICK_MAX
        end
    end
end

-- 处理触摸结束
function InputController.HandleTouchEnd(touchID)
    local t = InputController.touch
    if touchID == t.joystickTouchID then
        t.joystickTouchID = -1
        t.joystickActive = false
        t.joystickDirX = 0
        t.joystickDirY = 0
    end
    if touchID == t.attackTouchID then
        t.attackTouchID = -1
        t.attackActive = false
    end
end

function InputController.HandleInput(dt, gameState)
    local s = InputController.state
    local actions = {
        placeTower = nil,
        placeX = nil,
        placeY = nil,
        castSkill = nil,
        castX = nil,
        castY = nil,
        upgradeSkill = nil,
        upgradeSelectedTower = false,
        returnToMenu = false,
        restartBattle = false,
        startGame = false,
    }
    local phase = gameState and gameState.phase or "battle"
    s.moveX = 0
    s.moveY = 0
    s.attacking = false

    local isMobile = UI.isMobile

    -- 标题画面
    if phase == "title" then
        if input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_SPACE) then
            actions.startGame = true
        end
        if input:GetMouseButtonPress(MOUSEB_LEFT) then
            local pos = input:GetMousePosition()
            local dpr = graphics:GetDPR()
            local mx = pos.x / dpr
            local my = pos.y / dpr
            local screenWidth = graphics:GetWidth() / dpr
            local screenHeight = graphics:GetHeight() / dpr
            if UI.GetTitleButtonAt(mx, my, screenWidth, screenHeight) == "start" then
                actions.startGame = true
            end
        end
        -- 触屏：点击任意位置也可开始（由 TouchBegin 事件处理标题页点击）
        return actions
    end

    -- ESC 返回标题
    if input:GetKeyPress(KEY_ESCAPE) then
        actions.returnToMenu = true
        return actions
    end

    -- 战斗结束状态
    if gameState and gameState.isBattleFinished then
        if input:GetKeyPress(KEY_R) then
            actions.restartBattle = true
        end
        if input:GetMouseButtonPress(MOUSEB_LEFT) then
            local pos = input:GetMousePosition()
            local dpr = graphics:GetDPR()
            local mx = pos.x / dpr
            local my = pos.y / dpr
            local screenWidth = graphics:GetWidth() / dpr
            local screenHeight = graphics:GetHeight() / dpr
            local button = UI.GetBattleEndButtonAt(mx, my, screenWidth, screenHeight)
            if button == "restart" then
                actions.restartBattle = true
            elseif button == "menu" then
                actions.returnToMenu = true
            end
        end
        return actions
    end

    -- ==== 战斗中 ====

    -- 移动（WASD / 方向键）
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

    -- 合并触屏虚拟摇杆输入
    local t = InputController.touch
    if t.joystickActive then
        s.moveX = s.moveX + t.joystickDirX
        s.moveY = s.moveY + t.joystickDirY
    end

    if s.moveX ~= 0 and s.moveY ~= 0 then
        local len = math.sqrt(s.moveX * s.moveX + s.moveY * s.moveY)
        s.moveX = s.moveX / len
        s.moveY = s.moveY / len
    end

    -- 建塔快捷键
    if input:GetKeyPress(KEY_5) then s.placingTower = "archer_tower" end
    if input:GetKeyPress(KEY_6) then s.placingTower = "cannon_tower" end
    if input:GetKeyPress(KEY_7) then s.placingTower = "frost_tower" end
    if input:GetKeyPress(KEY_8) then s.placingTower = "lightning_tower" end

    -- 技能快捷键
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
        -- 陨石技能：使用鼠标世界坐标
        local pos = input:GetMousePosition()
        local dpr = graphics:GetDPR()
        local sx, sy = pos.x / dpr, pos.y / dpr
        local wx, wy = Camera.ScreenToWorld(sx, sy)
        actions.castSkill = 4
        actions.castX = wx
        actions.castY = wy
    end

    -- 升级快捷键
    if input:GetKeyPress(KEY_F1) then actions.upgradeSkill = 1 end
    if input:GetKeyPress(KEY_F2) then actions.upgradeSkill = 2 end
    if input:GetKeyPress(KEY_F3) then actions.upgradeSkill = 3 end
    if input:GetKeyPress(KEY_F4) then actions.upgradeSkill = 4 end
    if input:GetKeyPress(KEY_U) then actions.upgradeSelectedTower = true end

    -- 小地图 M 键切换
    if input:GetKeyPress(KEY_M) then
        Minimap.Toggle()
    end

    -- 鼠标左键
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        local pos = input:GetMousePosition()
        local dpr = graphics:GetDPR()
        local mx = pos.x / dpr
        local my = pos.y / dpr
        local screenWidth = graphics:GetWidth() / dpr
        local screenHeight = graphics:GetHeight() / dpr

        -- 先检查小地图是否消费此事件
        if Minimap.HandleClick(mx, my, screenWidth, screenHeight) then
            -- 小地图消费了，不做其他处理
        else
            -- 检查 UI 防御塔栏
            local towerType = UI.GetTowerCardAt(mx, my, screenWidth, screenHeight)
            if towerType then
                s.placingTower = towerType
            else
                -- 屏幕坐标 → 世界坐标 后检查塔选中
                local wx, wy = Camera.ScreenToWorld(mx, my)
                local selectedTower = Tower.SelectAt(wx, wy)
                if not selectedTower then
                    s.attacking = true
                end
            end
        end
    end

    if input:GetKeyDown(KEY_SPACE) then
        s.attacking = true
    end

    -- 触屏攻击按钮
    if t.attackActive then
        s.attacking = true
    end

    -- 鼠标右键放塔（使用世界坐标）
    if input:GetMouseButtonDown(MOUSEB_RIGHT) then
        local pos = input:GetMousePosition()
        local dpr = graphics:GetDPR()
        local sx, sy = pos.x / dpr, pos.y / dpr
        if s.placingTower then
            local wx, wy = Camera.ScreenToWorld(sx, sy)
            actions.placeTower = s.placingTower
            actions.placeX = wx
            actions.placeY = wy
        end
    end

    return actions
end

return InputController
