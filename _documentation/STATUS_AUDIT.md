# Shards — Status Audit (2026-11-08)

How this was checked: static scans of the whole repo (broken resource paths, scene file order, signals, stubs, TODOs), all 54 GUT tests, and a runtime sweep that travelled to all 18 maps in the real game and logged errors + a screenshot of each.

## Fixed during the audit
- **GloomReach caves (CaveLevel1–3) could not load** — a `LevelTitleTrigger` ext_resource sat after the sub_resources ("Unknown tag 'ext_resource'"). Moved; all 3 load now.
- **Menu buttons' normal texture missing** — HUD.tscn and BattleHUD.tscn pointed at `ui/HUD/menu_button.svg`; now `menu_button.png`.
- **A party wipe saved the dead party** — CombatManager saved after every battle, including a wipe. Wipes now skip the save and emit `SignalBus.party_defeated` → new Game Over screen.
- **Leveling ignored the class** — XP curve, points and HP now come from `Data/Class_Progression.csv` (see below).

## Priority 1 — breaks the game for testers
1. ~~**Saves don't remember where you are.**~~ **DONE (2026-11-08)** — see "Saves" below.
2. ~~**Exported builds will lose spells, skills and status effects.**~~ **DONE (2026-11-08)** — `AbilityLibrary` / `ResourceLoader.list_directory`. Original note: `CatCharacter.populate_starting_*`, `CombatManager` spell index, `StatusEffectDatabase`, `RosterSaveSystem` list `res://` folders and keep `*.tres` names — in an export these are `*.tres.remap`, so nothing loads. Fix: strip `.remap` (or use `ResourceLoader.list_directory`). No `export_presets.cfg` exists yet, so nobody has hit it.
3. **Most of the world is unreachable.** From GreenGrove you reach FeroShaw, Broken Bone Marsh (+ cave), FeroShaw dungeon and the windmill cellars. Nothing links INTO GloomReach (+ its dungeons and caves), VeroWood or StoneTrail. (Since fixed: stone gates lead to them. EmeraldWoods was removed; its 3 gates say "This area is not part of the current demo.")
4. **Max HP drops on the first level-up for the default party.** `default_save.tres` hand-sets HP (Commander Whiskers 259) but the formula gives VIT × HP-per-VIT (~90). Decide: change the formula/sheet, or the save.

## Priority 2 — core loop gaps
- ~~**Character creation**~~ — DONE: New Game → roster → 3-step creator (race/class, 3d6 bonus roll + stats + starting abilities, name) → party of up to 6 → GreenGrove `SpawnPointNewGame`. Roster in `user://character_pool/`, locked once used in a game. Created characters start with **no equipment** yet. See `CHARACTER_CREATION.md`.
- ~~**Economy**~~ **DONE (2026-11-08)** — gold on exploration HUD (`%GoldLabel`); FeroShaw **Quartermaster** crate opens Buy/Sell shop (`ShopMenu` / `SignalBus.shop_requested`). Sylvania Town still not built (Stone Trail gate remains StoneGate2).
- ~~**Spell learning**~~ **DONE (2026-11-08)** — starter sets + Spell Books / Skill Crystals, see SKILLS_AND_SPELLS.md "Learning". Original note: characters get their whole spellbook at creation, ignoring spell level and the class's "Spells Unlock At Level" (Warden/Echo/Amazon/Crusader/Ronin/Voidhand/Ghostblade get spells at level 1). Level-ups only rank up known abilities; nothing teaches new ones.
- ~~**Class weapon rules**~~ **DONE (2026-11-08)** — `ProfessionData.allowed_weapon_types` from CSV Weapon Bonus; `CatCharacter.can_equip_item` / equip UI enforce it (armor / `NONE` always ok).
- ~~**Level-up screen**~~ **DONE (2026-11-08)** — character sheet shows **[ SPEND POINTS ]** when unspent points remain; reopens `LevelUpMenu` via `level_up_screen_requested`.
- **Rest** — `_process_party_rest` has `@TODO: Display hp and energy recovered`; no feedback to the player.

## Priority 3 — polish / known TODOs (from `_documentation/TODO.md` + sweep)
- EmeraldWoods spawn view shows a huge beige wedge; FeroShaw and VeroWood spawns face a black void at the map edge.
- Fog doesn't come back after forest → dungeon (TODO.md).
- Combat: auto/default actions; front/back row indicator on the battle HUD.
- Skill-based world interaction (lockpicking, search, hazards); intro movie; About screen placeholder; inventory full-screen mode.
- Bridge camera lift; forest grass/mushrooms/crash site.
- TODO.md "WINDMILL isn't animating" is out of date — it spins and leads to the windmill cellars now.

## Noise (safe to ignore, worth cleaning)
- "Another resource is loaded from path EnX.tres (possible cyclic resource inclusion)" on every map with dungeon enemies.
- ~~Data CSVs imported as translations~~ — DONE: every `.csv` imports as *Keep File* now and the generated `.translation` files are gone.
- Invalid UID warnings (CryptHole script, ZombieCat_Base, Kenny materials, HypeChest); `resources/OutdoorParts/mesa/Textures/colormap.png` missing (9 import errors); `ui/MeshLibrary_Source.tscn` points at a missing .dae.

## Class progression sheet — `Data/Class_Progression.csv`
Read at runtime by `Scripts/Progression/ClassProgression.gd` (no compile step; edit and run). Rows are easiest → hardest: Spartan, Shade (Easy) · Soulwright, Archanist (Normal) · Warden, Echo, Maester, Psynic (Tricky) · Amazon, Wizard, Crusader (Hard) · Ronin, Voidhand, Ghostblade (Expert).

| Column | Meaning |
|---|---|
| Base XP, XP Growth | XP from level L to L+1 = Base XP × L^Growth (800/1.40 easy → 1500/1.60 expert) |
| Max Level | XP stops levelling past this |
| HP Per VIT, HP Per Level | max HP = VIT × HP/VIT + (level−1) × HP/Level (then the dice +3% bonuses) |
| MP Per Level | max MP = INT + PIE + (level−1) × MP/Level |
| Stat / Skill / Spell Points Per Level | granted every level (copied from Character_Classes.csv) |
| Spells Unlock At Level | no spell points before this (0 = never) |
| Auto Stat Gains | e.g. `STR+1,VIT+1`, applied every level (replaces the old hard-coded STR+1 VIT+1) |
| Milestone Every / Milestone Stat Points | extra stat points every N levels (harder classes get more) |
| Aliases | other names that match (e.g. Psionic → Psynic) |

The per-level point columns still exist in `Character_Classes.csv` / `ProfessionData`; the progression sheet now wins.

## Saves (done 2026-11-08)
`SaveGame` (`save_version` 2) now stores, besides party / inventory / floor:
- **gold**; **location** — `map_scene_path`, `location_name`, `player_cell`, `player_facing`;
- **world state** — `GameState.environment_states` (chests, puzzles, windmill, bosses, wall masks, skulls...);
- **clock** — `world_time` (0..1) + `time_period`; **play time** (`play_time_seconds`).

How it flows:
- `GameState.save_game(include_location = true)` reads the live map + party tile via `capture_location()`.
- `GameState.load_game()` restores everything and sets `pending_location`; `MapManager._ready()` consumes it: opens the saved map and calls `player.restore_location(cell, facing)` (falls back to the default map if the saved map is gone). Works for cold start (game launch) and in-game Load / Game Over → LOAD SAVE.
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
