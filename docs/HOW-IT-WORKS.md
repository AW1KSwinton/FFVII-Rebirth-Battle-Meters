# Battle Meters — how it works

The design in reference form. For the story, see [HOW-WE-BUILT-IT.md](HOW-WE-BUILT-IT.md). To install and play, see
[GUIDE.md](GUIDE.md).

## Overview

It's a UE4SS Lua mod with no data pak, so it replaces no game files. It reads HP and MP from the game's battle APIs, works out rates,
and draws a UMG panel built at runtime. It writes nothing to the game.

| File | Job | Calls the game? |
| --- | --- | --- |
| `main.lua` | The loop: finds the battle, reads HP and MP, handles the key | Yes |
| `overlay.lua` | Builds and draws the panel | Yes |
| `meters.lua` | Totals, rates, the rolling window, the killing-blow rule | No |
| `meter_view.lua` | What the panel shows, including each character's colour | No |
| `settings.lua` | Remembers the chosen meter in `settings.txt` | No |
| `config.lua` | Settings | No |

The pure files have offline tests in `tests/`.

## The loop

UE4SS `LoopAsync` runs every 200 ms and hands work to the game thread with `ExecuteInGameThread`. Each of those calls allocates a Lua
thread that UE4SS never frees, so outside a fight it only goes to the game thread once a second.

Battle functions are called only after a save has loaded (a party character or vehicle pawn has been seen), because calling them from
the title screen has crashed this game. During a battle the controller has no pawn, so a missing pawn only counts as leaving play after
two minutes outside a battle.

`pcall(ExecuteInGameThread, function() end)` runs while the mod loads. Each mod's first call adds a callback to UE4SS's process-event
list, and doing that during play can move the list under a running callback.

## What it reads

| Value | From |
| --- | --- |
| In a battle | `EndBattleAPI:IsInBattle` |
| Enemies | `EndBattleAPI:GetEnemyMembersRef` |
| HP and max HP | `EndBattleAPI:GetCharaHP`, `GetHPMax` |
| Party | `EndPartyAPI:GetBattleMemberCount`, `GetBattleMember`, `GetBattleMemberType` |
| MP | `EndMenuBPAPI:BPGetPlayerMP` |
| Time | `GameplayStatics:GetTimeSeconds` |
| Paused | `GameplayStatics:IsGamePaused` |

A fall in an enemy's HP is damage. A fall in a party member's HP is damage taken, and a rise is healing. A fall in MP is MP spent. The
first reading of anyone is only a baseline.

Enemies are told apart by address, so no game object is held between ticks.

### Killing blows

An enemy can die and leave the list between two reads, taking its last HP with it.

- **It leaves during the fight:** its last known HP counts as damage.
- **All enemies are gone when the battle ends:** that could be a kill, giving up or a wipe. Its HP counts only if it was at half HP or
  less when last read.
- **Enemies still listed when the battle ends** are taken to be alive, so nothing is added.

### Battle boundaries

A battle starts when `IsInBattle` is true with at least one enemy listed. It must stay false for 2 seconds to count as over, so a moment
between waves doesn't end it. Meters reset at the start of the next battle.

## The panel

Plain UMG widgets built at runtime: `Image` with the game's `U_Status_Base_01` sprite, and `TextBlock` in Roboto. The game's own
`EndTextBlock` and `EndImage` draw nothing when created at runtime. All widgets are made once, and only those that changed are updated,
since each setter is a reflected call on the game thread.

It sits at (48, 240) in 1920x1080 units: below the objective list a Combat Assignment shows in the top left, and above the combat help.
A level change takes it off the screen without destroying it, so `IsInViewport` decides when to rebuild it.

## Training Dummy

Battle Meters checks each new enemy's territory. In `terVR_COL30_SUMMON_Gilgamesh_010_BtlTest_Hard`, the one Training Dummy's courses use,
it hides its panel for that battle and adds no killing blow.

## Why there's no Settings menu entry

The Gameplay rows live in `UEndMainOptionsMenu._OptionItems`, a `TMap`. This UE4SS build logs `Property type 'MapProperty' not supported`
and aborts the whole chunk, even inside `pcall`, so Lua can't read or change it. Changing the widget's asset needs tooling we don't have
for this game: `retoc` fails on its container headers. Each row is also tied to a native `EOptionCategory`.

## Why there's no breakdown by who dealt it

Nothing we could reach in Lua says who caused an HP change:

- `OnTakeDamageInvoke` carries the attacker, but only some enemy AI classes have it, and a hook on one registered and never fired while that
  enemy lost 830 HP.
- `EndBattleSceneBlueprint:OnTakeDamage` didn't fire either.
- `GetCurrentAbilityID` could only share a hit equally between characters acting at the same moment, which is a guess.

So damage has no split, and healing is split by who received it. Damage taken is split by who took it. Those are measured per character.

## What was tested

In the real game, on 2026-11-03, on a Level 17 save.

| Test | Result |
| --- | --- |
| Field fight, 2 Elphadunks of 1,179 HP | Damage total 2,358, exact, in several fights |
| Combat Assignment, 2 Venorats of 1,616 HP | Damage total 3,232, exact, in several fights |
| Stepping through all the meters mid-fight, past Off | Total still exact |
| The key, sent to the game and pressed by hand | Steps through the meters |
| Starting off, and remembering the choice | Works, and survives reinstalling |
| Riding a chocobo, then a fight | Measured. A two-minute ride no longer turns the mod off (the fix itself is only tested by the shorter rides) |
| Tutorial course in the simulator | Panel shows, numbers count |
| Training Dummy course | Only that mod's panel shows |
| Install and uninstall | Clean; Training Dummy untouched; game loads |
| MP spent | Counted, 38 in one fight |

## Limits

- **Reads every 200 ms.** Hits within the same read count as one for "Biggest hit". Totals aren't affected.
- **All HP changes count**, whatever caused them. Revives, potions, Regen ticks, HP Absorb, abilities that heal without MP and any refill from the game count as healing.
  Only HP actually gained is counted, so overhealing adds nothing. These follow from how the mod reads HP: Regen, HP Absorb and MP-free heals weren't tested one by one.
- **MP spent is all the party's MP,** on any spell. MP gained isn't subtracted. Healing per MP is all healing divided by all of that MP, so offensive spells lower it and
  MP-free healing raises it. It only shows true healing efficiency if healing is all the party spends MP on.
- **Changes within one read net out.** A character who takes 100 and gets 300 healing in the same 200 ms records 200 healing and no damage taken, so HPS and DTPS can both
  read slightly low in busy moments. MP nets out the same way.
- **Game time:** it stops when paused and runs slower when the game slows down. A 142 s fight showed as 85 s.
- **A fight's first second:** outside a fight the mod checks once a second, so up to a second of the start can be missed.
- **The last enemy:** one killed in one blow from above half HP doesn't have that blow counted. Running away is untested: enemies still
  listed are treated as alive, but if the list is empty, one at half HP or less would count.
- **Not tested:** boss fights, scenes during a fight, summons, guest characters, other mods. The colours of characters outside our party
  are set but haven't been seen in-game.
- **The panel can cover other UI:** it hides when paused, and it hasn't been checked against every screen.
