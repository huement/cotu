# res://tests/progression/test_class_build_guide.gd
extends GutTest


func test_one_point_always_goes_to_speed() -> void:
	assert_eq(ClassBuildGuide.plan_stat_points(CatCharacter.new(), 1), { "speed": 1 })


func test_spends_every_point_with_speed_first() -> void:
	var deltas: Dictionary = ClassBuildGuide.plan_stat_points(CatCharacter.new(), 6)
	var total: int = 0
	for key: Variant in deltas.keys():
		total += int(deltas[key])
	assert_eq(total, 6)
	assert_true(int(deltas.get("speed", 0)) >= 1)


func test_alias_resolves_to_class_build() -> void:
	assert_eq(ClassBuildGuide.build_for_class("Fighter"), ClassBuildGuide.BUILDS["Spartan"])
	assert_eq(ClassBuildGuide.build_for_class("Nobody"), ClassBuildGuide.DEFAULT_BUILD)


func test_lowest_rank_skill_first() -> void:
	var cat: CatCharacter = CatCharacter.new()
	var a: SkillData = SkillData.new()
	a.skill_id = "slash"
	var b: SkillData = SkillData.new()
	b.skill_id = "parry"
	cat.ability_ranks = { "slash": 3 }
	var picks: Array[String] = ClassBuildGuide.plan_ability_ranks(cat, 3, [a, b], true)
	assert_eq(picks, ["parry", "parry", "slash"] as Array[String])


func test_pick_lowest_ranks_is_distinct() -> void:
	var cat: CatCharacter = CatCharacter.new()
	var a: SkillData = SkillData.new()
	a.skill_id = "slash"
	var b: SkillData = SkillData.new()
	b.skill_id = "parry"
	cat.ability_ranks = { "slash": 3 }
	assert_eq(ClassBuildGuide.pick_lowest_ranks(cat, 1, [a, b], true), ["parry"] as Array[String])
	assert_eq(ClassBuildGuide.pick_lowest_ranks(cat, 5, [a, b], true), ["parry", "slash"] as Array[String])
