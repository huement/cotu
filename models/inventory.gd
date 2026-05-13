class_name Inventory
extends Resource

signal item_added(item)
signal item_removed(item)
signal item_used(item)

var _items: Array = []


func add_item(item) -> bool:
	if not (item is ItemData):
		return false
	if item == null:
		return false
	_items.append(item)
	item_added.emit(item)
	return true


func remove_item(item) -> bool:
	var index := _items.find(item)
	if index == -1:
		return false
	var removed = _items[index]
	_items.remove_at(index)
	item_removed.emit(removed)
	return true


func get_items() -> Array:
	return _items.duplicate()


func size() -> int:
	return _items.size()


func use_item(index: int, target_stats: CharacterStats) -> bool:
	if target_stats == null:
		return false
	if index < 0 or index >= _items.size():
		return false

	var item = _items[index]
	if item == null:
		return false

	_apply_stat_effects(item.stat_effect, target_stats)
	item_used.emit(item)

	if item.item_type == ItemData.ItemType.CONSUMABLE:
		_items.remove_at(index)
		item_removed.emit(item)

	return true


func _apply_stat_effects(stat_effect: Dictionary, target_stats: CharacterStats) -> void:
	if stat_effect.has("heal"):
		target_stats.heal(int(stat_effect["heal"]))

	if stat_effect.has("max_health"):
		target_stats.max_health = maxi(1, target_stats.max_health + int(stat_effect["max_health"]))
		target_stats.health = clampi(target_stats.health, 0, target_stats.max_health)

	if stat_effect.has("attack"):
		target_stats.attack += int(stat_effect["attack"])

	if stat_effect.has("defence"):
		target_stats.defence += int(stat_effect["defence"])

	if stat_effect.has("health"):
		var delta := int(stat_effect["health"])
		if delta > 0:
			target_stats.heal(delta)
		elif delta < 0:
			target_stats.take_damage(-delta)
