# Enemy Roster by Level

Every level, the enemies placed in it, and what they fight with. Generated from the level scenes and `Data/Enemies/*.tres` on 2026-11-14 — rerun the scan after big changes (ask Claude to regenerate it).

**Columns**
- **Level** — `base_level` on the enemy data (for blob bosses: `boss_level` on the scene).
- **HP / Speed / Attack** — what the enemy actually has in this level, after any per-placement `stat_multiplier` (WorldEnemy / BossEnemy only) or blob-boss level and size scaling.
- **Battle ATK** — Attack × the level damage band CombatManager applies (L1–3 ×1.2, L4–6 ×1.4, L7+ ×1.5). This is the number that hits the party, before the party's defense.
- **Pack** — enemies per fight from that placement (a range of placements is shown as e.g. `2, 3`).
- **Placed** — how many separate placements of it the level has.

## Does raising LEVEL make an enemy tougher?

**Yes (since 2026-11-15).** The CSV / `.tres` numbers are now an enemy's **level-1** stats, and its level grows them in battle (`CombatMath.apply_enemy_level`):

| Per level above 1 | HP | Attack / magic | Defense | Speed / initiative | Mana | XP / gold |
|---|---|---|---|---|---|---|
| growth | +20% | +15% | +10% | +4% | +10% | +30% |

So a level-6 enemy has 2× the HP and 1.75× the attack of its level-1 sheet. The old ×1.2 / ×1.4 / ×1.5 attack bands are gone.

**Three ways to set a level:**
- **Everywhere:** `base_level` in `Data/Enemies.csv` (then run `EnemyCompiler.gd`, or edit the `.tres`).
- **One placement:** `level` on a placed WorldEnemy / BossEnemy (0 = the sheet's level). Applies to the whole pack. Dungeon generators take `"level"` per enemy type and on `boss_enemy`.
- **Blob bosses:** `boss_level` on the scene. **0 (new default) = the sheet's level.** The Slime Lord had no level set, so it used to fight at level 1; it now fights at its sheet level 8. Blob bosses use the same growth rates (their *Level Scaling* exports default to the game-wide rates).

`stat_multiplier` still works on top of level, for one-off tweaks.

**The tables below were generated before the rework.** Effective numbers are unchanged for most enemies (their sheets were converted to level-1 values); see *Rework 2026-11-15* at the end for the ones that changed. Regenerate the tables to see the new values.

## Overworld
### GreenGrove
No enemies on the first visit. `ReturnVisitEnemySpawner` counts the visit and, the next time the party enters, spawns 3 Slime Drones away from the new-game spawn.
### VeroWood

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Lurking Tentacle | 3 | 60 | 11.0 | 12 | 14 | 2 | 3 | `EnLakeTentacle.tres` |
| Sea Monster | 5 | 230 | 12.0 | 20 | 28 | 1 | 1 | `EnLakeMonster.tres` |
| Marsh Crab | 1 | 22 | 10.0 | 6 | 7 | 2 | 4 | `EnMarshCrab.tres` |

### StoneTrail

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Minotaur | 4 | 108 | 11.0 | 28 | 39 | 1 | 3 | `MinotaurBase.tres` |
| Pulsing Sac | 1 | 180 | 11.0 | 30 | 36 | - | 7 | Boss, size x3.0, level from scene |
| Pulsing Sac | 5 | 324 | 12.3 | 44 | 62 | - | 1 | Boss, size x3.0, level from scene |
| Pulsing Sac | 2 | 72 | 11.3 | 11 | 13 | 2 | 1 | Boss minion (x2) |
| Enraged Azurian | 1 | 55 | 11.0 | 19 | 23 | 2, 3 | 3 | Rusher (charges the party) |

### FeroShaw

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Minotaur | 4 | 108 | 11.0 | 28 | 39 | 1 | 3 | `MinotaurBase.tres` |

### GloomReach

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Minotaur | 4 | 108 | 11.0 | 28 | 39 | 1 | 2 | `MinotaurBase.tres` |
| Corrupted | 2 | 55 | 10.0 | 12 | 14 | 2, 3 | 3 | `EnZombieCat.tres` |
| Feral Beast | 4 | 110 | 13.0 | 22 | 31 | 2, 3 | 4 | `EnBeast.tres` |
| Corrupted Punk | 4 | 75 | 12.0 | 20 | 28 | 2 | 3 | `EnZombiePunk.tres` |
| Corruptodon | 5 | 52 | 14.0 | 9 | 13 | 2, 3 | 3 | `EnZombieSaber.tres` |
| Enraged Azurian | 1 | 55 | 11.0 | 19 | 23 | 1 | 4 | Rusher (charges the party) |
| Slime Lord | 1 | 320 | 14.0 | 26 | 31 | - | 1 | Boss, size x4.0, level from scene |
| Hazard Cleaner | 5 | 70 | 12.0 | 18 | 25 | 1 | 1 | pack: EnCorruptedRonin + EnHazardCleaner |
| Enraged Azurian | 1 | 55 | 11.0 | 19 | 23 | - | 1 | Ambush spawner (FloorTileAmbushSpawner) |

### BrokenBoneMarsh

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Marsh Stalker | 4 | 75 | 12.0 | 20 | 28 | - | 1 | Ambush spawner (MarshTreeAmbushSpawner) |
| Beast King | 7 | 484 | 17.7 | 31 | 46 | - | 1 | Boss, size x2.6, level from scene |

### CastleHollow
Not built yet.

## Caves
### WindmillCave1

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Slime Drone | 1 | 18 | 10.0 | 4 | 5 | 3 | 2 | `EnSlimeDrone.tres` |
| Scavenger Cyclops | 1 | 54 | 10.0 | 7 | 8 | 1 | 2 | stat_multiplier x0.9 |
| Marsh Crab | 1 | 20 | 10.0 | 5 | 6 | 3 | 1 | stat_multiplier x0.9 |
| Ghost | 3 | 120 | 15.0 | 18 | 22 | 1 | 1 | stat_multiplier x0.6 |

### WindmillCave2

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Scavenger Cyclops | 1 | 60 | 10.0 | 8 | 10 | 2, 3 | 2 | `EnScavengerCyclops.tres` |
| Slime Drone | 1 | 18 | 10.0 | 4 | 5 | 2, 4 | 2 | `EnSlimeDrone.tres` |
| Corrupted | 2 | 38 | 10.0 | 8 | 10 | 1 | 1 | stat_multiplier x0.7 |
| Marsh Crab | 1 | 22 | 10.0 | 6 | 7 | 2 | 1 | `EnMarshCrab.tres` |
| Ghost | 3 | 150 | 15.0 | 23 | 28 | 1 | 2 | stat_multiplier x0.75 |

### CaveLevel1

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Savage Corrupted | 3 | 80 | 11.0 | 18 | 22 | 2 | 2 | `EnZombieSavage.tres` |
| Ghost | 3 | 130 | 15.0 | 20 | 24 | 1 | 1 | stat_multiplier x0.65 |

### CaveLevel2

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Savage Corrupted | 3 | 80 | 11.0 | 18 | 22 | 2 | 2 | `EnZombieSavage.tres` |
| Corrupted Guard | 4 | 75 | 12.0 | 20 | 28 | 2 | 1 | `EnZombieGuard.tres` |
| Ghost | 3 | 160 | 15.0 | 24 | 29 | 1 | 1 | stat_multiplier x0.8 |

### CaveLevel3

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Corrupted Guard | 4 | 75 | 12.0 | 20 | 28 | 2 | 2 | `EnZombieGuard.tres` |
| Corrupted Knight | 4 | 95 | 12.0 | 25 | 35 | 2 | 2 | `EnZombieKnight.tres` |
| Ghost | 3 | 200 | 15.0 | 30 | 36 | 1 | 2 | `EnGhost.tres` |

### BrokenBoneMarshCave

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Marsh Crab | 1 | 22 | 10.0 | 6 | 7 | 2, 3, 4 | 10 | `EnMarshCrab.tres` |
| Ghost | 3 | 180 | 15.0 | 27 | 32 | 1 | 2 | stat_multiplier x0.9 |


## Dungeons
### DungeonLevel1_Upper

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Corrupted Guard | 4 | 75 | 12.0 | 20 | 28 | 2 | 2 | `EnZombieGuard.tres` |
| Corrupted Knight | 4 | 95 | 12.0 | 25 | 35 | 2 | 2 | `EnZombieKnight.tres` |
| Corruptodon | 5 | 52 | 14.0 | 9 | 13 | 2 | 1 | `EnZombieSaber.tres` |

### DungeonLevel1
- **Boss chamber:** Corrupted Blob (`BlobCorrupt.tscn`, Bosses.csv row 1: level 2, size 1.5)

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Corrupted Guard | 4 | 75 | 12.0 | 20 | 28 | 2 | 2 | `EnZombieGuard.tres` |
| Corrupted Knight | 4 | 95 | 12.0 | 25 | 35 | 2 | 2 | `EnZombieKnight.tres` |
| Corruptodon | 5 | 52 | 14.0 | 9 | 13 | 2 | 2 | `EnZombieSaber.tres` |

### DungeonLevel2
- **Boss chamber:** `BlobCorrupt.tscn` (Bosses.csv row 2 is mostly blank: level 1, size 1.5)

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Corrupted Guard | 4 | 75 | 12.0 | 20 | 28 | 2 | 2 | `EnZombieGuard.tres` |
| Corrupted Knight | 4 | 95 | 12.0 | 25 | 35 | 2 | 2 | `EnZombieKnight.tres` |
| Corruptodon | 5 | 52 | 14.0 | 9 | 13 | 2 | 2 | `EnZombieSaber.tres` |

### FeroShawDungeon_Upper

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Ghost | 3 | 120 | 15.0 | 18 | 22 | 1 | 2 | stat_multiplier x0.6 |
| Slime Drone | 1 | 18 | 10.0 | 4 | 5 | 2 | 2 | `EnSlimeDrone.tres` |
| Scavenger Cyclops | 1 | 60 | 10.0 | 8 | 10 | 2 | 2 | `EnScavengerCyclops.tres` |
| Corrupted | 2 | 44 | 10.0 | 10 | 12 | 1 | 2 | stat_multiplier x0.8 |
| Rage Wraith | 2 | 56 | 13.0 | 10 | 12 | 1 | 1 | stat_multiplier x0.8 |

### FeroShawDungeon
- **Boss chamber:** Bosses.csv row 11 has no boss scene: the chamber's own `Boss` node (below) is the fight

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Corrupted Knight | 4 | 229 | 12.0 | 61 | 85 | 1 | 1 | stat_multiplier x1.5, then boss x1.6. Two Corrupted Punk minions |
| Corrupted Punk | 4 | 113 | 12.0 | 30 | 42 | 1 | 2 | Boss minion (x2), stat_multiplier x1.5 |
| Ghost | 3 | 120 | 15.0 | 18 | 22 | 1 | 2 | stat_multiplier x0.6 |
| Corrupted | 2 | 44 | 10.0 | 10 | 12 | 2 | 2 | stat_multiplier x0.8 |
| Scavenger Cyclops | 1 | 60 | 10.0 | 8 | 10 | 2 | 2 | `EnScavengerCyclops.tres` |
| Rage Wraith | 2 | 56 | 13.0 | 10 | 12 | 2 | 1 | stat_multiplier x0.8 |
| Slime Drone | 1 | 18 | 10.0 | 4 | 5 | 3 | 1 | `EnSlimeDrone.tres` |

### VeroWoodDungeon_Upper

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Ghost | 3 | 150 | 15.0 | 23 | 28 | 1 | 2 | stat_multiplier x0.75 |
| Savage Corrupted | 3 | 80 | 11.0 | 18 | 22 | 2 | 2 | `EnZombieSavage.tres` |
| Scavenger Cyclops | 1 | 60 | 10.0 | 8 | 10 | 2 | 2 | `EnScavengerCyclops.tres` |
| Rage Wraith | 2 | 63 | 13.0 | 11 | 13 | 1 | 2 | stat_multiplier x0.9 |
| Corrupted Guard | 4 | 75 | 12.0 | 20 | 28 | 2 | 1 | `EnZombieGuard.tres` |

### VeroWoodDungeon
- **Boss chamber:** Bosses.csv row 12 has no boss scene: the chamber's own `Boss` node (below) is the fight

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Hazard Cleaner | 5 | 210 | 12.0 | 54 | 76 | 1 | 1 | stat_multiplier x1.5, then boss x2.0. Two Corrupted Punk minions |
| Corrupted Punk | 4 | 113 | 12.0 | 30 | 42 | 1 | 2 | Boss minion (x2), stat_multiplier x1.5 |
| Ghost | 3 | 150 | 15.0 | 23 | 28 | 1 | 2 | stat_multiplier x0.75 |
| Rage Wraith | 2 | 70 | 13.0 | 12 | 14 | 2 | 2 | `EnRageWraith.tres` |
| Corruptodon | 5 | 52 | 14.0 | 9 | 13 | 2 | 2 | `EnZombieSaber.tres` |
| Scavenger Cyclops | 1 | 66 | 10.0 | 9 | 11 | 2 | 1 | stat_multiplier x1.1 |
| Oculat Striker | 3 | 60 | 13.0 | 12 | 14 | 1 | 1 | `EnOculatStriker.tres` |


## Testbed (not part of the world)
### dungeon_map

| Enemy | Level | HP | Speed | Attack | Battle ATK | Pack | Placed | Notes |
|---|---|---|---|---|---|---|---|---|
| Savage Corrupted | 3 | 80 | 11.0 | 18 | 22 | 1, 2 | 2 | `EnZombieSavage.tres` |
| Rage Wraith | 2 | 70 | 13.0 | 12 | 14 | 2 | 1 | Boss (+2 minions) |
| Scavenger Cyclops | 1 | 60 | 10.0 | 8 | 10 | 2 | 1 | Boss minion (x2) |
| Scavenger Cyclops | 1 | 60 | 10.0 | 8 | 10 | 1 | 1 | pack: EnScavengerCyclops + EnZombieSaber |
| Ghost | 3 | 200 | 15.0 | 30 | 36 | 1 | 3 | `EnGhost.tres` |
| Corrupted Bio-Unit | 1 | 30 | 10.0 | 8 | 10 | 1 | 1 | `ZombieCat_Base.tres` |
| Oculat Striker | 3 | 60 | 13.0 | 12 | 14 | 4 | 1 | `EnOculatStriker.tres` |
| Azurian Drone | 1 | 55 | 10.0 | 15 | 18 | 1 | 1 | `EnAzurianDrone.tres` |


## Every enemy data file

The sheet values (`Data/Enemies/*.tres`, compiled from `Data/Enemies.csv` where a row exists). Edit these to change an enemy everywhere.

| File | Enemy | Level | HP | Speed | Attack | Defense | XP | Found in |
|---|---|---|---|---|---|---|---|---|
| `EnAzurianDrone.tres` | Azurian Drone | 1 | 55 | 10.0 | 15 | 9 | 100 | dungeon_map |
| `ZombieCat_Base.tres` | Corrupted Bio-Unit | 1 | 30 | 10.0 | 8 | 2 | 50 | dungeon_map |
| `EnEnragedAzurian.tres` | Enraged Azurian | 1 | 55 | 11.0 | 19 | 10 | 125 | GloomReach, StoneTrail |
| `EnMarshCrab.tres` | Marsh Crab | 1 | 22 | 10.0 | 6 | 2 | 15 | BrokenBoneMarshCave, VeroWood, WindmillCave1, WindmillCave2 |
| `EnScavengerCyclops.tres` | Scavenger Cyclops | 1 | 60 | 10.0 | 8 | 7 | 80 | FeroShawDungeon, FeroShawDungeon_Upper, VeroWoodDungeon, VeroWoodDungeon_Upper, WindmillCave1, WindmillCave2, dungeon_map |
| `EnSlimeDrone.tres` | Slime Drone | 1 | 18 | 10.0 | 4 | 0 | 36 | FeroShawDungeon, FeroShawDungeon_Upper, WindmillCave1, WindmillCave2 |
| `EnZombieCat.tres` | Corrupted | 2 | 55 | 10.0 | 12 | 6 | 110 | FeroShawDungeon, FeroShawDungeon_Upper, GloomReach, WindmillCave2 |
| `EnRageWraith.tres` | Rage Wraith | 2 | 70 | 13.0 | 12 | 5 | 140 | FeroShawDungeon, FeroShawDungeon_Upper, VeroWoodDungeon, VeroWoodDungeon_Upper, dungeon_map |
| `EnGhost.tres` | Ghost | 3 | 200 | 15.0 | 30 | 8 | 240 | BrokenBoneMarshCave, CaveLevel1, CaveLevel2, CaveLevel3, FeroShawDungeon, FeroShawDungeon_Upper, VeroWoodDungeon, VeroWoodDungeon_Upper, WindmillCave1, WindmillCave2, dungeon_map |
| `EnLakeTentacle.tres` | Lurking Tentacle | 3 | 60 | 11.0 | 12 | 6 | 142 | VeroWood |
| `EnOculatStriker.tres` | Oculat Striker | 3 | 60 | 13.0 | 12 | 12 | 120 | VeroWoodDungeon, dungeon_map |
| `EnBlob.tres` | Pulsing Sac | 3 | 60 | 11.0 | 10 | 10 | 150 | StoneTrail | |
| `EnZombieSavage.tres` | Savage Corrupted | 3 | 80 | 11.0 | 18 | 10 | 150 | CaveLevel1, CaveLevel2, VeroWoodDungeon_Upper, dungeon_map |
| `EnZombieGuard.tres` | Corrupted Guard | 4 | 75 | 12.0 | 20 | 15 | 200 | CaveLevel2, CaveLevel3, DungeonLevel1, DungeonLevel1_Upper, DungeonLevel2, VeroWoodDungeon_Upper |
| `EnZombieKnight.tres` | Corrupted Knight | 4 | 95 | 12.0 | 25 | 15 | 260 | CaveLevel3, DungeonLevel1, DungeonLevel1_Upper, DungeonLevel2, FeroShawDungeon |
| `EnZombiePunk.tres` | Corrupted Punk | 4 | 75 | 12.0 | 20 | 15 | 200 | FeroShawDungeon, GloomReach, VeroWoodDungeon |
| `EnBeast.tres` | Feral Beast | 4 | 110 | 13.0 | 22 | 7 | 260 | GloomReach |
| `EnMarshStalker.tres` | Marsh Stalker | 4 | 75 | 12.0 | 20 | 15 | 200 | BrokenBoneMarsh |
| `MinotaurBase.tres` | Minotaur | 4 | 108 | 11.0 | 28 | 10 | 300 | FeroShaw, GloomReach, StoneTrail |
| `EnZombieSaber.tres` | Corruptodon | 5 | 52 | 14.0 | 9 | 3 | 120 | DungeonLevel1, DungeonLevel1_Upper, DungeonLevel2, GloomReach, VeroWoodDungeon |
| `EnHazardCleaner.tres` | Hazard Cleaner | 5 | 70 | 12.0 | 18 | 6 | 135 | GloomReach, VeroWoodDungeon |
| `EnLakeMonster.tres` | Sea Monster | 5 | 230 | 12.0 | 20 | 10 | 500 | VeroWood |
| `EnCorruptedRonin.tres` | Corrupted Ronin | 6 | 85 | 14.0 | 22 | 7 | 160 | GloomReach (in a mixed pack) |
| `EnShadowAssassin.tres` | Shadow Assassin | 6 | 75 | 16.0 | 24 | 4 | 175 | _not placed_ |
| `EnBeastKing.tres` | Beast King | 7 | 220 | 15.0 | 18 | 7 | 666 | BrokenBoneMarsh |
| `EnHeavyServitor.tres` | Heavy Servitor | 7 | 110 | 13.0 | 25 | 10 | 220 | _not placed_ |
| `EnVoidWeaver.tres` | Void Weaver | 7 | 80 | 15.0 | 14 | 5 | 200 | _not placed_ |
| `EnArchanistHusk.tres` | Archanist Husk | 8 | 95 | 15.0 | 18 | 6 | 280 | _not placed_ |
| `EnPlasmaSentinel.tres` | Plasma Sentinel | 8 | 100 | 14.0 | 28 | 8 | 250 | _not placed_ |
| `EnSlimeLord.tres` | Slime Lord | 8 | 320 | 14.0 | 26 | 12 | 1800 | GloomReach |
| `EnDreadGolem.tres` | Dread Golem | 9 | 140 | 14.0 | 32 | 12 | 320 | _not placed_ |
| `EnCyberLichPrime.tres` | Cyber Lich Prime | 10 | 160 | 17.0 | 25 | 9 | 400 | _not placed_ |

## Problems found while building this

- **Level doesn't track difficulty.** Corruptodon is level 5 with 52 HP / 9 attack, weaker than level-2 Corrupted (55 / 12). Scavenger Cyclops is level 1 but the main enemy in two dungeons. Level and stats were tuned separately.
- **The Sea Monster boss (230 HP, battle ATK 28)** is weaker than the level-5 Pulsing Sac in Stone Trail (324 HP, ATK 62), and only a bit tougher than the 7 ordinary Pulsing Sacs there (180 HP).
- **Dungeon bosses.** Fero Shaw is a Corrupted Knight (about 229 HP, battle attack 85) with two Corrupted Punks. Vero Wood is a Hazard Cleaner (about 210 HP, battle attack 76) with two Corrupted Punks. Minions use the pack multiplier only; the boss is scaled again.
- **`dungeon_map.tscn`** is a testbed. It is not linked from the world.

## Rework 2026-11-15: level drives difficulty

Done. Code: `CombatMath.apply_enemy_level` (+ `ENEMY_*_GROWTH`), `CombatManager._build_enemy_combatant`, `BlobBossController` (`boss_level` 0 = sheet level, shared rates), `WorldEnemy.level`, `DungeonFloorBuilder` (`"level"`), `BattleHUD` (starting HP bar). Tests: `tests/combat/test_combat_math.gd`.

Data: every sheet was converted to level-1 stats so each enemy keeps its battle strength, except enemies that were far below their level. Those were raised to at least 75% of a normal enemy of that level (normal = 55 HP / 16 attack at level 1, grown by the rates above). The Ghost, swarm fodder (Slime Drone, Marsh Crab) and the blob bosses were kept as they were. `Data/Enemies.csv` is the single source again: the Marsh Crab's hand-tuned values were copied back into it, and new columns `magic_power` and `combat_camera_pushback` keep the Ghost's magic and the Sea Monster's camera setting when the compiler runs.

Changed in battle (HP / battle attack / XP at the enemy's level, before → after):

| Enemy | Level | HP | Attack | XP | Why |
|---|---|---|---|---|---|
| Pulsing Sac | 3 → 1 | 60 → 60 | 12 → 12 | 150 → 150 | blob (Pulsing Sac / Corrupted Blob) - level 3->1 so the scenes stay as they are |
| Scavenger Cyclops | 1 → 1 | 60 → 64 | 10 → 10 | 80 → 86 | raised x1.15 power (was 0.65 of a normal level-1) |
| Corrupted | 2 → 2 | 55 → 59 | 14 → 15 | 110 → 118 | raised x1.15 power (was 0.65 of a normal level-2) |
| Lurking Tentacle | 3 → 3 | 60 → 71 | 14 → 17 | 142 → 168 | raised x1.39 power (was 0.54 of a normal level-3) |
| Oculat Striker | 3 → 3 | 60 → 71 | 14 → 17 | 120 → 141 | raised x1.39 power (was 0.54 of a normal level-3) |
| Hazard Cleaner | 5 → 5 | 70 → 81 | 25 → 29 | 135 → 157 | raised above every regular level-4 enemy |
| Sea Monster | 5 → 5 | 230 → 400 | 28 → 42 | 500 → 649 | boss buff: now above the level-5 Pulsing Sac |
| Corruptodon | 5 → 5 | 52 → 99 | 13 → 24 | 120 → 231 | was 0.26 of a normal level-5; raised above every regular level-4 enemy |
| Void Weaver | 7 → 7 | 80 → 103 | 21 → 27 | 200 → 258 | raised x1.64 power (was 0.46 of a normal level-7) |
| Archanist Husk | 8 → 8 | 95 → 108 | 27 → 31 | 280 → 316 | raised x1.27 power (was 0.59 of a normal level-8) |
| Slime Lord | 8 → 8 | 320 → 379 | 31 → 37 | 1800 → 1801 | now fights at its level 8 (was level 1 by accident); a bit tougher |
| Cyber Lich Prime | 10 → 10 | 160 → 179 | 38 → 42 | 400 → 451 | was weaker than the level-9 Dread Golem |

Everything else: same strength as before, new level-1 sheet numbers. Level-1 enemies' sheet attack went up ×1.2 to replace the old band.
