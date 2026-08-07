# res://Scripts/Resources/loot_table.gd
class_name LootTable
extends Resource

signal pre_roll
signal post_roll
signal hit

@export var table_name: String = ""
@export var num_of_items_to_roll: int = 1
@export var probability: int = 10
@export var is_unique: bool = false
@export var should_drop_always: bool = false
@export var is_enabled: bool = true

@export var table_contents: Array[Resource] = []
var unique_items: Array[Resource] = []


func _init(p_name: String = "", p_num_items: int = 1, p_probability: int = 10, p_unique: bool = false, p_always_drop: bool = false, p_enabled: bool = true) -> void:
	table_name = p_name
	num_of_items_to_roll = p_num_items
	probability = p_probability
	is_unique = p_unique
	should_drop_always = p_always_drop
	is_enabled = p_enabled


func add_item(item_entry: LootItem) -> void:
	table_contents.append(item_entry)


func add_table(table_entry: LootTable) -> void:
	table_contents.append(table_entry)


## Rolls the table and returns a list of rolled ItemData resources
func roll_table() -> Array[ItemData]:
	var rolled_items: Array[ItemData] = []
	unique_items = []

	for loot in table_contents:
		if loot.has_signal("pre_roll"):
			loot.emit_signal("pre_roll")

	var num_of_items_always_rolled: int = 0
	for loot in table_contents:
		if loot.get("should_drop_always") and loot.get("is_enabled"):
			_add_to_rolled_items(rolled_items, loot)
			num_of_items_always_rolled += 1

	var real_drop_count: int = num_of_items_to_roll - num_of_items_always_rolled

	if real_drop_count > 0:
		for _i in range(real_drop_count):
			var loot_that_can_be_rolled: Array = []
			var total_probability: float = 0.0
			for table_content in table_contents:
				if table_content.get("is_enabled") and not table_content.get("should_drop_always"):
					loot_that_can_be_rolled.append(table_content)
					total_probability += float(table_content.get("probability"))

			if total_probability > 0.0:
				var hit_value: float = randf_range(0.0, total_probability)
				var running_value: float = 0.0
				for loot in loot_that_can_be_rolled:
					running_value += float(loot.get("probability"))
					if hit_value < running_value:
						_add_to_rolled_items(rolled_items, loot)
						break

	for o in table_contents:
		if o.has_signal("post_roll"):
			o.emit_signal("post_roll")

	return rolled_items


func _add_to_rolled_items(rolled_items: Array[ItemData], loot: Resource) -> void:
	if not loot.get("is_unique") or not unique_items.has(loot):
		if loot.get("is_unique"):
			unique_items.append(loot)

		var items_to_add: Array = [loot]

		if loot.has_method("roll_table"):
			items_to_add = loot.roll_table()

		for loot_entry in items_to_add:
			if loot_entry is LootItem:
				if loot_entry.item is ItemData:
					rolled_items.append(loot_entry.item as ItemData)
			elif loot_entry is ItemData:
				rolled_items.append(loot_entry as ItemData)

			if loot.has_signal("hit"):
				loot.emit_signal("hit")
