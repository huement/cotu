# res://Scripts/Environment/PartyGearDrop.gd
class_name PartyGearDrop
extends Node

## Attach as a child of DungeonChest / HypeChest.
## On open, the parent chest appends these rolls alongside gold / guaranteed / loot_table items.

## How many class-gear pieces to roll (0 disables).
@export_range(0, 10) var drop_count: int = 3

## regular = starter kit from basic_items.csv; advanced = upgraded set.
@export_enum("regular", "advanced") var gear_tier: String = "regular"

@export var include_armor: bool = true
@export var include_weapons: bool = true

## If true, each party class is listed once (no weight for duplicate Spartans, etc.).
@export var unique_classes_only: bool = false


## Called by DungeonChest / HypeChest during loot generation.
func roll_loot() -> Array[ItemData]:
	if drop_count <= 0:
		var empty: Array[ItemData] = []
		return empty
	return PartyGearLoot.roll_for_party(
		drop_count,
		gear_tier,
		include_armor,
		include_weapons,
		null,
		unique_classes_only
	)
