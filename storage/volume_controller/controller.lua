local common_functions = require(".storage.common_functions")
local Item = require("item")

local Controller = {items = {}, storage_inventories = {}, io_inventories = {}}

function Controller:add_item(item_name, storage_inv, amount)
    local item = self.items[item_name] or Item:new()
    item:add_occurence(storage_inv, amount)
    self.items[item_name] = item
end

function Controller:populate_items()
    -- Reset items
    self.items = {}
    for _, inv in pairs(self.storage_inventories) do
        local items_in_inv = inv.list()
        for _, item in pairs(items_in_inv) do self:add_item(item["name"], inv, item["count"]) end
    end
end

function Controller:io_push_item(io_inv, slot, amount, item_name)
    -- TODO Optimize by trying to push into invs that already have the same item first
    for _, storage_inv in pairs(self.storage_inventories) do
        local peripheral_name = peripheral.getName(storage_inv)
        local pushed_item_count = io_inv.pushItems(peripheral_name, slot, amount)
        amount = amount - pushed_item_count
        self.items[item_name]:add_occurence(storage_inv, pushed_item_count)
        if amount <= 0 then break end
    end
    if amount > 0 then printError("Couldn't move item from io into storage, is storage full?") end
end

function Controller:io_clear()
    for _, io_inv in pairs(self.io_inventories) do
        local items_in_io_inv = io_inv.list()
        for slot, item in pairs(items_in_io_inv) do self:io_push_item(io_inv, slot, item["count"], item["name"]) end
    end
end

-- Returns slots that contain item_name
local function inventory_get_slots_of_item(item_name, inv)
    local slots = {}
    local items_in_inv = inv.list()
    for slot, item in pairs(items_in_inv) do if item["name"] == item_name then table.insert(slots, slot) end end
    return slots
end

function Controller:io_pull_item(io_inv, item_name, amount)
    local item = self.items[item_name]
    if item == nil then
        printError("Cannot pull item, not stored:", item_name)
        return
    end

    -- Remember how many items we transfered and then decrease the occurence item count afterwards
    -- since it's probably not good to remove an element from a list we a currently iterating (at least not in spair)
    local transfer_count_per_occurence = {}

    -- Pull item from inventories with low item count first to decrease internal fragmentation
    for storage_inv_name, _ in common_functions.spairs(item.occurences, function(t, a, b) return t[b].count > t[a].count end) do
        local storage_inv = peripheral.wrap(storage_inv_name)
        local slots = inventory_get_slots_of_item(item_name, storage_inv)

        local transfer_count_occurence = 0
        for _, slot in pairs(slots) do -- We could sort this like the chests, but wouldn't make such a big difference
            local transfer_count_slot = io_inv.pullItems(storage_inv_name, slot, amount)
            amount = amount - transfer_count_slot
            transfer_count_occurence = transfer_count_occurence + transfer_count_slot
            if amount <= 0 then break end
        end

        transfer_count_per_occurence[storage_inv_name] = transfer_count_occurence
        if amount <= 0 then break end
    end

    if amount > 0 then printError("Item pull not finished, remaining amount:", amount) end

    for storage_inv_name, count in pairs(transfer_count_per_occurence) do item:decrease_occurence_count(storage_inv_name, count) end
end

-- Returns a simple item list with the item names as keys and count as value
function Controller:export_item_table()
    local item_table = {}
    for item_name, item in pairs(self.items) do item_table[item_name] = item:get_count() end
    return item_table
end

return Controller
