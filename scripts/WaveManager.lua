
-- Path 模块已移除（大地图模式不再使用路径），保留桩以兼容旧逻辑
local Path = { routes = {}, RandomRoute = function() return {} end }

local WaveManager = {}
WaveManager.waves = {}

WaveManager.currentWave = 0
WaveManager.spawnQueue = {}
WaveManager.spawnTimer = 0
WaveManager.waveActive = false
WaveManager.prepTimer = 0
WaveManager.allComplete = false

function WaveManager.Update(dt, gold)
    if WaveManager.allComplete then return gold end

    if not WaveManager.waveActive then
        WaveManager.prepTimer = WaveManager.prepTimer - dt
        if WaveManager.prepTimer <= 0 then
            WaveManager.StartNextWave()
        end
        return gold
    end

    WaveManager.spawnTimer = WaveManager.spawnTimer - dt
    if WaveManager.spawnTimer <= 0 and #WaveManager.spawnQueue > 0 then
        local next = table.remove(WaveManager.spawnQueue, 1)
        local route
        if next.route == "random" then
            route = Path.RandomRoute()
        elseif next.route == "A" then
            route = Path.routes[1]
        else
            route = Path.routes[2]
        end
        Enemy.Create(next.type, route)
        WaveManager.spawnTimer = next.interval
    end

    if #WaveManager.spawnQueue == 0 and #Enemy.list == 0 then
        WaveManager.waveActive = false
        local nextWave = WaveManager.waves[WaveManager.currentWave + 1]
        if nextWave then
            WaveManager.prepTimer = nextWave.prepTime
        else
            WaveManager.allComplete = true
        end
    end

    return gold
end

function WaveManager.StartNextWave()
    WaveManager.currentWave = WaveManager.currentWave + 1
    local wave = WaveManager.waves[WaveManager.currentWave]
    if not wave then WaveManager.allComplete = true; return end

    WaveManager.spawnQueue = {}
    for _, group in ipairs(wave.groups) do
        for j = 1, group.count do
            table.insert(WaveManager.spawnQueue, {
                type = group.type,
                interval = group.interval,
                route = group.route,
            })
        end
    end
    WaveManager.spawnTimer = 0
    WaveManager.waveActive = true
end

function WaveManager.Init(levelConfig)
    local source = levelConfig and levelConfig.waves or nil
    if source then
        WaveManager.waves = source
    else
        WaveManager.waves = {}
    end

    WaveManager.currentWave = 0
    WaveManager.spawnQueue = {}
    WaveManager.spawnTimer = 0
    WaveManager.waveActive = false
    local firstWave = WaveManager.waves[1]
    WaveManager.prepTimer = firstWave and firstWave.prepTime or 0
    WaveManager.allComplete = false
end

return WaveManager
