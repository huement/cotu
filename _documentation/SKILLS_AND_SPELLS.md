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

## LEARNING SPELLS & SKILLS (2026-11)

Characters no longer know every spell/skill of their class. Code: `Scripts/Progression/AbilityRules.gd` (rules, pure, tested in `tests/progression/test_ability_rules.gd`) and `AbilityLibrary.gd` (loads every SpellData/SkillData).

### What a new character starts with (`AbilityRules.initialize_abilities`)
- Up to **2 cheapest tier-1 spells** of their spellbook(s) — only if the book is already open at their level.
- The **first class COMBAT skill** (Skills.csv order by cost/name) + **every race skill** for their breed.
- `CatCharacter.abilities_initialized` is saved; it runs once. Old saves (that knew everything) are trimmed to the starter set but keep anything already ranked up with level-up points.
- When a class's spellbook opens on a level-up (Warden / Echo / Amazon / Crusader / Voidhand at 3, Ronin / Ghostblade at 5 — `Spells Unlock At Level` in `Data/Class_Progression.csv`) the character gets its starter spells for free + a toast.

### Who can learn what
| | Rule |
|---|---|
| Spell | spellbook is one of the class's books (`ProfessionData.spellbook_type`, e.g. "Soulwright, Archanist") · book is open · **tier ≤ 1 + (level − unlock level) / 3** (tier 1 at unlock, tier 2 three levels later...) · level ≥ the spell's `requirement` · `class_locked` spells only for the class that owns the book |
| Skill | class in `assigned_classes` **or** breed in `assigned_races` (no lists = anyone) |

Tunables: `LEVELS_PER_TIER`, `STARTER_SPELLS`, `STARTER_CLASS_SKILLS` at the top of `AbilityRules.gd`.

### Spell Books & Skill Crystals
- Items: `Data/Loot.csv` rows `lrn_spell_book` / `lrn_skill_crystal` → `Data/Items/LrnSpellBook.tres` / `LrnSkillCrystal.tres` (effects `LearnSpell` / `LearnSkill`, field-only, consumable). Icons `Data/Items/spell_book.png` / `skill_crystal.png` (rendered from the models).
- **Using** one from ITEMS on a party member opens `AbilityLearnScreen` (what they can learn now + the class's later spells greyed out with "Needs level 7" etc.). The item is consumed **only** when something is learned; Cancel / Esc keeps it.
- **World pickups**: `Scenes/Objects/SpellBook.tscn` / `SkillCrystal.tscn` use `Scripts/Environment/ItemPickup.gd` (floats, spins, glows; search the tile in front of it to collect; vanishes and is saved per map). Drop instances anywhere — each gets a save id from its node name + grid cell (or set `object_id`). `ItemPickup` works with any `ItemData` (`item`, `quantity`, `pickup_message`, glow colour...).
- **Boss rewards**: `BlobBossController` (Slime Lord, Beast King, BossChamber `DungeonBoss`), `BossEnemy` (FeroShaw drone) and `TentacleBossController` have **Boss Rewards → reward_spell_books / reward_skill_crystals** (default 1 + 1). They call `GameState.register_boss_rewards()` before the fight; `CombatManager` adds the items on victory (shown on the victory screen) and drops them if you lose / flee.

### Level-up points vs books
Spell/skill **points** from levelling still only **rank up** abilities a character already knows (Level Up screen). Books and crystals are the only way to learn **new** ones.

### Export safety
All `res://` folder scans (spells, skills, status effects) go through `AbilityLibrary.load_all()` / `ResourceLoader.list_directory`, which works in exported builds (raw `DirAccess` only sees `*.remap` files there).
