# Battle Meters — FF7 Rebirth combat meters

A small panel showing how your fight is going, in any battle. Press **Ctrl+Shift+D** to step through:

| Press | Shows |
| --- | --- |
| 1st | **DPS**: damage per second |
| 2nd | **HPS**: healing per second, MP spent and healing per MP |
| 3rd | **DTPS**: damage taken per second |
| 4th | Off |

HPS and DTPS also have a coloured line, split by party member: who received the healing, and who took the damage. Each battle
starts from zero. The last numbers stay on screen for 8 seconds afterwards.

It only reads the game and draws a panel. It doesn't change damage, HP, MP or anything else, and it doesn't touch your saves.

This mod was built, tested and played by an AI (Claude Opus 5.5 in Claude Code), with a human setting the direction. It's part
of a bigger goal: teaching an agent to play the game, so that mods can be researched, built and tested end to end.

- How to install and use it: [docs/GUIDE.md](docs/GUIDE.md).
- How we built it, step by step: [docs/HOW-WE-BUILT-IT.md](docs/HOW-WE-BUILT-IT.md).
- The design in reference form, what was tested and the limits: [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md).

## Install

Needs UE4SS v3 for FF7 Rebirth.

1. Copy the `BattleMeters` folder into `End/Binaries/Win64/ue4ss/Mods/`.
2. Add `BattleMeters : 1` to `mods.txt` in that folder, above the `Keybinds` line.

Or, from this repository: `tools/Install-BattleMeters.ps1 -Mode Install -GameRoot "<your game folder>"`. `-Mode Uninstall` and
`-Mode Status` also exist.

It starts switched off, so nothing shows until you press the key.

It works alongside [Training Dummy](https://github.com/AW1KSwinton/FFVII-Rebirth-Training-Dummy): on that mod's courses, only
its panel shows.

## Tests

`python -m pip install lupa`, then `python tests/run_tests.py`.

## Credits

- UE4SS, FModel and the OpenFF7R community
- The panel comes from our Training Dummy mod and uses the game's own HUD art, loaded from your copy of the game

This repository contains no game files.

## Licence

MIT (see `LICENSE`).
