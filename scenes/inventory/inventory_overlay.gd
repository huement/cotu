extends Control

signal close_requested

@onready var _title_label: Label = %InventoryTitleLabel
@onready var _player_hp_label: Label = %InventoryPlayerHPLabel
@onready var _item_list: ItemList = %InventoryItemList
@onready var _status_label: Label = %InventoryStatusLabel
@onready var _use_button: Button = %InventoryUseButton
@onready var _close_button: Button = %InventoryCloseButton

var _world: Node
var _last_snapshot: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_world = _resolve_world_context()
	if _use_button != null and not _use_button.pressed.is_connected(_on_use_pressed):
		_use_button.pressed.connect(_on_use_pressed)
	if _close_button != null and not _close_button.pressed.is_connected(_on_close_pressed):
		_close_button.pressed.connect(_on_close_pressed)
	_refresh_view(true)


func _process(_delta: float) -> void:
	_refresh_view(false)


func request_overlay_focus() -> void:
	if _item_list != null:
		_item_list.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if not event.is_pressed():
		return
	if event.is_action_pressed("close_overlay") or event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _refresh_view(force_list_refresh: bool) -> void:
	if _world == null:
		_world = _resolve_world_context()
		if _world == null:
			return

	if _title_label != null:
		_title_label.text = "Inventory"

	var player_stats: CharacterStats = null
	if _world.has_method("get_player_stats"):
		player_stats = _world.call("get_player_stats") as CharacterStats
	if _player_hp_label != null:
		if player_stats != null:
			_player_hp_label.text = "Player HP: %d/%d" % [player_stats.health, player_stats.max_health]
		else:
			_player_hp_label.text = "Player HP: --"

	var items: Array = []
	if _world.has_method("get_player_inventory_items"):
		items = _world.call("get_player_inventory_items") as Array

	var snapshot := PackedStringArray()
	for item in items:
		if item == null:
			snapshot.append("<null>")
			continue
		var item_name := String(item.item_name)
		var item_type := int(item.item_type)
		snapshot.append("%s|%d" % [item_name, item_type])

	if force_list_refresh or snapshot != _last_snapshot:
		_rebuild_item_list(items)
		_last_snapshot = snapshot

	if _use_button != null:
		_use_button.disabled = _item_list == null or _item_list.get_selected_items().is_empty()


func _rebuild_item_list(items: Array) -> void:
	if _item_list == null:
		return

	var previous_selection := -1
	if not _item_list.get_selected_items().is_empty():
		previous_selection = int(_item_list.get_selected_items()[0])

	_item_list.clear()
	for item in items:
		if item == null:
			_item_list.add_item("Unknown Item")
			continue
		var item_name := String(item.item_name)
		if item_name.is_empty():
			item_name = "Unnamed Item"
		_item_list.add_item(item_name)

	if _item_list.item_count == 0:
		if _status_label != null:
			_status_label.text = "Inventory is empty"
		return

	var selected := clampi(previous_selection, 0, _item_list.item_count - 1)
	_item_list.select(selected)
	if _status_label != null:
		_status_label.text = "Select an item and choose Use"


func _on_use_pressed() -> void:
	if _item_list == null:
		return
	if _item_list.get_selected_items().is_empty():
		if _status_label != null:
			_status_label.text = "Select an item first"
		return

	var index := int(_item_list.get_selected_items()[0])
	if _world == null or not _world.has_method("use_player_inventory_item"):
		if _status_label != null:
			_status_label.text = "Inventory unavailable"
		return

	if bool(_world.call("use_player_inventory_item", index)):
		if _status_label != null:
			_status_label.text = "Item used"
	else:
		if _status_label != null:
			_status_label.text = "Could not use item"

	_refresh_view(true)


func _on_close_pressed() -> void:
	close_requested.emit()


func _resolve_world_context() -> Node:
	var cursor: Node = self
	while cursor != null:
		if cursor.has_method("get_player_inventory_items") and cursor.has_method("use_player_inventory_item"):
			return cursor
		cursor = cursor.get_parent()

	return get_tree().current_scene
