-- Plain Lua 5.4 checks for settings.lua (run with tests/run_tests.py).
local Settings = require("settings")

assert(Settings.next("off") == "dps")
assert(Settings.next("dps") == "hps")
assert(Settings.next("hps") == "dtps")
assert(Settings.next("dtps") == "off", "the last press turns it off")
assert(Settings.next("nonsense") == "dps")

assert(Settings.parse("meter=hps\n") == "hps")
assert(Settings.parse("meter = off") == "off")
assert(Settings.parse("meter=loud") == "off", "an unknown value means the default")
assert(Settings.parse("nonsense") == "off")
assert(Settings.parse(nil) == "off", "no file means off: the first press brings up DPS")
assert(Settings.parse(Settings.serialize("dtps")) == "dtps", "round trip")
