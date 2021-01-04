-- Storage Remote
-- Config
local storage_channel = 234
local listening_channel = 123
local modem_side = "back"
-- End of Config

-- Import common function api
local common_functions = require(".storage.common_functions")

local items = {}
local item_menu_entries = {}

local cobalt = dofile("cobalt")
cobalt.ui = dofile("cobalt-ui/init.lua")

local Panel = cobalt.ui.new({w = "100%", h = "100%", backColour = colors.green})

local Input = Panel:add("input", {
    w = "70%",
    y = 1,
    backPassiveColour = colors.green,
    backActiveColour = colors.lime,
    placeholder = "Search item",
    wrap = "left"
})
local RefreshButton = Panel:add("button", {
    w = "25%",
    y = 1,
    h = 1,
    text = "Refresh",
    wrap = "right",
    marginleft = "75%",
    foreColour = colors.black,
    backColour = colors.purple
})

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

local ItemMenuEntry = {}
function ItemMenuEntry:new(item_name, item_count)
    item_count = math.min(item_count, 999)
    local NewPanel = Panel:add("panel", {w = "100%", h = 1})
    local TextCount = NewPanel:add("text", {text = string.format("%03d", item_count)})
    local TextName = NewPanel:add("text", {text = common_functions.pretty_item_name(item_name), marginleft = 4})

    local new_entry = {panel = NewPanel, text_name = TextName, text_count = TextCount}
    setmetatable(new_entry, self)
    self.__index = self
    return new_entry
end

function ItemMenuEntry:show(y) self.panel.y = y end

function ItemMenuEntry:hide() self.panel.y = -1000 end

function ItemMenuEntry:set_color_index(index)
    local scheme = index % 2
    -- You can add to or modify the entry color scheme here!
    if scheme == 0 then
        self.panel.backColour = colors.lightBlue
        self.text_name.backColour = colors.lightBlue
        self.text_count.backColour = colors.cyan
    elseif scheme == 1 then
        self.panel.backColour = colors.yellow
        self.text_name.backColour = colors.yellow
        self.text_count.backColour = colors.orange
    else
        printError("Unknown color scheme")
    end
end

function ItemMenuEntry:update_count(item_count)
    item_count = math.min(item_count, 999)
    self.text_count.text = string.format("%03d", item_count)
end

function update_items()
    modem.transmit(storage_channel, listening_channel, "ITEMS")
    _, _, _, _, items = os.pullEvent("modem_message")

    -- Update count for existing entries
    for item_name, count in pairs(items) do
        local entry = item_menu_entries[item_name]
        if entry then entry:update_count(count) end
    end
end

function update_panels()
    if common_functions.is_table_empty(items) then
        set_InfoText(true, "No items found.")
        return
    end

    local matching_item_names = search_items(Input.text:lower())

    -- Hide all panels
    for _, entry in pairs(item_menu_entries) do entry:hide() end

    local no_match = common_functions.is_table_empty(matching_item_names)
    set_InfoText(no_match, "No items matching search.")
    if no_match then return end

    for index, item_name in pairs(matching_item_names) do
        local entry = item_menu_entries[item_name] or ItemMenuEntry:new(item_name, items[item_name])
        entry:show(index + 1)
        entry:set_color_index(index)
        item_menu_entries[item_name] = entry
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
