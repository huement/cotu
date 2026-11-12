# Shards — Status Audit (2026-11-08)

How this was checked: static scans of the whole repo (broken resource paths, scene file order, signals, stubs, TODOs), all 54 GUT tests, and a runtime sweep that travelled to all 18 maps in the real game and logged errors + a screenshot of each.

## Update 2026-11-11 — playtest prep
- **New games work** end to end: main menu → roster → **intro video** (`assets/intro.ogv`, `Scenes/GameMenus/IntroVideo.tscn`, skippable, no audio track) → GreenGrove at `SpawnPointNewGame`. The first save is written before the video plays. `Audio/Voice/intro.mp3` is unrelated (Nine's in-level instructions).
- **Game starts at the main menu.** Main scene is `Scenes/Boot.tscn` → main menu. Opening the game no longer writes a save, so a first-time player sees "No save yet".
- **Dev start.** `Scenes/world.tscn` → MapManager → **Dev Start Override**. ON (editor only): Run skips the menu and drops the test party on MapManager's **Default Map Scene**; that session saves to `user://save_game_dev.tres`, never the player save. OFF: normal player start. Exported builds ignore it. The normal start map is hardcoded (`GameState.NEW_GAME_MAP`).
- **Export presets added** (`export_presets.cfg`): Android, macOS, Windows, Linux → `build/`. Data CSVs, `Data/Help/` and `Data/Lore/` are force-included (they are read as plain files); GUT, tests and docs are excluded. ETC2/ASTC texture import is on (needed for Android and macOS universal). **Not yet exported or run on a device.**

Still open before testers: first real export + run on each platform; UI scaling on phone screens (no stretch mode is set in Project Settings); a clear "end of demo" moment; rest feedback; FeroShaw / VeroWood spawn views; About screen text; name generator → `name-maker.gd` (TODO.md).

## Fixed during the audit
- **GloomReach caves (CaveLevel1–3) could not load** — a `LevelTitleTrigger` ext_resource sat after the sub_resources ("Unknown tag 'ext_resource'"). Moved; all 3 load now.
- **Menu buttons' normal texture missing** — HUD.tscn and BattleHUD.tscn pointed at `ui/HUD/menu_button.svg`; now `menu_button.png`.
- **A party wipe saved the dead party** — CombatManager saved after every battle, including a wipe. Wipes now skip the save and emit `SignalBus.party_defeated` → new Game Over screen.
- **Leveling ignored the class** — XP curve, points and HP now come from `Data/Class_Progression.csv` (see below).


## Priority 3 — polish / known TODOs (from `_documentation/TODO.md` + sweep)
- FeroShaw and VeroWood spawns face a black void at the map edge.
- Combat: auto/default actions; front/back row indicator on the battle HUD.
- ~~Skill-based world interaction (lockpicking, search, hazards)~~
- ~~intro movie~~ (done 2026-11-11); 
- About screen placeholder; 
- inventory full-screen mode.


## Noise (safe to ignore, worth cleaning)
- "Another resource is loaded from path EnX.tres (possible cyclic resource inclusion)" on every map with dungeon enemies.
- ~~Data CSVs imported as translations~~ — DONE: every `.csv` imports as *Keep File* now and the generated `.translation` files are gone.
- Invalid UID warnings (CryptHole script, ZombieCat_Base, Kenny materials, HypeChest); `resources/OutdoorParts/mesa/Textures/colormap.png` missing (9 import errors); `ui/MeshLibrary_Source.tscn` points at a missing .dae.

## Class progression sheet — `Data/Class_Progression.csv`
Canonical write-up: **[`LEVELING.md`](LEVELING.md)**. Read at runtime by `Scripts/Progression/ClassProgression.gd` (no compile step). Rows easiest → hardest. XP = Base XP × L^Growth; skill/spell grants capped at half known abilities. Per-level point columns in `Character_Classes.csv` / `ProfessionData` are superseded by this sheet.

## Saves (done 2026-11-08)
`SaveGame` (`save_version` 2) now stores, besides party / inventory / floor:
- **gold**; **location** — `map_scene_path`, `location_name`, `player_cell`, `player_facing`;
- **world state** — `GameState.environment_states` (chests, puzzles, windmill, bosses, wall masks, skulls...);
- **clock** — `world_time` (0..1) + `time_period`; **play time** (`play_time_seconds`).

How it flows:
- `GameState.save_game(include_location = true)` reads the live map + party tile via `capture_location()`.
- `GameState.load_game()` restores everything and sets `pending_location`; `MapManager._ready()` consumes it: opens the saved map and calls `player.restore_location(cell, facing)` (falls back to the start map, `GameState.NEW_GAME_MAP`, if the saved map is gone). Works for cold start (game launch) and in-game Load / Game Over → LOAD SAVE.
- **Autosave**: after every battle (except a wipe) and after every `MapTransition.travel()`.
- **New Game** wipes world state, gold, clock and play time; its first save has no location.
- **One world clock**: `GameState.world_time` is the master; each map's `DayNightCycle` reads + advances it (so time no longer resets on map change, and code can set it, e.g. for resting).
- **World-state keys are per map now** (`GameState.get_current_map_id()` = active map name, was always "World"). The BossChamber prefab's chest / mask wall (same ids in DungeonLevel1, DungeonLevel2, FeroShawDungeon) no longer share state.
- Older saves (v1) still load: they start on the default map with a fresh world.
- Save label (menu tooltip / Game Over): "2026-11-08 04:14  ·  FeroShaw".

## Skills & spells (done 2026-11-08)
- Export-safe loading (`AbilityLibrary`, also used by `StatusEffectDatabase` and CombatManager's spell lookup).
- Characters start with a small class/race set and learn the rest from **Spell Books / Skill Crystals** (world pickups via `ItemPickup`, boss rewards, Loot.csv items). Rules + tunables: `_documentation/SKILLS_AND_SPELLS.md` → "Learning".
- Also fixed: race `.tres` files pointed at a stale `CatBreed.gd` uid; `LootCompiler` dropped every item's uid on re-run (now keeps them); `hud.gd` popup handler had the wrong signature (the "can't sleep here" line never played).
- Data mismatch to fix by hand: the starter Wizard's breed is "Sphinx" but `sk_purr_renewal` (Skills.csv) is assigned to "Sphynx", so that race skill never matches.
