# Tile & MeshLibrary Pipeline

How to turn a folder of `.glb` tile models into a **tile scene** (like `Scenes/Tiles/NatureTiles.tscn`)
and then into a **MeshLibrary** you can paint with in a GridMap.

All the scripts live in `Scripts/Utilities/` and are **EditorScripts**:
they run on whatever scene is currently open in the editor.

> **How to run an EditorScript:** open the target scene → open the script in the Script editor →
> **File → Run** (or `Ctrl/Cmd + Shift + X`). Output appears in the Output panel.
> Nothing is saved automatically — **press Ctrl/Cmd + S afterwards**.

---

## The short version

1. Drop the `.glb` files in a folder under `resources/tile_sets/<set_name>/`.
2. Make sure each kit's `Textures/` folder (usually `Textures/colormap.png`) sits next to the GLBs (see [Textures](#textures-gotcha)).
3. Create a new scene: root **Node3D**, named e.g. `MesaFloorTiles`. Save it in `Scenes/Tiles/`.
4. Drag every `.glb` from the FileSystem dock into the scene as **direct children of the root**.
5. Run **`PrepareMeshLibraryScene.gd`** (does steps A–D below in one go). Save.
6. **Scene → Export As… → MeshLibrary…**, tick **Apply MeshInstance Transforms**,
   save to `resources/mesh_library/<set_name>_mesh_library.tres`.
7. Assign that MeshLibrary to your GridMap.

If the tiles aren't all 1×1 m Kenney tiles, read [Gotchas](#gotchas) before step 5.

---

## Scene layout the scripts expect

```
MesaFloorTiles (Node3D)            ← scene root
├── floor (Node3D)                 ← one per tile (the GLB root), positioned on a grid
│   └── floor (MeshInstance3D)     ← scaled to 2×2 m; its name becomes the library item name
│       └── floor_col (StaticBody3D)
│           └── CollisionShape3D   ← trimesh (ConcavePolygonShape3D)
├── floor-wood (Node3D)
│   └── ...
```

Godot's MeshLibrary exporter uses each **MeshInstance3D** (name + mesh + its own transform)
and any **StaticBody3D → CollisionShape3D** under it as that item's collision. The parent Node3D's grid
position is ignored, which is why the tiles can be spread out in a grid for easy viewing.

---

## The scripts

### A. `MakeNodesLocal.gd`
Turns every instanced scene (each dragged-in `.glb`) that's a direct child of the root into regular
local nodes. Same as right-clicking each one → **Make Local**.
**Why:** you can't add collision nodes inside an instance or edit its children until it's local, and
the meshes get embedded in the `.tscn` (that's why `NatureTiles.tscn` is 5,000+ lines).

### B. `ScaleTilesTo2M.gd`
For each tile: sets the child **MeshInstance3D scale to (2, 2, 2)** and **doubles the tile's position**
(so the grid spreads out and the bigger tiles don't overlap).
**Assumes source tiles are 1×1 m** (Kenney standard) → our grid cells are 2×2 m.
⚠️ Running it twice doubles positions again, but scale stays at 2 (it *sets* the scale, it doesn't multiply).

### C. `GenerateTileCollisions.gd`
For each tile, finds the first MeshInstance3D child and calls `create_trimesh_collision()`, which adds
`<name>_col` (StaticBody3D) + `CollisionShape3D` under the mesh. Skips tiles that already have a
StaticBody3D, so it's safe to re-run.

### D. `ArrangeLibraryGrid.gd`
Lays the tiles out in a grid: `COLUMNS = 6`, `SPACING = 4.0` (edit the consts at the top).
Purely for looking at them; it doesn't affect the exported library.

### ⭐ `PrepareMeshLibraryScene.gd` — the all-in-one
Runs **A → B (scale only) → C → D** in that order. This is the one to use normally.
(Its scale step only sets mesh scale to 2; it doesn't double positions, since D re-grids anyway.)

### `build_mesh_library.gd` — alternative to the built-in export (use with care)
Builds a MeshLibrary in code and saves it to the hard-coded `OUTPUT_PATH`
(currently `res://resources/mesh_library/forest_mesh_kenny.tres` — **change it first or you'll overwrite that file**).
- Uses **convex** collision shapes (not the trimesh ones from step C).
- Pushes each item up so its bottom sits at Y = 0.
- ⚠️ It measures transforms relative to the **scene root**, so the tile's **grid position gets baked into
  the item** (items end up offset in the GridMap). Only use it on a scene where every tile sits at the
  origin, or just use **Scene → Export As → MeshLibrary** instead (recommended).

### `TextureMaterialGenerator.gd` — not part of the tile pipeline
Makes unshaded, nearest-filtered `texture-a.tres … texture-r.tres` materials from the PNGs in
`res://resources/Enemies/Kenny/`. Only for the Kenney enemy models.

---

## Order cheat-sheet

| Step | Do it with | Notes |
|---|---|---|
| 1 | Drag GLBs into a new Node3D scene | direct children of root |
| 2 | `PrepareMeshLibraryScene.gd` | or A → B → C → D individually |
| 3 | Ctrl/Cmd + S | scripts don't save for you |
| 4 | Scene → Export As → MeshLibrary | tick *Apply MeshInstance Transforms* |
| 5 | GridMap → Mesh Library = the new `.tres` | cell size 2×2×2 to match |

Re-exporting to the same `.tres` updates the library in place. Item IDs follow the order of
the children, so **add new tiles at the end** or existing GridMaps will show the wrong tiles.

---

## Gotchas

### Not every GLB is a 1×1 m tile
The "scale ×2" steps assume 1 m Kenney tiles. Check before running them:
- `template-floor*.glb` (Kenney dungeon kit) are **4×4 m** → they need scale **0.5**, not 2.
- Older Kenney packs (2020 `terrain_*.glb`, `platform_center.glb`) have the mesh **offset inside the GLB**
  (`(2, 0, 1.5)`), and some pieces (`terrain_roadCorner`, `terrain_roadSplit`) pivot from a **corner**, not
  the center. After scaling you must re-center the MeshInstance3D or they'll be off-grid in the GridMap.

Quick check: select the MeshInstance3D and look at its AABB in the inspector, or place the tile at the
origin next to a known-good tile.

### Textures gotcha
Kenney GLBs don't contain their texture; they point to `Textures/colormap.png` **next to the .glb**.
If that folder is missing, the tiles import untextured (plain white).
Different Kenney kits have **different** `colormap.png` files with the same name, so mixing kits in one
folder breaks this. Fix: set **Surface Material Override** on the MeshInstance3D to a material
using the right colormap (that's what `MesaFloorTiles.tscn` does).

### Collision faces
Trimesh collision is one-sided. If the player falls through a tile, enable **Backface Collision** on its
ConcavePolygonShape3D.

---

## MesaFloorTiles.tscn (already prepared)

`Scenes/Tiles/MesaFloorTiles.tscn` was generated from `resources/tile_sets/mesa_floor/` and is
**already done through step 2**. **Don't run Prepare / ScaleTilesTo2M on it**: they'd force every tile to
scale 2 and break the fitted ones. It's ready for **Scene → Export As → MeshLibrary**.

What was done to each tile:
- Fitted to a **2×2 m** footprint, centered on the tile, bottom at Y = 0
  (1 m tiles → scale 2, the 4 m `template-floor*` → scale 0.5, offset/corner-pivot terrain pieces re-centered).
- Trimesh collision (`<name>_col` → `CollisionShape3D`, backface collision on).
- Textures, via material override:
  - `floor`, `floor-detail`, `floor-wood`, `floor-concrete` → `resources/DungeonParts/Textures/colormap.png`
  - `template-floor`, `template-floor-detail`, `template-floor-detail-a` → `resources/tile_sets/dungeon/Textures/colormap.png`
  - `terrain*` and `platform_center` use their built-in colours (no texture).
- 6-column grid, 4 m spacing.

The tiles are still GLB **instances** (like `TreeTiles.tscn`). That's fine for exporting. If you want them
embedded like `NatureTiles.tscn`, run `MakeNodesLocal.gd` (only that one) and save.

---

## CaveFloorTiles.tscn + CaveWallTiles.tscn (already prepared)

Built from `resources/tile_sets/cave/` (Kenney dungeon-kit cave re-skin, 4 m modules). Like Mesa:
**don't run Prepare / ScaleTilesTo2M on them**. Go straight to **Scene → Export As → MeshLibrary**:
- `CaveFloorTiles.tscn` → `resources/mesh_library/cave_floor_mesh_library.tres` (FloorMap)
- `CaveWallTiles.tscn` → `resources/mesh_library/cave_wall_mesh_library.tres` (WallMap)

GridMap settings for both: **cell_size (2, 2, 2), cell_center_y = false, cell_scale = 1**, no node scale.

The tiles are pre-fitted `cave-*.glb` files (generated from the originals, which are left untouched):
- **Floors** scaled ×0.5 → 2×2 m. Flat trimesh collision at y = 0.
- **Walls** scaled 0.5 × 1.0 × 0.5 → 2 m wide, ~4 m tall (camera eye height is 2.5 m, so uniform ×0.5 walls
  would only be 2 m tall and you'd see over them).
- **Solid-cell walls:** paint walls in the *blocked* cells. Each wall's rock face sits on the cell edge facing
  **+Z** by default (rotate with the GridMap keys); low rubble spills ~0.5 m into the walkable cell.
  Collision is a 2×4×2 box that stays inside the cell, so it never trips the player's 1.6 m blocking query
  in the neighbouring cell.
- One GridMap cell holds one item, so cells with several open sides use combined pieces:

| Item | Open sides |
|---|---|
| `cave-wall`, `cave-wall-b`, `cave-wall-c` | 1 (variants) |
| `cave-wall-corner` | 2 adjacent (outer corner, faces +Z and +X) |
| `cave-wall-double` | 2 opposite (1-cell divider between corridors, faces +Z and −Z) |
| `cave-wall-end` | 3 (dead-end nub, open side −Z is the solid one) |
| `cave-pillar` | 4 (free-standing column) |
| `cave-crystal-rock` | prop: blocks its cell |

Inner (concave) corners need no special piece: the two neighbouring walls meet on the corner line.

**Not included:** `corridor-corner`, `corridor-junction`, `template-corner`. Those put walls *inside* a
walkable 4 m cell (the kit's room-tile layout), which doesn't fit the 2 m solid-cell grid.

**Texture:** `resources/tile_sets/cave/Textures/colormap.png` is currently a *copy of the dungeon kit atlas*
(the cave pack's own atlas wasn't in the project). It's close, but `cave-floor-detail-a` samples a swatch
that is pink on the dungeon atlas. Overwrite that PNG with the cave pack's real `Textures/colormap.png`
and everything updates; no re-export needed.

Regenerating the fitted GLBs: the generator lives outside the project (ask Claude); the originals in
`resources/tile_sets/cave/` are the source.

---

## DungeonFloorTiles.tscn + DungeonStructureTiles.tscn (already prepared)

Built from `resources/tile_sets/dungeon/` (Kenney modular dungeon kit, **4 m modules, native scale**).
Don't run Prepare / ScaleTilesTo2M on them; go straight to **Scene → Export As → MeshLibrary**:
- `DungeonFloorTiles.tscn` → `resources/mesh_library/dungeon_floor_mesh_library.tres`
- `DungeonStructureTiles.tscn` → `resources/mesh_library/dungeon_structure_mesh_library.tres`

| Library | Item ids |
|---|---|
| floor | 0 `template-floor`, 1 `template-floor-detail`, 2 `template-floor-detail-a` |
| structure | 0 `corridor`, 1 `corridor-corner-square`, 2 `corridor-end`, 3 `corridor-junction`, 4 `corridor-intersection`, 5 `template-wall`, 6 `template-wall-detail-a`, 7 `template-wall-half`, 8 `template-wall-top`, 9 `template-wall-corner`, 10 `template-corner`, 11 `template-detail` |

**GridMap settings:** `cell_size = (4, 4, 4)`, `cell_center_y = false`, and **offset the GridMap node to
position (1, 0, 1)**. The player walks a 2 m grid; the offset puts every 4 m module centre on a 2 m cell
centre so corridor walkways (2.5 m wide, centred) line up with movement. Place room scenes on the same
rule (room centre on a 2 m cell centre).

**No collision on purpose:** movement blocking comes from an invisible 2 m nav layer (named `WallMap`, so
MapManager treats it as solid), generated from the placed pieces. Mesh collision on these irregular walls
would randomly block walkway cells through MapManager's physics check.

**`corridor-corner-square.glb`** is generated (corridor-junction + the straight corridor's side wall). The
kit's curved `corridor-corner` puts its wall through the module centre, so the camera would sit inside the
wall on the turn cell; it's left out of the library. Same reason `template-wall`/`template-corner` are
"this module is wall" pieces: their pivot is on the module edge, so the wall's back lands on the cell centre.

Textures: the GLBs use `resources/tile_sets/dungeon/Textures/colormap.png`; the scenes also override the
material with that atlas and nearest filtering (same as Mesa).

---

## BossFloorTiles.tscn + BossWallTiles.tscn (already prepared)

From `resources/tile_sets/dungeon_boss/` (same kit as the dungeon rooms, 4 m modules). Export with
**Scene → Export As → MeshLibrary**:
- `BossFloorTiles.tscn` → `resources/mesh_library/boss_floor_mesh_library.tres` (0 `floor`, 1 `floor-detail`, 2 `floor-detail-a`)
- `BossWallTiles.tscn` → `resources/mesh_library/boss_wall_mesh_library.tres` (0 `boss-wall`, 1 `boss-wall-detail`,
  2 `boss-wall-half`, 3 `boss-wall-top`, 4 `boss-wall-post`, 5 `boss-corner`, 6 `boss-column`)

The `boss-*.glb` wall pieces are **fitted copies** of the kit's template pieces. The originals pivot on their back
face (module edge), so they can't share a grid with the floor tiles. The fitted ones are centred on the 4 m cell:
default rotation = wall on the cell's **north (-Z) edge** facing into the cell (post in the NW corner, corner piece
on N + W). Rotate in the GridMap for other sides. Their floor-level faces were removed - the floor GridMap supplies
all floor (no flicker).

**GridMap settings** (both maps): `cell_size = (4, 4, 4)`, `cell_center_y = false`, node position **(2, 0, 2)** relative
to the room root. That puts module centres on multiples of 4 m, exactly like `room-large.glb`, so a room built on it
lines up with Room Large's walls and doorways. A 2 m doorway = an empty wall slot with a `boss-wall-post` in the
two outer corners of the doorway cell.

**Starter:** `Scenes/Dungeons/Parts/BossChamber.tscn` has both GridMaps pre-positioned (`BossFloor`, `BossWalls` - don't
name them FloorMap/WallMap), the DungeonRoom script, the north door marker + gate cap at Room Large's north doorway,
and `room-large.glb` as `AlignmentGuide_DeleteWhenDone`. The `Walls` collision body is empty: once the layout is
done, the wall collision gets generated from the GridMaps (same per-cell method as the other rooms).
