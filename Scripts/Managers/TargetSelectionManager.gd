# res://Scripts/Managers/TargetSelectionManager.gd
extends Node

signal target_selected(target_index: int)
signal selection_canceled()
signal selection_mode_changed(is_selecting: bool, item: ItemData)

var _pending_item: ItemData = null
var _pending_ability: Resource = null
var _pending_slot_index: int = -1
var _acting_party_slot: int = -1
var _is_selecting_target: bool = false


func _ready() -> void:
	var sb: Node = SignalBus
	if is_instance_valid(sb) and sb.has_signal("portrait_clicked"):
		if not sb.portrait_clicked.is_connected(_on_portrait_clicked):
			sb.portrait_clicked.connect(_on_portrait_clicked)


func start_item_target_selection(item: ItemData, slot_index: int, acting_party_slot: int = -1) -> void:
	if not is_instance_valid(item):
		return

	_pending_item = item
	_pending_slot_index = slot_index
	_acting_party_slot = acting_party_slot

	GameLogger.info("TargetSelectionManager: Started item selection for %s (Slot %d, Acting %d)" % [item.item_name, slot_index, acting_party_slot])

	match item.target_type:
		ItemData.TargetType.NONE:
			_execute_no_target_use()
		ItemData.TargetType.ALL_PARTY:
			_execute_all_party_use()
		ItemData.TargetType.ALL_ENEMIES:
			_execute_all_enemies_use()
		ItemData.TargetType.SINGLE_PARTY_MEMBER, ItemData.TargetType.SINGLE_ENEMY:
			_is_selecting_target = true
			selection_mode_changed.emit(true, _pending_item)


func _on_portrait_clicked(target_slot_index: int) -> void:
	if not _is_selecting_target:
		return

	_is_selecting_target = false
	selection_mode_changed.emit(false, null)

	if _acting_party_slot >= 0:
		SignalBus.player_action_selected.emit(_acting_party_slot, &"ITEM", target_slot_index)
	else:
		_apply_field_item_to_slot(target_slot_index)

	target_selected.emit(target_slot_index)
	_reset_selection_state()


func set_pending_ability(ability: Resource) -> void:
	_pending_ability = ability


func get_pending_ability() -> Resource:
	return _pending_ability


func is_ally_targeting(target_type_val: Variant) -> bool:
	if is_instance_valid(_pending_ability):
		var raw_type: Variant = _pending_ability.get("target_type") if "target_type" in _pending_ability else _pending_ability.get("target")
		if raw_type is String or raw_type is StringName:
			var type_str: String = str(raw_type).to_upper()
			if "ENEMY" in type_str or "ENEMIES" in type_str:
				return false
			if "PARTY" in type_str or "MEMBER" in type_str or "ALLY" in type_str or "ALLIES" in type_str or "SELF" in type_str:
				return true

		var heal_val: int = 0
		if "heal_amount" in _pending_ability:
			heal_val = int(_pending_ability.get("heal_amount"))
		elif "health_restore" in _pending_ability:
			heal_val = int(_pending_ability.get("health_restore"))
		elif "heal" in _pending_ability:
			heal_val = int(_pending_ability.get("heal"))

		var damage_val: int = 0
		if "damage" in _pending_ability:
			damage_val = int(_pending_ability.get("damage"))
		elif "damage_amount" in _pending_ability:
			damage_val = int(_pending_ability.get("damage_amount"))

		if heal_val > 0 and damage_val == 0:
			return true
		if damage_val > 0 and heal_val == 0:
			return false

		var ability_name: String = ""
		if "spell_name" in _pending_ability:
			ability_name = str(_pending_ability.get("spell_name")).to_lower()
		elif "skill_name" in _pending_ability:
			ability_name = str(_pending_ability.get("skill_name")).to_lower()

		if "heal" in ability_name or "purr" in ability_name or "cure" in ability_name or "restore" in ability_name:
			return true
		if "dart" in ability_name or "bolt" in ability_name or "fire" in ability_name or "claw" in ability_name or "strike" in ability_name:
			return false

	if target_type_val is int or target_type_val is float:
		var val: int = int(target_type_val)
		if val == 2 or val == 3:
			return false
		if val == 0 or val == 1 or val == 4:
			return true

	var str_val: String = str(target_type_val).to_upper()
	if "ENEMY" in str_val or "ENEMIES" in str_val:
		return false
	if "PARTY" in str_val or "MEMBER" in str_val or "ALLY" in str_val or "ALLIES" in str_val or "SELF" in str_val:
		return true

	return false


func _execute_no_target_use() -> void:
	if _acting_party_slot >= 0:
		SignalBus.player_action_selected.emit(_acting_party_slot, &"ITEM", -1)
	else:
		var gs: Node = get_tree().root.get_node_or_null("GameState")
		if is_instance_valid(gs) and "inventory" in gs and gs.inventory != null:
			var active_cat: Resource = gs.get_active_cat() if gs.has_method("get_active_cat") else null
			var active_idx: int = gs.get("active_cat_index") if "active_cat_index" in gs else 0
			var success: bool = gs.inventory.use_item(_pending_slot_index, active_cat)
			GameLogger.info("TargetSelectionManager: No-target item use success = %s" % [str(success)])
			if success and is_instance_valid(active_cat):
				if active_cat.get("current_hp") != null:
					SignalBus.character_health_changed.emit(active_idx, active_cat.get("current_hp"))
				if active_cat.get("current_energy") != null:
					SignalBus.character_mana_changed.emit(active_idx, active_cat.get("current_energy"))
	_reset_selection_state()


func _execute_all_party_use() -> void:
	if _acting_party_slot >= 0:
		SignalBus.player_action_selected.emit(_acting_party_slot, &"ITEM", -1)
	else:
		var gs: Node = get_tree().root.get_node_or_null("GameState")
		if is_instance_valid(gs) and "current_party" in gs and gs.current_party:
			var party_slots: Array = gs.current_party.get("slots") as Array
			for idx: int in range(party_slots.size()):
				var cat: Resource = party_slots[idx] as Resource
				if is_instance_valid(cat) and "inventory" in gs and gs.inventory != null:
					var success: bool = gs.inventory.use_item(_pending_slot_index, cat)
					GameLogger.info("TargetSelectionManager: All-party item use on slot %d success = %s" % [idx, str(success)])
					if success:
						if cat.get("current_hp") != null:
							SignalBus.character_health_changed.emit(idx, cat.get("current_hp"))
						if cat.get("current_energy") != null:
							SignalBus.character_mana_changed.emit(idx, cat.get("current_energy"))
	_reset_selection_state()


func _execute_all_enemies_use() -> void:
	if _acting_party_slot >= 0:
		SignalBus.player_action_selected.emit(_acting_party_slot, &"ITEM", -1)
	_reset_selection_state()


func _apply_field_item_to_slot(target_slot_index: int) -> void:
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(gs) and "current_party" in gs and gs.current_party:
		var party_slots: Array = gs.current_party.get("slots") as Array
		if target_slot_index >= 0 and target_slot_index < party_slots.size():
			var target_cat: Resource = party_slots[target_slot_index] as Resource
			if is_instance_valid(target_cat) and "inventory" in gs and gs.inventory != null:
				var success: bool = gs.inventory.use_item(_pending_slot_index, target_cat)
				GameLogger.info("TargetSelectionManager: Field item applied to slot %d success = %s" % [target_slot_index, str(success)])
				if success:
					if target_cat.get("current_hp") != null:
						SignalBus.character_health_changed.emit(target_slot_index, target_cat.get("current_hp"))
					if target_cat.get("current_energy") != null:
						SignalBus.character_mana_changed.emit(target_slot_index, target_cat.get("current_energy"))


func cancel_selection() -> void:
	if not _is_selecting_target:
		return
	selection_mode_changed.emit(false, null)
	_reset_selection_state()
	selection_canceled.emit()


func get_pending_item() -> ItemData:
	return _pending_item


func get_pending_slot_index() -> int:
	return _pending_slot_index


func is_selecting_target() -> bool:
	return _is_selecting_target


func _reset_selection_state() -> void:
	_is_selecting_target = false
	_pending_item = null
	_pending_ability = null
	_pending_slot_index = -1
	_acting_party_slot = -1
