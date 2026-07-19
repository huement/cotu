extends Node
class_name WorldInputOrchestrator

var _btn_open_inventory: Button
var _btn_open_combat: Button
var _btn_open_town: Button
var _btn_toggle_minimap: Button
var _btn_close_overlay: Button

var _open_inventory_fn: Callable
var _open_combat_fn: Callable
var _open_town_fn: Callable
var _toggle_minimap_fn: Callable
var _close_overlay_fn: Callable


func configure(
		btn_open_inventory: Button,
		btn_open_combat: Button,
		btn_open_town: Button,
		btn_toggle_minimap: Button,
		btn_close_overlay: Button,
		open_inventory_fn: Callable,
		open_combat_fn: Callable,
		open_town_fn: Callable,
		toggle_minimap_fn: Callable,
		close_overlay_fn: Callable) -> void:
	_btn_open_inventory = btn_open_inventory
	_btn_open_combat = btn_open_combat
	_btn_open_town = btn_open_town
	_btn_toggle_minimap = btn_toggle_minimap
	_btn_close_overlay = btn_close_overlay
	_open_inventory_fn = open_inventory_fn
	_open_combat_fn = open_combat_fn
	_open_town_fn = open_town_fn
	_toggle_minimap_fn = toggle_minimap_fn
	_close_overlay_fn = close_overlay_fn


func wire_overlay_controls() -> void:
	if _btn_open_inventory != null and not _btn_open_inventory.pressed.is_connected(_open_inventory_fn):
		_btn_open_inventory.pressed.connect(_open_inventory_fn)
	if _btn_open_combat != null and not _btn_open_combat.pressed.is_connected(_open_combat_fn):
		_btn_open_combat.pressed.connect(_open_combat_fn)
	if _btn_open_town != null and not _btn_open_town.pressed.is_connected(_open_town_fn):
		_btn_open_town.pressed.connect(_open_town_fn)
	if _btn_toggle_minimap != null and not _btn_toggle_minimap.pressed.is_connected(_toggle_minimap_fn):
		_btn_toggle_minimap.pressed.connect(_toggle_minimap_fn)
	if _btn_close_overlay != null and not _btn_close_overlay.pressed.is_connected(_close_overlay_fn):
		_btn_close_overlay.pressed.connect(_close_overlay_fn)


func handle_unhandled_input(event: InputEvent, gameplay_active: bool) -> bool:
	if event is InputEventKey and event.echo:
		return false

	if not gameplay_active:
		return false

	if event.is_action_pressed("open_inventory"):
		_open_inventory_fn.call()
		return true

	if event.is_action_pressed("open_combat"):
		_open_combat_fn.call()
		return true

	if event.is_action_pressed("open_town"):
		_open_town_fn.call()
		return true

	if event.is_action_pressed("close_overlay") or event.is_action_pressed("ui_cancel"):
		_close_overlay_fn.call()
		return true

	return false
