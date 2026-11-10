extends GutTest
## Smoke checks for outdoor battle clearance helpers (no full map required).


func test_battle_space_clearance_constants_are_sane() -> void:
	assert_gt(BattleSpaceClearance.FORWARD_METERS, 2.0, "Need depth ahead of the party")
	assert_gt(BattleSpaceClearance.SIDE_METERS, 1.0, "Need lateral room for formation")
	assert_gt(BattleSpaceClearance.SHOVE_METERS, BattleSpaceClearance.SIDE_METERS, "Shove must leave the clear box")


func test_minotaur_combat_scale_is_readable() -> void:
	var data: EnemyData = load("res://Data/Enemies/Minotaur_Base.tres") as EnemyData
	assert_not_null(data)
	assert_gt(data.model_scale.x, 0.2, "Combat minotaur was previously tiny (0.08)")
	assert_lt(data.model_scale.x, 0.5, "Combat minotaur should stay below tree-scale")
	assert_not_null(data.model_scene)
	assert_true(str(data.model_scene.resource_path).ends_with("MinotaurModel.tscn"))
