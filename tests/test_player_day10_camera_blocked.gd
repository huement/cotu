extends GutTest

# ---------------------------------------------------------------------------
# Camera position and yaw correctness after blocked moves (bump feedback).
# Guards against residual offset or yaw corruption after blocked-forward
# animations and ensures the camera tracks correctly after a blocked-then-turn
# sequence.
# ---------------------------------------------------------------------------

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

# CARDINAL_YAWS indexed by GridDefinitions.Facing enum value (0=N,1=E,2=S,3=W).
const CARDINAL_YAWS := [0.0, 270.0, 180.0, 90.0]


func _spawn_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.movement_config.smooth_mode = false
	player.movement_config.blocked_feedback_enabled = true
	player.movement_config.blocked_bump_distance = 0.1
	player.movement_config.blocked_bump_duration = 0.04   # short for reliable frame-based wait
	return player


func _wait_frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _normalized_degrees(value: float) -> float:
	var n := fmod(value, 360.0)
	if n < 0.0:
		n += 360.0
	if is_equal_approx(n, 360.0):
		n = 0.0
	return n


func _is_cardinal_yaw(value: float) -> bool:
	var n := _normalized_degrees(value)
	for yaw in CARDINAL_YAWS:
		if is_equal_approx(n, yaw):
			return true
	return false


func _get_camera(player: Player) -> Camera3D:
	var camera := player.get_node_or_null("Camera3D") as Camera3D
	assert_not_null(camera, "Player must have a Camera3D child")
	return camera


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_camera_position_canonical_after_blocked_forward() -> void:
	var player := _spawn_player()
	player.movement_controller.passability_fn = func(_cell: Vector2i) -> bool: return false

	var canonical_pos := player.global_position
	assert_false(player.execute_command(GridCommand.Type.STEP_FORWARD))

	await _wait_frames(15)

	assert_eq(player.global_position, canonical_pos,
		"player must return to canonical position after forward bump animation")

	var camera := _get_camera(player)
	assert_eq(
		camera.global_position,
		player.global_position + Vector3(0.0, player.camera_height, 0.0),
		"camera must sit at eye height over canonical position after bump"
	)


func test_camera_yaw_unchanged_after_blocked_forward() -> void:
	var player := _spawn_player()
	player.movement_controller.passability_fn = func(_cell: Vector2i) -> bool: return false

	var camera := _get_camera(player)
	var yaw_before := _normalized_degrees(camera.global_rotation_degrees.y)

	assert_false(player.execute_command(GridCommand.Type.STEP_FORWARD))
	await _wait_frames(15)

	var yaw_after := _normalized_degrees(camera.global_rotation_degrees.y)
	assert_true(_is_cardinal_yaw(yaw_after), "camera yaw must remain cardinal after blocked forward")
	assert_true(is_equal_approx(yaw_after, yaw_before),
		"camera yaw must not change on a blocked forward move")


func test_camera_position_canonical_after_blocked_strafe() -> void:
	# Strafe blocks have no bump animation — position must stay canonical immediately.
	var player := _spawn_player()
	player.movement_controller.passability_fn = func(_cell: Vector2i) -> bool: return false

	var canonical_pos := player.global_position
	assert_false(player.execute_command(GridCommand.Type.MOVE_LEFT))

	await get_tree().process_frame   # allow signal handlers to complete

	assert_eq(player.global_position, canonical_pos,
		"player position must stay canonical immediately after blocked strafe")

	var camera := _get_camera(player)
	assert_eq(
		camera.global_position,
		player.global_position + Vector3(0.0, player.camera_height, 0.0),
		"camera must stay at eye height after blocked strafe"
	)


func test_camera_follows_turn_after_prior_blocked_forward() -> void:
	# Guards the regression where a blocked-forward + bump sequence could leave
	# the camera in an inconsistent state for the subsequent turn animation.
	var player := _spawn_player()
	var om := GridOccupancyMap.new()
	om.set_blocked(Vector2i(0, -1), true)   # block one step north of origin
	player.movement_controller.passability_fn = om.is_passable

	# Blocked forward triggers bump animation
	assert_false(player.execute_command(GridCommand.Type.STEP_FORWARD))
	await _wait_frames(15)   # wait for bump to complete

	# Turn left: NORTH → WEST (must succeed and update camera yaw)
	assert_true(player.execute_command(GridCommand.Type.TURN_LEFT))
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.WEST)

	var camera := _get_camera(player)
	var expected_yaw := CARDINAL_YAWS[int(GridDefinitions.Facing.WEST)]   # 90.0
	assert_true(
		is_equal_approx(_normalized_degrees(camera.global_rotation_degrees.y), expected_yaw),
		"camera yaw must update to WEST after TURN_LEFT following a blocked forward"
	)
	assert_eq(
		camera.global_position,
		player.global_position + Vector3(0.0, player.camera_height, 0.0),
		"camera position must remain canonical after blocked-then-turn sequence"
	)
