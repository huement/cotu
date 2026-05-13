extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var player: Player


func before_each() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.movement_config = MovementConfig.new()


func test_player_transform_projects_from_grid_state() -> void:
	player.grid_state = GridState.new(Vector2i(3, -2), GridDefinitions.Facing.EAST)

	player._apply_canonical_transform()

	assert_eq(player.global_position, Vector3(3.0, 0.0, -2.0), "Player position should project directly from grid_state.cell")
	assert_eq(player.rotation_degrees.y, -90.0, "Player yaw should be -facing * 90.0")


func test_player_yaw_is_cardinal_for_all_facings() -> void:
	var expected_yaw: Dictionary = {
		GridDefinitions.Facing.NORTH: 0.0,
		GridDefinitions.Facing.EAST: -90.0,
		GridDefinitions.Facing.SOUTH: -180.0,
		GridDefinitions.Facing.WEST: -270.0,
	}

	for facing in expected_yaw.keys():
		player.grid_state = GridState.new(Vector2i.ZERO, facing)
		player._apply_canonical_transform()
		assert_eq(player.rotation_degrees.y, expected_yaw[facing], "Facing %s should produce cardinal yaw" % [facing])
