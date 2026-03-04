-- ia_names/init.lua

assert(minetest.get_modpath('ia_util'))
assert(ia_util ~= nil)
local modname                    = minetest.get_current_modname() or "ia_names"
local storage                    = minetest.get_mod_storage()
ia_names                         = {}
local modpath, S                 = ia_util.loadmod(modname)
local log                        = ia_util.get_logger(modname)
local assert                     = ia_util.get_assert(modname)

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
            --table.insert(mobs, obj)
            local player = fakelib.get_player_interface(obj)
            table.insert(mobs, player)
        end
    end
    return mobs
end

--- Returns a table containing both players and active mobs
function ia_names.get_all_actors() -- minetest.get_connected_player()
    local actors = minetest.get_connected_players()
    local mobs = ia_names.get_connected_mobs()
    for _, mob in ipairs(mobs) do
        table.insert(actors, mob)
    end
    return actors
end

--- Find any actor (Player or Mob) by name
function ia_names.get_actor_by_name(name) -- minetest.get_player_by_name()
    local player = minetest.get_player_by_name(name)
    if player then return player end
    --return active_mobs[name]
    local obj    = active_mobs[name]
    return fakelib.get_player_interface(obj)
end

-- ia_names/init.lua

--- Internal helper to check if an actor is a real engine player.
-- This is necessary because both real and fake players return true for :is_player().
-- Real players are userdata (ObjectRef), while bridged mobs are tables (luaentity).
function ia_names.is_engine_player(actor)
	return type(actor) == "userdata"
end

--- Returns the default privilege set for non-engine actors (mobs/fake players).
-- Centralizing this makes it easier to modify mob capabilities globally.
function ia_names.get_mob_default_privs()
	return {
		interact = true,
		shout = true,
		fly = false,
	}
end

--- ia_names counterpart to core.check_player_privs
-- Handles both real engine players and bridged entities/mobs.
-- @param name_or_actor String (name) or ObjectRef/Table (the actor)
-- @param privs Table of privileges to check {priv_name = true}
-- @return boolean (has all), table (missing privileges)
function ia_names.check_actor_privs(name_or_actor, privs)
	assert(privs ~= nil, "ia_names.check_actor_privs: privs table is nil")

	local actor
	local name

	-- 1. Resolve Actor and Name
	if type(name_or_actor) == "string" then
		name = name_or_actor
		actor = ia_names.get_actor_by_name(name)
	else
		actor = name_or_actor
		-- Ensure we have a valid actor before calling methods
		if actor and actor.get_player_name then
			name = actor:get_player_name()
		end
	end

	-- Validation: If no actor is found, they have no privileges.
	if not actor or not name or name == "" then
		return false, privs
	end

	-- 2. Route Check based on Actor Type
	if ia_names.is_engine_player(actor) then
		-- Use standard engine privilege database for real players
		return minetest.check_player_privs(name, privs)
	else
		-- 3. Logic for Fake Players / Bridged Mobs
		-- These actors use a predefined set of virtual privileges.
		local actor_privs = ia_names.get_mob_default_privs()
		local missing = {}
		local has_all = true

		for priv, _ in pairs(privs) do
			if not actor_privs[priv] then
				has_all = false
				table.insert(missing, priv)
			end
		end

		-- Log if a system entity is missing a privilege (useful for debugging mob behavior)
		if not has_all then
			minetest.log("info", string.format("[ia_names] Actor '%s' missing privs: %s",
				name, table.concat(missing, ", ")))
		end

		return has_all, missing
	end
end

-- Block real players from joining with reserved names
minetest.register_on_prejoinplayer(function(name)
    if reserved[name] then
        return "This ID is reserved for system entities."
    end
end)

futil.log("action", "Naming Authority initialized.")
