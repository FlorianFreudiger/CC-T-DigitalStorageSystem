local Item = {}

-- Peripheral name is key of occurences table
local ItemOccurence = {}
function ItemOccurence:new()
    local new_occurence = {count = 0}
    setmetatable(new_occurence, self)
    self.__index = self
    return new_occurence
end

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

return Item
