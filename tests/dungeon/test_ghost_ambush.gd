# res://tests/dungeon/test_ghost_ambush.gd
extends GutTest


func test_default_haunt_covers_most_of_a_floor() -> void:
	assert_eq(GhostAmbushComponent.DEFAULT_HAUNT_RADIUS, 15)


func test_level_one_window_is_a_quick_turn_not_a_stroll() -> void:
	var window: float = GhostAmbushComponent.reaction_window(1.15, 1)
	assert_almost_eq(window, 1.15, 0.001)
	assert_lt(window, 2.0)


func test_higher_level_tightens_until_the_floor() -> void:
	assert_almost_eq(GhostAmbushComponent.reaction_window(1.15, 2), 1.07, 0.001)
	assert_almost_eq(GhostAmbushComponent.reaction_window(1.15, 20), GhostAmbushComponent.MIN_REACTION_SECONDS, 0.001)


func test_only_turning_around_counts_as_a_dodge() -> void:
	assert_false(GhostAmbushComponent.player_turned_around(90.0))
	assert_false(GhostAmbushComponent.player_turned_around(134.9))
	assert_true(GhostAmbushComponent.player_turned_around(135.0))
	assert_true(GhostAmbushComponent.player_turned_around(180.0))


func test_outer_haunt_is_quiet_and_the_center_beats_faster() -> void:
	var radius: int = GhostAmbushComponent.DEFAULT_HAUNT_RADIUS
	assert_lt(GhostAmbushComponent.heartbeat_interval(radius, radius, false), 0.0)
	var mid: float = GhostAmbushComponent.heartbeat_interval(8, radius, false)
	var center: float = GhostAmbushComponent.heartbeat_interval(0, radius, false)
	assert_gt(mid, 0.0)
	assert_gt(mid, center)
	assert_almost_eq(GhostAmbushComponent.heartbeat_interval(14, radius, true), GhostAmbushComponent.HEARTBEAT_AMBUSH_SECONDS, 0.001)
