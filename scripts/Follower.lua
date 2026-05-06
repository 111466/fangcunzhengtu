local Config = require("scripts.Config")
local Camera = require("scripts.Camera")

local Follower = {}

----------------------------------------------------------------------
-- 精灵图配置
----------------------------------------------------------------------
local FRAME_SIZE = 192   -- 每帧 192x192
local DRAW_SIZE  = 80    -- 屏幕显示尺寸
local ANIM_FPS   = 8     -- 动画帧率

-- 精灵表定义: { file, frameCount }
local spriteSheets_ = {
    walk_right  = { file = "image/follower_walk_right.png",  frames = 8 },
    walk_left   = { file = "image/follower_walk_left.png",   frames = 8 },
    sword_right = { file = "image/follower_sword_right.png", frames = 6 },
    sword_left  = { file = "image/follower_sword_left.png",  frames = 6 },
    axe_right   = { file = "image/follower_axe_right.png",   frames = 6 },
    axe_left    = { file = "image/follower_axe_left.png",    frames = 6 },
    skill_right = { file = "image/follower_skill_right.png", frames = 4 },
    skill_left  = { file = "image/follower_skill_left.png",  frames = 4 },
}

-- nvg 图片句柄
local images_ = {}

----------------------------------------------------------------------
-- 实例管理
----------------------------------------------------------------------
Follower.list = {}    -- 所有随从
Follower.woodCount = 0   -- 全局木头计数

-- 木头飞行动画列表
Follower.woodAnims = {}

----------------------------------------------------------------------
-- 加载/清理资源
----------------------------------------------------------------------

---@param nvg NVGContextWrapper
function Follower.LoadSprites(nvg)
    for name, info in pairs(spriteSheets_) do
        images_[name] = nvgCreateImage(nvg, info.file, 0)
        if images_[name] and images_[name] > 0 then
            print("[Follower] Loaded sprite: " .. name)
        else
            print("[Follower] WARNING: Failed to load: " .. name)
        end
    end
    -- 加载木头图标
    images_.wood_icon = nvgCreateImage(nvg, "image/wood_icon.png", 0)
    -- 加载树桩（4种，对应不同树木类型）
    images_.tree_stump1 = nvgCreateImage(nvg, "image/tree_stump1.png", 0)
    images_.tree_stump2 = nvgCreateImage(nvg, "image/tree_stump2.png", 0)
    images_.tower_sprite1 = nvgCreateImage(nvg, "image/tower_sprite1.png", 0)
    images_.tower_sprite2 = nvgCreateImage(nvg, "image/tower_sprite2.png", 0)
end

---@param nvg NVGContextWrapper
function Follower.CleanupSprites(nvg)
    if nvg then
        for name, handle in pairs(images_) do
            if handle and handle > 0 then
                nvgDeleteImage(nvg, handle)
            end
        end
    end
    images_ = {}
end

----------------------------------------------------------------------
-- 随从创建
----------------------------------------------------------------------

--- 创建一个随从
---@param x number 初始世界坐标 X
---@param y number 初始世界坐标 Y
---@return table follower
function Follower.Create(x, y)
    local f = {
        x = x,
        y = y,
        alive = true,
        facing = 1,             -- 1=right, -1=left

        -- AI 状态
        aiState = "idle",       -- "idle" | "follow" | "attack" | "chop" | "walk_to_tree"
        targetEnemy = nil,
        targetTree = nil,       -- 砍树目标 (装饰物引用)
        targetTreeX = 0,
        targetTreeY = 0,

        -- 动画
        animKey = "walk_right", -- 当前精灵表 key
        animFrame = 0,
        animTimer = 0,
        animPlaying = false,    -- 攻击/砍树动画播放标记

        -- 攻击
        attackCooldown = 0,
        attackDamage = 25,
        attackRange = 55,
        attackSpeed = 1.2,      -- 每秒攻击次数

        -- 移动
        moveSpeed = 170,
        followDist = 60,        -- 跟随距离
        followMaxDist = 300,    -- 超出此距离会快速追赶

        -- 砍树
        chopDamage = 20,
        chopCooldown = 0,
        chopSpeed = 0.8,        -- 每秒砍击次数
    }
    table.insert(Follower.list, f)
    print("[Follower] Created at (" .. math.floor(x) .. ", " .. math.floor(y) .. ")")
    return f
end

----------------------------------------------------------------------
-- 辅助
----------------------------------------------------------------------

local function Dist(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function UpdateFacing(f, tx, ty)
    if tx > f.x + 2 then
        f.facing = 1
    elseif tx < f.x - 2 then
        f.facing = -1
    end
end

local function GetAnimKey(action, facing)
    local dir = facing >= 0 and "right" or "left"
    return action .. "_" .. dir
end

-- 树木类型 → 树桩精灵映射 + 每种树桩的 Y 偏移微调
local stumpMap_ = {
    tree_leaf       = { img = "tower_sprite1",  offsetY = 10 },  -- 阔叶树（矮树）
    tree_autumn     = { img = "tower_sprite2",  offsetY = 10 },  -- 秋叶树（矮树）
    tree_pine_dark  = { img = "tree_stump2",    offsetY = 6 },   -- 深松树（高树）
    tree_pine_green = { img = "tree_stump1",    offsetY = 6 },   -- 绿松树（高树）
}

-- 树木的帧高度（用于计算根部位置偏移）
local treeFrameH_ = {
    tree_leaf       = 192,
    tree_autumn     = 192,
    tree_pine_dark  = 256,
    tree_pine_green = 256,
}

--- 计算树根部的 Y 偏移（从树中心到根部偏上一点）
--- 树绘制以 (x, y) 为中心, drawH = baseW * (frameH/frameW) * scale
--- 树根在 y + drawH/2 附近，砍树位置在根部偏上
local function GetTreeRootOffsetY(treeType, scale)
    local frameH = treeFrameH_[treeType] or 192
    local frameW = 192
    local baseW = 100
    local drawH = baseW * (frameH / frameW) * (scale or 1.0)
    return drawH / 2
end

local function MoveToward(f, tx, ty, speed, dt)
    local dx = tx - f.x
    local dy = ty - f.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 2 then return true end

    local step = speed * dt
    if step >= dist then
        f.x = tx
        f.y = ty
        return true
    end

    f.x = f.x + (dx / dist) * step
    f.y = f.y + (dy / dist) * step
    return false
end

----------------------------------------------------------------------
-- AI 更新
----------------------------------------------------------------------

local function FindNearestEnemy(f, enemies)
    if not enemies then return nil end
    local closest = nil
    local closestDist = 200   -- 索敌范围
    for _, e in ipairs(enemies) do
        if e.alive then
            local d = Dist(f.x, f.y, e.x, e.y)
            if d < closestDist then
                closestDist = d
                closest = e
            end
        end
    end
    return closest
end

function Follower.Update(dt, heroState, enemies)
    for _, f in ipairs(Follower.list) do
        if f.alive then
            Follower._UpdateOne(f, dt, heroState, enemies)
        end
    end

    -- 更新木头飞行动画
    for i = #Follower.woodAnims, 1, -1 do
        local a = Follower.woodAnims[i]
        a.timer = a.timer + dt
        local t = a.timer / a.duration
        if t >= 1 then
            Follower.woodCount = Follower.woodCount + a.amount
            table.remove(Follower.woodAnims, i)
        else
            -- 抛物线插值
            a.curX = a.startX + (a.endX - a.startX) * t
            a.curY = a.startY + (a.endY - a.startY) * t - math.sin(t * math.pi) * 60
            a.curAlpha = 255
        end
    end
end

function Follower._UpdateOne(f, dt, heroState, enemies)
    -- 减少冷却
    if f.attackCooldown > 0 then f.attackCooldown = f.attackCooldown - dt end
    if f.chopCooldown > 0 then f.chopCooldown = f.chopCooldown - dt end

    -- 更新动画帧
    f.animTimer = f.animTimer + dt
    if f.animTimer >= 1.0 / ANIM_FPS then
        f.animTimer = f.animTimer - 1.0 / ANIM_FPS
        local sheet = spriteSheets_[f.animKey]
        if sheet then
            f.animFrame = f.animFrame + 1
            if f.animFrame >= sheet.frames then
                f.animFrame = 0
                if f.animPlaying then
                    f.animPlaying = false  -- 一轮攻击/砍树动画播完
                end
            end
        end
    end

    -- 边界限制
    f.x = math.max(20, math.min(f.x, Config.WORLD_WIDTH - 20))
    f.y = math.max(20, math.min(f.y, Config.WORLD_HEIGHT - 20))

    ----------------------------------------------------------------
    -- AI 状态机
    ----------------------------------------------------------------

    -- 如果正在砍树，优先砍树
    if f.aiState == "walk_to_tree" then
        local tree = f.targetTree
        if not tree or tree.chopped then
            f.aiState = "follow"
            f.targetTree = nil
            return
        end
        UpdateFacing(f, f.targetTreeX, f.targetTreeY)
        f.animKey = GetAnimKey("walk", f.facing)
        local arrived = MoveToward(f, f.targetTreeX, f.targetTreeY, f.moveSpeed, dt)
        if arrived or Dist(f.x, f.y, f.targetTreeX, f.targetTreeY) < 10 then
            f.aiState = "chop"
        end
        return
    end

    if f.aiState == "chop" then
        local tree = f.targetTree
        if not tree or tree.chopped then
            f.aiState = "follow"
            f.targetTree = nil
            return
        end
        UpdateFacing(f, f.targetTreeX, f.targetTreeY)
        f.animKey = GetAnimKey("axe", f.facing)
        if f.chopCooldown <= 0 then
            f.chopCooldown = 1.0 / f.chopSpeed
            f.animFrame = 0
            f.animPlaying = true
            -- 扣血
            tree.hp = (tree.hp or 100) - f.chopDamage
            if tree.hp <= 0 then
                tree.chopped = true
                -- 生成木头飞行动画（世界坐标 → 之后在渲染时转为屏幕坐标）
                Follower._SpawnWoodAnim(f.targetTreeX, f.targetTreeY)
                f.aiState = "follow"
                f.targetTree = nil
                print("[Follower] Tree chopped! Wood collected.")
            end
        end
        return
    end

    -- 检测敌人（优先于跟随）
    local enemy = FindNearestEnemy(f, enemies)
    if enemy then
        local eDist = Dist(f.x, f.y, enemy.x, enemy.y)
        if eDist <= f.attackRange then
            -- 攻击
            f.aiState = "attack"
            UpdateFacing(f, enemy.x, enemy.y)
            f.animKey = GetAnimKey("sword", f.facing)
            if f.attackCooldown <= 0 then
                f.attackCooldown = 1.0 / f.attackSpeed
                f.animFrame = 0
                f.animPlaying = true
                -- 造成伤害
                if enemy.alive then
                    enemy.hp = enemy.hp - f.attackDamage
                    if enemy.hp <= 0 then
                        enemy.alive = false
                    end
                end
            end
            return
        else
            -- 走向敌人
            f.aiState = "attack"
            UpdateFacing(f, enemy.x, enemy.y)
            f.animKey = GetAnimKey("walk", f.facing)
            MoveToward(f, enemy.x, enemy.y, f.moveSpeed * 1.1, dt)
            return
        end
    end

    -- 跟随英雄
    if not heroState or not heroState.alive then
        f.aiState = "idle"
        f.animKey = GetAnimKey("walk", f.facing)
        return
    end

    local distToHero = Dist(f.x, f.y, heroState.x, heroState.y)
    if distToHero > f.followDist then
        f.aiState = "follow"
        UpdateFacing(f, heroState.x, heroState.y)
        f.animKey = GetAnimKey("walk", f.facing)
        -- 超出最大跟随距离时瞬移（防止掉队太远）
        if distToHero > f.followMaxDist then
            local dx = heroState.x - f.x
            local dy = heroState.y - f.y
            local d = math.sqrt(dx * dx + dy * dy)
            f.x = heroState.x - (dx / d) * f.followMaxDist * 0.5
            f.y = heroState.y - (dy / d) * f.followMaxDist * 0.5
        end
        -- 跟随时偏移到英雄身后
        local followX = heroState.x - heroState.facing * 40
        local followY = heroState.y + 20
        local speed = f.moveSpeed
        if distToHero > 150 then speed = f.moveSpeed * 1.5 end
        MoveToward(f, followX, followY, speed, dt)
    else
        f.aiState = "idle"
        -- 待机时用 walk 第一帧
        f.animKey = GetAnimKey("walk", f.facing)
        f.animFrame = 0
    end
end

----------------------------------------------------------------------
-- 分配砍树任务
----------------------------------------------------------------------

--- 分配随从去砍一棵树
---@param tree table 装饰物引用 (from Map.GetDecorations)
---@return boolean 是否成功分配
function Follower.AssignChopTree(tree)
    if not tree or tree.chopped then return false end
    -- 只允许砍树类型的装饰物
    if tree.type == "rock" then return false end
    -- 找第一个空闲的随从
    for _, f in ipairs(Follower.list) do
        if f.alive and f.aiState ~= "chop" and f.aiState ~= "walk_to_tree" then
            f.targetTree = tree
            f.targetTreeX = tree.x
            -- 砍树位置偏移到树根部偏上（-10 使随从站在树干处）
            local rootOffY = GetTreeRootOffsetY(tree.type, tree.scale)
            f.targetTreeY = tree.y + rootOffY - 10
            f.aiState = "walk_to_tree"
            -- 初始化树的 HP
            if not tree.hp then
                tree.hp = 100
            end
            print("[Follower] Assigned to chop tree at (" .. math.floor(tree.x) .. ", " .. math.floor(tree.y) .. ")")
            return true
        end
    end
    return false
end

----------------------------------------------------------------------
-- 木头飞行动画
----------------------------------------------------------------------

function Follower._SpawnWoodAnim(worldX, worldY)
    table.insert(Follower.woodAnims, {
        startX = worldX,
        startY = worldY,
        endX = worldX,   -- 将在渲染时更新为屏幕坐标
        endY = worldY,
        curX = worldX,
        curY = worldY,
        curAlpha = 255,
        timer = 0,
        duration = 0.8,
        amount = 5,       -- 每棵树产生的木头数
        isWorldCoord = true, -- 标记需要坐标转换
    })
end

----------------------------------------------------------------------
-- 绘制
----------------------------------------------------------------------

---@param nvg NVGContextWrapper
---@param f table 单个随从实例
function Follower.Draw(nvg, f)
    if not f.alive then return end

    local sheet = spriteSheets_[f.animKey]
    if not sheet then return end
    local img = images_[f.animKey]
    if not img or img <= 0 then
        -- 回退：画一个小圆
        nvgBeginPath(nvg)
        nvgCircle(nvg, f.x, f.y, 16)
        nvgFillColor(nvg, nvgRGBA(160, 120, 80, 255))
        nvgFill(nvg)
        return
    end

    local frameW = FRAME_SIZE
    local totalW = frameW * sheet.frames
    local frameH = FRAME_SIZE

    local drawW = DRAW_SIZE
    local drawH = DRAW_SIZE
    local destX = f.x - drawW / 2
    local destY = f.y - drawH / 2

    -- 精灵表是水平排列的
    local frame = f.animFrame % sheet.frames
    local frameDrawX = frame * drawW

    local stripDrawW = drawW * sheet.frames
    local stripDrawH = drawH

    nvgSave(nvg)
    nvgScissor(nvg, destX, destY, drawW, drawH)

    local patternX = destX - frameDrawX
    local patternY = destY

    local paint = nvgImagePattern(nvg, patternX, patternY, stripDrawW, stripDrawH, 0, img, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, patternX, patternY, stripDrawW, stripDrawH)
    nvgFillPaint(nvg, paint)
    nvgFill(nvg)

    nvgResetScissor(nvg)
    nvgRestore(nvg)
end

--- 绘制树桩
---@param nvg NVGContextWrapper
---@param deco table 被砍的装饰物
function Follower.DrawStump(nvg, deco)
    -- 按树木类型选择对应的树桩精灵和偏移
    local stumpInfo = stumpMap_[deco.type] or { img = "tree_stump1", offsetY = 6 }
    local img = images_[stumpInfo.img]
    if not img or img <= 0 then
        -- 回退：画一个小棕色矩形
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, deco.x - 12, deco.y - 6, 24, 12, 3)
        nvgFillColor(nvg, nvgRGBA(120, 80, 40, 200))
        nvgFill(nvg)
        return
    end

    -- 计算树根部 Y 位置（与活树底部对齐）
    local rootOffY = GetTreeRootOffsetY(deco.type, deco.scale)
    local rootY = deco.y + rootOffY

    -- 树桩/塔精灵图原始比例 192:256 = 3:4
    -- 树木 baseW=100，树桩宽度与树木一致
    local scale = deco.scale or 1.0
    local drawW = 100 * scale
    local drawH = 133 * scale
    local destX = deco.x - drawW / 2
    -- 树桩底部对齐树根位置（每种树桩独立偏移）
    local destY = rootY - drawH + stumpInfo.offsetY

    local paint = nvgImagePattern(nvg, destX, destY, drawW, drawH, 0, img, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, destX, destY, drawW, drawH)
    nvgFillPaint(nvg, paint)
    nvgFill(nvg)
end

--- 绘制木头飞行动画（屏幕空间，在 UI 层调用）
---@param nvg NVGContextWrapper
---@param screenWidth number
---@param screenHeight number
function Follower.DrawWoodAnims(nvg, screenWidth, screenHeight)
    local img = images_.wood_icon
    if not img or img <= 0 then return end

    -- HUD 木头图标位置（左上角）
    local hudX = 0
    local hudY = 0

    for _, a in ipairs(Follower.woodAnims) do
        -- 世界坐标转屏幕坐标
        if a.isWorldCoord then
            local camOX, camOY = Camera.GetOffset()
            a.startX = a.startX - camOX
            a.startY = a.startY - camOY
            -- 木头飞向 HUD 位置
            a.endX = hudX + 30
            a.endY = hudY + 30
            a.curX = a.startX
            a.curY = a.startY
            a.isWorldCoord = false
        end

        -- 更新目标位置（HUD 位置固定）
        local t = a.timer / a.duration
        local screenX = a.startX + (a.endX - a.startX) * t
        local screenY = a.startY + (a.endY - a.startY) * t - math.sin(t * math.pi) * 80
        local alpha = math.floor(255 * math.min(1, (1 - t) * 3))

        local iconSize = 32
        local paint = nvgImagePattern(nvg, screenX - iconSize / 2, screenY - iconSize / 2,
            iconSize, iconSize, 0, img, alpha / 255)
        nvgBeginPath(nvg)
        nvgRect(nvg, screenX - iconSize / 2, screenY - iconSize / 2, iconSize, iconSize)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    end
end

--- 绘制木头图标和计数（HUD 层, 固定屏幕位置）
---@param nvg NVGContextWrapper
---@param x number 屏幕 X
---@param y number 屏幕 Y
function Follower.DrawWoodHUD(nvg, x, y)
    local img = images_.wood_icon
    local iconSize = 28

    if img and img > 0 then
        local paint = nvgImagePattern(nvg, x, y, iconSize, iconSize, 0, img, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, iconSize, iconSize)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        -- 回退：画棕色圆
        nvgBeginPath(nvg)
        nvgCircle(nvg, x + iconSize / 2, y + iconSize / 2, 10)
        nvgFillColor(nvg, nvgRGBA(139, 90, 43, 255))
        nvgFill(nvg)
    end

    nvgFillColor(nvg, nvgRGBA(200, 160, 80, 255))
    nvgFontSize(nvg, 16)
    nvgTextAlign(nvg, 0) -- NVG_ALIGN_LEFT
    nvgText(nvg, x + iconSize + 4, y + iconSize / 2 + 5, "" .. Follower.woodCount)
end

--- 查找最近的可砍树（用于点击交互）
---@param worldX number
---@param worldY number
---@param decorations table[]
---@param maxDist number
---@return table|nil
function Follower.FindTreeAt(worldX, worldY, decorations, maxDist)
    maxDist = maxDist or 60
    local closest = nil
    local closestDist = maxDist
    for _, deco in ipairs(decorations) do
        if deco.type ~= "rock" and not deco.chopped then
            local d = Dist(worldX, worldY, deco.x, deco.y)
            if d < closestDist then
                closestDist = d
                closest = deco
            end
        end
    end
    return closest
end

return Follower
