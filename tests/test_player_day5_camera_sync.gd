extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CARDINAL_YAWS := [0.0, 270.0, 180.0, 90.0]


func _spawn_player(smooth_mode: bool = false, step_duration: float = 0.03, turn_duration: float = 0.02) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.movement_config.smooth_mode = smooth_mode
	player.movement_config.step_duration = step_duration
	player.movement_config.turn_duration = turn_duration
	return player


func _wait_until_not_busy(player: Player, max_frames: int = 180) -> void:
	for _i in range(max_frames):
		if not player.movement_controller.is_busy:
			return
		await get_tree().process_frame
	fail_test("Timed out waiting for smooth action completion")


func _normalized_degrees(value: float) -> float:
	var normalized := fmod(value, 360.0)
	if normalized < 0.0:
		normalized += 360.0
	if is_equal_approx(normalized, 360.0):
		normalized = 0.0
	return normalized


func _is_cardinal_yaw(value: float) -> bool:
	var normalized := _normalized_degrees(value)
	for yaw in CARDINAL_YAWS:
		if is_equal_approx(normalized, yaw):
			return true
	return false


func _assert_camera_centered(player: Player) -> void:
	var camera := player.get_node_or_null("Camera3D") as Camera3D
	assert_not_null(camera, "Player should provide a Camera3D child")
	assert_eq(camera.global_position, player.global_position + Vector3(0.0, player.camera_height, 0.0), "Camera must remain centered on player eye height")


func test_player_scene_has_camera3d_child() -> void:
	var player := _spawn_player()
	var camera := player.get_node_or_null("Camera3D") as Camera3D

	assert_not_null(camera)
	assert_true(camera.current)


func test_camera_uses_camera_height_offset() -> void:
	var player := _spawn_player()
	player.camera_height = 1.25
	player._apply_canonical_transform()

	_assert_camera_centered(player)


func test_camera_yaw_is_cardinal_for_all_facings() -> void:
	var player := _spawn_player()
	var camera := player.get_node_or_null("Camera3D") as Camera3D
	assert_not_null(camera)

	for facing in GridDefinitions.Facing.values():
		player.grid_state = GridState.new(Vector2i.ZERO, facing)
		player._apply_canonical_transform()

		assert_true(_is_cardinal_yaw(camera.global_rotation_degrees.y), "Camera yaw must stay cardinal")
		assert_true(is_equal_approx(_normalized_degrees(camera.global_rotation_degrees.y), CARDINAL_YAWS[facing]), "Camera yaw should match cardinal facing")


func test_snap_and_smooth_modes_match_camera_transform() -> void:
	var snap_player := _spawn_player(false)
	var smooth_player := _spawn_player(true, 0.01, 0.01)
	var script: Array[GridCommand.Type] = [
		GridCommand.Type.STEP_FORWARD,
		GridCommand.Type.TURN_RIGHT,
	]

	for cmd in script:
		assert_true(snap_player.execute_command(cmd))
		assert_true(smooth_player.execute_command(cmd))
		await _wait_until_not_busy(smooth_player)

	var snap_camera := snap_player.get_node_or_null("Camera3D") as Camera3D
	var smooth_camera := smooth_player.get_node_or_null("Camera3D") as Camera3D
	assert_not_null(snap_camera)
	assert_not_null(smooth_camera)
	assert_eq(smooth_camera.global_position, snap_camera.global_position)
	assert_eq(_normalized_degrees(smooth_camera.global_rotation_degrees.y), _normalized_degrees(snap_camera.global_rotation_degrees.y))


func test_camera_stays_centered_and_cardinal_across_command_loop() -> void:
	var player := _spawn_player(true, 0.01, 0.01)
	var camera := player.get_node_or_null("Camera3D") as Camera3D
	assert_not_null(camera)

	var loop_script: Array[GridCommand.Type] = [
		GridCommand.Type.STEP_FORWARD,
		GridCommand.Type.TURN_RIGHT,
		GridCommand.Type.MOVE_LEFT,
		GridCommand.Type.STEP_BACK,
		GridCommand.Type.TURN_LEFT,
		GridCommand.Type.MOVE_RIGHT,
	]

	for i in range(12):
		var cmd := loop_script[i % loop_script.size()]
		assert_true(player.execute_command(cmd), "Each loop command should execute")
		await _wait_until_not_busy(player)
		_assert_camera_centered(player)
		assert_true(_is_cardinal_yaw(camera.global_rotation_degrees.y), "Camera yaw must remain cardinal after each action")
