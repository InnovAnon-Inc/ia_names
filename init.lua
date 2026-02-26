assert(futil ~= nil)

ia_names = {}

local storage = minetest.get_mod_storage()
local reserved = minetest.deserialize(storage:get_string("reserved")) or {}

local function save()
    storage:set_string("reserved", minetest.serialize(reserved))
end

-- Check if a name is truly available (Database, Online, and Registry)
function ia_names.is_available(name)
    if reserved[name] then return false end
    if minetest.get_player_by_name(name) then return false end
    if minetest.player_exists(name) then return false end
    return true
end

-- Claim a name for an entity
function ia_names.reserve(name)
    if not ia_names.is_available(name) then
        return false
    end
    reserved[name] = true
    save()
    return true
end

-- Free a name
function ia_names.release(name)
    reserved[name] = nil
    save()
    futil.log("action", "Released ID: %s", name)
end

-- Block real players from joining with reserved names
minetest.register_on_prejoinplayer(function(name)
    if reserved[name] then
        return "This ID is reserved for system entities."
    end
end)

futil.log("action", "Naming Authority initialized.")
