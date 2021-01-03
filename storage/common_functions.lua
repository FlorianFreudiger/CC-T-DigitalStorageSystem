local common_functions = {}

-- https://stackoverflow.com/a/2705804
-- Thank you https://stackoverflow.com/users/137317/u0b34a0f6ae
function common_functions.tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

-- https://stackoverflow.com/a/15706820
-- Thank you https://stackoverflow.com/users/221509/michal-kottman
-- Example Usage:
-- for k,v in spairs(Table, function(t,a,b) return t[b] < t[a] end) do
--    print(k,v)
-- end
function common_functions.spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a, b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then return keys[i], t[keys[i]] end
    end
end

function common_functions.is_table_empty(t) return next(t) == nil end

function common_functions.pretty_item_name(item_name)
    -- Find colon
    local colon_index = string.find(item_name, ":")
    if colon_index == nil then
        return item_name -- This should not happen for minecraft items
    end

    local item_name_without_group = item_name:sub(colon_index + 1)
    local item_name_spaces = item_name_without_group:gsub("%_", " ")
    return item_name_spaces:gsub("^%l", string.upper)
end

return common_functions
