
local Equipment = {}

Equipment.progression = {
    weapon = { "iron_sword", "steel_sword", "flame_blade" },
    armor = { "leather_armor", "chain_mail", "dragon_armor" },
    accessory = { "speed_boots", "mana_ring", "life_steal" },
}

Equipment.items = {
    iron_sword = {
        name = "铁剑", type = "weapon", slot = "weapon",
        stats = { atk = 10 }, desc = "+10 攻击", price = 80,
    },
    steel_sword = {
        name = "钢剑", type = "weapon", slot = "weapon",
        stats = { atk = 25 }, desc = "+25 攻击", price = 200,
    },
    flame_blade = {
        name = "烈焰之刃", type = "weapon", slot = "weapon",
        stats = { atk = 40 }, desc = "+40 攻击，攻击附带灼烧",
        special = "burn", price = 500,
    },
    leather_armor = {
        name = "皮甲", type = "armor", slot = "armor",
        stats = { def = 8, hp = 50 }, desc = "+8 防御 +50 生命", price = 60,
    },
    chain_mail = {
        name = "锁子甲", type = "armor", slot = "armor",
        stats = { def = 20, hp = 100 }, desc = "+20 防御 +100 生命", price = 180,
    },
    dragon_armor = {
        name = "龙鳞甲", type = "armor", slot = "armor",
        stats = { def = 40, hp = 300 }, desc = "+40 防御 +300 生命",
        special = "thorns", price = 450,
    },
    speed_boots = {
        name = "疾风靴", type = "accessory", slot = "accessory",
        stats = { speed = 50 }, desc = "+50 移动速度", price = 100,
    },
    mana_ring = {
        name = "法力之环", type = "accessory", slot = "accessory",
        stats = { hp = 80 }, desc = "+80 生命，法力回复+50%",
        special = "mana_regen", price = 150,
    },
    life_steal = {
        name = "吸血鬼之牙", type = "accessory", slot = "accessory",
        stats = { atk = 15 }, desc = "+15 攻击，攻击回复 10% 伤害",
        special = "lifesteal", price = 350,
    },
}

function Equipment.Equip(itemId, gold)
    local item = Equipment.items[itemId]
    if not item then return false, gold end
    if gold < item.price then return false, gold end

    gold = gold - item.price
    Hero.state.equipment[item.slot] = itemId
    Hero.RecalcStats()
    return true, gold
end

function Equipment.Unequip(slot)
    Hero.state.equipment[slot] = nil
    Hero.RecalcStats()
end

function Equipment.GetNextItem(slot)
    local order = Equipment.progression[slot]
    if not order then return nil end
    local equipped = Hero.state.equipment[slot]
    if not equipped then
        return order[1]
    end
    for i, itemId in ipairs(order) do
        if itemId == equipped then
            return order[i + 1]
        end
    end
    return nil
end

function Equipment.BuyNext(slot, gold)
    local itemId = Equipment.GetNextItem(slot)
    if not itemId then return false, gold, nil end
    local ok
    ok, gold = Equipment.Equip(itemId, gold)
    return ok, gold, itemId
end

return Equipment
