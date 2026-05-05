
local WaveManager = {}

WaveManager.waves = {
    {
        prepTime = 10,
        groups = {
            { type = "grunt", count = 6, interval = 1.2, route = "random" },
        },
    },
    {
        prepTime = 15,
        groups = {
            { type = "grunt", count = 8, interval = 1.0, route = "random" },
            { type = "runner", count = 4, interval = 1.5, route = "A" },
        },
    },
    {
        prepTime = 15,
        groups = {
            { type = "grunt", count = 5, interval = 1.0, route = "A" },
            { type = "runner", count = 5, interval = 1.0, route = "B" },
            { type = "grunt", count = 5, interval = 1.0, route = "B" },
        },
    },
    {
        prepTime = 20,
        groups = {
            { type = "grunt", count = 10, interval = 0.7, route = "random" },
            { type = "brute", count = 2, interval = 4.0, route = "A" },
            { type = "archer", count = 3, interval = 2.0, route = "B" },
        },
    },
    {
        prepTime = 20,
        groups = {
            { type = "runner", count = 8, interval = 0.6, route = "random" },
            { type = "brute", count = 3, interval = 3.0, route = "A" },
            { type = "archer", count = 5, interval = 1.5, route = "B" },
        },
    },
    {
        prepTime = 20,
        groups = {
            { type = "archer", count = 10, interval = 1.0, route = "random" },
            { type = "grunt", count = 5, interval = 1.5, route = "A" },
        },
    },
    {
        prepTime = 25,
        groups = {
            { type = "grunt", count = 15, interval = 0.5, route = "random" },
            { type = "brute", count = 4, interval = 2.5, route = "random" },
            { type = "runner", count = 6, interval = 0.8, route = "B" },
        },
    },
    {
        prepTime = 30,
        groups = {
            { type = "boss", count = 1, interval = 0, route = "A" },
            { type = "grunt", count = 10, interval = 0.6, route = "B" },
            { type = "brute", count = 3, interval = 3.0, route = "A" },
        },
    },
}

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

function WaveManager.Init()
    WaveManager.currentWave = 0
    WaveManager.spawnQueue = {}
    WaveManager.spawnTimer = 0
    WaveManager.waveActive = false
    WaveManager.prepTimer = WaveManager.waves[1].prepTime
    WaveManager.allComplete = false
end

return WaveManager
