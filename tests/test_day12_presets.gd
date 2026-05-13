extends GutTest

const WORLD_SCENE := preload("res://scenes/world/main.tscn")
const SNAP_PRESET := preload("res://resources/presets/movement_config_snap.tres")
const SMOOTH_PRESET := preload("res://resources/presets/movement_config_smooth.tres")


func _spawn_world() -> Node3D:
	var world := WORLD_SCENE.instantiate() as Node3D
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	return world


func _wait_until_not_busy(player: Player, max_frames: int = 240) -> void:
	for _i in range(max_frames):
		if not player.movement_controller.is_busy:
			return
		await get_tree().process_frame
	fail_test("Timed out waiting for command completion")


func _run_script_for_preset(world: Node3D, preset_name: String) -> Dictionary:
	assert_true(world.apply_movement_preset(preset_name), "Expected movement preset to apply")
	var player := world.get_node_or_null("Player") as Player
	assert_not_null(player)
	# Keep this regression focused on preset behavior, not map layout passability.
	player.movement_controller.passability_fn = Callable()

	var script: Array[GridCommand.Type] = [
		GridCommand.Type.STEP_FORWARD,
		GridCommand.Type.TURN_RIGHT,
		GridCommand.Type.STEP_FORWARD,
		GridCommand.Type.TURN_LEFT,
		GridCommand.Type.STEP_BACK,
	]

	for cmd in script:
		assert_true(player.execute_command(cmd), "Expected command to execute for preset %s" % preset_name)
		await _wait_until_not_busy(player)

	return {
		"cell": player.grid_state.cell,
		"facing": int(player.grid_state.facing),
		"position": player.global_position,
		"yaw": player.rotation_degrees.y,
	}


func test_day12_preset_resources_define_snap_and_smooth_modes() -> void:
	assert_false(SNAP_PRESET.smooth_mode)
	assert_eq(SNAP_PRESET.step_duration, 0.0)
	assert_eq(SNAP_PRESET.turn_duration, 0.0)

	assert_true(SMOOTH_PRESET.smooth_mode)
	assert_gt(SMOOTH_PRESET.step_duration, 0.0)
	assert_gt(SMOOTH_PRESET.turn_duration, 0.0)


func test_day12_world_can_swap_presets_without_code_edits() -> void:
	var world := await _spawn_world()
	assert_true(world.apply_movement_preset("Snap"))
	assert_true(world.apply_movement_preset("Smooth"))


func test_day12_snap_and_smooth_presets_match_regression_outcome() -> void:
	var snap_world := await _spawn_world()
	var smooth_world := await _spawn_world()

	var snap_result := await _run_script_for_preset(snap_world, "Snap")
	var smooth_result := await _run_script_for_preset(smooth_world, "Smooth")

	assert_eq(smooth_result["cell"], snap_result["cell"])
	assert_eq(smooth_result["facing"], snap_result["facing"])
	assert_eq(smooth_result["position"], snap_result["position"])
	assert_eq(smooth_result["yaw"], snap_result["yaw"])
