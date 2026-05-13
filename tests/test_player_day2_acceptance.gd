extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

func test_transform_matches_grid_state_projection() -> void:
    var player := PLAYER_SCENE.instantiate()
    add_child_autofree(player)

    player.grid_state.cell = Vector2i(3, -2)
    player.grid_state.facing = GridDefinitions.Facing.WEST
    player._apply_canonical_transform()

    var expected_pos := GridMapper.cell_to_world(player.grid_state.cell, player.movement_config.cell_size, 0.0)
    assert_eq(player.global_position, expected_pos, "Player transform does not match GridState projection")

func test_yaw_is_cardinal_for_all_facings() -> void:
    var player := PLAYER_SCENE.instantiate()
    add_child_autofree(player)

    var expected_yaw_by_facing: Dictionary = {
        GridDefinitions.Facing.NORTH: 0.0,
        GridDefinitions.Facing.EAST: -90.0,
        GridDefinitions.Facing.SOUTH: -180.0,
        GridDefinitions.Facing.WEST: -270.0,
    }

    for facing in expected_yaw_by_facing.keys():
        player.grid_state.facing = facing
        player._apply_canonical_transform()
        assert_eq(
            player.rotation_degrees.y,
            expected_yaw_by_facing[facing],
            "Unexpected yaw for facing %s" % [facing]
        )
