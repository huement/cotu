extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CARDINAL_YAWS := [0.0, 90.0, 180.0, 270.0]


func _spawn_player() -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	player.movement_config.smooth_mode = false
	return player


func _normalized_degrees(value: float) -> float:
	var normalized := fmod(value, 360.0)
	if normalized < 0.0:
		normalized += 360.0
	if is_equal_approx(normalized, 360.0):
		normalized = 0.0
	return normalized


func _is_cardinal(value: float) -> bool:
	var normalized := _normalized_degrees(value)
	for yaw in CARDINAL_YAWS:
		if is_equal_approx(normalized, yaw):
			return true
	return false


func test_compliance_grid_commands_move_exactly_one_cell_or_noop_when_blocked() -> void:
	var player := _spawn_player()
	var traversals: Array[GridCommand.Type] = [
		GridCommand.Type.STEP_FORWARD,
		GridCommand.Type.STEP_BACK,
		GridCommand.Type.MOVE_LEFT,
		GridCommand.Type.MOVE_RIGHT,
	]

	for cmd in traversals:
		var before_cell := player.grid_state.cell
		assert_true(player.execute_command(cmd), "Traversal command should execute")
		var delta := player.grid_state.cell - before_cell
		var manhattan: int = absi(delta.x) + absi(delta.y)
		assert_eq(manhattan, 1, "Traversal command must move exactly one grid cell")

	player.grid_state = GridState.new(Vector2i.ZERO, GridDefinitions.Facing.NORTH)
	player._apply_canonical_transform()
	player.movement_controller.passability_fn = func(_cell: Vector2i) -> bool: return false

	var blocked_before := player.grid_state.cell
	assert_false(player.execute_command(GridCommand.Type.STEP_FORWARD), "Blocked forward step must no-op")
	assert_eq(player.grid_state.cell, blocked_before, "Blocked forward step must preserve grid cell")


func test_compliance_turns_are_cardinal_quarter_steps_only() -> void:
	var player := _spawn_player()
	var turns: Array[GridCommand.Type] = [
		GridCommand.Type.TURN_LEFT,
		GridCommand.Type.TURN_RIGHT,
	]

	for cmd in turns:
		var before_cell := player.grid_state.cell
		var before_facing := int(player.grid_state.facing)
		assert_true(player.execute_command(cmd), "Turn command should execute")
		assert_eq(player.grid_state.cell, before_cell, "Turn command must not translate position")

		var after_facing := int(player.grid_state.facing)
		var delta := (after_facing - before_facing + 4) % 4
		if cmd == GridCommand.Type.TURN_LEFT:
			assert_eq(delta, 3, "TURN_LEFT must be exactly one cardinal step")
		else:
			assert_eq(delta, 1, "TURN_RIGHT must be exactly one cardinal step")


func test_compliance_camera_yaw_remains_cardinal_during_mixed_script() -> void:
	var player := _spawn_player()
	var camera := player.get_node_or_null("Camera3D") as Camera3D
	assert_not_null(camera, "Player must provide first-person camera")

	var script: Array[GridCommand.Type] = [
		GridCommand.Type.STEP_FORWARD,
		GridCommand.Type.TURN_RIGHT,
		GridCommand.Type.MOVE_LEFT,
		GridCommand.Type.TURN_LEFT,
		GridCommand.Type.STEP_BACK,
	]

	for cmd in script:
		assert_true(player.execute_command(cmd))
		assert_true(_is_cardinal(camera.global_rotation_degrees.y), "Camera yaw must remain cardinal")
		assert_eq(camera.global_position, player.global_position + Vector3(0.0, player.camera_height, 0.0), "Camera must stay first-person centered")
