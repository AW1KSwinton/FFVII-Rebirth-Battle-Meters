-- Plain Lua 5.4 checks for meter_view.lua (run with tests/run_tests.py).
local View = require("meter_view")

local config = {rolling_window_seconds = 5}
local function kind(average, recent, total, biggest, by_source)
    return {average = average, recent = recent, total = total, biggest = biggest, by_source = by_source or {}}
end
local snapshot = {elapsed = 67.4, kinds = {
    damage = kind(4210.4, 3988, 1000, 9999, {Tifa = 250, Cloud = 750}),
    taken = kind(312, 287, 20904, 1290, {Tifa = 6404, Cloud = 14500}),
    heal = kind(40, 20, 2700, 900, {Aerith = 2700}),
    mp = kind(0, 0, 45, 9),
}}

assert(View.format_number(0) == "0")
assert(View.format_number(1000) == "1,000")
assert(View.format_number(1234567.6) == "1,234,568")
assert(View.format_number(nil) == "0")
assert(View.format_time(67.4) == "1:07")
assert(View.format_time(600) == "10:00")

assert(View.build(snapshot, "off", config) == nil, "off draws nothing")

local dps = View.build(snapshot, "dps", config)
assert(dps.title == "DPS" and dps.value == "4,210")
assert(dps.stats[1][1] == "Last 5 seconds" and dps.stats[1][2] == "3,988")
assert(dps.stats[2][1] == "Total" and dps.stats[2][2] == "1,000")
assert(dps.stats[3][1] == "Biggest hit" and dps.stats[3][2] == "9,999")
assert(dps.stats[4][1] == "Time" and dps.stats[4][2] == "1:07")
assert(#dps.stats == 4, "only HPS tracks MP")

-- Damage dealt has no line: HP loss on an enemy doesn't say who caused it.
assert(dps.show_line == false and #dps.segments == 0)

local hps = View.build(snapshot, "hps", config)
assert(hps.title == "HPS" and hps.stats[3][1] == "Biggest heal")
assert(hps.stats[4][1] == "MP spent" and hps.stats[4][2] == "45")
assert(hps.stats[5][1] == "Healing per MP" and hps.stats[5][2] == "60")
assert(#hps.segments == 1 and hps.segments[1].share == 1)

local dtps = View.build(snapshot, "dtps", config)
assert(dtps.title == "DTPS" and dtps.stats[3][1] == "Biggest hit taken")
-- The line keeps party order, whoever leads, and its sections add up to the whole.
local taken = dtps.segments
assert(dtps.show_line and #taken == 2 and taken[1].name == "Cloud" and taken[2].name == "Tifa")
assert(math.abs(taken[1].share + taken[2].share - 1) < 1e-9)
assert(taken[1].color.R == 1 and taken[1].color.B < 0.5 and taken[2].color.R == 0 and taken[2].color.B == 0, "yellow, then black")

-- Nothing yet: no sections, and no dividing by zero MP.
local empty = {elapsed = 0, kinds = {damage = kind(0, 0, 0, 0), taken = kind(0, 0, 0, 0), heal = kind(0, 0, 0, 0), mp = kind(0, 0, 0, 0)}}
local none = View.build(empty, "hps", config)
assert(#none.segments == 0 and none.value == "0" and none.stats[5][2] == "-")

-- A guest character outside the list still gets a section.
local guest = {elapsed = 1, kinds = {damage = kind(0, 0, 0, 0), heal = kind(0, 0, 0, 0), taken = kind(1, 1, 10, 1, {Stranger = 4, Cloud = 6})}}
local line = View.build(guest, "dtps", config).segments
assert(#line == 2 and line[1].name == "Cloud" and line[2].name == "Stranger" and line[2].share == 0.4)
