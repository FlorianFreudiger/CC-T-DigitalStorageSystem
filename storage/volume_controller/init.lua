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

local common_functions = require(".storage.common_functions")
local Controller = require("controller")

-- To please the lua diagnostics
os.pullEvent = os.pullEvent or printError("os.pullEvent missing")

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
