# Character Creation & Roster

Players make their own characters and pick a party of up to 6 from them. The test party in
`Data/default_save.tres` (starter six from `Data/StarterParty/`: Nyx, Socks, Tigris / Talon, Sable, Pixel) is only used by **QUICK START (TEST PARTY)**,
which appears on the party screen in debug builds (editor runs) only.

## Flow
```
Main Menu
 ├─ NEW GAME ──► (replace save? ) ──► RosterScreen [START]
 │                                     ├─ + NEW CHARACTER ─► CharacterCreator (3 steps) ─► roster
 │                                     ├─ ADD TO PARTY / TO BACK ROW / slot buttons (front 0-2, back 3-5)
 │                                     ├─ START GAME ─► SessionFlow.start_new_game_with_roster()
 │                                     └─ QUICK START (TEST PARTY)  [debug builds only]
 └─ PARTY BUILDER ─► RosterScreen [MANAGE]  (create / edit / delete, no party)
```
START GAME: deletes the old save, builds the party from **copies** of the roster characters, keeps the
test save's supplies (potions, gold), **locks** the roster characters, and starts on GreenGrove at
`SpawnPointNewGame` (`GameState.NEW_GAME_MAP` / `NEW_GAME_MARKER`).

## The creator (`Scripts/UI/CharacterCreator/CharacterCreator.gd`)
| Step | What happens |
|---|---|
| 1 Race & Class | Race list (left) · fur image ⬢ class portrait · class list (right, easiest → hardest, with difficulty). Below: race base stats vs class minimums and "needs N bonus points · X% chance per roll". Classes the race can't reach even with the best roll are greyed out and can't be confirmed. **? INFO** opens race / class details (`Data/Races/*.tres` description, `Data/Character_Classes.csv` text columns, `Data/Class_Progression.csv` difficulty + notes). |
| 2 Roll & Assign | 3 × 3D d6 (`DiceRoll3D`) = bonus pool (3–18). **RE-ROLL** any time (resets where the points went). Points go first to the class minimums automatically; − / + to move them, **AUTO**, **RESET**. No stat above 18. CONFIRM only when the class minimums are met and the pool is spent. Starting abilities: pick spells (up to 2 tier-1 spells, if the spellbook is open at level 1) and 1 class skill; race skills are free. HP / MP preview. |
| 3 Name & Confirm | Portrait over the race fur, name (or **RANDOM**), summary, **CREATE** / **SAVE CHANGES**. |

## Rules (`Scripts/Progression/CharacterCreation.gd`, tested)
- Base stats come from the race (`CatBreed.base_*`, unset = 8). Class minimums are `ProfessionData.req_*` (unset = **10**).
- `points_needed(race, class)` = sum of shortfalls; reachable when ≤ 18 and no minimum is above 18.
- Spell picks = `min(AbilityRules.STARTER_SPELLS, learnable spells at level 1)`; skill picks = `min(AbilityRules.STARTER_CLASS_SKILLS, class skills the race doesn't already get)`.
- `build_character(draft)` makes a level-1 character with `abilities_initialized = true` (so the automatic starter set never overwrites the picks), full HP/MP, and stores `creation_dice` / `creation_allocation` for editing.

## Art
- Race image: `Data/Furs/<race lower-case>.png` (pixel art, nearest filter).
- Class image: `Data/Portraits/<ClassName>.png` (e.g. `Warden.png`). Missing ones show the Arcanum crest
  (`ui/LOGOS/arcanum_crest_100.png`). Characters made before a portrait existed pick it up automatically
  the next time the roster loads them.
- Header logo: `ui/LOGOS/arcanum_logo_40.png`. Colours / buttons: `CreationUI.gd`.

## Roster storage (`Scripts/Progression/CharacterRoster.gd`)
- One file per character: `user://character_pool/<roster_id>.tres` (outside the save game, so it survives New Game).
- `roster_locked` is set when a character is taken into a game: no edit, no delete (it can still join new parties).
- The game always plays with copies (`build_party`), so the roster keeps the level-1 character.
- `RosterSaveSystem` (old API) now forwards to `CharacterRoster`.

## Tests
`tests/progression/test_character_creation.gd` — races/classes load, reachability, dice range, allocation
rules, ability picks, build + round-trip, validation messages, roster save/list/lock/remove/party.

## Starter kit (`Scripts/Progression/StarterKit.gd`)
When the game starts, every created character gets their class's **regular** gear from `Data/basic_items.csv`
(`armor_<class>_regular_*` + `weap_<class>_regular_*`, compiled to `Data/Items/Equipment/` by ItemCompiler):
5 armour pieces + weapon(s), each in its slot (two-handed weapons go in RIGHT_HAND). Items that don't fit a
free slot go in the party pack: the Warden's backup Iron Dagger, the Ghostblade's Steel Shuriken (slot NONE)
and backup dagger. Change a class's kit by editing its `_regular_` rows and re-running ItemCompiler.
`basic_items.csv` is imported as *Keep File* so the game can read it in exported builds too.

## Not done yet
- Some classes still have no class skill at level 1 (Echo), so they start with only their race skill.
