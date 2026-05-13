extends Control

signal close_requested

@onready var _title_label: Label = %TownTitleLabel
@onready var _player_hp_label: Label = %TownPlayerHPLabel
@onready var _status_label: Label = %TownStatusLabel
@onready var _rest_button: Button = %TownRestButton
@onready var _close_button: Button = %TownCloseButton

var _world: Node


func _ready() -> void:
	_world = _resolve_world_context()
	if _rest_button != null and not _rest_button.pressed.is_connected(_on_rest_pressed):
		_rest_button.pressed.connect(_on_rest_pressed)
	if _close_button != null and not _close_button.pressed.is_connected(_on_close_pressed):
		_close_button.pressed.connect(_on_close_pressed)
	_refresh_view()


func _process(_delta: float) -> void:
	_refresh_view()


func request_overlay_focus() -> void:
	if _rest_button != null:
		_rest_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if not event.is_pressed():
		return
	if event.is_action_pressed("close_overlay") or event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _refresh_view() -> void:
	if _world == null:
		_world = _resolve_world_context()
		if _world == null:
			return

	if _title_label != null:
		_title_label.text = "Town"

	var player_stats: CharacterStats = null
	if _world.has_method("get_player_stats"):
		player_stats = _world.call("get_player_stats") as CharacterStats

	if _player_hp_label != null:
		if player_stats != null:
			_player_hp_label.text = "Player HP: %d/%d" % [player_stats.health, player_stats.max_health]
		else:
			_player_hp_label.text = "Player HP: --"

	if _status_label != null and player_stats != null and player_stats.health >= player_stats.max_health:
		_status_label.text = "You are fully rested"


func _on_rest_pressed() -> void:
	if _world == null or not _world.has_method("rest_player"):
		if _status_label != null:
			_status_label.text = "Town services unavailable"
		return

	if bool(_world.call("rest_player")):
		if _status_label != null:
			_status_label.text = "You rest at the inn"
	else:
		if _status_label != null:
			_status_label.text = "Could not rest"

	_refresh_view()


func _on_close_pressed() -> void:
	close_requested.emit()


func _resolve_world_context() -> Node:
	var cursor: Node = self
	while cursor != null:
		if cursor.has_method("rest_player") and cursor.has_method("get_player_stats"):
			return cursor
		cursor = cursor.get_parent()

	return get_tree().current_scene
