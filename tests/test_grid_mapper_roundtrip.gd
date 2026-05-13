extends GutTest

func test_grid_mapper_round_trip_for_121_cells() -> void:
    var cell_size := 1.0
    for x in range(-5, 6):
        for z in range(-5, 6):
            var c := Vector2i(x, z)
            var p := GridMapper.cell_to_world(c, cell_size)
            var back := GridMapper.world_to_cell(p, cell_size)
            assert_eq(back, c, "Round-trip mismatch for cell %s" % [c])