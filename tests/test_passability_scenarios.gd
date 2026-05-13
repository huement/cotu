extends GutTest

# ---------------------------------------------------------------------------
# Passability edge-case scenarios:
# multi-cell obstacle layouts and all 16 facing × move combos.
# ---------------------------------------------------------------------------


func _make_controller(
		start_cell: Vector2i = Vector2i.ZERO,
		start_facing: GridDefinitions.Facing = GridDefinitions.Facing.NORTH) -> MovementController:
	var cfg := MovementConfig.new()
	cfg.smooth_mode = false
	var mc: MovementController = add_child_autofree(MovementController.new())
	mc.movement_config = cfg
	mc.grid_state = GridState.new(start_cell, start_facing)
	return mc


func test_all_translational_commands_blocked_when_surrounded() -> void:
	var mc := _make_controller()
	var om := GridOccupancyMap.new()
	om.set_blocked(Vector2i( 0, -1), true)   # NORTH neighbor
	om.set_blocked(Vector2i( 1,  0), true)   # EAST neighbor
	om.set_blocked(Vector2i( 0,  1), true)   # SOUTH neighbor
	om.set_blocked(Vector2i(-1,  0), true)   # WEST neighbor
	mc.passability_fn = om.is_passable

	assert_false(mc.execute_command(GridCommand.Type.STEP_FORWARD),  "STEP_FORWARD blocked when surrounded")
	assert_false(mc.execute_command(GridCommand.Type.STEP_BACK),     "STEP_BACK blocked when surrounded")
	assert_false(mc.execute_command(GridCommand.Type.MOVE_LEFT),     "MOVE_LEFT blocked when surrounded")
	assert_false(mc.execute_command(GridCommand.Type.MOVE_RIGHT),    "MOVE_RIGHT blocked when surrounded")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO, "cell unchanged when fully surrounded")
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.NORTH, "facing unchanged when fully surrounded")
	assert_false(mc.is_busy, "controller must not be busy after blocked commands")


func test_turns_unaffected_when_grid_fully_blocked() -> void:
	var mc := _make_controller()
	mc.passability_fn = func(_cell: Vector2i) -> bool: return false

	assert_true(mc.execute_command(GridCommand.Type.TURN_LEFT),  "TURN_LEFT succeeds despite full blockade")
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.WEST)
	assert_true(mc.execute_command(GridCommand.Type.TURN_RIGHT), "TURN_RIGHT succeeds despite full blockade")
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.NORTH)
	assert_eq(mc.grid_state.cell, Vector2i.ZERO, "turns must not translate position")


func test_corridor_traversal_forward_and_back() -> void:
	# Open corridor: (0,0) → (0,-1) → (0,-2) heading NORTH; walls at (0,-3) and (0,+1).
	var mc := _make_controller()
	var om := GridOccupancyMap.new()
	om.set_blocked(Vector2i(0, -3), true)   # north wall of corridor
	om.set_blocked(Vector2i(0,  1), true)   # south wall of corridor
	mc.passability_fn = om.is_passable

	assert_true(mc.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_eq(mc.grid_state.cell, Vector2i(0, -1))
	assert_true(mc.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_eq(mc.grid_state.cell, Vector2i(0, -2))
	assert_false(mc.execute_command(GridCommand.Type.STEP_FORWARD), "north wall blocks further advance")
	assert_eq(mc.grid_state.cell, Vector2i(0, -2))

	assert_true(mc.execute_command(GridCommand.Type.STEP_BACK))
	assert_eq(mc.grid_state.cell, Vector2i(0, -1))
	assert_true(mc.execute_command(GridCommand.Type.STEP_BACK))
	assert_eq(mc.grid_state.cell, Vector2i.ZERO, "back to origin")
	assert_false(mc.execute_command(GridCommand.Type.STEP_BACK), "south wall blocks further retreat")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)


func test_l_shaped_path_requires_turn_to_navigate() -> void:
	# Path: (0,0) → north → (0,-1) → turn right → east → (1,-1).
	# Dead end at (0,-2); east shortcut from origin blocked at (1,0).
	var mc := _make_controller()
	var om := GridOccupancyMap.new()
	om.set_blocked(Vector2i(0, -2), true)   # forward dead end past first step
	om.set_blocked(Vector2i(1,  0), true)   # east shortcut from origin
	mc.passability_fn = om.is_passable

	assert_false(mc.execute_command(GridCommand.Type.MOVE_RIGHT), "east shortcut from origin is blocked")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)

	assert_true(mc.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_eq(mc.grid_state.cell, Vector2i(0, -1))
	assert_false(mc.execute_command(GridCommand.Type.STEP_FORWARD), "dead end ahead is blocked")
	assert_eq(mc.grid_state.cell, Vector2i(0, -1))

	assert_true(mc.execute_command(GridCommand.Type.TURN_RIGHT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.EAST)
	assert_true(mc.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_eq(mc.grid_state.cell, Vector2i(1, -1), "L-corner reached via required turn")


func test_blocked_state_unchanged_for_all_facing_and_move_combos() -> void:
	# 4 facings × 4 translational commands = 16 scenarios.
	# In each, only the target cell is blocked; state must remain identical after the attempt.
	var all_facings: Array = [
		GridDefinitions.Facing.NORTH,
		GridDefinitions.Facing.EAST,
		GridDefinitions.Facing.SOUTH,
		GridDefinitions.Facing.WEST,
	]
	var commands: Array = [
		GridCommand.Type.STEP_FORWARD,
		GridCommand.Type.STEP_BACK,
		GridCommand.Type.MOVE_LEFT,
		GridCommand.Type.MOVE_RIGHT,
	]

	for facing in all_facings:
		for cmd in commands:
			var mc := _make_controller(Vector2i.ZERO, facing)

			var fwd_dir := GridDefinitions.facing_to_vec2i(facing)
			var rgt_dir := GridDefinitions.facing_to_vec2i(GridDefinitions.rotate_right(facing))

			var target: Vector2i
			match cmd:
				GridCommand.Type.STEP_FORWARD:  target = fwd_dir
				GridCommand.Type.STEP_BACK:     target = -fwd_dir
				GridCommand.Type.MOVE_LEFT:     target = -rgt_dir
				GridCommand.Type.MOVE_RIGHT:    target = rgt_dir

			var om := GridOccupancyMap.new()
			om.set_blocked(target, true)
			mc.passability_fn = om.is_passable

			var label := "facing=%d cmd=%d" % [int(facing), int(cmd)]
			assert_false(mc.execute_command(cmd),          "%s: must return false when target blocked" % label)
			assert_eq(mc.grid_state.cell,   Vector2i.ZERO, "%s: cell must not change on blocked" % label)
			assert_eq(mc.grid_state.facing, facing,        "%s: facing must not change on blocked move" % label)
