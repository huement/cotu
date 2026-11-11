# ITEMS AND LOOT

## LOOT

### Party Economy Architecture

#### Storage & Scope

- **Location**: `res://Core/GameState.gd`
- **Variable**: `@export var party_gold: int = 0`
- **Scope**: Global party resource (shared across all 6 slots).

#### API Methods (`GameState.gd`)

- `add_gold(amount: int) -> void`: Increments party wallet and emits `SignalBus.party_gold_changed`.
- `spend_gold(amount: int) -> bool`: Deducts gold if `party_gold >= amount`. Returns `true` on success, `false` if insufficient funds.

#### Signals (`SignalBus.gd`)

- `signal party_gold_changed(new_total: int, amount_changed: int)`
  - `new_total`: The total gold in the wallet after modification.
  - `amount_changed`: Positive for rewards/loot, negative for purchases/costs.

### Loot System & Item Compiler Documentation

#### 1. Item Schema Mapping (`Loot.csv` -> `ItemData.gd`)

The `Loot.csv` file defines items using 27 property columns:

- Core Identity: `item_id`, `item_name`, `description`, `item_type`, `target_type`, `quantity`, `can_use_in_battle`, `can_use_in_field`
- Equipment: `equipment_slot`, `weapon_type`, `attack_bonus`, `defense_bonus`, `speed_bonus`, `credit_value`, `max_durability`, `current_durability`
- Consumable Restoration: `is_consumable`, `heal_amount`, `energy_restore`, `mana_restore`, `health_restore`
- Magic & Effects: `effects`, `effect_amount`, `effect_element`, `effect_stat`, `icon_path`
- Throwing: `is_throwable` (TRUE/FALSE, optional last column — see "Throwing items" below)

#### 2. Editor Compilation

- Executing `LootCompiler.gd` in the Godot Script Editor processes `Loot.csv` and outputs compiled `ItemData` resource files (`.tres`) to `res://Data/Items/Loot/`.
- Allowed `item_id` prefixes: `gem_*`, `lrn_*`, `token_*`.

#### 3. Loot Rolling Engine (`LootTable.gd` & `LootItem.gd`)

- `LootTable.roll_table()` evaluates nested drop probabilities using Godot 4's `randf_range(0.0, total_probability)`.
- Rolled items return as typed `Array[ItemData]`, which are automatically added to `GameState.inventory` and reported in `victory_data` on battle completion.

#### 4. Party gear tokens (chests)

Drag these into any `DungeonChest.guaranteed_items` (or put them in a chest `LootTable`). On first open they expand into real class-tagged gear via `PartyGearLoot` — the token itself never enters inventory.

| Resource | `effects` | Result |
|---|---|---|
| `Data/Items/Loot/TokenPartyGear.tres` | `PartyGear` | 1 regular armor or weapon for the live party |
| `Data/Items/Loot/TokenPartyGearBone.tres` | `PartyGear:bone` (`effect_stat=armor`) | 1 Bone-tier armor piece (mid stats + Defense Up I) |
| `Data/Items/Loot/TokenPartyGearAdv.tres` | `PartyGear:advanced` | 1 advanced armor or weapon |

Bone armor sets exist for Spartan, Shade, Warden, Amazon, Crusader, and Ghostblade (`armor_{class}_bone_{slot}`). Each piece grants `eff_defense_up_1` (2% DEF); a full five-piece set stacks to +10% DEF in combat. Armor is not class-locked on equip — class tags are loot targeting only.

Optional knobs on the token: `quantity` = how many pieces that slot rolls; `effect_stat` = `armor` / `weapons` / empty (both). Add the same token multiple times for independent rolls.

HypeChest still uses a child `PartyGearDrop` node for bulk rolls; tokens are the designer-friendly path for regular chests.

Positive *Up* status multipliers (Attack/Defense/Accuracy/Dexterity/Magic/Speed): level I/II/III = **2% / 5% / 8%**.


## Throwing items

Any item with **`is_throwable = TRUE`** can be thrown at enemies from the battle **ITEMS** menu (the button
reads **THROW**). Throwing stars, throwing knives, exploding potions... Set it in the last column of
`Loot.csv` (`is_throwable`) or `basic_items.csv` (column 21, `is_throwable`) and re-run the compiler, or tick
**Throwing > Is Throwable** on the item resource.

- **Target**: one enemy (pick from the target cards), or every enemy when `target_type = ALL_ENEMIES`
  (exploding potions). Battle only; one is used up per throw.
- **Power**: `attack_bonus` (or `effect_amount` when attack_bonus is 0).
- **DEX hits / crits; STR damages** (formulas + tuning in `CombatMath.gd` → "Throwing"):
  - hit chance = 80% + (DEX − target speed) × 2.5%, clamped 40–98%
  - damage = (power × 2 + STR) × (1 + STR × 0.05) − half the target's defence (min 1); weakness / resist
    from `effect_element` (RANGED when none)
  - crit chance = DEX × 1% (max 35%), crits do ×1.5
  - plus any `granted_status_effects` on a hit
- Example: Steel Shuriken (power 4) from a STR 14 thrower at a defence-6 enemy ≈ 34 damage
  (a STR-28 melee swing does ~23); hit chance still uses DEX.

Throwable now: **Steel Shuriken** / **Holo-Shuriken** (Ghostblade kit — a new Ghostblade starts with 5 in the
pack), **Throwing Knife** (seeded for Deadly Throw classes), and **Kunai**.
