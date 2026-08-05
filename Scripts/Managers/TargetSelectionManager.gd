# res://Scripts/Managers/TargetSelectionManager.gd
extends Node

signal target_selected(target_index: int)
signal selection_canceled()
signal selection_mode_changed(is_selecting: bool, item: ItemData)

var _pending_item: ItemData = null
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


func _execute_no_target_use() -> void:
	if _acting_party_slot >= 0:
		SignalBus.player_action_selected.emit(_acting_party_slot, &"ITEM", -1)
	else:
		var gs: Node = get_tree().root.get_node_or_null("GameState")
		if is_instance_valid(gs) and "inventory" in gs and gs.inventory != null:
			var active_cat: Resource = gs.get_active_cat() if gs.has_method("get_active_cat") else null
			var active_idx: int = gs.get("active_cat_index") if "active_cat_index" in gs else 0
			gs.inventory.use_item(_pending_slot_index, active_cat)
			if is_instance_valid(active_cat):
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
					gs.inventory.use_item(_pending_slot_index, cat)
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
				gs.inventory.use_item(_pending_slot_index, target_cat)
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
	_pending_slot_index = -1
	_acting_party_slot = -1
