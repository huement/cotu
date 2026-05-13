extends Node
class_name WorldPolicyOrchestrator

var _player
var _overlay_module: WorldOverlayModule
var _ui_module: WorldUIModule
var _btn_open_inventory: Button


func configure(player, overlay_module: WorldOverlayModule, ui_module: WorldUIModule, btn_open_inventory: Button) -> void:
	_player = player
	_overlay_module = overlay_module
	_ui_module = ui_module
	_btn_open_inventory = btn_open_inventory


func open_overlay(kind: StringName, allow_non_gameplay: bool, gameplay_active: bool) -> bool:
	if not allow_non_gameplay and not gameplay_active:
		return false
	if _overlay_module.active_overlay_kind() == kind and _overlay_module.has_active_overlay():
		return false
	if not _overlay_module.open_overlay(kind):
		return false

	set_exploration_active(false)
	_refresh_debug_buttons()
	return true


func close_overlay(restore_exploration: bool) -> void:
	_overlay_module.close_overlay()

	if restore_exploration:
		set_exploration_active(true)
		if _btn_open_inventory != null:
			_btn_open_inventory.call_deferred("grab_focus")

	_refresh_debug_buttons()


func apply_state_side_effects(
		current_state: StringName,
		is_gameplay_active: bool,
		is_combat_active: bool,
		overlay_combat: StringName,
		overlay_victory: StringName,
		overlay_defeat: StringName,
		state_gameover_failure: StringName,
		state_gameover_success: StringName) -> void:
	if is_gameplay_active:
		var current_overlay_kind := _overlay_module.active_overlay_kind()
		if current_overlay_kind == overlay_combat or current_overlay_kind == overlay_victory or current_overlay_kind == overlay_defeat:
			close_overlay(false)
		if not _overlay_module.has_active_overlay():
			set_exploration_active(true)
		return

	if is_combat_active:
		set_exploration_active(false)
		return

	close_overlay(false)
	set_exploration_active(false)

	if current_state == state_gameover_failure:
		open_overlay(overlay_defeat, true, true)
	elif current_state == state_gameover_success:
		open_overlay(overlay_victory, true, true)


func set_exploration_active(is_active: bool) -> void:
	if _player == null:
		return
	if is_active:
		_player.resume_exploration_commands()
	else:
		_player.pause_exploration_commands()


func _refresh_debug_buttons() -> void:
	_ui_module.refresh_debug_buttons(_overlay_module.has_active_overlay())
