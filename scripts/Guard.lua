local Camera = require("scripts.Camera")
local Config = require("scripts.Config")

local Guard = {}

----------------------------------------------------------------------
-- 精灵图元数据
----------------------------------------------------------------------
local spriteMeta_ = {
    idle_right    = { file = "image/guard_idle_right.png",    frames = 8, frameW = 192, frameH = 192 },
    idle_left     = { file = "image/guard_idle_left.png",     frames = 8, frameW = 192, frameH = 192 },
    walk_right    = { file = "image/guard_walk_right.png",    frames = 6, frameW = 192, frameH = 192 },
    walk_left     = { file = "image/guard_walk_left.png",     frames = 6, frameW = 192, frameH = 192 },
    attack_right  = { file = "image/guard_attack_right.png",  frames = 4, frameW = 192, frameH = 192 },
    attack_left   = { file = "image/guard_attack_left.png",   frames = 4, frameW = 192, frameH = 192 },
}

local ANIM_FPS = 6    -- 每秒帧数
local DRAW_W   = 64   -- 绘制宽度
local DRAW_H   = 64   -- 绘制高度

----------------------------------------------------------------------
-- 战斗配置
----------------------------------------------------------------------
local GUARD_HP          = 150
local GUARD_ATK         = 15
local GUARD_DEF         = 5
local GUARD_ATTACK_RANGE = 30   -- 攻击距离（贴近才攻击）
local GUARD_DETECT_RANGE = 150  -- 索敌距离
local GUARD_PATROL_RANGE = 200  -- 最大巡逻距离（距出生点）
local GUARD_MOVE_SPEED   = 120  -- 移动速度
local GUARD_ATTACK_SPEED = 1.0  -- 每秒攻击次数

----------------------------------------------------------------------
-- 模块状态
----------------------------------------------------------------------
local nvg_ = nil
local images_ = {}
local guards_ = {}  -- 守卫列表

----------------------------------------------------------------------
-- 工具函数
----------------------------------------------------------------------
local function Dist(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function MoveToward(g, tx, ty, speed, dt)
    local dx = tx - g.x
    local dy = ty - g.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 2 then return true end
    local step = speed * dt
    if step >= dist then
        g.x = tx
        g.y = ty
        return true
    end
    g.x = g.x + (dx / dist) * step
    g.y = g.y + (dy / dist) * step
    return false
end

----------------------------------------------------------------------
-- 加载 / 清理
----------------------------------------------------------------------

---@param nvg NVGContextWrapper
function Guard.LoadSprites(nvg)
    nvg_ = nvg
    for name, meta in pairs(spriteMeta_) do
        images_[name] = nvgCreateImage(nvg, meta.file, 0)
        if images_[name] and images_[name] > 0 then
            print("[Guard] Loaded sprite: " .. name .. " (handle=" .. images_[name] .. ")")
        else
            print("[Guard] WARNING: Failed to load sprite: " .. name)
        end
    end
end

---@param nvg NVGContextWrapper
function Guard.CleanupSprites(nvg)
    if nvg then
        for name, handle in pairs(images_) do
            if handle and handle > 0 then
                nvgDeleteImage(nvg, handle)
            end
        end
    end
    images_ = {}
    guards_ = {}
    nvg_ = nil
    print("[Guard] Cleanup done")
end

----------------------------------------------------------------------
-- 守卫管理
----------------------------------------------------------------------

--- 创建一个守卫
---@param x number 世界坐标 X
---@param y number 世界坐标 Y
---@param facing string "right" 或 "left"
function Guard.Create(x, y, facing)
    facing = facing or "right"
    local guard = {
        x = x,
        y = y,
        spawnX = x,      -- 出生点（用于巡逻范围限制）
        spawnY = y,
        facing = facing == "right" and 1 or -1,
        alive = true,

        -- 生命值
        hp = GUARD_HP,
        maxHP = GUARD_HP,

        -- AI 状态
        aiState = "idle",   -- "idle" | "chase" | "attack" | "return"
        target = nil,       -- 当前攻击目标 { x, y, ... }
        targetType = nil,   -- "hero" | "follower"

        -- 动画
        anim = "idle_" .. facing,
        animTime = math.random() * 10,
        animFrame = 0,
        animPlaying = false,  -- 攻击动画播放中

        -- 攻击冷却
        attackCooldown = 0,

        -- 受击闪烁
        hitFlashTimer = 0,
    }
    table.insert(guards_, guard)
    print("[Guard] Created at (" .. math.floor(x) .. ", " .. math.floor(y) .. ") facing " .. facing)
    return guard
end

---@return table[]
function Guard.GetList()
    return guards_
end

function Guard.Reset()
    guards_ = {}
end

----------------------------------------------------------------------
-- 动画辅助
----------------------------------------------------------------------

local function GetAnimKey(action, facing)
    local dir = facing >= 0 and "right" or "left"
    return action .. "_" .. dir
end

local function UpdateFacing(g, tx)
    if tx > g.x + 2 then
        g.facing = 1
    elseif tx < g.x - 2 then
        g.facing = -1
    end
end

----------------------------------------------------------------------
-- 更新
----------------------------------------------------------------------

--- 更新所有守卫（含 AI 和战斗）
---@param dt number
---@param heroState table 英雄状态
---@param followers table[] 随从列表
function Guard.Update(dt, heroState, followers)
    for i = #guards_, 1, -1 do
        local g = guards_[i]
        if g.alive then
            Guard._UpdateOne(g, dt, heroState, followers)
        end
    end
end

function Guard._UpdateOne(g, dt, heroState, followers)
    -- 冷却
    if g.attackCooldown > 0 then g.attackCooldown = g.attackCooldown - dt end
    if g.hitFlashTimer > 0 then g.hitFlashTimer = g.hitFlashTimer - dt end

    -- 动画帧更新
    g.animTime = g.animTime + dt
    local meta = spriteMeta_[g.anim]
    if meta then
        local totalFrames = meta.frames
        local frameIndex = math.floor(g.animTime * ANIM_FPS) % totalFrames
        -- 攻击动画播完回到 idle
        if g.animPlaying then
            if frameIndex < g.animFrame and g.animFrame > 0 then
                g.animPlaying = false
            end
        end
        g.animFrame = frameIndex
    end

    ----------------------------------------------------------------
    -- AI 状态机：巡逻出生点附近，发现敌人就追击攻击
    ----------------------------------------------------------------

    -- 查找最近的威胁目标（英雄或随从）
    local closestTarget = nil
    local closestDist = GUARD_DETECT_RANGE
    local closestType = nil

    -- 检测英雄
    if heroState and heroState.alive then
        local d = Dist(g.x, g.y, heroState.x, heroState.y)
        if d < closestDist then
            closestDist = d
            closestTarget = heroState
            closestType = "hero"
        end
    end

    -- 检测随从
    if followers then
        for _, f in ipairs(followers) do
            if f.alive then
                local d = Dist(g.x, g.y, f.x, f.y)
                if d < closestDist then
                    closestDist = d
                    closestTarget = f
                    closestType = "follower"
                end
            end
        end
    end

    -- 检查是否距出生点太远
    local distFromSpawn = Dist(g.x, g.y, g.spawnX, g.spawnY)

    if g.aiState == "return" then
        -- 回到出生点
        g.anim = GetAnimKey("walk", g.facing)
        UpdateFacing(g, g.spawnX)
        local arrived = MoveToward(g, g.spawnX, g.spawnY, GUARD_MOVE_SPEED, dt)
        if arrived or distFromSpawn < 10 then
            g.aiState = "idle"
            g.anim = GetAnimKey("idle", g.facing)
        end
        -- 回程中如果附近有敌人且没走太远，可以打断
        if closestTarget and closestDist < GUARD_ATTACK_RANGE and distFromSpawn < GUARD_PATROL_RANGE then
            g.aiState = "attack"
            g.target = closestTarget
            g.targetType = closestType
        end
        return
    end

    -- 如果距离出生点超出巡逻范围且当前没有近距离目标，返回
    if distFromSpawn > GUARD_PATROL_RANGE and (not closestTarget or closestDist > GUARD_ATTACK_RANGE) then
        g.aiState = "return"
        g.target = nil
        return
    end

    if closestTarget then
        g.target = closestTarget
        g.targetType = closestType

        if closestDist <= GUARD_ATTACK_RANGE then
            -- 在攻击范围内 → 攻击
            g.aiState = "attack"
            UpdateFacing(g, closestTarget.x)
            g.anim = GetAnimKey("attack", g.facing)

            if g.attackCooldown <= 0 then
                g.attackCooldown = 1.0 / GUARD_ATTACK_SPEED
                g.animTime = 0
                g.animFrame = 0
                g.animPlaying = true

                -- 造成伤害
                Guard._DealDamage(g, closestTarget, closestType)
            end
        else
            -- 追击
            g.aiState = "chase"
            UpdateFacing(g, closestTarget.x)
            g.anim = GetAnimKey("walk", g.facing)
            MoveToward(g, closestTarget.x, closestTarget.y, GUARD_MOVE_SPEED, dt)
        end
    else
        -- 无目标 → 待机
        g.aiState = "idle"
        g.target = nil
        if not g.animPlaying then
            g.anim = GetAnimKey("idle", g.facing)
        end
    end
end

--- 守卫对目标造成伤害
function Guard._DealDamage(g, target, targetType)
    if targetType == "hero" then
        -- 调用 Hero.TakeDamage（在 main.lua 侧处理）
        -- 这里通过标记让 main.lua 调用
        g._pendingDamage = { target = target, type = targetType, amount = GUARD_ATK }
    elseif targetType == "follower" then
        -- 直接扣随从 HP
        target.hp = (target.hp or 100) - GUARD_ATK
        if target.hp <= 0 then
            target.alive = false
            print("[Guard] Killed a follower!")
        end
    end
end

----------------------------------------------------------------------
-- 受伤 / 被攻击
----------------------------------------------------------------------

--- 守卫受到伤害
---@param guard table
---@param damage number
---@return number 实际伤害
function Guard.TakeDamage(guard, damage)
    if not guard.alive then return 0 end

    -- 防御减伤
    local reduction = GUARD_DEF / (GUARD_DEF + 80)
    local actual = math.max(1, math.floor(damage * (1 - reduction)))

    guard.hp = guard.hp - actual
    guard.hitFlashTimer = 0.15

    if guard.hp <= 0 then
        guard.hp = 0
        guard.alive = false
        print("[Guard] Defeated!")
    end

    return actual
end

----------------------------------------------------------------------
-- 消费待处理的伤害事件
----------------------------------------------------------------------

--- 收集并清除所有待处理的英雄伤害
---@return table[] { {amount, guard} }
function Guard.FlushPendingDamage()
    local damages = {}
    for _, g in ipairs(guards_) do
        if g._pendingDamage then
            table.insert(damages, { amount = g._pendingDamage.amount, guard = g })
            g._pendingDamage = nil
        end
    end
    return damages
end

----------------------------------------------------------------------
-- 绘制
----------------------------------------------------------------------

---@param nvg NVGContextWrapper
---@param guard table
function Guard.Draw(nvg, guard)
    if not guard.alive then return end

    local meta = spriteMeta_[guard.anim]
    if not meta then return end
    local img = images_[guard.anim]
    if not img or img <= 0 then return end

    -- 受击闪烁
    if guard.hitFlashTimer > 0 and math.floor(guard.hitFlashTimer * 20) % 2 == 0 then
        return
    end

    -- 计算当前帧
    local totalFrames = meta.frames
    local frameIndex = guard.animFrame % totalFrames

    -- 绘制
    local stripDrawW = DRAW_W * totalFrames
    local stripDrawH = DRAW_H
    local frameDrawX = frameIndex * DRAW_W

    local destX = guard.x - DRAW_W / 2
    local destY = guard.y - DRAW_H / 2

    nvgSave(nvg)
    nvgScissor(nvg, destX, destY, DRAW_W, DRAW_H)

    local patternX = destX - frameDrawX
    local patternY = destY

    local paint = nvgImagePattern(nvg, patternX, patternY, stripDrawW, stripDrawH, 0, img, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, patternX, patternY, stripDrawW, stripDrawH)
    nvgFillPaint(nvg, paint)
    nvgFill(nvg)

    nvgResetScissor(nvg)
    nvgRestore(nvg)

    -- 血条（只在受伤时显示）
    if guard.hp < guard.maxHP then
        local barW = 40
        local barH = 4
        local barX = guard.x - barW / 2
        local barY = guard.y - DRAW_H / 2 - 8

        -- 底色
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX, barY, barW, barH, 2)
        nvgFillColor(nvg, nvgRGBA(60, 20, 20, 180))
        nvgFill(nvg)

        -- 血量
        local hpRatio = guard.hp / guard.maxHP
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX, barY, barW * hpRatio, barH, 2)
        nvgFillColor(nvg, nvgRGBA(200, 50, 50, 220))
        nvgFill(nvg)
    end
end

return Guard
