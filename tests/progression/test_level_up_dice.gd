# res://tests/progression/test_level_up_dice.gd
extends GutTest


func test_low_rolls_give_that_many_stat_points() -> void:
	for r: int in [1, 2, 3]:
		assert_eq(LevelUpDice.bonus_for_roll(r), { "stat": r, "ability": 0, "hp_percent": 0.0 })


func test_four_and_five() -> void:
	assert_eq(LevelUpDice.bonus_for_roll(4), { "stat": 3, "ability": 1, "hp_percent": 0.0 })
	assert_eq(LevelUpDice.bonus_for_roll(5), { "stat": 3, "ability": 2, "hp_percent": 0.0 })


func test_six_adds_hp_boost() -> void:
	assert_eq(LevelUpDice.bonus_for_roll(6), { "stat": 3, "ability": 2, "hp_percent": 3.0 })


func test_out_of_range_is_clamped() -> void:
	assert_eq(int(LevelUpDice.bonus_for_roll(0)["stat"]), 1)
	assert_eq(float(LevelUpDice.bonus_for_roll(9)["hp_percent"]), 3.0)


func test_split_ability_points() -> void:
	assert_eq(LevelUpDice.split_ability_points(2, 3, 0), Vector2i(2, 0))
	assert_eq(LevelUpDice.split_ability_points(2, 0, 4), Vector2i(0, 2))
	assert_eq(LevelUpDice.split_ability_points(2, 2, 2), Vector2i(1, 1))
	assert_eq(LevelUpDice.split_ability_points(1, 2, 2), Vector2i(1, 0))
	assert_eq(LevelUpDice.split_ability_points(1, 1, 3), Vector2i(0, 1))
	assert_eq(LevelUpDice.split_ability_points(2, 0, 0), Vector2i(2, 0))
	assert_eq(LevelUpDice.split_ability_points(0, 2, 2), Vector2i.ZERO)


func test_describe() -> void:
	assert_eq(LevelUpDice.describe(LevelUpDice.bonus_for_roll(6)), "+3 STAT  •  +2 SKILL/SPELL  •  +3% MAX HP")
	assert_eq(LevelUpDice.describe(LevelUpDice.bonus_for_roll(2)), "+2 STAT")


func test_cat_apply_level_roll() -> void:
	var cat := CatCharacter.new()
	cat.vitality = 50 # 100 max HP for non-warriors
	cat._calculate_vitals()
	cat.current_hp = 100
	cat.pending_level_rolls = 2
	# Cap is half of known spells (4 → max 2), so a roll-6 ability bank still lands in full.
	cat.known_spells = [SpellData.new(), SpellData.new(), SpellData.new(), SpellData.new()]
	var bonus: Dictionary = cat.apply_level_roll(6)
	assert_eq(cat.unspent_stat_points, 3)
	assert_eq(cat.unspent_spell_points, 2)
	assert_eq(cat.unspent_skill_points, 0)
	assert_eq(int(bonus["spell"]), 2)
	assert_eq(cat.max_hp, 103)
	assert_eq(cat.current_hp, 103)
	assert_eq(cat.pending_level_rolls, 1)
	cat.apply_level_roll(2)
	assert_eq(cat.unspent_stat_points, 5)
	assert_eq(cat.max_hp, 103)
	assert_eq(cat.pending_level_rolls, 0)


func test_level_up_grants_points_and_a_roll() -> void:
	var cat := CatCharacter.new()
	cat.add_xp(cat.get_required_xp_for_level(1)) # XP target comes from Data/Class_Progression.csv
	assert_eq(cat.level, 2)
	assert_eq(cat.pending_level_rolls, 1)
	assert_true(cat.unspent_stat_points > 0)
