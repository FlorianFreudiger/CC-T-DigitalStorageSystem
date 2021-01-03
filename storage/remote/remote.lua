-- Storage Remote
-- Config
local storage_channel = 234
local listening_channel = 123
local modem_side = "back"
-- End of Config

-- Import common function api
local common_functions = require(".storage.common_functions")

local items = {}
local item_panels = {}

local cobalt = dofile("cobalt")
cobalt.ui = dofile("cobalt-ui/init.lua")

local Panel = cobalt.ui.new({w = "100%", h = "100%", backColour = colors.green})

local Input = Panel:add("input", {
    w = "70%",
    y = 1,
    backPassiveColour = colors.green,
    backActiveColour = colors.orange,
    placeholder = "Search item",
    wrap = "left"
})
local RefreshButton = Panel:add("button",
                                {w = "25%", y = 1, h = 1, text = "Refresh", wrap = "right", marginleft = "75%", foreColour = colors.black})

local InfoText = Panel:add("text", {text = "Info-Text", wrap = "center", margintop = "50%", backColour = colors.red})

function set_InfoText(visible, text)
    if visible then
        InfoText.text = text
        InfoText.y = 0
    else
        InfoText.y = -1000
    end
end

-- Cobalt events
function cobalt.draw() cobalt.ui.draw() end
function cobalt.update(dt)
    cobalt.ui.update(dt)
    update_panels()
end
function cobalt.mousepressed(x, y, button) cobalt.ui.mousepressed(x, y, button) end
function cobalt.mousereleased(x, y, button) cobalt.ui.mousereleased(x, y, button) end
function cobalt.keypressed(keycode, key) cobalt.ui.keypressed(keycode, key) end
function cobalt.keyreleased(keycode, key) cobalt.ui.keyreleased(keycode, key) end
-- cobalt.textinput is not called when text is removed
function cobalt.textinput(t) cobalt.ui.textinput(t) end

local modem = peripheral.wrap(modem_side)
modem.open(listening_channel)

-- Returns item names in order of them matching search term
function search_items(search_term)
    local matching_item_names = {}
    if (search_term == nil or search_term == "") then
        for item_name, _ in pairs(items) do table.insert(matching_item_names, item_name) end
    else
        for item_name, _ in pairs(items) do
            if string.find(item_name, search_term) ~= nil then table.insert(matching_item_names, item_name) end
        end
    end

    return matching_item_names
end

function new_item_panel(item_name)
    local NewPanel = Panel:add("panel", {w = "100%", h = 1})
    local NewText = NewPanel:add("text", {text = common_functions.pretty_item_name(item_name), w = "100%"})
    return {NewPanel, NewText}
end

function update_items()
    modem.transmit(storage_channel, listening_channel, "ITEMS")
    _, _, _, _, items = os.pullEvent("modem_message")
end

function update_panels()
    if common_functions.is_table_empty(items) then
        set_InfoText(true, "No items found.")
        return
    end

    local matching_item_names = search_items(Input.text:lower())

    -- Hide all panels
    for _, panel_and_text in pairs(item_panels) do panel_and_text[1].y = -1000 end

    if common_functions.is_table_empty(matching_item_names) then
        set_InfoText(true, "No items matching search.")
        return
    else
        set_InfoText(false)
    end

    for index, item_name in pairs(matching_item_names) do
        local panel_and_text = item_panels[item_name] or new_item_panel(item_name)
        local panel = panel_and_text[1]
        local text = panel_and_text[2]
        panel.y = index + 1
        if index % 2 == 1 then
            panel.backColour = colors.lightGray
            text.backColour = colors.lightGray
        else
            panel.backColour = colors.white
            text.backColour = colors.white
        end
        item_panels[item_name] = panel_and_text
    end
end

RefreshButton.onclick = function()
    update_items()
    update_panels()
end

print("Fetching initial items, if you see this the storage controller hasn't responded yet, it's probably offline.")
print("Start the volume controller and terminate this program by holding Ctrl+T, then start me again")

update_items()
update_panels()
cobalt.initLoop()
