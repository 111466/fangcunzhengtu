local Utils = require("scripts/Utils")

local Projectile = {}

local function splashDamage(projectile, enemies, enemyApi)
    if projectile.splash <= 0 then
        return
    end

    local splashRadiusSquared = projectile.splash * projectile.splash
    for _, enemy in ipairs(enemies) do
        if enemy ~= projectile.target and enemy.alive then
            local distanceSquared = Utils.DistanceSquared(projectile.target.x, projectile.target.y, enemy.x, enemy.y)
            if distanceSquared <= splashRadiusSquared then
                enemyApi.Damage(enemy, projectile.damage * 0.5)
            end
        end
    end
end

function Projectile.Create(data)
    return {
        x = data.x,
        y = data.y,
        target = data.target,
        damage = data.damage,
        speed = data.speed,
        radius = data.radius or 5,
        color = data.color or { 255, 255, 255, 255 },
        splash = data.splash or 0,
        slowFactor = data.slowFactor,
        slowDuration = data.slowDuration,
        alive = true,
    }
end

function Projectile.Update(projectile, dt, enemies, enemyApi)
    if not projectile.alive then
        return
    end

    if not projectile.target or not projectile.target.alive then
        projectile.alive = false
        return
    end

    local dx = projectile.target.x - projectile.x
    local dy = projectile.target.y - projectile.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local maxStep = projectile.speed * dt

    if distance <= maxStep or distance <= projectile.radius then
        projectile.x = projectile.target.x
        projectile.y = projectile.target.y
        enemyApi.Damage(projectile.target, projectile.damage)

        if projectile.slowFactor and projectile.slowDuration then
            enemyApi.ApplySlow(projectile.target, projectile.slowFactor, projectile.slowDuration)
        end

        splashDamage(projectile, enemies, enemyApi)
        projectile.alive = false
        return
    end

    projectile.x = projectile.x + dx / distance * maxStep
    projectile.y = projectile.y + dy / distance * maxStep
end

function Projectile.Draw(nvg, projectile, transform)
    if projectile.alive == false then
        return
    end

    local x, y = Utils.ToScreen(transform, projectile.x, projectile.y)
    local radius = math.max(2, Utils.ToScreenSize(transform, projectile.radius))

    nvgBeginPath(nvg)
    nvgCircle(nvg, x, y, radius)
    nvgFillColor(nvg, nvgRGBA(projectile.color[1], projectile.color[2], projectile.color[3], projectile.color[4]))
    nvgFill(nvg)
end

return Projectile
