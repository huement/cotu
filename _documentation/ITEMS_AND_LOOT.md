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

The `Loot.csv` file defines items using 26 property columns:

- Core Identity: `item_id`, `item_name`, `description`, `item_type`, `target_type`, `quantity`, `can_use_in_battle`, `can_use_in_field`
- Equipment: `equipment_slot`, `weapon_type`, `attack_bonus`, `defense_bonus`, `speed_bonus`, `credit_value`, `max_durability`, `current_durability`
- Consumable Restoration: `is_consumable`, `heal_amount`, `energy_restore`, `mana_restore`, `health_restore`
- Magic & Effects: `effects`, `effect_amount`, `effect_element`, `effect_stat`, `icon_path`

#### 2. Editor Compilation

- Executing `LootCompiler.gd` in the Godot Script Editor processes `Loot.csv` and outputs compiled `ItemData` resource files (`.tres`) to `res://Data/Items/`.

#### 3. Loot Rolling Engine (`LootTable.gd` & `LootItem.gd`)

- `LootTable.roll_table()` evaluates nested drop probabilities using Godot 4's `randf_range(0.0, total_probability)`.
- Rolled items return as typed `Array[ItemData]`, which are automatically added to `GameState.inventory` and reported in `victory_data` on battle completion.
