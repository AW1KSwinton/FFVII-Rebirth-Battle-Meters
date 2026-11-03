-- Which meter the key has switched to, kept in a small text file. Pure Lua: no game calls, so it can be tested outside
-- the game (see tests/settings_test.lua).
local M = {}

local NEXT = {dps = "hps", hps = "dtps", dtps = "off", off = "dps"}

function M.next(mode)
    return NEXT[mode] or "dps"
end

-- One line like "meter=hps". Anything else in the file is ignored.
function M.parse(text)
    local mode = tostring(text or ""):match("meter%s*=%s*(%w+)")
    if mode and NEXT[mode] then return mode end
    return "off"
end

function M.serialize(mode)
    return "meter=" .. mode .. "\n"
end

function M.load(path)
    local file = io.open(path, "r")
    if not file then return M.parse(nil) end
    local text = file:read("a")
    file:close()
    return M.parse(text)
end

function M.save(path, mode)
    local file = io.open(path, "w")
    if not file then return false end
    file:write(M.serialize(mode))
    file:close()
    return true
end

return M
