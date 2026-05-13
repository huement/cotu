extends GutTest

# ---------------------------------------------------------------------------
# GridOccupancyMap unit tests (no scene required)
# ---------------------------------------------------------------------------

func test_empty_map_all_passable() -> void:
	var om := GridOccupancyMap.new()
	assert_true(om.is_passable(Vector2i(0, 0)), "origin should be passable on empty map")
	assert_true(om.is_passable(Vector2i(5, -3)), "arbitrary cell should be passable on empty map")


func test_set_blocked_makes_cell_impassable() -> void:
	var om := GridOccupancyMap.new()
	om.set_blocked(Vector2i(2, 3), true)
	assert_false(om.is_passable(Vector2i(2, 3)), "blocked cell should not be passable")


func test_unblocking_restores_passability() -> void:
	var om := GridOccupancyMap.new()
	om.set_blocked(Vector2i(1, 1), true)
	om.set_blocked(Vector2i(1, 1), false)
	assert_true(om.is_passable(Vector2i(1, 1)), "unblocked cell should be passable again")


func test_blocking_does_not_affect_adjacent_cells() -> void:
	var om := GridOccupancyMap.new()
	om.set_blocked(Vector2i(0, 0), true)
	assert_true(om.is_passable(Vector2i(1, 0)), "neighbour should remain passable")
	assert_true(om.is_passable(Vector2i(0, 1)), "neighbour should remain passable")


# ---------------------------------------------------------------------------
# MovementController passability integration tests (snap mode)
# ---------------------------------------------------------------------------

func _make_controller() -> MovementController:
	var cfg := MovementConfig.new()
	cfg.smooth_mode = false

	var state := GridState.new(Vector2i.ZERO, GridDefinitions.Facing.NORTH)

	var mc: MovementController = add_child_autofree(MovementController.new())
	mc.movement_config = cfg
	mc.grid_state = state
	return mc


func test_no_passability_fn_all_moves_pass() -> void:
	var mc := _make_controller()
	watch_signals(mc)
	var ok := mc.execute_command(GridCommand.Type.STEP_FORWARD)
	assert_true(ok, "should execute without passability_fn")
	assert_signal_emit_count(mc, "action_completed", 1)


func test_blocked_translation_returns_false_and_emits_nothing() -> void:
	var mc := _make_controller()
	var om := GridOccupancyMap.new()
	om.set_blocked(Vector2i(0, -1), true)  # cell directly north of origin (NORTH facing → z-1)
	mc.passability_fn = om.is_passable

	watch_signals(mc)
	var ok := mc.execute_command(GridCommand.Type.STEP_FORWARD)
	assert_false(ok, "blocked move should return false")
	assert_false(mc.is_busy, "is_busy must remain false after blocked command")
	assert_signal_emit_count(mc, "action_completed", 0)
	assert_signal_emit_count(mc, "action_started", 0)


func test_blocked_translation_does_not_mutate_state() -> void:
	var mc := _make_controller()
	var om := GridOccupancyMap.new()
	om.set_blocked(Vector2i(0, -1), true)
	mc.passability_fn = om.is_passable

	mc.execute_command(GridCommand.Type.STEP_FORWARD)
	assert_eq(mc.grid_state.cell, Vector2i(0, 0), "cell must not change when blocked")


func test_valid_translation_completes_exactly_once() -> void:
	var mc := _make_controller()
	var om := GridOccupancyMap.new()
	# origin (0,0) is open; target (0,-1) is open
	mc.passability_fn = om.is_passable

	watch_signals(mc)
	var ok := mc.execute_command(GridCommand.Type.STEP_FORWARD)
	assert_true(ok, "unblocked move should return true")
	assert_signal_emit_count(mc, "action_completed", 1)


func test_turns_never_blocked_even_with_always_false_passability_fn() -> void:
	var mc := _make_controller()
	# A passability_fn that always denies
	mc.passability_fn = func(_cell: Vector2i) -> bool: return false

	watch_signals(mc)
	var ok_left := mc.execute_command(GridCommand.Type.TURN_LEFT)
	assert_true(ok_left, "TURN_LEFT should not be blocked by passability_fn")
	assert_signal_emit_count(mc, "action_completed", 1)


func test_all_four_translation_directions_checked_individually() -> void:
	# Block each cardinal neighbour and verify each direction is blocked
	var directions := [
		[GridCommand.Type.STEP_FORWARD,  Vector2i(0, -1)],
		[GridCommand.Type.STEP_BACK,     Vector2i(0,  1)],
		[GridCommand.Type.MOVE_LEFT,     Vector2i(-1, 0)],
		[GridCommand.Type.MOVE_RIGHT,    Vector2i(1,  0)],
	]
	for pair in directions:
		var cmd: GridCommand.Type = pair[0]
		var blocked_cell: Vector2i = pair[1]

		var mc := _make_controller()
		var om := GridOccupancyMap.new()
		om.set_blocked(blocked_cell, true)
		mc.passability_fn = om.is_passable

		watch_signals(mc)
		var ok := mc.execute_command(cmd)
		assert_false(ok, "cmd %d should be blocked" % cmd)
		assert_signal_emit_count(mc, "action_completed", 0)
