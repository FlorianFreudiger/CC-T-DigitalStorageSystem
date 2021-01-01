-- Storage Volume Controller
-- Config
local storage_types = {
    "minecraft:chest", "ironchest:iron_chest", "ironchest:gold_chest", "ironchest:diamond_chest", "ironchest:copper_chest",
    "ironchest:silver_chest", "ironchest:obsidian_chest"
}
local io_types = {"minecraft:trapped_chest", "ironchest:crystal_chest"}
local listening_channel = 234
-- End of Config

-- Check config settings
local cc_expect = require("cc.expect")
cc_expect.expect(1, storage_types, "table")
cc_expect.expect(1, io_types, "table")
cc_expect.expect(1, listening_channel, "number")

-- To please the lua diagnostics
os.pullEvent = os.pullEvent or printError("os.pullEvent missing")
os.loadAPI = os.loadAPI or printError("os.loadAPI missing")

-- Import common function api
common_functions_loaded = os.loadAPI("/storage/common_functions.lua")
if not common_functions_loaded then printError("Common functions library not found, please add") end

-- Returns array of inventories of peripheral type
function find_inventories(types)
    local result = {}
    for _, type in pairs(types) do
        local found_invs = table.pack(peripheral.find(type))
        for k, inv in pairs(found_invs) do -- TODO Ignore sides, since inventory.pull/pushItem doesn't work with them
            if k ~= "n" then table.insert(result, inv) end
        end
    end
    return result
end

-- Returns slots that contain item_name
function get_slots_of_item_in_inventory(item_name, inv)
    local slots = {}
    local items_in_inv = inv.list()
    for slot, item in pairs(items_in_inv) do if item["name"] == item_name then table.insert(slots, slot) end end
    return slots
end

---- ITEMS ----
-- Name of item is the key of items table
Item = {}
function Item:new()
    local new_item = {occurences = {}}
    setmetatable(new_item, self)
    self.__index = self
    return new_item
end

function Item:add_occurence(inventory, count)
    inventory = peripheral.getName(inventory)

    -- "or" only evals new if there is none
    local occurence = self.occurences[inventory] or ItemOccurence:new()
    occurence.count = occurence.count + count
    self.occurences[inventory] = occurence
end

-- TODO: Find alternative to overloading to make function arguments more flexible
function Item:decrease_occurence_count(inventory_name, count)
    -- "or" only evals new if there is none
    local occurence = self.occurences[inventory_name]
    occurence.count = occurence.count - count
    if occurence.count <= 0 then
        if occurence.count < 0 then printError("Occurence count is negative") end
        self.occurences[inventory_name] = nil
    else
        self.occurences[inventory_name] = occurence
    end
end

function Item:get_count()
    local count = 0
    for _, occurence in pairs(self.occurences) do count = count + occurence.count end
    return count
end

-- Peripheral name is key of occurences table
ItemOccurence = {}
function ItemOccurence:new()
    local new_occurence = {count = 0}
    setmetatable(new_occurence, self)
    self.__index = self
    return new_occurence
end

---- CONTROLLER ----
Controller = {items = {}, storage_inventories = {}, io_inventories = {}}

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

function Controller:io_push_item(io_inv, slot, amount)
    -- TODO Optimize by trying to push into invs that already have the same item first
    for _, storage_inv in pairs(self.storage_inventories) do
        local peripheral_name = peripheral.getName(storage_inv)
        amount = amount - io_inv.pushItems(peripheral_name, slot, amount)
        if amount <= 0 then break end
    end
    if amount > 0 then printError("Couldn't move item from io into storage, is storage full?") end
end

function Controller:io_clear()
    for _, io_inv in pairs(self.io_inventories) do
        local items_in_io_inv = io_inv.list()
        for slot, item in pairs(items_in_io_inv) do self:io_push_item(io_inv, slot, item["count"]) end
    end
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
        local slots = get_slots_of_item_in_inventory(item_name, storage_inv)

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

-- Find modems
local modems = table.pack(peripheral.find("modem"))
if #modems <= 0 then
    printError("No modem found, please attach one!")
    return
else
    print(#modems .. " modems mounted.\n")
end

---- NETWORKING STUFF ----

function receive_string_ping(modem, reply_channel)
    modem.transmit(reply_channel, listening_channel, "PONG")
    print("Replied to ping")
end
function receive_string_clear_io()
    -- TODO: Confirmation
    -- modem.transmit(listening_channel, channel, "CLEARED IO")
    print("Clearing io")
    Controller:io_clear()
end
function receive_string_items(modem, reply_channel)
    local items = Controller:export_item_table()
    modem.transmit(reply_channel, listening_channel, items)
    print("Sent items")
end
networking_actions_string = {["PING"] = receive_string_ping, ["CLEAR IO"] = receive_string_clear_io, ["ITEMS"] = receive_string_items}

function receive_table_pull_item(_, _, message)
    local io_inv = peripheral.wrap(message.io_inv_name)
    local item_name = message.item_name
    local amount = message.amount
    print("Pulling", amount, item_name, "into", message.io_inv_name)
    Controller:io_pull_item(io_inv, item_name, amount)
end
networking_actions_table = {["PULL ITEM"] = receive_table_pull_item}

print("Searching for inventories..")
Controller.storage_inventories = find_inventories(storage_types)
print("-Found " .. common_functions.tablelength(Controller.storage_inventories) .. " storage inventories")
Controller.io_inventories = find_inventories(io_types)
print("-Found " .. common_functions.tablelength(Controller.io_inventories) .. " io inventories")
print()

print("Scanning inventories..")
Controller:populate_items()
print("-Found " .. common_functions.tablelength(Controller.items) .. " different items.")
print()

for key, modem in pairs(modems) do if (key ~= "n") then modem.open(listening_channel) end end
print("Listening on port " .. listening_channel)

-- Main loop
while true do
    local _, peripheral_name, _, reply_channel, message = os.pullEvent("modem_message")
    local modem = peripheral.wrap(peripheral_name)

    if type(message) == "string" then
        local action = networking_actions_string[message]
        if action ~= nil then
            action(modem, reply_channel)
        else
            printError("Unknown string message: ", message)
        end

    elseif type(message) == "table" then
        local action = networking_actions_table[message.action]
        if action ~= nil then
            action(modem, reply_channel, message)
        else
            printError("Unknown table message action: ", message.action)
        end

    else
        printError("Unknown " .. type(message) .. " message: ", message)
    end
end
