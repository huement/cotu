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
		GameLogger.warning("Inventory: Invalid target or index %d out of bounds." % index)
		return false

	var item: ItemData = _items[index]
	if not is_instance_valid(item):
		GameLogger.warning("Inventory: Item at slot %d is null." % index)
		return false

	# Usability check: CONSUMABLE, POTION, or marked is_consumable
	var is_usable: bool = item.is_consumable or item.item_type == ItemData.ItemType.CONSUMABLE or item.item_type == ItemData.ItemType.POTION
	if is_usable:
		var cat: CatCharacter = target_character as CatCharacter
		if is_instance_valid(cat):
			_apply_item_effects(item, cat)

		item_used.emit(item)

		# Decrement stack quantity or remove item if last one
		if item.quantity > 1:
			item.quantity -= 1
			GameLogger.info("Inventory: Used %s (Remaining quantity: %d)" % [item.item_name, item.quantity])
		else:
			var removed: ItemData = _items[index]
			_items.remove_at(index)
			item_removed.emit(removed)
			GameLogger.info("Inventory: Consumed last %s and removed slot %d" % [item.item_name, index])

		return true

	GameLogger.warning("Inventory: Item %s is not usable as a consumable." % item.item_name)
	return false


func _apply_item_effects(item: ItemData, cat: CatCharacter) -> void:
	if not is_instance_valid(cat) or not is_instance_valid(item):
		return

	var heal_amt: int = 0
	var energy_amt: int = 0

	# 1. Read from stat_effect dictionary
	if item.stat_effect.has("heal"):
		heal_amt = int(item.stat_effect["heal"])
	elif item.stat_effect.has("hp"):
		heal_amt = int(item.stat_effect["hp"])

	if item.stat_effect.has("energy"):
		energy_amt = int(item.stat_effect["energy"])
	elif item.stat_effect.has("mana"):
		energy_amt = int(item.stat_effect["mana"])

	# 2. Fallback to direct properties on ItemData if present
	if heal_amt == 0 and "heal_amount" in item and int(item.get("heal_amount")) > 0:
		heal_amt = int(item.get("heal_amount"))
	if heal_amt == 0 and "health_restore" in item and int(item.get("health_restore")) > 0:
		heal_amt = int(item.get("health_restore"))

	if energy_amt == 0 and "energy_restore" in item and int(item.get("energy_restore")) > 0:
		energy_amt = int(item.get("energy_restore"))
	if energy_amt == 0 and "mana_restore" in item and int(item.get("mana_restore")) > 0:
		energy_amt = int(item.get("mana_restore"))

	# 3. Default fallback for Catnip / Health potions if unconfigured
	if heal_amt == 0 and energy_amt == 0:
		var low_id: String = item.item_id.to_lower()
		var low_name: String = item.item_name.to_lower()
		if "catnip" in low_id or "catnip" in low_name or "health" in low_name or "potion" in low_name:
			heal_amt = 25
		elif "mana" in low_name or "energy" in low_name:
			energy_amt = 15

	# 4. Apply healing & energy restoration
	var cat_name: String = cat.character_name if "character_name" in cat and not cat.character_name.is_empty() else cat.name

	if heal_amt > 0:
		var old_hp: int = cat.current_hp
		if cat.has_method("heal"):
			cat.heal(heal_amt)
		else:
			cat.current_hp = clampi(cat.current_hp + heal_amt, 0, cat.max_hp)

		GameLogger.combat("[Inventory] Used %s on %s! Restored HP: +%d (%d -> %d / %d)" % [item.item_name, cat_name, heal_amt, old_hp, cat.current_hp, cat.max_hp])

	if energy_amt > 0:
		var old_en: int = cat.current_energy
		cat.current_energy = clampi(cat.current_energy + energy_amt, 0, cat.max_energy)

		GameLogger.combat("[Inventory] Used %s on %s! Restored EN: +%d (%d -> %d / %d)" % [item.item_name, cat_name, energy_amt, old_en, cat.current_energy, cat.max_energy])

	# 5. Broadcast live HUD update signal
	var sb: Node = Engine.get_main_loop().root.get_node_or_null("SignalBus") if Engine.get_main_loop() else null
	if is_instance_valid(sb):
		var slot_idx: int = 0
		var gs: Node = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
		if is_instance_valid(gs) and "current_party" in gs and gs.current_party:
			var slots: Array = gs.current_party.slots
			for i in range(slots.size()):
				if slots[i] == cat:
					slot_idx = i
					break

		if sb.has_signal("character_health_changed") and heal_amt > 0:
			sb.character_health_changed.emit(slot_idx, cat.current_hp, cat.max_hp)
		if sb.has_signal("character_mana_changed") and energy_amt > 0:
			sb.character_mana_changed.emit(slot_idx, cat.current_mana, cat.max_mana)
