# res://Scripts/Resources/inventory.gd
class_name Inventory
extends Resource

signal item_added(item: ItemData)
signal item_removed(item: ItemData)
signal item_used(item: ItemData)

@export var max_slots: int = 48
@export var _items: Array[ItemData] = []

func add_item(item: ItemData) -> bool:
	if not is_instance_valid(item):
		return false
	if _items.size() >= max_slots:
		push_warning("Inventory full! Could not add: " + item.item_name)
		return false
		
	_items.append(item)
	item_added.emit(item)
	return true

func remove_item(item: ItemData) -> bool:
	var index: int = _items.find(item)
	if index == -1:
		return false
		
	var removed: ItemData = _items[index]
	_items.remove_at(index)
	item_removed.emit(removed)
	return true

func get_items() -> Array[ItemData]:
	return _items.duplicate()

func size() -> int:
	return _items.size()

func use_item(index: int, target_character: Resource) -> bool:
	if not is_instance_valid(target_character) or index < 0 or index >= _items.size():
		return false

	var item: ItemData = _items[index]
	if not is_instance_valid(item):
		return false

	if item.item_type == ItemData.ItemType.CONSUMABLE:
		_apply_stat_effects(item.stat_effect, target_character)
		item_used.emit(item)
		_items.remove_at(index)
		item_removed.emit(item)
		return true
		
	return false

func _apply_stat_effects(effects: Dictionary, cat: CatCharacter) -> void:
	if effects.has("heal"):
		cat.heal(int(effects["heal"]))
	if effects.has("energy"):
		cat.current_energy = clampi(cat.current_energy + int(effects["energy"]), 0, cat.max_energy)
