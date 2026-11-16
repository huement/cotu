# Boss villain cutscene (Malviathan)

The main villain appears, taunts the party and is gone again. No boss fight (yet).

## Use it in a level

1. Drag `Scenes/Enemies/Malviathan.tscn` into the level. His eyes face the scene's **+X**; the big
   `ActivationArea` box sits in front of them. Rotate / move the whole node.
2. Select the node and fill in **Cutscene Ending** in the inspector (below).
3. Give each Malviathan in the game its own **Object Id**.

In the editor the model is visible. In the game he is hidden until the party steps into the
ActivationArea footprint. His `StaticBody3D` blocks the party even while hidden.

## Cutscene Ending (on the Malviathan node)

| Setting | What it does |
|---|---|
| Speaker Name / Dialog Text / Dialog Avatar | The dialog box. Avatar empty = `resources/Lore/cube_avatar.png`. Text empty = no box. |
| After Dialog | `Nothing` / `Path 1 - Fight enemies` / `Path 3 - Travel to a level`. Only one. |
| Path 1 - Fight > Fight Enemies | Up to 4 `EnemyData` (same resources as `WorldEnemy.enemy_group`). |
| Path 2 - Drain > Drain Party + Vitals Left Percent | Works with any choice. Living members keep that % of max HP / Mana (never below 1 HP, never healed). |
| Path 3 - Travel > Travel Scene + Arrival Point | Level to wake up in, and the marker to arrive on. |
| Play Once | On = once per save (`cutscene_seen` in GameState object state). Off = every time the party walks back in. |

## What plays (order)

freeze + face him -> he appears (quake, red/black strobe) -> red vignette + camera backs away ->
cube flash + voice -> **dialog** -> fade to black -> (he vanishes, drain, travel, save) -> wake up ->
forced fight if set.

## Code map

| File | Role |
|---|---|
| `Scripts/Enemies/MalviathanController.gd` | Hidden-until-entered boss; owns the ending settings; asks for the cutscene. |
| `Scripts/Cutscenes/BossVillainCutscene.gd` | The sequence. One node in `world.tscn` (survives map swaps). Timing / camera / voice exports live here. |
| `Scripts/Cutscenes/BossCutsceneEnding.gd` | Ending data + drain maths + fight pack. Tests: `tests/cutscenes/`. |
| `Scripts/universal_popup.gd` (`BOSS_DIALOG`) | Dialog box with the avatar on the corner. |
| `Scripts/Enemies/GhostScareFX.gd` (`start_red_vignette`) | Sustained vignette. |
| `Scripts/3D/BlobBossJuice.gd` | His shader look (`rim_color`, `wobble_amount`; multi-surface models supported). |

SignalBus: `boss_cutscene_requested(id, anchor, ending)`, `boss_cutscene_villain_visible(id, shown)`,
`boss_cutscene_finished(id)`. Another boss can reuse the cutscene by emitting the first and
answering the second.
