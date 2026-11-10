# res://Scripts/Resources/inventory.gd
class_name Inventory
extends Resource

signal item_added(item: ItemData)
signal item_removed(item: ItemData)
signal item_used(item: ItemData)

@export var max_slots: int = 48
@export var _items: Array[ItemData] = []


## Adds `amount` of an item (default: the item's own quantity, at least 1).
## Stackable items (potions, consumables, gems, ammo...) merge into the existing stack.
## The inventory always stores its OWN copy, never the shared resource loaded from disk,
## so stack counts can't leak between slots and are saved with the game.
func add_item(item: ItemData, amount: int = 1) -> bool:
	if not is_instance_valid(item):
		return false

	var qty_to_add: int = maxi(1, item.quantity) if amount == 1 else maxi(1, amount)

	if is_stackable(item):
		var existing: ItemData = find_stack(item)
		if existing != null:
			existing.quantity += qty_to_add
			item_added.emit(existing)
			return true
		if _items.size() >= max_slots:
			push_warning("Inventory full! Could not add: " + item.item_name)
			return false
		var stack: ItemData = _make_own_copy(item)
		stack.quantity = qty_to_add
		_items.append(stack)
		item_added.emit(stack)
		return true

	# Non-stackable (weapons / armor): one slot per piece
	for i in range(qty_to_add):
		if _items.size() >= max_slots:
			push_warning("Inventory full! Could not add: " + item.item_name)
			return i > 0
		var piece: ItemData = _make_own_copy(item)
		piece.quantity = 1
		_items.append(piece)
		item_added.emit(piece)
	return true


## Removes an item stack. amount = -1 removes the whole stack, otherwise that many from it.
func remove_item(item: ItemData, amount: int = -1) -> bool:
	var index: int = _items.find(item)
	if index == -1:
		return false

	var stack: ItemData = _items[index]
	if amount > 0 and stack.quantity > amount:
		stack.quantity -= amount
		item_removed.emit(stack)
		return true

	_items.remove_at(index)
	item_removed.emit(stack)
	return true


func get_items() -> Array[ItemData]:
	return _items.duplicate()


func size() -> int:
	return _items.size()


## Total count of an item across the inventory (by item_id, falls back to name).
func get_item_count(item_id_or_item: Variant) -> int:
	var total: int = 0
	for it: ItemData in _items:
		if not is_instance_valid(it):
			continue
		if item_id_or_item is ItemData:
			if _stack_key(it) == _stack_key(item_id_or_item as ItemData):
				total += maxi(1, it.quantity)
		elif it.item_id == str(item_id_or_item):
			total += maxi(1, it.quantity)
	return total


func is_stackable(item: ItemData) -> bool:
	if not is_instance_valid(item):
		return false
	var low_id: String = item.item_id.to_lower()
	return item.item_type in [ItemData.ItemType.CONSUMABLE, ItemData.ItemType.POTION, ItemData.ItemType.MISC, ItemData.ItemType.QUEST] \
		or item.is_consumable \
		or item.equipment_slot == ItemData.EquipmentSlot.NONE \
		or "arrow" in low_id or "bolt" in low_id or "ammo" in low_id


## The existing stack this item would merge into, or null.
func find_stack(item: ItemData) -> ItemData:
	var key: String = _stack_key(item)
	for existing: ItemData in _items:
		if is_instance_valid(existing) and _stack_key(existing) == key:
			return existing
	return null


## Merges duplicate entries into single stacks and replaces shared (on-disk) resources with
## inventory-owned copies. Called by GameState after every load; safe to call any time.
func normalize_stacks() -> void:
	var counts: Dictionary = {} # key -> total quantity (stackables)
	var order: Array[ItemData] = [] # first entry of each stack / every non-stackable, in order
	var first_of_key: Dictionary = {}

	for it: ItemData in _items:
		if not is_instance_valid(it):
			continue
		if is_stackable(it):
			var key: String = _stack_key(it)
			counts[key] = int(counts.get(key, 0)) + maxi(1, it.quantity)
			if not first_of_key.has(key):
				first_of_key[key] = it
				order.append(it)
		else:
			order.append(it)

	var rebuilt: Array[ItemData] = []
	var seen_instances: Dictionary = {}
	for it: ItemData in order:
		var copy: ItemData = it
		# Shared disk resources (or the same instance listed twice) become owned copies
		if not it.resource_path.is_empty() or seen_instances.has(it.get_instance_id()):
			copy = _make_own_copy(it)
		seen_instances[it.get_instance_id()] = true
		if is_stackable(it):
			copy.quantity = int(counts[_stack_key(it)])
		else:
			copy.quantity = maxi(1, copy.quantity)
		rebuilt.append(copy)
	_items = rebuilt


func _stack_key(item: ItemData) -> String:
	return item.item_id if not item.item_id.is_empty() else "name:" + item.item_name


func _make_own_copy(item: ItemData) -> ItemData:
	return item.duplicate() as ItemData


func use_item(index: int, target_character: Resource) -> bool:
	if not is_instance_valid(target_character) or index < 0 or index >= _items.size():
		GameLogger.warning("Inventory: Invalid target or index %d out of bounds." % index)
		return false

	var item: ItemData = _items[index]
	if not is_instance_valid(item):
		GameLogger.warning("Inventory: Item at slot %d is null." % index)
		return false

	# Spell Books / Skill Crystals open the learn picker instead; the item is only used up when the
	# character actually learns something (handled asynchronously, so this returns false right away).
	var learn_kind: StringName = AbilityLearnScreen.kind_for_item(item)
	if learn_kind != &"":
		var learner: CatCharacter = target_character as CatCharacter
		if is_instance_valid(learner):
			_learn_from_item(item, learner, learn_kind)
		return false

	# Usability check: CONSUMABLE, POTION, or marked is_consumable
	var is_usable: bool = item.is_consumable or item.item_type == ItemData.ItemType.CONSUMABLE or item.item_type == ItemData.ItemType.POTION
	if is_usable:
		var cat: CatCharacter = target_character as CatCharacter
		if is_instance_valid(cat):
			_apply_item_effects(item, cat)

		item_used.emit(item)

		if is_instance_valid(AudioManager):
				AudioManager.play_potion_sound()	

		consume_one(index)
		return true

	GameLogger.warning("Inventory: Item %s is not usable as a consumable." % item.item_name)
	return false


## Uses ONE item on every character in `targets` (group heal potions etc.).
## Downed characters (0 HP) are skipped unless the item is a revive item.
## Consumes a single item. Returns false (and consumes nothing) if no one was affected.
func use_item_on_targets(index: int, targets: Array) -> bool:
	if index < 0 or index >= _items.size():
		GameLogger.warning("Inventory: Index %d out of bounds." % index)
		return false

	var item: ItemData = _items[index]
	if not is_instance_valid(item):
		return false

	var is_usable: bool = item.is_consumable or item.item_type == ItemData.ItemType.CONSUMABLE or item.item_type == ItemData.ItemType.POTION
	if not is_usable:
		GameLogger.warning("Inventory: Item %s is not usable as a consumable." % item.item_name)
		return false

	var revives: bool = "revive" in item.item_id.to_lower() or "revive" in item.effects.to_lower()
	var affected: int = 0
	for target in targets:
		var cat: CatCharacter = target as CatCharacter
		if not is_instance_valid(cat):
			continue
		if cat.current_hp <= 0 and not revives:
			continue
		_apply_item_effects(item, cat)
		affected += 1

	if affected == 0:
		GameLogger.info("Inventory: %s had no valid targets." % item.item_name)
		return false

	item_used.emit(item)
	if is_instance_valid(AudioManager):
		AudioManager.play_potion_sound()
	GameLogger.info("Inventory: %s affected %d character(s)" % [item.item_name, affected])
	consume_one(index)
	return true


func _learn_from_item(item: ItemData, learner: CatCharacter, learn_kind: StringName) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var learned: Resource = await AbilityLearnScreen.open(tree, learner, learn_kind)
	if learned == null:
		return
	var idx: int = _items.find(item)
	if idx >= 0:
		item_used.emit(item)
		consume_one(idx)
	if is_instance_valid(GameState):
		GameState.save_game()


## Removes one from the stack at `index` (or the whole slot if it was the last one).
func consume_one(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	var item: ItemData = _items[index]
	if is_instance_valid(item) and item.quantity > 1:
		item.quantity -= 1
		GameLogger.info("Inventory: Used %s (Remaining quantity: %d)" % [item.item_name, item.quantity])
	else:
		_items.remove_at(index)
		item_removed.emit(item)
		GameLogger.info("Inventory: Consumed last %s and removed slot %d" % [item.item_name if is_instance_valid(item) else "item", index])


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
