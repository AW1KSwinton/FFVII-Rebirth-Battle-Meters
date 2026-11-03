# Battle Meters — player guide

See your damage, healing and damage taken per second in any battle, in a small panel on the left of the screen. It changes nothing
in the game: it only reads HP and MP, and draws the panel.

## What you need

- FINAL FANTASY VII REBIRTH (PC).
- [UE4SS v3](https://github.com/UE4SS-RE/RE-UE4SS) set up for FF7 Rebirth.

## Install

The game folder below is the one that holds `End/`, for example
`C:\Program Files (x86)\Steam\steamapps\common\FINAL FANTASY VII REBIRTH`.

1. Copy the `BattleMeters` folder into `End\Binaries\Win64\ue4ss\Mods\`.
2. Open `End\Binaries\Win64\ue4ss\Mods\mods.txt` and add this line above the `Keybinds` line:

   ```text
   BattleMeters : 1
   ```

3. Start the game.

## Use it

Press **Ctrl+Shift+D** to step through the meters. It starts switched off.

| Press | Panel |
| --- | --- |
| 1st | DPS |
| 2nd | HPS |
| 3rd | DTPS |
| 4th | Off |

The mod remembers your choice next time. Outside a battle, the panel shows for a few seconds after you press the key, so you can
see what you picked.

Each battle starts from zero. When it ends, the last numbers stay on screen for 8 seconds. Stepping through the meters during a
fight doesn't lose its numbers, even past Off. If the meter is already off when a fight starts, that fight isn't measured until you
turn it on.

The panel hides while the game is paused.

## What the numbers mean

| Line | Meaning |
| --- | --- |
| The big number | The average per second, since the first number was counted in this fight |
| Last 5 seconds | The rate over the last five seconds |
| Total | Everything counted in this fight |
| Biggest hit / heal | The biggest single change seen (see the limits below) |
| MP spent (HPS) | MP used by the party in this fight |
| Healing per MP (HPS) | Total healing divided by MP spent |
| Time | How long since the first number was counted, in game time |

### The coloured line

On HPS and DTPS, a line shows each party member's share of the total: who **received** the healing, and who **took** the damage.
The bigger the section, the bigger their share.

| Character | Colour |
| --- | --- |
| Cloud | Yellow |
| Barret | Green |
| Tifa | Black |
| Aerith | Pink |
| Red XIII | Red |
| Yuffie | Blue |
| Cait Sith | White |
| Zack | Cyan |
| Sephiroth | Purple |
| Vincent | Dark red |
| Cid | Orange |

DPS has no line. The game doesn't tell a mod who dealt a hit, and we'd rather show nothing than a guess. HPS shows who received
healing, not who cast it, for the same reason.

## Settings

Edit `BattleMeters\Scripts\config.lua`, then restart the game:

| Setting | Default | What it does |
| --- | --- | --- |
| `overlay_x`, `overlay_y` | 48, 240 | Where the panel sits, in 1920x1080 units from the top left |
| `cycle_key` | `D` | The key pressed with Ctrl+Shift |
| `linger_seconds` | 8 | How long the last numbers stay after a battle |
| `rolling_window_seconds` | 5 | The window for the "Last 5 seconds" line |
| `write_json` | `true` | Also writes `meters.json` next to the mod, useful for stream overlays |

## Known limits

- **Numbers are read five times a second.** Two hits landing in the same fifth of a second count as one for "Biggest hit". Totals
  aren't affected.
- **Everything an enemy loses counts as your damage**, whatever caused it, and any party member's HP rising counts as healing,
  including potions, revives, Regen ticks, HP Absorb, abilities that heal without MP and any refill the game gives you. Only HP actually
  gained counts, so overhealing adds nothing.
- **MP spent is every MP the party spends,** on any spell, not just on healing. Healing per MP divides all healing by all of that MP, so
  casting Fire lowers it, and healing that costs no MP raises it. It only shows true healing efficiency if healing is all you spend MP on.
- **Changes in the same reading cancel out.** If someone takes 100 damage and gets 300 healing within the same fifth of a second, that
  shows as 200 healing and no damage taken, so HPS and DTPS can both read slightly low in busy moments. MP works the same way.
- **Time is game time.** It stops while paused and runs slower while the game slows down, so a meter's time can be well below the
  real time. In one of our fights, 142 real seconds showed as 85.
- **The last enemy's final hit:** the battle can end before its last HP is read. That HP is added if the enemy was at half HP or less
  when last read, so giving up or wiping doesn't count an enemy's remaining HP as damage. A last enemy killed in one blow from above
  half HP won't have that blow counted.
- **Boss fights haven't been tested.** We tested field fights, a Combat Assignment and the simulator. Scenes in the middle of a boss
  fight may show the panel, and a boss's scripted HP changes may count as damage.

## Other mods

- **Training Dummy:** works alongside it. On its courses, only its panel shows.
- It replaces no game files, so it shouldn't conflict with other mods. We haven't tested it with mods other than Training Dummy.

## Troubleshooting

- **Nothing shows:** it starts off, so press Ctrl+Shift+D. Then check that `BattleMeters : 1` is in `mods.txt`, and look for
  `[BattleMeters] loaded` in `ue4ss\UE4SS.log`.
- **The key does nothing:** the game window needs focus. Pressing the three keys together can briefly make Cloud move, since D is also
  a movement key.

## Uninstall

Delete `End\Binaries\Win64\ue4ss\Mods\BattleMeters` and remove its line from `mods.txt`. Your saves aren't touched.
