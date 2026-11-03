-- Battle Meters: DPS, HPS or DTPS on screen in every battle. It only reads HP and MP and draws a panel; it changes
-- nothing in the game.
--
-- Rules learned on this game (see docs/HOW-IT-WORKS.md): only call functions that exist in the UE4SS header dump,
-- never ask an object for a member it lacks (it leaks the Lua C stack even inside pcall), and keep no battle object
-- across ticks.
local config = require("config")
local Meters = require("meters")
local Settings = require("settings")
local meter_view = require("meter_view")
local overlay_ok, overlay = pcall(require, "overlay")

local TAG = "[BattleMeters] "
local MAX_ENEMIES, MAX_PARTY = 32, 8
local BATTLE_API = "/Script/EndGame.Default__EndBattleAPI"
local PARTY_API = "/Script/EndGame.Default__EndPartyAPI"
local MENU_API = "/Script/EndGame.Default__EndMenuBPAPI"
local STATICS = "/Script/Engine.Default__GameplayStatics"
local ENEMY_AI_CLASS = "/Script/EndGame.EndAIControllerEnemyBase"
-- The Training Dummy mod's courses share this territory and draw their own panel.
local TRAINING_TERRITORY = "terVR_COL30_SUMMON_Gilgamesh_010_BtlTest_Hard"

-- This mod's folder: UE4SS puts each mod's Scripts folder on package.path, and may spell the folder "scripts".
local MOD_DIR = package.path:match("([^;]*[\\/]BattleMeters[\\/])[Ss]cripts[\\/]%?%.lua")
    or (debug.getinfo(1, "S").source:match("^@(.*[\\/])[Ss]cripts[\\/]")) or ""
local SETTINGS_PATH = MOD_DIR .. "settings.txt"

local meters = Meters.new(config.rolling_window_seconds)
local mode = Settings.load(SETTINGS_PATH)
local state = {active = false, stand_aside = false, enemies = {}, party = {}, logged = {}, last_json = 0, view = nil}

local function log(message) print(TAG .. message .. "\n") end
local function log_once(key, message)
    if state.logged[key] then return end
    state.logged[key] = true
    log(message)
end
local last_trace = {}
local function trace(key, message)
    if not config.debug or last_trace[key] == message then return end
    last_trace[key] = message
    log("debug " .. key .. ": " .. message)
end

local function safe(f, ...)
    local ok, value = pcall(f, ...)
    if ok then return value end
    return nil
end
local function valid(object)
    return object ~= nil and safe(function() return object:IsValid() end) == true
end
local function cdo(path)
    local object = safe(StaticFindObject, path)
    if valid(object) then return object end
    return nil
end
local function name_of(object)
    local name = safe(function() return object:GetFName():ToString() end)
    return type(name) == "string" and name or "?"
end
local function number(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

-- GetEnemyMembersRef fills an out array; UE4SS hands it back either as the out table, a table holding one TArray, or
-- a TArray (seen on this game).
local function enemy_list(battle)
    local out = {}
    local returned = safe(function() return battle:GetEnemyMembersRef(out) end)
    local value = returned ~= nil and returned or out
    local list = {}
    local function add(item)
        local actor = item
        if type(item) == "userdata" then
            local kind = safe(function() return item:type() end)
            if kind == "RemoteUnrealParam" or kind == "LocalUnrealParam" then actor = safe(function() return item:get() end) end
        end
        if valid(actor) and #list < MAX_ENEMIES then list[#list + 1] = actor end
    end
    local function walk(array)
        safe(function() array:ForEach(function(_, element) add(element) end) end)
    end
    if type(value) == "table" then
        if #value == 1 and type(value[1]) == "userdata" and safe(function() return value[1]:type() end) == "TArray" then
            walk(value[1])
        else
            for _, item in ipairs(value) do add(item) end
        end
    elseif type(value) == "userdata" and safe(function() return value:type() end) == "TArray" then
        walk(value)
    end
    return list
end

-- Battle members with their EPlayerType, read by slot (GetPlayerType(actor) fails on this game).
local function party_members(party)
    local count = number(safe(function() return party:GetBattleMemberCount() end)) or 0
    local list = {}
    for i = 0, math.min(count, MAX_PARTY) - 1 do
        local member = safe(function() return party:GetBattleMember(i) end)
        local kind = number(safe(function() return party:GetBattleMemberType(i) end))
        if valid(member) then list[#list + 1] = {actor = member, kind = kind} end
    end
    return list
end

-- The class is checked before the call because naming a function an object lacks breaks the Lua state.
local function in_training_territory(actor)
    local controller = safe(function() return actor:GetController() end)
    local enemy_ai = cdo(ENEMY_AI_CLASS)
    if not (valid(controller) and enemy_ai and safe(function() return controller:IsA(enemy_ai) end) == true) then return false end
    return safe(function() return controller:GetOwnerTerritoryIdBP():ToString() end) == TRAINING_TERRITORY
end

-- The controlled pawn once a save is loaded: a party character (PC0000 Cloud, PC0001 Barret...), or the chocobo or other
-- vehicle they ride (VE0009...). Battle functions are not called before this; calling them from the title screen has
-- crashed the game.
local engine, controller = nil, nil
local function gameplay_pawn()
    local pawn
    if not valid(engine) then engine = safe(FindFirstOf, "GameEngine") end
    local viewport = valid(engine) and safe(function() return engine.GameViewport end)
    local statics = cdo(STATICS)
    if valid(viewport) and statics then pawn = safe(function() return statics:GetPlayerPawn(viewport, 0) end) end
    if not valid(pawn) then
        -- Looked up again only when the kept one is gone (FindFirstOf walks every object).
        if not valid(controller) then controller = safe(FindFirstOf, "EndPlayerControllerBP_C") end
        pawn = valid(controller) and safe(function() return controller.Pawn end) or nil
    end
    if not valid(pawn) then return nil end
    local class = safe(function() return pawn:GetClass():GetFName():ToString() end) or ""
    if class:match("^PC%d%d%d%d_") or class:match("^VE%d%d%d%d_") then return pawn end
    return nil
end

local function hp(battle, actor)
    return number(safe(function() return battle:GetCharaHP(actor) end)),
        number(safe(function() return battle:GetHPMax(actor) end))
end

-- Game time stops while the game is paused, so menus don't dilute the meters.
local function now_seconds(world_object)
    local statics = cdo(STATICS)
    return number(statics and safe(function() return statics:GetTimeSeconds(world_object) end)) or os.time()
end

local function hide_panel()
    state.linger_until = nil
    if overlay_ok and overlay then safe(overlay.hide) end
end

local function begin_battle(count)
    meters:reset()
    state.active, state.stand_aside, state.enemies, state.party = true, false, {}, {}
    state.over_since, state.linger_until, state.mp = nil, nil, {}
    log(string.format("battle started: %d enemies", count))
end

local function end_battle()
    local snapshot = state.last_snapshot
    log(string.format("battle ended: damage %d, healing %d, taken %d, mp %d, %.1f s",
        snapshot and snapshot.kinds.damage.total or 0, snapshot and snapshot.kinds.heal.total or 0,
        snapshot and snapshot.kinds.taken.total or 0, snapshot and snapshot.kinds.mp.total or 0, snapshot and snapshot.elapsed or 0))
    state.active, state.over_since = false, nil
    state.enemies, state.party = {}, {}
    if state.stand_aside then
        state.stand_aside = false
    elseif mode ~= "off" and state.view then
        state.linger_until = os.time() + config.linger_seconds
    end
end

-- Enemies are told apart by address, so nothing from the game is held between ticks. An enemy can die and leave the list
-- between two reads, taking its last HP with it: that HP was the killing blow, so it counts when the enemy goes.
local function track_enemies(battle, list, now, battle_over)
    local present = {}
    for _, enemy in ipairs(list) do
        local key = safe(function() return enemy:GetAddress() end) or name_of(enemy)
        present[key] = true
        local cur, max = hp(battle, enemy)
        local known = state.enemies[key]
        if not known then
            state.enemies[key] = {hp = cur, max = max}
            if in_training_territory(enemy) then
                if not state.stand_aside then log("Training Dummy course: leaving the panel to that mod") end
                state.stand_aside = true
            end
        elseif cur then
            if known.hp and cur < known.hp then meters:add("damage", known.hp - cur, now) end
            known.hp = cur
        end
    end
    for key, known in pairs(state.enemies) do
        if not present[key] then
            meters:add("damage", Meters.killing_blow(known.hp, known.max, battle_over), now)
            state.enemies[key] = nil
        end
    end
end

-- EPlayerType order (EndDataBase).
local PLAYER_NAMES = {[0] = "Cloud", "Barret", "Tifa", "Aerith", "Red XIII", "Yuffie", "Cait Sith", "Zack",
    "Sephiroth", "Vincent", "Cid"}

local function track_party(battle, party, now)
    local menu = cdo(MENU_API)
    local seen = {}
    for _, entry in ipairs(party_members(party)) do
        local id = PLAYER_NAMES[entry.kind] or name_of(entry.actor)
        seen[id] = true
        local cur = hp(battle, entry.actor)
        if cur then
            local known = state.party[id]
            if known then
                if cur < known then meters:add("taken", known - cur, now, id)
                elseif cur > known then meters:add("heal", cur - known, now, id) end
            end
            state.party[id] = cur
        end
        local mp = menu and entry.kind and number(safe(function() return menu:BPGetPlayerMP(entry.kind) end))
        if mp then
            if state.mp[id] and mp < state.mp[id] then meters:add("mp", state.mp[id] - mp, now, id) end
            state.mp[id] = mp
        end
    end
    for id in pairs(state.party) do if not seen[id] then state.party[id] = nil end end
end

local function json_number(v) return string.format("%.3f", v or 0) end
local function write_json(snapshot)
    local parts = {}
    for kind, k in pairs(snapshot.kinds) do
        parts[#parts + 1] = string.format('"%s":{"average":%s,"recent":%s,"total":%s,"biggest":%s}', kind,
            json_number(k.average), json_number(k.recent), json_number(k.total), json_number(k.biggest))
    end
    local body = string.format('{"elapsed":%s,"time":%d,"meters":{%s}}', json_number(snapshot.elapsed), os.time(), table.concat(parts, ","))
    local path = MOD_DIR .. "meters.json"
    local f = io.open(path .. ".tmp", "wb")
    if not f then return end
    f:write(body); f:close()
    os.remove(path)
    os.rename(path .. ".tmp", path)
end

-- Every enemy has gone: count what they had left and bring the numbers up to date.
local function settle_enemies(battle)
    if not state.last_now or state.stand_aside then return end
    track_enemies(battle, {}, state.last_now, true)
    state.last_snapshot = meters:snapshot(state.last_now)
    state.view = meter_view.build(state.last_snapshot, mode, config)
    if config.write_json then safe(write_json, state.last_snapshot) end
end

local function draw(world_object)
    if not (overlay_ok and overlay) then return end
    local statics = cdo(STATICS)
    -- The menus and tips that pause a battle draw where the panel sits.
    local paused = statics and safe(function() return statics:IsGamePaused(world_object) end) == true
    if paused or not state.view then
        safe(overlay.hide)
    else
        safe(overlay.show, state.view, config, world_object)
    end
end

-- Key presses only leave a note here: they arrive off the game thread.
local function apply_key_presses()
    if not state.settings_changed then return end
    state.settings_changed = false
    Settings.save(SETTINGS_PATH, mode)
    log("meter: " .. mode)
    if mode == "off" then
        -- A fight already under way keeps counting, so stepping past off doesn't lose its numbers.
        state.view = nil
        hide_panel()
    else
        -- Outside a battle the panel shows briefly, so the key visibly did something.
        local snapshot = state.last_snapshot or meters:snapshot(0)
        state.view = meter_view.build(snapshot, mode, config)
        if not state.active then state.linger_until = os.time() + config.linger_seconds end
    end
end

-- Battle functions are called only once a save has been loaded ("armed"): calling them from boot and the title screen
-- crashed the game. In battle the controller possesses no pawn, so a missing pawn disarms only after DISARM_SECONDS
-- outside battle (the title screen, a long scene).
local DISARM_SECONDS = 120
local function tick()
    apply_key_presses()
    local pawn = gameplay_pawn()
    if pawn then
        state.armed, state.pawnless_since = true, nil
    elseif not state.armed then
        return
    end
    local battle = cdo(BATTLE_API)
    if not battle then trace("battle_api", "missing"); return end
    local in_battle = safe(function() return battle:IsInBattle() end)
    trace("in_battle", tostring(in_battle))
    if in_battle ~= true then
        if state.active then
            -- The last enemy's killing blow: enemies still listed here are alive, so the party ran from them.
            if not state.over_since and #enemy_list(battle) == 0 then settle_enemies(battle) end
            state.over_since = state.over_since or os.time()
            if os.time() - state.over_since >= config.battle_end_grace_seconds then end_battle() end
        end
        if state.linger_until then
            if os.time() >= state.linger_until then hide_panel() elseif pawn then draw(pawn) end
        end
        if not pawn then
            state.pawnless_since = state.pawnless_since or os.time()
            if os.time() - state.pawnless_since >= DISARM_SECONDS then state.armed, state.pawnless_since = false, nil end
        end
        return
    end
    state.pawnless_since, state.over_since = nil, nil
    -- Switched off, a new fight isn't measured at all.
    if mode == "off" and not state.active then return end
    local list = enemy_list(battle)
    if #list == 0 then
        if state.active then settle_enemies(battle) end
        return
    end
    if not state.active then begin_battle(#list) end
    local now = now_seconds(list[1])
    state.last_now = now
    track_enemies(battle, list, now)
    if state.stand_aside then
        hide_panel()
        return
    end
    local party = cdo(PARTY_API)
    if party then track_party(battle, party, now) end
    local snapshot = meters:snapshot(now)
    state.last_snapshot = snapshot
    state.view = meter_view.build(snapshot, mode, config)
    draw(list[1])
    if config.write_json and now - state.last_json >= 0.5 then
        state.last_json = now
        safe(write_json, snapshot)
    end
end

RegisterKeyBind(Key[config.cycle_key], {ModifierKey.CONTROL, ModifierKey.SHIFT}, function()
    mode = Settings.next(mode)
    state.settings_changed = true
end)

-- Register this mod's game-thread callback now, while mods load. UE4SS adds it to the process-event callback list
-- on a mod's first ExecuteInGameThread; doing that during play can move the list under a running callback and crash.
pcall(ExecuteInGameThread, function() end)

-- Each ExecuteInGameThread allocates a Lua thread that UE4SS never forgets, so tick at full rate only in a battle.
local IDLE_EVERY = math.max(1, math.floor(1000 / config.tick_ms))
local idle = 0
LoopAsync(config.tick_ms, function()
    idle = idle + 1
    if state.active or state.settings_changed or idle >= IDLE_EVERY then
        idle = 0
        ExecuteInGameThread(function()
            local ok, err = pcall(tick)
            if not ok then log_once("tick:" .. tostring(err), "tick error: " .. tostring(err)) end
        end)
    end
    return false
end)

if not overlay_ok then log("overlay disabled: " .. tostring(overlay)) end
log("loaded")
