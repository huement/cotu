# Cave Levels

Three generated cave levels hang off **GloomReach**, built from the cave tile set
(`cave_floor_mesh_library` / `cave_wall_mesh_library`, 2 m cells).

```
GloomReach  ──CryptHole──▶  CaveLevel1  ──crypt hole──▶  CaveLevel2  ──crypt hole──▶  CaveLevel3
    ▲  (arrive: CaveExitArrival)                                                         │
    └──────────────────────────────── exit stairs ────────────────────────────────────────┘
Every level's entrance stairs lead back UP to the previous map (arrive on its ExitArrival).
```

| Scene | Size | Rooms | Enemies | Exit |
|---|---|---|---|---|
| `Scenes/Caves/CaveLevel1.tscn` | 24×24 | 6 | 2 × Zombie Savage | crypt hole → CaveLevel2 |
| `Scenes/Caves/CaveLevel2.tscn` | 28×28 | 8 | Savage / Guard | crypt hole → CaveLevel3 |
| `Scenes/Caves/CaveLevel3.tscn` | 32×32 | 10 | Guard / Knight | stairs → GloomReach (`CaveExitArrival`) |

GloomReach changes: the existing `Environment/CryptHole` now targets `CaveLevel1.tscn`, and a new
`CaveExitArrival` marker (2 cells south of the hole, facing away) is where you come back out.
Backup of the old file: `_extra/GloomReach.tscn.backup-before-caves`.

## How travel works

`Scripts/Environment/MapTransition.gd` → `MapTransition.travel(tree, scene_path, arrival_point_name)`:
swaps the sub-map with `MapManager.switch_map()` (Player/HUD stay loaded), then teleports the party to
the named marker in the new map, facing the marker's **-Z**. Falls back to `SpawnPoint`.

- **CryptHole**: new `arrival_point_name` export (default `SpawnPoint`, so other maps behave as before).
- **Stairs**: new `use_map_manager` (default **false** = old behaviour, `change_scene_to_file`) and
  `arrival_point_name`. Cave stairs set `use_map_manager = true`, because `change_scene_to_file` would
  replace the whole World scene with a sub-map.

## Level scene layout (what the generator builds)

```
CaveLevelN (CaveLevel.gd: map_type "dungeon", bgm, generator settings)
├── WorldEnvironment        black background, warm ambient, depth fog
├── EditorWorkLight         editor-only lights + fog-free preview (gone in game)
├── WorldSceneInitializer   torch on the player camera + dust; no floor/ceiling
├── SpawnPoint              in front of the entrance stairs (eye_height 1.5 like GloomReach)
├── ExitArrival             next to the exit - where you land when coming back UP from below
├── FloorMap / WallMap      GridMaps, cell size 2, cell_center_y off, no scaling
├── EntryStairs             Stairs.tscn in an alcove, leads to the previous map
├── Exit                    CryptHole.tscn (scale 0.17) or Stairs.tscn in an alcove
├── Lights                  EntryLight, ExitLight, CrystalLight1..n (teal, on each crystal rock)
└── Enemies                 enemy.tscn instances
```

## Making more levels

**`Scripts/Utilities/GenerateCaveLevel.gd`** (EditorScript): edit the CONFIGURATION block, then
File → Run. It generates the layout, builds the whole scene above and saves it to
`Scenes/Caves/<LEVEL_NAME>.tscn` (overwrites; an open copy is reloaded).

- `LEVEL_SEED`: change it for a different cave with the same settings.
- `GRID_SIZE`, `ROOM_COUNT`, `ENEMY_COUNT`, `ENEMY_DATA`: size and population.
- `PREVIOUS_SCENE` / `PREVIOUS_ARRIVAL`: where the entrance stairs lead.
- `EXIT_IS_STAIRS`, `NEXT_SCENE` / `NEXT_ARRIVAL`: crypt hole down, or stairs out.

To add a 4th level: generate `CaveLevel4` (defaults already point back to CaveLevel3), then on
CaveLevel3 change the Exit to lead to CaveLevel4 (or regenerate CaveLevel3 with
`EXIT_IS_STAIRS = false`, `NEXT_SCENE = CaveLevel4`) and move the "out to GloomReach" stairs to
the new last level (`EXIT_IS_STAIRS = true`, `NEXT_SCENE = GloomReach`, `NEXT_ARRIVAL = CaveExitArrival`).

**`Scripts/Utilities/RebuildCaveWalls.gd`** (EditorScript): for hand edits. Open a cave level, paint
or erase cells on the **FloorMap**, then File → Run: the whole WallMap is re-picked from the floor
(crystal rocks are kept). Press Ctrl/Cmd+S. If you move the stairs or exit by hand, keep a floor cell
under them and move `SpawnPoint` / `ExitArrival` with them.

**`Scripts/Utilities/CaveGenerator.gd`**: the shared layout logic (rooms → winding tunnels → loops →
pillars → entrance alcove → farthest exit → crystals → enemies → wall pieces). Walls go in rock cells
next to floor; the piece is chosen by how many sides are open:
1 = `cave-wall`/`-b`/`-c`, 2 adjacent = `cave-wall-corner`, 2 opposite = `cave-wall-double`,
3 = `cave-wall-end`, 4 = `cave-pillar`.

## Editing a dark level

Every cave has an **EditorWorkLight** node (`Scripts/Environment/EditorWorkLight.gd`, a `@tool`
script). In the editor it adds two soft lights and shows a brighter, fog-free copy of the cave
environment, so you can see to place treasure. Nothing it adds is saved (the real environment is
restored before every save) and it deletes itself when the game runs. Tweak `light_energy`,
`ambient_energy` or `disable_fog` in the Inspector; untick `enabled` to see the real in-game look
or to edit the real WorldEnvironment. Works in any dark map: just add the node.

## Notes

- Mesh library item ids are hard-coded in `CaveGenerator.gd` (floor 0/1, walls 0–7). If you re-export
  the libraries with a different item order, update the constants.
- The player torch added by `WorldSceneInitializer` stays on the camera after leaving the caves
  (same as other dungeon maps).
