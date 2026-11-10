# Battle System: Triggers, Arena, Formation and Combat Helpers

The single place to read how a battle **starts**, **where** it happens, **how enemies are laid out** on screen, and **which helper scripts** do the maths.
For turn-by-turn action flow and tuning knobs, see `COMBAT_README.md`.

---

## 1. The big picture

```
World enemy / boss / statue / terminal
        │  (1) can a fight start?   GameState.can_begin_encounter()
        │  (2) get the party ready  BattleArena.prepare_party()  (fade to battle room, or turn to face)
        ▼
SignalBus.combat_started(enemy_group, party_slots, facing)
        │
        ├── CombatManager        builds Combatants, runs turn meters, resolves actions
        ├── EnemyVisualManager   spawns models, places them with CombatFormation
        ├── BattleHUD            action bar, enemy header, VFX
        ├── DungeonPlayer        locks movement
        └── GameState            mode = BATTLE
        ▼
SignalBus.combat_ended(victory)     ← only CombatManager emits this
        ├── BattleArena          cuts the view back to the dungeon
        ├── EnemyVisualManager   clears models
        ├── world enemy          queue_free on victory, show() again on flee/defeat
        └── GameState            5 s post-battle cooldown
```

Everything talks through **SignalBus**. Nothing outside CombatManager emits `combat_ended`.

---

## 2. How battles are triggered

### 2a. Who emits `combat_started`

| Source | Script | How it fires |
|---|---|---|
| Dungeon / cave enemies, ghosts, `BossEnemy` | `Scripts/Enemies/enemy.gd` (`WorldEnemy`) | Party bumps into its cell, or it walks next to the party (`_check_pursuit_range`, distance ≤ 1) |
| Outdoor enemies | `Scripts/Enemies/world_enemy.gd` | Activation `Area3D` overlap or adjacency |
| Bump fallback | `Scripts/Components/GridMovementComponent.gd` | A blocked step onto an enemy cell calls its `trigger_combat_encounter()` |
| Ghost ambush | `Scripts/Enemies/GhostAmbushComponent.gd` | Ghost appears behind the party, then calls the parent `trigger_combat_encounter()` |
| Blob bosses / DungeonBoss | `Scripts/Enemies/BlobBossController.gd` | After its rise animation (`_start_combat_encounter`) |
| Rushers, tentacles, lake boss | `RushEnemyController.gd`, `TentacleBossController.gd`, `TentacleEnemyController.gd`, `LakeBossTrigger.gd` | Their own scripted triggers |
| Boss statue | `Scripts/Environment/BossStatue.gd` | Lore popup closes → fade, teleport to `fight_start`, boss rises |
| Battle test terminal | `Scripts/Environment/BattleConfigTerminal.gd` | Menu confirm → fade, teleport, fight |
| Debug | `Scripts/Testing/BattleTest.gd` | Direct emit |

### 2b. The guard: `GameState.can_begin_encounter()`

A fight is refused while any of these is true:
- `encounter_lock_timer > 0`: set by `lock_encounters(seconds)` during scripted moves (turning, fading, statues).
- `post_combat_immunity_timer > 0`: 5 s after **any** battle ends (`POST_BATTLE_COOLDOWN`).
- `awaiting_victory_screen`: from a win until the victory popup closes, plus 3 s more.
- `CombatManager.is_combat_active` or `is_transitioning_out`.

Each enemy also has its own `_is_in_active_combat` flag so it can't trigger twice.

### 2c. `WorldEnemy.trigger_combat_encounter()` step by step

1. Bail if already fighting or the guard says no.
2. Ghost check: an ambush ghost only fights through its ambush.
3. `_is_in_active_combat = true`.
4. `await BattleArena.prepare_party(get_tree(), global_position)` (see §3).
5. If another fight started meanwhile, undo and stop.
6. `hide()` the world model.
7. Emit `combat_started(enemy_group, GameState.current_party.slots, facing)`.

`BossEnemy` also calls `GameState.register_boss_rewards(books, crystals)` first.

### 2d. The enemy pack (`enemy_group`)

Built in `WorldEnemy._setup_enemy_group()`:
- Uses `enemy_group` from the inspector if it's filled in.
- Otherwise it duplicates `data` / `enemy_data` `pack_size` times (1–6).
- `stat_multiplier` (per placed enemy) scales HP / ATK / magic / MP / XP / gold. Defense only moves ¼ as much.
- `BossEnemy`: minions left, boss in the middle, minions right. The boss copy is marked with `CombatFormation.mark_boss()`.

---

## 3. Where the battle happens

### 3a. Dungeons: the battle room (`Scripts/Managers/BattleArena.gd`)

Dungeon corridors are too tight to fit a pack, so dungeon fights move to `Scenes/Dungeons/DungeonBattle.tscn`.

- **When:** the map root is a `DungeonLevel`, or has root metadata `use_battle_room = true`. Set it to `false` to turn it off for one map.
- **Not when:** the party stands on a `BossChamber`'s `BossFloor`. That room is big enough, so the fight stays there.
- **Enter:** fade to black (0.25 s) → wait for any step/turn tween to finish → `DungeonPlayer.enter_battle_view(pos, yaw)` on the room's `SpawnPoint` marker (looking along its −Z) → fade in (0.35 s) while the battle opens.
- **Leave:** on `combat_ended` the view cuts to black, `leave_battle_view()` puts it back on the party's cell, then fades in.
- **The party never leaves its grid cell.** Only the Player node's transform moves (`battle_position_override`). `current_grid_pos`, saves and dungeon enemies are untouched.
- The room is instanced once per map as a hidden child called `BattleArena`, 2000 m away from the level.

Editing the room: keep **Center Y off** on both GridMaps (like BossChamber), keep `SpawnPoint` facing the open space, and leave about 4 m of clear floor in front of it.

### 3b. Everywhere else: `BattleFacing.orient_party()` + `BattleSpaceClearance`

Outdoor maps, caves and boss chambers fight in place. The party turns on the spot to face the enemy's cell (always open floor). If the enemy is on the party's own cell, it turns to the first open direction. A full about-face gets a quick dip to black.

After facing, `BattleSpaceClearance.ensure_space()` (`Scripts/Managers/BattleSpaceClearance.gd`) shoves trees / wall-chunk props / StaticBody clutter out of a forward box (~8 m deep × 8 m wide) so combat models don't clip into the scenery. Cleared GridMap wall cells and moved nodes are restored on `combat_ended`. Dungeon battle-room fights skip this. Opt out per map with root metadata `use_battle_clearance = false`.

### 3c. Scripted arenas

`BossStatue` and `BattleConfigTerminal` fade out, `teleport_to(fight_start, look_at)`, then fade in. That puts the party on a real grid cell, so they don't use the battle room.

---

## 4. How enemies are arranged on screen

### 4a. `EnemyVisualManager` (`Scripts/3D/EnemyVisualManager.gd`)

On `combat_started`:
1. Resolves the payload into `enemy_group` (an array of EnemyData).
2. Gets formation slots from `CombatFormation.get_best_slots(enemy_group)`.
3. Spawns each `EnemyData.model_scene` (or a red debug box) as its child, ids `enemy_0`, `enemy_1`, …
   - Enemies with `combat_uses_world_node` / meta `use_world_combat_model` (blob bosses) skip this. Their own world model is used.
4. Lays them out, then again next frame, at 0.25 s and at 0.6 s, so the camera has settled after a turn or fade.

### 4b. `CombatFormation` (`Scripts/3D/CombatFormation.gd`)

Five slots, seen from the camera (farther away = front row):

```
        [2]     [1]     [3]        ← front row (forward_distance)
            [4]     [5]            ← back row (back_row_pull closer)

                 📷 party
```

Slot 1 is front centre and is reserved for a solo enemy or the boss.

| Pack size | No boss | With boss (`combat_is_boss` meta) |
|---|---|---|
| 1 | 1 | 1 |
| 2 | 2, 3 | boss 1, other 2 |
| 3 | 2, 1, 3 (left / centre / right) | boss 1, others 2, 3 |
| 4 | 2, 1, 3, 4 | boss 1, others 2, 3, 4 |
| 5+ | 2, 1, 3, 4, 5 (extras stack on 5) | boss 1, others 2, 3, 4, 5 (extras on 5) |

`slot_offset(slot, spacing, back_pull)` → `Vector2(lateral, depth_delta)`:

| Slot | lateral | depth |
|---|---|---|
| 1 | 0 | 0 |
| 2 | −spacing | 0 |
| 3 | +spacing | 0 |
| 4 | −spacing/2 | −back_pull |
| 5 | +spacing/2 | −back_pull |

Tests: `tests/combat/test_combat_formation.gd`.

### 4c. Placement maths (`_position_enemy`)

```
distance = (EnemyData.combat_forward_distance > 0 ? that : forward_distance 3.4) + depth
position = camera.origin
         − camera.basis.z × distance          (in front)
         + camera.basis.x × lateral           (sideways)
         + camera.basis.y × vertical_offset   (EnemyData.vertical_offset or −0.85,
                                               + map SpawnPoint meta "battle_vertical_offset")
scale    = EnemyData.model_scale (default 0.4 if zero)
```

Then the model looks at the camera (flat), turns by `combat_yaw_offset_degrees` (180 by default, 0 for meshes that already face +Z), and `_push_back_from_camera()` pushes it away until no part of its mesh is closer than `min_camera_clearance` (1.8 m).

Inspector knobs on EnemyVisualManager: `forward_distance`, `vertical_offset`, `min_camera_clearance`, `model_scale`, `formation_spacing` (1.8), `back_row_pull` (0.75).
Per enemy (EnemyData / `Data/Enemies.csv`): `model_scale`, `combat_forward_distance`, `combat_yaw_offset_degrees`, `vertical_offset`.

**Models sunk into the floor or lying down** usually mean the GLB isn't Y-up or has its origin in the middle. Wrap it in a small scene that rotates/raises it and point `model_scene` at that. Examples: `Scenes/Enemies/SlimeDroneModel.tscn`, `Scripts/Utilities/blobby_post_import.gd`.

---

## 5. The combat helpers (`Scripts/Combat/`)

CombatManager owns state, logging and signals. The formulas live in these small, static, scene-free scripts. **Change a formula here and update its test in `tests/combat/`** (GUT; shared fixtures in `combat_fixtures.gd`).

### `Combatant.gd`: one fighter
Built by CombatManager at battle start; **stats are snapshotted** then.

| Field | Meaning |
|---|---|
| `id` | `"party_<slot>"`-style for players, `"enemy_<i>"` for enemies |
| `speed`, `meter` | Base speed (with gear) and turn meter 0–100 |
| `strength`, `defense` | Players: STR + all gear `attack_bonus`; base def + gear `defense_bonus`. Enemies: `attack_damage`, `defense` |
| `is_front_row`, `slot_index` | Row rules and HUD slot |
| `weapon_attack` | Part of strength from hand weapons (dropped when unarmed / out of ammo) |
| `element_resists`, `weakness` | Resist fraction per element (max 0.9); weakness element |
| `spell_amplify`, `pierce`, `on_hit_statuses` | Gear specials |
| `can_cast_spells`, `spells`, `magic_power`, `attack_type` | Enemy casting and attack type |
| `active_effects` | Array of `ActiveEffect` |

Methods: `add_effect` (same id refreshes duration/value), `get_effective_stat` (flat `STAT_BUFF` first, then % `STAT_PCT`), `get_stat_multiplier` (magic / accuracy), `get_effective_attack/defense/speed`, `get_resist`, `absorb_with_shields` (SHIELD soaks everything, MAGIC_SHIELD soaks spells; empty shields are removed), `get_negative_status_names`.
Tests: `test_combatant.gd`.

### `ActiveEffect.gd`: one buff / debuff / DoT
`effect_type` is one of `STAT_BUFF`, `STAT_PCT`, `DOT`, `HOT`, `SHIELD`, `MAGIC_SHIELD`, `SKIP_TURN`, `LOCK_MAGIC`.
`stat_target`: `strength`, `defense`, `speed`, `magic`, `accuracy`, `dexterity`.
`duration` counts the **affected** combatant's turns.

### `CombatMath.gd`: formulas
| Function | What |
|---|---|
| `physical_damage` | `max(1, ATK − DEF×(1−pierce))` × 0.5 back-row melee attacker × 0.5 back-row target × 0.5 guarding × weakness × (1 − resist). Unarmed drops weapon attack and pierce. |
| `ability_power` | `calculate_potency(stat)`: player uses the ability's `stat_scaling` attribute (default INT, with gear), enemy uses `magic_power`. Spells × magic buffs × amplify. Else `effect_amount` → `base_amount` → 10. |
| `ability_damage` | Spells: × weakness (MAGIC, or LIFE for life spells) × (1 − magic resist); ignore DEF/rows/guard. Skills: × row × guard × weakness × (1 − element resist); ignore DEF. |
| `ability_duration` | `duration` × spell `tier`, min 1 |
| `next_meter` | `meter + speed × tick_rate × delta`, capped |
| `flee_chance` | `base + (party speed − enemy avg) × 0.05`, clamped 0.15–0.95 |
| `average_speed` | Living members of one side |
| `throw_hit_chance` / `throw_crit_chance` / `throw_damage` | Thrown items: DEX vs target speed (40–98%), crit DEX×1% (max 35%, ×1.5), half armour, rows ignored |
| Helpers | `attack_type_from_element`, `element_for_attack_type`, `effective_attack_type_for_character` (RANGED with no ammo → BASH), `is_weak_to`, `as_fraction`, `cat_attribute`, `modifier_stat_name` |

Constants at the top (`ROW_GUARD_MULT`, `FLEE_*`, `THROW_*`) are the tuning.
Tests: `test_combat_math.gd`.

### `CombatTargeting.gd`: who gets hit
- `pick_opponent`: party → chosen `enemy_<index>` if alive, else the first living enemy. Enemies → a random living party member.
- `resolve_ability_targets` by `target_type` (0 SINGLE_ENEMY, 1 ALL_ENEMY, 2 SINGLE_ALLY, 3 ALL_ALLY, 4 SELF, 5 NONE):
  - ALL_*: the whole living side (dead allies too when `allow_dead_ally`, for revives).
  - SINGLE_ALLY: party picks a slot; enemies pick their lowest-HP ally; falls back to the caster.
  - SELF / NONE: the caster.
- `find_by_id`, `find_by_slot`, `living`.

Tests: `test_combat_targeting.gd`.

### `AbilityInfo.gd`: reading SpellData / SkillData
`category` (DAMAGE / HEAL / BUFF / DEBUFF / UTILITY), `display_name`, `id`, `status_id` ("" for empty / NONE), `hit_verb` for the log (SHOT / SLASHED / BASHED / BLASTED).
Tests: `test_ability_info.gd`.

---

## 6. During and after the fight (short version)

- Meters fill each frame; at 100 the combatant queues. Meters freeze while a player picks an action and while any action plays out.
- Party turn → `combatant_turn_ready` → HUD → `player_action_selected(slot, action, target)`.
- Enemy turn → spell (if it casts and rolls under `enemy_spell_chance`) or physical attack; `enemy_attack_started` drives its animation.
- After every action and DoT tick CombatManager checks for a win, loss or flee, then emits `combat_ended(victory)` once. Flee and defeat both send `false`.

Full detail: `COMBAT_README.md`.

---

## 7. Where to change what

| I want to… | Change |
|---|---|
| Stop fights starting too soon after another | `GameState.POST_BATTLE_COOLDOWN` |
| Use / skip the battle room on a map | Root metadata `use_battle_room` |
| Redesign the dungeon battle room | `Scenes/Dungeons/DungeonBattle.tscn` (`SpawnPoint`, lights, props) |
| Move an enemy closer / bigger in battle | `EnemyData.combat_forward_distance`, `model_scale`, `vertical_offset` |
| Spread enemies wider | EnemyVisualManager `formation_spacing`, `back_row_pull` |
| Change slot order / boss placement | `CombatFormation.get_best_slots` + its test |
| Change damage, flee, throw maths | `CombatMath.gd` + `test_combat_math.gd` |
| Change who an ability hits | `CombatTargeting.gd` + its test |
| Battle tempo, windups, weakness ×1.5 | CombatManager inspector (see `COMBAT_README.md` §8) |
