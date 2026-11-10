# AGENTS.md — Shards (Godot 4.5)

Blobber / Wizardry-style first-person grid crawler. Space-cat party, ATB combat, CRT HUD.
Engine: **Godot 4.5.1**. Language: **GDScript 2.0**, strictly typed.

This file is the shared briefing for every agent. Deep system docs live in `_documentation/`. Prefer those over guessing.

---

## Hard rules (do not violate)

1. **Strict static typing** on every `var`, param, and return. No untyped dynamics.
2. **SignalBus decoupling**: game logic never reaches into UI trees. Emit on `SignalBus`; UI listens.
3. **Composition over inheritance**: components + `Resource` data, not deep class trees.
4. **Grid movement**: `Vector2i` / cell math + Tweens + RayCast3D / GridMap. Never `CharacterBody3D` physics for party steps.
5. **Cardinal facings** on the wire are uppercase strings: `"NORTH" | "SOUTH" | "EAST" | "WEST"` (enums exist in code; convert at signal / save boundaries).
6. **Do not guess visual bugs** from source. Run the game, read logs, take a screenshot.
7. **Do not invent Godot 4.5 APIs** from memory. Query Context7 (`/godotengine/godot-docs`, branch `4.5`) or read engine docs.
8. Prefer editing existing scripts/scenes over creating parallel systems.

---

## Autoloads (`project.godot`)

| Name | Path | Role |
|---|---|---|
| `SignalBus` | `Core/SignalBus.gd` | Global event bus (exploration, combat, VFX, UI) |
| `GameState` | `Core/GameState.gd` | Session mode, party, save/load, encounter locks |
| `CombatManager` | `Scripts/Managers/CombatManager.gd` | ATB brain; **only emitter of `combat_ended`** |
| `TargetSelectionManager` | `Scripts/Managers/TargetSelectionManager.gd` | Pending item/ability between popup → combat |
| `GameLogger` | `Core/GameLogger.gd` | Log plumbing |
| `AudioManager` | `Core/AudioManager.gd` | BGM / SFX / voice |
| `LoreManager` | `Scripts/Singletons/LoreManager.gd` | Lore unlocks |
| Menu / settings addons | `addons/...` | MenuKit, PulseLiteUI, SettingsManager |

---

## Directory map

```
Core/                 Autoload singletons (SignalBus, GameState, Audio, Logger)
Scripts/
  player.gd           DungeonPlayer — grid party controller
  MapManager.gd       Sub-map swap without tearing down World/Player/HUD
  Components/         GridMovementComponent, etc.
  Managers/           CombatManager, LevelManager, BattleFacing, BattleArena (dungeon battle room), TargetSelection
  Combat/             Pure combat helpers: Combatant, ActiveEffect, CombatMath, CombatTargeting, AbilityInfo
  Dungeon/            Procedural dungeon rooms / generator / boss chamber
  Environment/        MapTransition, caves, chests, day/night, interactables
  Enemies/            WorldEnemy, bosses, AI, ambush
  UI/                 BattleHUD, NineHUD, inventory, skills, menus
  Resources/          ItemData, SpellData, SkillData, EnemyData, SaveGame…
  Grid/               GridDefinitions, GridCommand
  3D/                 Enemy visuals, camera shake, weapon animator, boss juice
  Utilities/          Generators, compilers (CSV → .tres), loot helpers
resources/            CatCharacter, DungeonParty, breeds, professions, mesh libs
Data/                 CSV sources + compiled .tres (Items, Enemies, Spells, Skills…)
Scenes/               world.tscn, maps, UI, dungeons, caves, menus
ui/                   Shared UI scenes / frames
addons/               gut, game_menu_kit, pulselite_ui, settings_menu
_documentation/       System docs (source of truth for agents)
tests/                GUT unit tests (tests/combat/ = pure combat helpers)
```

Ignore when searching unless asked: `.godot/`, `*.import`, `*.translation`, `addons/gut/` internals, `_backup*`.

---

## Core gameplay contracts

### Party matrix (`resources/Party.gd` → `DungeonParty`)

- Exactly **6 slots**.
- **Front row**: indices `0, 1, 2` (melee-exposed).
- **Back row**: indices `3, 4, 5` (melee-safe; ranged / spells / claws).
- At least one living member should remain front-row when reorganizing.
- Identity resource: `CatCharacter` → bridges vitals through `CharacterStats` getters/setters. Do not flatten that boundary.

### Exploration

- Player: `Scripts/player.gd` (`DungeonPlayer`) + `GridMovementComponent`.
- Maps swap via `MapManager.switch_map()` / `MapTransition.travel()` — keep Player + HUD alive.
- Arrival markers: named nodes (e.g. `SpawnPoint`, `CaveExitArrival`); facing uses marker **-Z**.
- Topology reference: `_documentation/OVERWORLD_TOPOLOGY.md`.

### Combat (ATB)

Canonical doc: **`_documentation/COMBAT_README.md`** (prefer over older “planning phase” wording in `STATUS.md`).

Flow:

1. World enemy / boss emits `SignalBus.combat_started(group, party, facing)`.
2. `CombatManager` snapshots combatants, runs turn meters, resolves actions.
   Formulas are NOT in CombatManager — read the small typed helpers in `Scripts/Combat/` instead
   (`CombatMath` damage/potency/flee/meters, `CombatTargeting` target resolve, `AbilityInfo` ability reads,
   `Combatant` / `ActiveEffect` stat + buff math). Change a formula there + its test in `tests/combat/`.
3. `BattleHUD` / popups emit `player_action_selected`; never call CombatManager UI APIs from random scripts.
4. Only `CombatManager` emits `combat_ended`.

Targets in CSV / resources: `SINGLE_ENEMY | SINGLE_ALLY | ALL_ENEMY | ALL_ALLY | SELF`.

### Data

- Author in CSV under `Data/` when a compiler exists; compile to `.tres` (see Utilities `*Compiler.gd`).
- Do not hand-edit huge generated `.translation` sidecars.
- Default save template: `Data/default_save.tres`. Runtime save: `user://save_game.tres`.

### UI / CRT

- Layered `Control` modules; Scene Unique Nodes via `%Name`.
- PNG frames: `TextureRect`, Expand Mode **Ignore Size**, filter **Nearest**.
- Minimap `SubViewport` cameras stay decoupled from the FP camera.
- Battle UI entry: `Scripts/UI/BattleHUD.gd`. Exploration HUD: `Scripts/hud.gd` / NineHUD docs.

---

## Where to read before coding

| Task | Read first |
|---|---|
| Combat formulas / targeting | `Scripts/Combat/*.gd` (each ≤ 210 LOC) + `tests/combat/` — not CombatManager |
| Combat flow / abilities / turn meters | `_documentation/COMBAT_README.md`, `BATTLES.md` |
| Skills / spells data shape | `_documentation/SKILLS_AND_SPELLS.md` |
| Items / loot | `_documentation/ITEMS_AND_LOOT.md` |
| Status effects | `_documentation/STATUS.md` (effects section) + `StatusEffectData.gd` |
| Caves | `_documentation/CAVE_LEVELS.md` |
| Dungeons | `_documentation/DUNGEON_LEVELS.md` |
| Overworld links | `_documentation/OVERWORLD_TOPOLOGY.md` |
| Sky / day-night / clouds | `_documentation/SKY_AND_DAYLIGHT.md` |
| HUD layout | `_documentation/NINE_HUD.md`, `UI.md` |
| Tile / mesh pipeline | `_documentation/TILE_PIPELINE_README.md` |
| Known bugs / backlog | `_documentation/FIX.md`, `TODO.md` |

**Narrative tasks only** (dialogue, lore text, boss story beats, naming characters/places): `_documentation/BOSSES.md`, `_extra/WORLD.md`.
Do not open them for code, data-balance, level-building or UI work — they are story notes, not system contracts.

---

## Run / look / test

Use the project skill `.cursor/skills/godot-shards` and the game runner:

```bash
# Preferred look loop (from repo root)
node /Users/eris/.claude/skills/game-development/game.mjs run
node /Users/eris/.claude/skills/game-development/game.mjs logs --errors
node /Users/eris/.claude/skills/game-development/game.mjs shot
node /Users/eris/.claude/skills/game-development/game.mjs stop

# Direct Godot
godot --path . --headless --quit-after 2          # smoke
godot --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit   # GUT
godot --path .                                    # play
godot --path . --editor
```

Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (also `godot` on PATH).
Godot MCP (`godot` namespace) is configured in `.cursor/mcp.json` — prefer it for launch / debug output / scene node edits when connected.

`SCRIPT ERROR:` lines with `res://…` map 1:1 to workspace files.

---

## Code style (GDScript)

```gdscript
# ✅
var current_hp: int = 50
@onready var camera: Camera3D = $Camera3D as Camera3D
@onready var label: Label = %CompassLabel as Label

func _get_cell() -> Vector2i:
	return current_grid_pos

# ❌ untyped, uncast, path-coupled UI from combat logic
var hp = 50
@onready var camera = $Camera3D
CombatManager.get_node("…/BattleHUD").show()
```

- Match existing naming in the file you touch (`snake_case` funcs/vars, `PascalCase` classes).
- New signals go on `SignalBus` if cross-system; keep typed args.
- Prefer `%UniqueName` for UI nodes referenced from scripts.

---

## Hot files (large — read selectively)

| File | ~LOC | Notes |
|---|---|---|
| `Scripts/Managers/CombatManager.gd` | ~1350 | Combat state + orchestration. For formulas read `Scripts/Combat/` instead |
| `Scripts/UI/BattleHUD.gd` | ~950 | Battle presentation |
| `Scripts/player.gd` | ~770 | Movement / facing / proximity |
| `Scripts/MapManager.gd` | ~475 | Map swaps |
| `Core/GameState.gd` | ~340 | Mode + save |
| `Core/SignalBus.gd` | ~80 | Add signals here |

---

## Agent workflow checklist

1. Find the owning system in the table above; open the matching `_documentation/` page.
2. Grep `SignalBus` + the manager before adding a new coupling path.
3. Keep changes scoped; no drive-by refactors of CombatManager/BattleHUD unless asked.
4. After gameplay / UI changes: smoke or run + `logs --errors` (+ `shot` for visuals).
5. Do not commit unless the user asks. Do not edit `.godot/` or mass-regenerate `.import` files.
