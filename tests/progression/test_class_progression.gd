# res://tests/progression/test_class_progression.gd
extends GutTest

const SHEET: String = """Class ID,Name,Aliases,Difficulty,Base XP,XP Growth,Max Level,HP Per VIT,HP Per Level,MP Per Level,Stat Points Per Level,Skill Points Per Level,Spell Points Per Level,Spells Unlock At Level,Auto Stat Gains,Milestone Every,Milestone Stat Points
1,Spartan,Fighter,1,240,1.40,50,3,4,0,4,6,0,0,"STR+1,VIT+1",5,2
8,Psynic,Psionic,3,330,1.5,20,2,2,2,4,1,5,3,"INT+1,VIT+1",5,3
"""


func test_parse_and_aliases() -> void:
	var t: Dictionary = ClassProgression.parse_csv_text(SHEET)
	assert_eq(t["spartan"]["base_xp"], 240)
	assert_eq(t["psionic"]["name"], "Psynic")
	assert_eq(t["psionic"]["max_level"], 20)
	assert_eq(t["spartan"]["auto_stat_gains"], { "strength": 1, "vitality": 1 })


func test_xp_curve_grows_and_harder_costs_more() -> void:
	var t: Dictionary = ClassProgression.parse_csv_text(SHEET)
	assert_eq(ClassProgression.xp_to_next_level(t["spartan"], 1), 240)
	assert_gt(ClassProgression.xp_to_next_level(t["spartan"], 5), ClassProgression.xp_to_next_level(t["spartan"], 4))
	assert_gt(ClassProgression.xp_to_next_level(t["psynic"], 5), ClassProgression.xp_to_next_level(t["spartan"], 5))


func test_points_milestone_and_spell_unlock() -> void:
	var t: Dictionary = ClassProgression.parse_csv_text(SHEET)
	assert_eq(ClassProgression.points_for_level(t["spartan"], 2), Vector3i(4, 6, 0))
	assert_eq(ClassProgression.points_for_level(t["spartan"], 5), Vector3i(6, 6, 0))
	assert_eq(ClassProgression.points_for_level(t["psynic"], 2), Vector3i(4, 1, 0)) # spellbook at 3
	assert_eq(ClassProgression.points_for_level(t["psynic"], 3), Vector3i(4, 1, 5))


func test_hp_mp() -> void:
	var t: Dictionary = ClassProgression.parse_csv_text(SHEET)
	assert_eq(ClassProgression.max_hp(t["spartan"], 20, 1), 60)
	assert_eq(ClassProgression.max_hp(t["spartan"], 20, 3), 68)
	assert_eq(ClassProgression.max_mp(t["psynic"], 10, 5, 2), 17)


func test_parse_stat_gains() -> void:
	assert_eq(ClassProgression.parse_stat_gains("str+1, dex+2,BAD+1, SPD-1"), { "strength": 1, "dexterity": 2, "speed": -1 })


func test_real_sheet_has_every_class_in_difficulty_order() -> void:
	ClassProgression.reload()
	var names: Array[String] = []
	var last_diff: int = 0
	for row: Dictionary in ClassProgression.all_classes():
		names.append(str(row["name"]))
		assert_true(int(row["difficulty"]) >= last_diff, "%s out of difficulty order" % row["name"])
		last_diff = int(row["difficulty"])
	for n: String in ["Spartan", "Shade", "Soulwright", "Archanist", "Warden", "Echo", "Maester", "Psynic", "Amazon", "Wizard", "Crusader", "Ronin", "Voidhand", "Ghostblade"]:
		assert_has(names, n)
	assert_eq(ClassProgression.for_class("Psionic")["name"], "Psynic")
	assert_eq(ClassProgression.for_class("Nope")["base_xp"], 300)


func test_cat_levels_by_class() -> void:
	ClassProgression.reload()
	var spartan := ProfessionData.new()
	spartan.profession_name = "Spartan"
	var cat := CatCharacter.new()
	cat.profession = spartan
	cat.max_xp = cat.get_required_xp_for_level(1)
	assert_eq(cat.max_xp, 240)
	var str_before: int = cat.strength
	cat.add_xp(240)
	assert_eq(cat.level, 2)
	assert_eq(cat.strength, str_before + 1)
	assert_eq(cat.unspent_stat_points, 4)
	assert_eq(cat.unspent_skill_points, 6)
	assert_eq(cat.unspent_spell_points, 0)
	assert_eq(cat.max_hp, cat.vitality * 3 + 4)
