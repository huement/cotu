extends GutTest

# ---------------------------------------------------------------------------
# Exhaustive facing transition matrix: 4 starting facings × 4 target facings
# = 16 combinations. Uses MovementController in snap mode.
# Each 2-step transition also asserts the intermediate facing, not just the
# final one. Cell position must never change during any turn sequence.
# ---------------------------------------------------------------------------


func _make_controller(start_facing: GridDefinitions.Facing) -> MovementController:
	var cfg := MovementConfig.new()
	cfg.smooth_mode = false
	var mc: MovementController = add_child_autofree(MovementController.new())
	mc.movement_config = cfg
	mc.grid_state = GridState.new(Vector2i.ZERO, start_facing)
	return mc


# ---------------------------------------------------------------------------
# From NORTH
# ---------------------------------------------------------------------------

func test_transitions_from_north() -> void:
	# N→N: identity — no turns needed
	var mc := _make_controller(GridDefinitions.Facing.NORTH)
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.NORTH, "N→N identity")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)

	# N→E: 1 right
	mc = _make_controller(GridDefinitions.Facing.NORTH)
	assert_true(mc.execute_command(GridCommand.Type.TURN_RIGHT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.EAST, "N→E after TURN_RIGHT")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)

	# N→S: 2 rights — check EAST intermediate after first turn
	mc = _make_controller(GridDefinitions.Facing.NORTH)
	assert_true(mc.execute_command(GridCommand.Type.TURN_RIGHT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.EAST, "N→S: intermediate must be EAST after 1st turn")
	assert_true(mc.execute_command(GridCommand.Type.TURN_RIGHT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.SOUTH, "N→S after 2× TURN_RIGHT")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)

	# N→W: 1 left
	mc = _make_controller(GridDefinitions.Facing.NORTH)
	assert_true(mc.execute_command(GridCommand.Type.TURN_LEFT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.WEST, "N→W after TURN_LEFT")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)


# ---------------------------------------------------------------------------
# From EAST
# ---------------------------------------------------------------------------

func test_transitions_from_east() -> void:
	# E→E: identity
	var mc := _make_controller(GridDefinitions.Facing.EAST)
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.EAST, "E→E identity")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)

	# E→S: 1 right
	mc = _make_controller(GridDefinitions.Facing.EAST)
	assert_true(mc.execute_command(GridCommand.Type.TURN_RIGHT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.SOUTH, "E→S after TURN_RIGHT")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)

	# E→W: 2 rights — check SOUTH intermediate after first turn
	mc = _make_controller(GridDefinitions.Facing.EAST)
	assert_true(mc.execute_command(GridCommand.Type.TURN_RIGHT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.SOUTH, "E→W: intermediate must be SOUTH after 1st turn")
	assert_true(mc.execute_command(GridCommand.Type.TURN_RIGHT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.WEST, "E→W after 2× TURN_RIGHT")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)

	# E→N: 1 left
	mc = _make_controller(GridDefinitions.Facing.EAST)
	assert_true(mc.execute_command(GridCommand.Type.TURN_LEFT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.NORTH, "E→N after TURN_LEFT")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)


# ---------------------------------------------------------------------------
# From SOUTH
# ---------------------------------------------------------------------------

func test_transitions_from_south() -> void:
	# S→S: identity
	var mc := _make_controller(GridDefinitions.Facing.SOUTH)
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.SOUTH, "S→S identity")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)

	# S→W: 1 right
	mc = _make_controller(GridDefinitions.Facing.SOUTH)
	assert_true(mc.execute_command(GridCommand.Type.TURN_RIGHT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.WEST, "S→W after TURN_RIGHT")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)

	# S→N: 2 rights — check WEST intermediate after first turn
	mc = _make_controller(GridDefinitions.Facing.SOUTH)
	assert_true(mc.execute_command(GridCommand.Type.TURN_RIGHT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.WEST, "S→N: intermediate must be WEST after 1st turn")
	assert_true(mc.execute_command(GridCommand.Type.TURN_RIGHT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.NORTH, "S→N after 2× TURN_RIGHT")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)

	# S→E: 1 left
	mc = _make_controller(GridDefinitions.Facing.SOUTH)
	assert_true(mc.execute_command(GridCommand.Type.TURN_LEFT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.EAST, "S→E after TURN_LEFT")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)


# ---------------------------------------------------------------------------
# From WEST
# ---------------------------------------------------------------------------

func test_transitions_from_west() -> void:
	# W→W: identity
	var mc := _make_controller(GridDefinitions.Facing.WEST)
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.WEST, "W→W identity")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)

	# W→N: 1 right
	mc = _make_controller(GridDefinitions.Facing.WEST)
	assert_true(mc.execute_command(GridCommand.Type.TURN_RIGHT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.NORTH, "W→N after TURN_RIGHT")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)

	# W→E: 2 rights — check NORTH intermediate after first turn
	mc = _make_controller(GridDefinitions.Facing.WEST)
	assert_true(mc.execute_command(GridCommand.Type.TURN_RIGHT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.NORTH, "W→E: intermediate must be NORTH after 1st turn")
	assert_true(mc.execute_command(GridCommand.Type.TURN_RIGHT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.EAST, "W→E after 2× TURN_RIGHT")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)

	# W→S: 1 left
	mc = _make_controller(GridDefinitions.Facing.WEST)
	assert_true(mc.execute_command(GridCommand.Type.TURN_LEFT))
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.SOUTH, "W→S after TURN_LEFT")
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)
