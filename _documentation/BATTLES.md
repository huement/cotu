# BATTLE SYSTEM

| **Row Position** | **Blade / Bash (Melee)** | **Ranged Weapons** | **Spells** | **Damage Taken (Physical)** |
|---|---|---|---|---|
| **Front Row** | Full Damage | Full Damage | Full Damage | 100% (Standard) |
| **Back Row** | Disabled *(or 50% penalty)* | Full Damage | Full Damage | 50% (Protected) |


## COMBAT MANAGER

### Combat Ability Execution Pipeline

#### Execution Steps (`CombatManager.gd`)

1. **Resource Check**: Verifies `current_mp >= energy_cost`. Deducts cost and emits `SignalBus.character_mana_changed`.
2. **Accuracy Check**: Rolls `roll_success_check()` for skills before applying effects.
3. **Target Selection**: Parses standardized targets (`SINGLE_ENEMY`, `SINGLE_ALLY`, `ALL_ENEMY`, `ALL_ALLY`, `SELF`).
4. **Potency & Scaling**: Invokes `calculate_potency(caster_stat)` using the caster's primary scaling stat (`INT`/`PIE`).
5. **Duration Scaling**: Calculates total duration (`Total Duration = Base Duration * Spell Level`).
6. **Effect Application**:
   - `BUFF` / `SHIELD` / `HASTE`: Applies positive `STAT_BUFF` active effect.
   - `DEBUFF` / `DEFENSE_DOWN` / `SLOW`: Applies negative `STAT_BUFF` active effect.
   - `POISON` / `DOT`: Applies `DOT` active effect.
   - `STUN`: Resets target turn meter to 0.0.
   - `HEAL` / `HOT`: Direct heal HP + applies `HOT` active effect if duration > 1.
   - `DAMAGE`: Direct damage to target HP.
7. **Cleanup**: Resets pending ability state on `TargetSelectionManager`.

### Ability & Spell Systems Documentation

#### 1. Target Standards

Targeting strings in CSVs and Resources follow a strict naming convention:

- `SINGLE_ENEMY`: Single hostile target.
- `SINGLE_ALLY`: Single friendly party member target.
- `ALL_ENEMY`: All alive hostiles in combat.
- `ALL_ALLY`: All alive party members in combat.

#### 2. Duration Scaling Rules

- **Skills**: Duration is fixed to the `duration` column defined in `Skills.csv` (default: 1 turn).
- **Spells**: Total duration scales dynamically based on spell level:
  `Total Duration = Base Duration * Spell Level`
- Active DoT (Damage over Time), HoT (Heal over Time), and Stat Buff effects tick once per combatant turn until duration reaches `0`.

### TargetType Enum Mapping & Resolution Standard

Godot 4 serializes `@export` enum properties as integers within `.tres` resource files.

#### TargetType Enum Values

0: SINGLE_ENEMY
1: ALL_ENEMIES / ALL_ENEMY
2: SINGLE_ALLY
3: ALL_PARTY / ALL_ALLY
4: SELF
5: NONE (SkillData only)

#### Target Resolution Rules (`CombatManager.gd`)

- If `target_type` is an integer:
  - `1`: Iterates through all living enemies (`not c.is_player and c.current_hp > 0`).
  - `2`: Targets the specific ally at `target_index` (falls back to caster if invalid).
  - `3`: Iterates through all living party members (`c.is_player and c.current_hp > 0`).
  - `4`: Targets the caster directly (`acting_char`).
  - `0` / Default: Targets a single living enemy by `target_index`.
- If `target_type` is a string (legacy support):
  - Matches `"ALL_ENEM"`, `"ENEMIES"`, or `"1"`.
  - Matches `"ALL_PART"`, `"ALL_ALL"`, `"PARTY"`, or `"3"`.
  - Matches `"SINGLE_ALL"`, `"ALLY"`, or `"2"`.
  - Matches `"SELF"` or `"4"`.
