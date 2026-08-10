# SKILLS AND SPELLS

## DETAILS

### Skill and Spell Data Compilers Architecture

#### 1. CSV Specifications & Index Mapping

##### Spells (`Spells.csv` - Minimum 15 Columns)

| Index | Header | Type | Resource Field | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `0` | `spell_id` | String | `spell_id` | Unique ID |
| `1` | `spell_name` | String | `spell_name` | Display Name |
| `2` | `spellbook` | String | `spellbook` | Enum: Archanist, Soulwright, Maester, Psynic |
| `3` | `tier` | int | `tier` | Spell level / Tier |
| `4` | `energy_cost` | int | `energy_cost` | Resource cost |
| `5` | `element` | String | `element` | Enum: Magic, Life, Bash, Blade |
| `6` | `target_type` | String | `target_type` | Enum: SINGLE_ENEMY, ALL_ENEMY, SINGLE_ALLY, ALL_ALLY, SELF |
| `7` | `effect_type` | String | `effect_type` | Enum: Damage, Heal, Buff, Debuff, Utility |
| `8` | `base_amount` | int | `base_amount` | Base damage/heal magnitude |
| `9` | `var_multiplier` | float | `var_multiplier` | Random variance percentage |
| `10` | `stat_scaling` | String | `stat_scaling` | Scaling stat (e.g. INT, PIE) |
| `11` | `status_effect` | String | `status_effect` | Enum: None, Stun, Poison, Slow, Haste, Shield, Defense_Down |
| `12` | `duration` | int | `duration` | Base turn duration |
| `13` | `description` | String | `description` | Multiline text |
| `14` | `icon_path` | String | `icon_path` | Resource path (`res://...`) |

##### Skills (`Skills.csv` - Minimum 14 Columns)

| Index | Header | Type | Resource Field | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `0` | `skill_id` | String | `skill_id` | Unique ID |
| `1` | `skill_name` | String | `skill_name` | Display Name |
| `2` | `type` | String | `skill_type` | Enum: Combat, Environment, Inventory |
| `3` | `energy_cost` | int | `energy_cost` | Energy cost |
| `4` | `target_type` | String | `target_type` | Enum: SINGLE_ENEMY, ALL_ENEMY, SINGLE_ALLY, ALL_ALLY, SELF, NONE |
| `5` | `effect_type` | String | `effect_type` | Enum: Damage, Heal, Lockpick, etc. |
| `6` | `effect_amount` | int | `effect_amount` | Base amount |
| `7` | `element` | String | `element` | Enum: Blade, Bash, Ranged, Magic, Life, None |
| `8` | `assigned_classes` | String | `assigned_classes` | Pipe-separated list (`Spartan | Amazon`) |
| `9` | `assigned_races` | String | `assigned_races` | Pipe-separated list (`Bengal | Sphynx`) |
| `10` | `description` | String | `description` | Display text |
| `11` | `icon_path` | String | `icon_path` | Resource path |
| `12` | `accuracy` | int | `accuracy` | Hit chance percentage (0-100) |
| `13` | `duration` | int | `duration` | Base turn duration |

#### 2. Target Type Standards

Targeting conventions across Spells, Skills, and Combat:

* `SINGLE_ENEMY`
* `ALL_ENEMY` (Compiler supports `ALL_ENEMIES` for backwards compatibility)
* `SINGLE_ALLY`
* `ALL_ALLY` (Compiler supports `ALL_PARTY` and `ALL_ALLIES` for backwards compatibility)
* `SELF`
* `NONE` (Skills only)

#### 3. Spell vs Skill Duration Logic

* **Spells**: Scaled dynamically during combat execution via:
  $$ \text{Total Duration} = \text{Base Duration} \times \text{Spell Level} $$

* **Skills**: Fixed base duration loaded from `Skills.csv` (defaults to `1`).

## SPELL DATA & CLASS LOCKING API SPECIFICATION

### Overview

Spells belong to specific `SpellbookType` domains (`ARCHANIST`, `SOULWRIGHT`, `MAESTER`, `PSYNIC`). While characters can equip off-class spellbooks for utility, signature high-tier spells may have `class_locked = true`.

### Resource API Helpers (`SpellData.gd`)

#### `is_class_allowed(character_class_name: String) -> bool`

* **Description**: Checks if a character's primary class name permits using this spell.

* **Return Value**:
  * `true` if `class_locked` is `false`.
  * `true` if `class_locked` is `true` AND `character_class_name` matches `SpellbookType.keys()[spellbook]`.
  * `false` otherwise.

#### `can_cast(current_energy: int, character_class_name: String = "") -> bool`

* **Description**: Validates energy availability and class restriction rules in a single call.

* **Parameters**:
  * `current_energy`: Caster's active energy/MP pool.
  * `character_class_name`: Optional string identifier for the caster's primary class.
