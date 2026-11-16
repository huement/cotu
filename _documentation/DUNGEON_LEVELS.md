# Dungeon Levels

Dungeons are built from room **parts** (hand-made scenes) joined by Kenney corridor tiles. They aren't painted on a GridMap like the caves.

## Files

| File | What it does |
|---|---|
| `Scenes/Dungeons/Parts/SmallRoom, WideRoom, LargeRoom, CornerRoom.tscn` | Room parts. Each has the `DungeonRoom.gd` script. |
| `Scenes/Dungeons/Parts/BossChamber.tscn` | The boss room, hand-built with the boss GridMaps. It has a single doorway (S); Cap_N stays shut, and Cap_W/Cap_E are side chambers that open after the boss fight (LATER). |
| `Scripts/Dungeon/DungeonRoom.gd` | At load time it removes the caps on connected doorways and the rolled-out dressing, then prefixes every `object_id` in the room. |
| `Scripts/Dungeon/DungeonLevel.gd` | Root of a generated level. Holds `map_type`, `bgm_track_name` and the seed it was built with. |
| `Scripts/Dungeon/DungeonGenerator.gd` | Layout logic: reads the room templates, places rooms and corridors, builds the movement model and picks enemy spots. |
| `Scripts/Utilities/GenerateDungeonLevel.gd` | EditorScript that builds a single level and saves it as a `.tscn`. |
| `Scripts/Dungeon/DungeonFloorBuilder.gd` | Shared builder for two-floor dungeons (chests, ghosts, BossEnemy, crypt exit). |
| `Scripts/Utilities/GenerateFeroShawDungeon.gd` | Two-floor Fero Shaw dungeon (EditorScript → File → Run). |
| `Scripts/Utilities/GenerateVeroWoodDungeon.gd` | Two-floor Vero Wood dungeon (EditorScript → File → Run). |
| `Scripts/Utilities/GenerateGloomReachDungeon.gd` | Three-floor Gloom Reach dungeon with a boss shard (EditorScript → File → Run). |
| `resources/mesh_library/nav_blocker_mesh_library.tres` | Invisible "nav-blocker" tile used on WallMap to mark corridor walls. |
| `Scenes/Dungeons/DungeonLevel1.tscn` | The first dungeon (with `DungeonLevel1_Upper`). No longer linked from GloomReach; kept for reference and the debug menu. |

## Making a new level

### Single floor (older path)

1. Open `Scripts/Utilities/GenerateDungeonLevel.gd` and edit the CONFIGURATION block: `LEVEL_NAME`, `LEVEL_SEED`, `ROOM_COUNT`, `ENEMY_COUNT`, `ENEMY_DATA`, the room weights, and where the entrance stairs lead back to.
2. Run it with **File → Run**. The level is saved and opened.
3. If you don't like the layout, change `LEVEL_SEED` and run it again. Running with the same name overwrites the file.
4. Hook the level up: point a CryptHole, StoneGate or Stairs at it (`target_dungeon_scene` / `target_scene`, plus `arrival_point_name`).

### Two-floor dungeon (preferred)

1. Copy `GenerateFeroShawDungeon.gd` or `GenerateVeroWoodDungeon.gd`, set floor names/seeds/enemies/boss, and a `Bosses.csv` row for reward/exit.
2. Run the EditorScript with **File → Run** (or headless: `godot --path . --headless -s res://Scripts/Utilities/BuildVeroWoodDungeon.gd` for Vero).
3. Point the overworld CryptHole at `*_Upper.tscn`.

## Gloom Reach dungeon (3 floors)

```
GloomReach RockCave ──▶ GloomReachDungeon_Upper ──crypt hole──▶ GloomReachDungeon_Middle ──crypt hole──▶ GloomReachDungeon
      ▲  (arrive: DungeonExitArrival)                                                           boss chamber + shard │
      └──────────────────────────────── boss chamber north gate (after the boss) ──────────────────────────────────┘
Each floor's entry stairs lead back UP (to GloomReach / the floor above's ExitArrival).
```

| Scene | Seed | Rooms | Enemy groups | Enemies (pack, multiplier) | Ghosts | Chests |
|---|---|---|---|---|---|---|
| `GloomReachDungeon_Upper` | 113 | 8 | 7 | Savage 2, Punk 2, **Hazard Cleaner 2 (level 5)**, Guard 2 | 1 | 3 |
| `GloomReachDungeon_Middle` | 127 | 9 | 8 | Knight 2, Ronin 2, **Hazard Cleaner 2 (level 6)**, Shadow Assassin 1 | 2 | 3 |
| `GloomReachDungeon` | 139 | 8 + boss | 7 | Ronin 2 ×1.1, Void Weaver 2, Heavy Servitor 2, Shadow Assassin 2, **Hazard Cleaner 2 (level 7)** | 2 | 3 |

- **Boss:** **Void Weaver**, level 8 with `boss_multiplier` 2.2 (boss only; ~250 HP / 63 attack), flanked by two level-8 **Hazard Cleaners**. `Bosses.csv` row **13** (reward wall east, exit → GloomReach `DungeonExitArrival`).
- **Shard:** the generator's `inject` step adds `ArcanumShard` (`shard_id = "gloomreach_dungeon"`) to the boss floor, pointed at the boss. It appears where the boss falls. `ShardLedger.CATALOG` lists it under area "Gloom Reach", so Gloom Reach counts **2** shards (Slime Lord + dungeon).
- **Settings:** per enemy type `"level"` (placement level, 0 = sheet). On `boss_enemy`: `"level"` (boss + minions) and `"boss_multiplier"` (boss only → `BossEnemy.boss_stat_multiplier`).
- **Rebuild:** `GenerateGloomReachDungeon.gd` → File → Run (or headless `BuildGloomReachDungeon.gd`). Re-running overwrites all three floors and re-adds the shard, so hand edits to those scenes are lost.

## How a level is put together

- **Grid.**
  - The world is laid out in 4 m modules; module (i, j) is centred at world (4i+3, 4j+3), which is always a 2 m movement-cell centre.
  - Rooms sit on a module centre, rotated 0/90/180/270.
- **Entrance and growth.**
  - The level starts from a dead-end corridor at module (0, 0). Its stairs lead back up, and the party spawns one cell east, facing east.
  - The generator then grows from open doorways: a corridor 0–3 modules long (sometimes with a turn), then a weighted random room rotated so that one of its doorways meets the corridor.
  - Doorways that are never used keep their gate (`Cap_X`).
- **Boss chamber.** Attached last, off the deepest open doorway.
- **Collision.**
  - Rooms block with their own `Walls`/`Caps` collision.
  - Corridors are bare models. Their walls are blocked by invisible tiles on `WallMap`, which MapManager treats as walls.
- **Checking and enemies.**
  - The generator floods the walkable cells with the same 1.6 m box test the player uses, so it can check that everything is reachable.
  - Enemies go on reachable room cells (never in the boss room): at most 2 per room, away from doorways and the entrance. A spot is rejected if an enemy standing there would cut anything off.
- **Save state.**
  - Each placed room gets an `id_prefix` (e.g. `dungeonlevel1_room3_largeroom`), so chests and masks keep their own save state.
  - `object_id`s must be globally unique, because save state is keyed by the scene name "World".

## Rules for room parts (so the generator can read them)

- **Doors.** `Doors/Door_N|E|S|W` are Marker3Ds on the doorway cell, with −Z pointing OUT of the room. The letters are room-local: N = −Z, E = +X.
- **Walls.** `Walls` is a StaticBody3D with one BoxShape3D per blocked cell. The room's size is worked out from these boxes (or from the GridMap tiles, for the boss chamber).
- **Caps.** `Caps/Cap_X` is a gate plus a box blocker for each doorway.
- **Dressing.**
  - Dressing is any node with **Unique Name (%)** outside RoomModel/Walls/Doors/Caps.
  - Plain Node3D folders are searched, not removed.
  - Torches use `torch_chance`; everything else uses `decor_chance`. Per-node metadata `spawn_chance` overrides both.
- **Blocking props.** Barrel, Column, Bones, Stones, chest and HypeChest block their cell. They are counted in the reachability check.

## Bosses (Data/Lore/Bosses.csv)

Each boss chamber reads one row of `Data/Lore/Bosses.csv`, chosen by `boss_id` on the BossChamber node. The generator sets it from `BOSS_ID`; DungeonLevel1 uses row 1. The `LoreManager` autoload loads the CSV (imported as "Keep File").

When the level loads, the chamber does three things:
1. It spawns the row's `boss_scene` in the middle of the room. That scene's root must use `DungeonBoss.gd` (BlobCorrupt does).
2. It fills the reward room on `reward_side` (EnvironmentE or EnvironmentW). Chests are filled in name order. The HornedSkull or WallMask gets the lore values.
3. It sets up the north gate (`Caps/Cap_N/Blocker`, which has `BossExitGate.gd`).

When the boss is beaten:
- The win is saved.
- That side's wall (`Caps/Cap_E` or `Caps/Cap_W`) sinks into the floor with a quake.
- The north gate unlocks. Facing it and pressing interact asks to leave, then travels to `exit_scene` and puts the party on the `exit_arrival` marker.

If you come back after the win, the boss is gone and the side room is already open.

Empty cells keep whatever the scene already has.

| Column | Used for |
|---|---|
| `id` | The row number that `boss_id` points to. |
| `title`, `description` | Lore popup title and text of the reward room's skull or mask. |
| `ascii_file_path`, `shader_path` | Loaded into LoreData, for later use. |
| `loot_item_path` | The boss's signature item. It is added to the first chest. |
| `sfx_path` | Sound for the HornedSkull scare, or for the WallMask when inspected. Only used if the file exists. |
| `boss_scene` | Boss scene to spawn (must use the DungeonBoss script). |
| `enemy_data_path` | Replaces the boss scene's `base_data`. |
| `boss_name` | Name shown in battle. |
| `boss_level`, `boss_scale`, `has_minions` | BlobBossController settings. |
| `reward_side` | Which wall drops: `east`, `west` or `none`. |
| `side_open_sfx` | Sound played while the wall sinks. |
| `chest_gold` | Gold per chest. One value for all (`1000`) or one per chest (`500\|500\|1000`). |
| `chest_items` | Items per chest. Separate chests with `\|` and items with `;`. If there are fewer groups than chests, the last group repeats. |
| `aura_type`, `xp_reward` | Settings for the skull or mask. |
| `scare_flash_texture`, `scare_shake`, `scare_hold` | HornedSkull scare FX. |
| `exit_scene`, `exit_arrival`, `exit_prompt` | Where the north gate leads, and the question it asks first. Empty `exit_scene` means the gate never opens. |
| `exit_requires_boss` | `true` means the gate stays locked until the boss dies. |

Scripts:
- `Scripts/Dungeon/BossChamber.gd` (extends DungeonRoom)
- `Scripts/Enemies/DungeonBoss.gd` (extends BlobBossController)
- `Scripts/Dungeon/BossExitGate.gd`
- `Scripts/Singletons/LoreManager.gd` (autoload)
- `Scripts/WorldData/LoreData.gd`

## Ghosts

Each floor places a couple of invisible haunts (`GhostAmbushComponent` on a `WorldEnemy`). The zone is a 15-tile diamond around the ghost's cell (`haunt_radius` in the generator, default `GhostAmbushComponent.DEFAULT_HAUNT_RADIUS`). About 1–2 seconds after the party is inside, the ghost warns them. They have roughly a second (less at higher `ghost_level`) to turn around. Stepping does not save them. If they don't turn, the ghost appears behind them and the fight starts in the battle room, with the ghost's turn meter already full so it acts first. One ghost strikes at a time. `stat_multiplier` still scales that floor's ghost; the sheet (`EnGhost.tres`) is a hard fight, so even ×0.6 is over 100 HP.

## Battle room (dungeon "battle mode")

Dungeon corridors are too tight to fit a whole enemy pack, so dungeon fights don't happen where they start.

- **What happens.** The screen fades to black, the party's view moves into `Scenes/Dungeons/DungeonBattle.tscn`, the battle runs there, and when it ends the view cuts back to where the party was.
- **Script.** `Scripts/Managers/BattleArena.gd`. Enemies call `await BattleArena.prepare_party(get_tree(), global_position)` just before they emit `combat_started` (`enemy.gd`, `world_enemy.gd`; ghosts and BossEnemy go through `enemy.gd`).
- **Which maps.** Any map whose root is a `DungeonLevel` (caves do the same with `Scenes/Caves/CaveBattle.tscn`, see `CAVE_LEVELS.md`). Set root metadata `use_battle_room` to `true` / `false` to force it on or off for one map. Other maps still just turn the party to face the enemy (`BattleFacing`).
- **Boss chamber.** A fight that starts while the party stands on a BossChamber's `BossFloor` stays in the chamber. A boss met anywhere else goes to the battle room.
- **The party never leaves its cell.** Only the Player node's transform moves (`DungeonPlayer.enter_battle_view` / `leave_battle_view`); `current_grid_pos`, saves and the dungeon's enemies are untouched.
- **Editing the room.** The party stands on the scene's `SpawnPoint` marker and looks along its -Z. Enemies appear about 3.4 m in front. `BattleLight` lights the fight. Floor and wall GridMaps both need **Center Y off** (like BossChamber), or the floor sits 2 m up the walls.
- The room is added to the level at runtime as a hidden child named `BattleArena`, 2000 m away.

## Not done yet

- A stair from the boss room down into another floor. The north gate already leaves the dungeon after the boss dies.
