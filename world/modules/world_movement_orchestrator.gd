extends Node
class_name WorldMovementOrchestrator

const PRESET_SNAP := &"snap"


func apply_preset(player, preset_name: String, active_preset_name: String, preset_snap_path: String, preset_smooth_path: String) -> Dictionary:
	if player == null:
		return {"ok": false, "active_name": active_preset_name}

	var selected_name := preset_name if not preset_name.is_empty() else active_preset_name
	var preset_key := selected_name.strip_edges().to_lower()
	var selected_path := preset_smooth_path
	var resolved_active_name := "Smooth"

	if preset_key == PRESET_SNAP:
		selected_path = preset_snap_path
		resolved_active_name = "Snap"

	var selected_preset := load(selected_path) as MovementConfig
	if selected_preset == null:
		return {"ok": false, "active_name": active_preset_name}

	if player.movement_config == null:
		player.movement_config = MovementConfig.new()

	_copy_movement_config_values(selected_preset, player.movement_config)
	if player.movement_controller != null:
		player.movement_controller.movement_config = player.movement_config
	if player.grid_state != null:
		player._apply_canonical_transform()

	return {"ok": true, "active_name": resolved_active_name}


func _copy_movement_config_values(source: MovementConfig, target: MovementConfig) -> void:
	target.cell_size = source.cell_size
	target.smooth_mode = source.smooth_mode
	target.step_duration = source.step_duration
	target.turn_duration = source.turn_duration
	target.blocked_feedback_enabled = source.blocked_feedback_enabled
	target.blocked_bump_distance = source.blocked_bump_distance
	target.blocked_bump_duration = source.blocked_bump_duration
