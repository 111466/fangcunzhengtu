local NativeUI = require("urhox-libs/UI")

local GameUI = {}

local root_ = nil

local function setText(id, text)
    if not root_ then
        return
    end

    local element = root_:FindById(id)
    if element then
        element:SetText(text)
    end
end

local function setVisible(id, visible)
    if not root_ then
        return
    end

    local element = root_:FindById(id)
    if element then
        element:SetVisible(visible)
    end
end

function GameUI.Init()
    NativeUI.Init({
        fonts = {
            {
                family = "sans",
                weights = {
                    normal = "Fonts/MiSans-Regular.ttf",
                }
            }
        },
        scale = NativeUI.Scale.DEFAULT,
    })

    root_ = NativeUI.Panel {
        id = "root",
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            NativeUI.Panel {
                id = "hud",
                position = "absolute",
                top = 14,
                left = 14,
                padding = 12,
                gap = 6,
                backgroundColor = { 0, 0, 0, 150 },
                borderRadius = 8,
                pointerEvents = "none",
                children = {
                    NativeUI.Label { id = "goldLabel", text = "金币: 0", fontSize = 18, fontColor = { 255, 225, 120, 255 } },
                    NativeUI.Label { id = "livesLabel", text = "生命: 0", fontSize = 16, fontColor = { 255, 120, 120, 255 } },
                    NativeUI.Label { id = "waveLabel", text = "波次: 0/0", fontSize = 16, fontColor = { 255, 255, 255, 255 } },
                    NativeUI.Label { id = "statusLabel", text = "状态", fontSize = 14, fontColor = { 180, 220, 255, 255 } },
                }
            },
            NativeUI.Panel {
                id = "selectionPanel",
                position = "absolute",
                top = 14,
                right = 14,
                width = 250,
                padding = 12,
                gap = 6,
                backgroundColor = { 0, 0, 0, 150 },
                borderRadius = 8,
                pointerEvents = "none",
                children = {
                    NativeUI.Label { id = "selectedTowerLabel", text = "当前选择: 弓箭塔", fontSize = 18, fontColor = { 255, 255, 255, 255 } },
                    NativeUI.Label { id = "selectedTowerHintLabel", text = "按 1/2/3 切换塔类型", fontSize = 14, fontColor = { 210, 210, 210, 255 } },
                    NativeUI.Label { id = "upgradeLabel", text = "选中塔后按 U 升级", fontSize = 14, fontColor = { 180, 220, 180, 255 } },
                }
            },
            NativeUI.Label {
                id = "footerLabel",
                text = "左键放置/选择塔 | 1/2/3 切换塔 | U 升级 | P 暂停 | R 重开",
                fontSize = 13,
                fontColor = { 235, 235, 235, 210 },
                position = "absolute",
                left = 0,
                right = 0,
                bottom = 12,
                textAlign = "center",
                pointerEvents = "none",
            },
            NativeUI.Panel {
                id = "menuOverlay",
                width = "100%",
                height = "100%",
                backgroundColor = { 0, 0, 0, 170 },
                pointerEvents = "none",
                children = {
                    NativeUI.Label {
                        id = "menuTitle",
                        text = "Tiny Swords 塔防",
                        fontSize = 42,
                        fontColor = { 255, 255, 255, 255 },
                        position = "absolute",
                        top = 240,
                        left = 0,
                        right = 0,
                        textAlign = "center",
                    },
                    NativeUI.Label {
                        id = "menuHint",
                        text = "按 Enter 或点击屏幕开始",
                        fontSize = 20,
                        fontColor = { 210, 210, 210, 255 },
                        position = "absolute",
                        top = 310,
                        left = 0,
                        right = 0,
                        textAlign = "center",
                    },
                }
            },
            NativeUI.Panel {
                id = "resultOverlay",
                visible = false,
                width = "100%",
                height = "100%",
                backgroundColor = { 0, 0, 0, 165 },
                pointerEvents = "none",
                children = {
                    NativeUI.Label {
                        id = "resultTitle",
                        text = "胜利",
                        fontSize = 42,
                        fontColor = { 255, 255, 255, 255 },
                        position = "absolute",
                        top = 250,
                        left = 0,
                        right = 0,
                        textAlign = "center",
                    },
                    NativeUI.Label {
                        id = "resultHint",
                        text = "按 R 或点击屏幕重新开始",
                        fontSize = 18,
                        fontColor = { 220, 220, 220, 255 },
                        position = "absolute",
                        top = 315,
                        left = 0,
                        right = 0,
                        textAlign = "center",
                    },
                }
            },
        }
    }

    NativeUI.SetRoot(root_)
end

function GameUI.Update(snapshot)
    setText("goldLabel", "金币: " .. snapshot.gold)
    setText("livesLabel", "生命: " .. snapshot.lives)
    setText("waveLabel", string.format("波次: %d/%d", snapshot.wave, snapshot.maxWave))
    setText("statusLabel", "状态: " .. snapshot.statusText)
    setText("selectedTowerLabel", "当前选择: " .. snapshot.selectedTowerName)
    setText("selectedTowerHintLabel", "费用: " .. snapshot.selectedTowerCost .. " 金币")
    setText("upgradeLabel", snapshot.upgradeText)

    setVisible("menuOverlay", snapshot.state == "menu")
    setVisible("resultOverlay", snapshot.state == "victory" or snapshot.state == "game_over")

    if snapshot.state == "victory" then
        setText("resultTitle", "守住了")
        setText("resultHint", "全部波次完成，按 R 或点击屏幕重开")
    elseif snapshot.state == "game_over" then
        setText("resultTitle", "防线失守")
        setText("resultHint", "按 R 或点击屏幕重新开始")
    end
end

function GameUI.Shutdown()
    NativeUI.Shutdown()
    root_ = nil
end

return GameUI
