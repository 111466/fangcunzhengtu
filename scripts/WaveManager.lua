local WaveManager = {}

WaveManager.waves = {
    {
        prepTime = 5.0,
        groups = {
            { type = "grunt", count = 6, interval = 0.9 },
        },
    },
    {
        prepTime = 8.0,
        groups = {
            { type = "grunt", count = 8, interval = 0.8 },
            { type = "scout", count = 4, interval = 1.0 },
        },
    },
    {
        prepTime = 10.0,
        groups = {
            { type = "grunt", count = 10, interval = 0.65 },
            { type = "scout", count = 6, interval = 0.75 },
        },
    },
    {
        prepTime = 12.0,
        groups = {
            { type = "grunt", count = 8, interval = 0.55 },
            { type = "tank", count = 3, interval = 2.2 },
            { type = "scout", count = 5, interval = 0.75 },
        },
    },
    {
        prepTime = 14.0,
        groups = {
            { type = "grunt", count = 12, interval = 0.45 },
            { type = "scout", count = 8, interval = 0.65 },
            { type = "tank", count = 5, interval = 1.9 },
        },
    },
}

local function buildQueue(groups)
    local queue = {}
    local remaining = {}

    for index, group in ipairs(groups) do
        remaining[index] = group.count
    end

    local added = true
    while added do
        added = false
        for index, group in ipairs(groups) do
            if remaining[index] > 0 then
            queue[#queue + 1] = {
                type = group.type,
                    delay = group.interval,
                }
                remaining[index] = remaining[index] - 1
                added = true
            end
        end
    end

    return queue
end

function WaveManager.Create()
    local manager = {
        currentWave = 0,
        prepTimer = WaveManager.waves[1].prepTime,
        spawnQueue = {},
        spawnTimer = 0,
        waveActive = false,
        allComplete = false,
    }
    return manager
end

function WaveManager.Update(manager, dt, spawnEnemy, countAliveEnemies)
    if manager.allComplete then
        return
    end

    if not manager.waveActive then
        manager.prepTimer = manager.prepTimer - dt
        if manager.prepTimer <= 0 then
            manager.currentWave = manager.currentWave + 1
            local waveDefinition = WaveManager.waves[manager.currentWave]
            if not waveDefinition then
                manager.allComplete = true
                return
            end

            manager.spawnQueue = buildQueue(waveDefinition.groups)
            manager.spawnTimer = 0
            manager.waveActive = true
        end
        return
    end

    manager.spawnTimer = manager.spawnTimer - dt
    while manager.spawnTimer <= 0 and #manager.spawnQueue > 0 do
        local nextSpawn = table.remove(manager.spawnQueue, 1)
        spawnEnemy(nextSpawn.type)
        if #manager.spawnQueue > 0 then
            manager.spawnTimer = manager.spawnTimer + nextSpawn.delay
        else
            manager.spawnTimer = 0
            break
        end
    end

    local activeEnemyCount = countAliveEnemies()
    if #manager.spawnQueue == 0 and activeEnemyCount == 0 then
        manager.waveActive = false
        local nextWave = WaveManager.waves[manager.currentWave + 1]
        if nextWave then
            manager.prepTimer = nextWave.prepTime
        else
            manager.allComplete = true
        end
    end
end

function WaveManager.GetWaveCount()
    return #WaveManager.waves
end

function WaveManager.IsFinished(manager)
    return manager.allComplete and not manager.waveActive and #manager.spawnQueue == 0
end

function WaveManager.GetStatusText(manager)
    if manager.allComplete then
        return "所有波次已完成"
    end

    if manager.waveActive then
        return "战斗进行中"
    end

    return string.format("下一波 %.1fs", math.max(0, manager.prepTimer))
end

return WaveManager
