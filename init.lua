-- ia_names/init.lua
--
--assert(futil ~= nil)
--
--ia_names = {}
--
--local storage = minetest.get_mod_storage()
--local reserved = minetest.deserialize(storage:get_string("reserved")) or {}
--
--local function save()
--    storage:set_string("reserved", minetest.serialize(reserved))
--end
--
---- Check if a name is truly available (Database, Online, and Registry)
--function ia_names.is_available(name)
--    if reserved[name] then return false end
--    if minetest.get_player_by_name(name) then return false end
--    if minetest.player_exists(name) then return false end
--    return true
--end
--
---- Claim a name for an entity
--function ia_names.reserve(name)
--    if not ia_names.is_available(name) then
--        return false
--    end
--    reserved[name] = true
--    save()
--    return true
--end
--
---- Free a name
--function ia_names.release(name)
--    reserved[name] = nil
--    save()
--    futil.log("action", "Released ID: %s", name)
--end
--
---- Block real players from joining with reserved names
--minetest.register_on_prejoinplayer(function(name)
--    if reserved[name] then
--        return "This ID is reserved for system entities."
--    end
--    -- TODO reserve name ?
--end)
--
--futil.log("action", "Naming Authority initialized.")
--
---- TODO need a counterpart to get_connected_players that will get the "connected" mobs
---- TODO need a counter part that gets connected players & mobs
----get_connected_players = core.get_connected_players
-- ia_names/init.lua

assert(futil ~= nil)

ia_names = {}

local storage = minetest.get_mod_storage()
local reserved = minetest.deserialize(storage:get_string("reserved")) or {}
-- Volatile table to store references to active mob entities
local active_mobs = {} 

local function save()
    storage:set_string("reserved", minetest.serialize(reserved))
end

--- Check if a name is truly available (Database, Online, and Registry)
function ia_names.is_available(name)
    if reserved[name] then return false end
    if minetest.get_player_by_name(name) then return false end
    if minetest.player_exists(name) then return false end
    return true
end

--- Claim a name for an entity
function ia_names.reserve(name)
    if not ia_names.is_available(name) then
        return false
    end
    reserved[name] = true
    save()
    return true
end

--- Free a name
function ia_names.release(name)
    reserved[name] = nil
    active_mobs[name] = nil
    save()
    futil.log("action", "Released ID: %s", name)
end

--- Register a mob as "online"
-- @param name The unique name of the mob
-- @param object The LuaEntitySAO reference
function ia_names.register_active_mob(name, object)
    assert(name, "register_active_mob: name is nil")
    assert(object, "register_active_mob: object is nil")
    active_mobs[name] = object
end

--- Remove a mob from the "online" list
function ia_names.unregister_active_mob(name)
    active_mobs[name] = nil
end

--- Returns a table of all "connected" mob entities
function ia_names.get_connected_mobs()
    local mobs = {}
    for _, obj in pairs(active_mobs) do
        -- Double check the object is still valid
        if obj:get_pos() then
            table.insert(mobs, obj)
        end
    end
    return mobs
end

--- Returns a table containing both players and active mobs
function ia_names.get_all_actors()
    local actors = minetest.get_connected_players()
    local mobs = ia_names.get_connected_mobs()
    for _, mob in ipairs(mobs) do
        table.insert(actors, mob)
    end
    return actors
end

--- Find any actor (Player or Mob) by name
function ia_names.get_actor_by_name(name)
    local player = minetest.get_player_by_name(name)
    if player then return player end
    return active_mobs[name]
end

-- Block real players from joining with reserved names
minetest.register_on_prejoinplayer(function(name)
    if reserved[name] then
        return "This ID is reserved for system entities."
    end
end)

futil.log("action", "Naming Authority initialized.")
