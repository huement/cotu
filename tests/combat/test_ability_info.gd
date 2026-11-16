# res://tests/combat/test_ability_info.gd
extends GutTest


func test_category() -> void:
	var s := CombatFixtures.spell()
	assert_eq(AbilityInfo.category(s), "DAMAGE")
	s.effect_type = SpellData.EffectType.BUFF
	assert_eq(AbilityInfo.category(s), "BUFF")
	var k := CombatFixtures.skill()
	k.effect_type = SkillData.EffectType.HEAL
	assert_eq(AbilityInfo.category(k), "HEAL")


func test_name_and_id() -> void:
	assert_eq(AbilityInfo.display_name(CombatFixtures.spell()), "Test Bolt")
	assert_eq(AbilityInfo.id(CombatFixtures.skill()), "skl_test")
	var s := CombatFixtures.spell()
	s.spell_id = ""
	assert_eq(AbilityInfo.id(s), "test_bolt")


func test_status_id() -> void:
	var s := CombatFixtures.spell()
	assert_eq(AbilityInfo.status_id(s), "")
	s.status_effect = " eff_hp_burn_1 "
	assert_eq(AbilityInfo.status_id(s), "eff_hp_burn_1")


func test_hit_verb() -> void:
	assert_eq(AbilityInfo.hit_verb("RANGED"), "SHOT")
	assert_eq(AbilityInfo.hit_verb("DOT"), "hit")
