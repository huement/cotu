extends GutTest
## Pure formation slot assignment (Scripts/3D/CombatFormation.gd).

const Formation := preload("res://Scripts/3D/CombatFormation.gd")


func test_solo_uses_slot_one() -> void:
	var group: Array[Resource] = [_enemy("A")]
	assert_eq(Formation.get_best_slots(group), PackedInt32Array([1]))


func test_two_regulars_flank() -> void:
	var group: Array[Resource] = [_enemy("A"), _enemy("B")]
	assert_eq(Formation.get_best_slots(group), PackedInt32Array([2, 3]))


func test_two_with_boss() -> void:
	var boss: Resource = _enemy("Boss")
	Formation.mark_boss(boss)
	var group: Array[Resource] = [boss, _enemy("Minion")]
	assert_eq(Formation.get_best_slots(group), PackedInt32Array([1, 2]))


func test_three_regulars_left_center_right() -> void:
	var group: Array[Resource] = [_enemy("L"), _enemy("C"), _enemy("R")]
	assert_eq(Formation.get_best_slots(group), PackedInt32Array([2, 1, 3]))


func test_three_with_boss_centered() -> void:
	var boss: Resource = _enemy("Boss")
	Formation.mark_boss(boss)
	var group: Array[Resource] = [_enemy("L"), boss, _enemy("R")]
	assert_eq(Formation.get_best_slots(group), PackedInt32Array([2, 1, 3]))


func test_five_slots() -> void:
	var group: Array[Resource] = [_enemy("A"), _enemy("B"), _enemy("C"), _enemy("D"), _enemy("E")]
	assert_eq(Formation.get_best_slots(group), PackedInt32Array([2, 1, 3, 4, 5]))


func test_slot_offset_front_and_back() -> void:
	var c: Vector2 = Formation.slot_offset(1, 1.8, 0.75)
	var l: Vector2 = Formation.slot_offset(2, 1.8, 0.75)
	var r: Vector2 = Formation.slot_offset(3, 1.8, 0.75)
	var bl: Vector2 = Formation.slot_offset(4, 1.8, 0.75)
	assert_eq(c, Vector2(0.0, 0.0))
	assert_eq(l, Vector2(-1.8, 0.0))
	assert_eq(r, Vector2(1.8, 0.0))
	assert_eq(bl, Vector2(-0.9, -0.75))


func _enemy(enemy_name: String) -> EnemyData:
	var d := EnemyData.new()
	d.enemy_name = enemy_name
	return d
