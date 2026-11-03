# How we built Battle Meters

This is the story of the build, dead ends included. For the finished design in reference form, see [HOW-IT-WORKS.md](HOW-IT-WORKS.md). To
install and play, see [GUIDE.md](GUIDE.md).

## Why

Nobody is holding a controller here. This is Battle Meters, a mod for Final Fantasy VII Rebirth, and an AI made it. Claude Opus 5.5, in Claude Code,
researched the game's code, built the mod, played the game to test it, and recorded the footage you've just watched. A human gave the brief, made the design calls
and caught problems the AI had missed.

We're doing two things at once here. One is making mods. The other, and the really interesting part, is teaching an AI agent to play the game by itself, so
that a mod can go from an idea to a tested release through one automated pipeline. It isn't fully there yet, and this story shows where it still needs a person.
Every problem the owner caught is one the pipeline can learn from.

The request was short: damage, healing and tanking meters in every battle, using the panel from our Training Dummy mod, without any of that
mod's gameplay changes.

## Tools

| Tool | Used for |
| --- | --- |
| [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) v3 | Running Lua inside the game |
| Our test harness | Letting the AI drive the game: walking, riding, fighting, reading the screen |
| OBS | Recording the fights |
| Python and Lua | Offline tests |

## Step 1: try the Settings menu first

The ideal was a switch in the game's own Gameplay settings. The rows on that screen live in a table inside the menu. The modding tool we use
can't read that kind of table at all: it logs an error and abandons the script, even when told to ignore errors. Changing the menu's game asset
instead would mean custom tooling on a screen every player depends on, and the tool for it couldn't parse this game's containers.

The request had already named a fallback, a key press, so that's what we used. Ctrl+Shift+D it is.

## Step 2: reuse the panel, and change the design

The first version brought over the Training Dummy panel with all three meters at once. Watching it in a fight, the owner said it took up too
much of the screen. So the design changed: one small panel, with the key stepping from damage, to healing, to damage taken, to off.

The owner also asked for a single coloured line in place of a list of names, with each character's section as wide as their share.

## Step 3: who did the damage?

The colour line was meant for damage too, showing how much each party member dealt. The game clearly knows, because its own events carry
the attacker. So the AI went looking for a way to read that, and hooked the event on a real enemy during a real fight. The hook registered.
Then it never fired, while that enemy lost 830 HP.

The fallback was to credit whoever was using an ability at that moment. But when two characters act at once, that only splits a hit evenly, and that
would be a guess presented as a measurement. The owner's rule was simple: if it can't be reliably accurate, scrap it. So damage has no line.
Damage taken and healing received are measured character by character, so those keep theirs.

## Step 4: the numbers had to be exact

A meter is only worth anything if it's right, and field fights give you a way to check it. Two Elphadunks with 1,179 HP each should add up to
2,358 damage.

They didn't. The first totals came up short, because an enemy can die and vanish before its last HP is read. So when an enemy leaves, its last HP
now counts as the killing blow.

That caused the opposite problem. Abandoning a Training Dummy fight logged a million damage. If the whole battle ends, the enemy might have died, or
you might have given up, so now that last HP only counts if the enemy was already at half health or less.

After that, the totals were exact, fight after fight: 2,358 for the Elphadunks, and 3,232 for a pair of Venorats, even when stepping through all the
meters in the middle of a fight.

## Step 5: getting the AI into a fight

This is where the second goal took over. The agent had mostly fought in the simulator or in story battles, where the fight comes to it. Going out to
pick one, it wasn't very good.

It hopped between walkable points, scanning for anything that looked like an enemy, and found crows. The owner pointed out that repeatable fights are
marked on the map. Then the owner got us to a fight by hand so that testing could go on, which is the kind of thing the pipeline shouldn't need.

The harness gained two new abilities from this: one that lists enemies near the player, and one that goes to the nearest and starts the fight. They
also taught it how the game does this. On foot, a fight starts by itself within about eight to ten metres. On chocoback nothing happens, even three metres
away, until you press First Strike or get off.

## Step 6: the chocobo and the ledge

Asked to ride to a Combat Assignment, the chocobo ran at a ledge and kept on running. The route used an eleven point seven metre drop, one of the jumps
the game has authored for its characters. A chocobo can't take it. Meanwhile, the AI's script retried the same route forty times without checking whether
it was getting anywhere.

The owner set a simple rule: no route takes a drop of more than eight metres. The route now takes a slightly longer way, and it arrives.

## Step 7: tips and cutscenes

The harness can close tutorial tips and skip cutscenes, but only while streaming, so in offline tests they just sat there. That was a small change. The harder
cases took longer.

A tip during a fight stayed open for over a minute, because the watcher closing tips was fighting the combat autopilot for the same screen reader. Now the
autopilot closes those itself.

The Combat Assignment opens with a forty-nine second scene that the game doesn't report as a scene at all. The AI tested pausing it four seconds in, saw only
Resume, and concluded it couldn't be skipped. The owner pointed out the scene hadn't really started yet. Fourteen seconds in, Skip was there. So the skipper now
looks for the subtitle on screen, and tries after six seconds. When it isn't offered, it closes the pause and tries again later.

## Step 8: the crash

Partway through, the game crashed while loading a save. The AI had just changed the telemetry to scan for scenes every two seconds while Cloud was held, and a load holds him too. It was the first
crash since the day before. The evidence was only circumstantial, but the scan hadn't even helped, so it was removed, and that crash hasn't come back.

Later, while we were recording the final fights, one load never finished. The game was still running, with the spinner turning, and the AI's script carried on pressing keys without noticing that the load had failed. The owner spotted it. We've seen the same hang
in this game before this mod existed, and we still don't know the cause. After a restart, the same save loaded in thirty seconds. The script now checks each load before it does anything else.

## What we found the hard way

- **Screen first, theory second.** Several wrong turns ended the moment someone actually looked at the screen.
- **Check progress, not just outcomes.** Forty identical retries told us nothing.
- **Test the whole path.** Offline tests passed for First Strike, while the real button binding was missing. Only a live run found it.
- **Human eyes still matter.** The owner found the panel size, the ledge, the unfinished scene and the tips. Every one of those is a gap the agent can be taught to close.

## Test results

| Test | Result |
| --- | --- |
| Two Elphadunks, 2,358 HP | Exact, in several fights |
| Two Venorats, 3,232 HP | Exact, in several fights |
| Stepping through the meters mid-fight | Total stays exact |
| Training Dummy course | Only that mod's panel shows |
| Install and uninstall | Clean |

## Known limits

Numbers are read five times a second, so hits landing together count as one for the biggest hit. Everything an enemy loses counts as damage, whatever caused it. Boss fights haven't been tested.
Healing shows who received it, not who cast it. Any rise in HP counts as healing, including potions, Regen, HP Absorb and abilities that heal without MP, while overhealing adds nothing. MP spent is every MP the party spends, on any spell, so healing per MP
only shows true healing efficiency if healing is all you spend MP on. And damage and healing on the same character within the same fifth of a second cancel out, so both can read slightly low in busy moments. The full list is in the reference guide.

## Build on this

Everything here is free to use, under the MIT licence, and you don't need our harness or an AI to make use of it. All you need is the modding tool, UE4SS.

If you want your own meter, or anything else that watches a fight, start with how we read the battle. Ask the game whether you're in a battle, list the enemies and the
party, and read their health a few times a second. The difference between two readings is your damage or your healing. That idea takes very little code, and the file that
does the arithmetic has no game code in it at all, so you can test it on its own.

If you want a panel in the game's style, ours is built from plain widgets when the game runs, with the game's own art. It needs no asset files, so anyone can change it without
special tools. Two warnings will save you time. The game's own text and image widgets draw nothing when you create them yourself. And never ask a game object for something
it doesn't have, even inside a protected call, because it slowly breaks the script engine.

Before you trust your numbers, check them against something you know. Find an enemy, add up its health, and see whether your total lands on it. That one check found
more bugs here than anything else.

The player guide, the technical reference and all the source are in the project's repository, and the links are in the description. If you make something with this, we'd love to
see it. And if you'd like to follow where the autonomous pipeline goes next, the channel is where it'll show up.

## Credits

Thanks to the UE4SS and FModel projects and the OpenFF7R community, whose work makes all of this possible.
