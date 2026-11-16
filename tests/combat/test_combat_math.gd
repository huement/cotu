# res://tests/combat/test_combat_math.gd
extends GutTest


# --- enemy level growth -------------------------------------------------------
func test_enemy_level_factor() -> void:
	assert_almost_eq(CombatMath.enemy_level_factor(1, 0.2), 1.0, 0.0001)
	assert_almost_eq(CombatMath.enemy_level_factor(0, 0.2), 1.0, 0.0001) # clamped to level 1
	assert_almost_eq(CombatMath.enemy_level_factor(5, 0.2), 1.8, 0.0001)
	assert_almost_eq(CombatMath.enemy_level_factor(11, 0.15), 2.5, 0.0001)


func test_apply_enemy_level_scales_level_one_sheet() -> void:
	var d := EnemyData.new()
	d.base_level = 6
	d.max_health = 100
	d.current_health = 100
	d.attack_damage = 20
	d.defense = 10
	d.speed = 10.0
	d.xp_value = 100
	d.gold_value = 50
	CombatMath.apply_enemy_level(d)
	assert_eq(d.max_health, 200)      # +20% x 5
	assert_eq(d.current_health, 200)
	assert_eq(d.attack_damage, 35)    # +15% x 5
	assert_eq(d.defense, 15)          # +10% x 5
	assert_almost_eq(d.speed, 12.0, 0.001) # +4% x 5
	assert_eq(d.xp_value, 250)        # +30% x 5
	assert_eq(d.gold_value, 125)
	assert_true(d.level_scaling_applied)


func test_apply_enemy_level_only_once() -> void:
	var d := EnemyData.new()
	d.base_level = 3
	d.max_health = 100
	d.current_health = 100
	CombatMath.apply_enemy_level(d)
	CombatMath.apply_enemy_level(d)
	assert_eq(d.max_health, 140)


func test_apply_enemy_level_one_is_unchanged() -> void:
	var d := EnemyData.new()
	d.base_level = 1
	d.max_health = 55
	d.current_health = 55
	d.attack_damage = 12
	CombatMath.apply_enemy_level(d)
	assert_eq(d.max_health, 55)
	assert_eq(d.attack_damage, 12)


func test_apply_enemy_level_keeps_damage_fraction() -> void:
	var d := EnemyData.new()
	d.base_level = 6
	d.max_health = 100
	d.current_health = 50
	CombatMath.apply_enemy_level(d)
	assert_eq(d.current_health, 100) # half of 200


# --- physical_damage ----------------------------------------------------------
func test_physical_basic_atk_minus_def() -> void:
	var a := CombatFixtures.party(0, 20)
	var d := CombatFixtures.enemy(0, 0, 5)
	assert_eq(CombatMath.physical_damage(a, d, "BLADE", false, 1.5), 15)


func test_physical_minimum_is_one() -> void:
	assert_eq(CombatMath.physical_damage(CombatFixtures.party(0, 3), CombatFixtures.enemy(0, 0, 50), "BLADE", false, 1.5), 1)


func test_physical_null_is_one() -> void:
	assert_eq(CombatMath.physical_damage(null, CombatFixtures.enemy(0), "BLADE", false, 1.5), 1)


func test_physical_pierce_ignores_defense_fraction() -> void:
	var a := CombatFixtures.party(0, 20)
	a.pierce = 0.5
	assert_eq(CombatMath.physical_damage(a, CombatFixtures.enemy(0, 0, 10), "BLADE", false, 1.5), 15) # 20 - 10*0.5


func test_physical_unarmed_drops_weapon_attack_and_pierce() -> void:
	var a := CombatFixtures.party(0, 20)
	a.weapon_attack = 8
	a.pierce = 0.5
	assert_eq(CombatMath.physical_damage(a, CombatFixtures.enemy(0, 0, 4), "UNARMED", false, 1.5), 8) # (20-8) - 4


func test_physical_back_row_melee_attacker_halved_ranged_not() -> void:
	var a := CombatFixtures.party(3, 24) # back row
	var d := CombatFixtures.enemy(0, 0, 4)
	assert_eq(CombatMath.physical_damage(a, d, "BLADE", false, 1.5), 10)
	assert_eq(CombatMath.physical_damage(a, d, "RANGED", false, 1.5), 20)


func test_physical_back_row_defender_and_guard_stack() -> void:
	var d := CombatFixtures.party(4, 0, 0) # back row party member
	assert_eq(CombatMath.physical_damage(CombatFixtures.enemy(0, 40), d, "BASH", false, 1.5), 20)
	assert_eq(CombatMath.physical_damage(CombatFixtures.enemy(0, 40), d, "BASH", true, 1.5), 10)


func test_physical_weakness_and_resist() -> void:
	var d := CombatFixtures.enemy(0, 0, 0, 40, ItemData.EffectElement.BLADE)
	assert_eq(CombatMath.physical_damage(CombatFixtures.party(0, 20), d, "BLADE", false, 1.5), 30)
	assert_eq(CombatMath.physical_damage(CombatFixtures.party(0, 20), d, "BASH", false, 1.5), 20)
	d.element_resists[ItemData.EffectElement.BLADE] = 0.5
	assert_eq(CombatMath.physical_damage(CombatFixtures.party(0, 20), d, "BLADE", false, 1.5), 15)


func test_physical_resist_capped_at_90_percent() -> void:
	var d := CombatFixtures.enemy(0, 0, 0)
	d.element_resists[ItemData.EffectElement.BASH] = 5.0
	assert_eq(CombatMath.physical_damage(CombatFixtures.party(0, 100), d, "BASH", false, 1.5), 10)


func test_physical_uses_buffed_stats() -> void:
	var a := CombatFixtures.party(0, 20)
	a.add_effect(ActiveEffect.new("buff", "Rage", 3, &"STAT_PCT", &"strength", 50.0))
	var d := CombatFixtures.enemy(0, 0, 10)
	d.add_effect(ActiveEffect.new("debuff", "Sunder", 3, &"STAT_BUFF", &"defense", -10.0))
	assert_eq(CombatMath.physical_damage(a, d, "BLADE", false, 1.5), 30)


# --- ability_power / ability_damage -----------------------------------------
func test_power_enemy_spell_uses_magic_power_and_amplify() -> void:
	var caster := CombatFixtures.enemy(0)
	caster.magic_power = 10
	caster.spell_amplify = 1.5
	assert_almost_eq(CombatMath.ability_power(caster, CombatFixtures.spell(20), &"SPELL"), 37.5, 0.001) # (20 + 10*0.5) * 1.5


func test_power_skill_falls_back_to_effect_amount() -> void:
	assert_almost_eq(CombatMath.ability_power(CombatFixtures.party(0), CombatFixtures.skill(15), &"SKILL"), 15.0, 0.001)


func test_spell_damage_ignores_defense_and_rows_applies_magic_weakness_and_resist() -> void:
	var t := CombatFixtures.party(4, 0, 99) # back row, huge defense
	assert_eq(CombatMath.ability_damage(CombatFixtures.enemy(0), t, CombatFixtures.spell(), &"SPELL", 20.0, true, 1.5), 20)
	t.weakness = ItemData.EffectElement.MAGIC
	t.element_resists[ItemData.EffectElement.MAGIC] = 0.25
	assert_eq(CombatMath.ability_damage(CombatFixtures.enemy(0), t, CombatFixtures.spell(), &"SPELL", 20.0, false, 1.5), 23) # 20*1.5*0.75 = 22.5


func test_life_spell_hits_life_weakness() -> void:
	var t := CombatFixtures.enemy(0, 0, 0, 40, ItemData.EffectElement.LIFE)
	assert_true(CombatMath.spell_hits_weakness(t, CombatFixtures.spell(20, 0, ItemData.ElementalBase.LIFE)))
	assert_false(CombatMath.spell_hits_weakness(t, CombatFixtures.spell(20, 0, ItemData.ElementalBase.FIRE)))


func test_skill_damage_rows_guard_and_element_from_caster() -> void:
	var caster := CombatFixtures.party(0) # attack_type BLADE
	var t := CombatFixtures.enemy(0, 0, 50, 40, ItemData.EffectElement.BLADE)
	assert_eq(CombatMath.skill_element(caster, CombatFixtures.skill()), ItemData.EffectElement.BLADE)
	assert_eq(CombatMath.ability_damage(caster, t, CombatFixtures.skill(), &"SKILL", 10.0, false, 1.5), 15) # defense ignored
	var back := CombatFixtures.party(5)
	assert_eq(CombatMath.ability_damage(CombatFixtures.enemy(1), back, CombatFixtures.skill(0, ItemData.EffectElement.BASH), &"SKILL", 20.0, true, 1.5), 5)


func test_ability_duration_spell_tier() -> void:
	var s := CombatFixtures.spell()
	s.duration = 2
	s.tier = 3
	assert_eq(CombatMath.ability_duration(s, &"SPELL"), 6)
	var k := CombatFixtures.skill()
	k.duration = 0
	assert_eq(CombatMath.ability_duration(k, &"SKILL"), 1)


# --- meters / flee / misc ----------------------------------------------------
func test_next_meter_caps() -> void:
	assert_almost_eq(CombatMath.next_meter(0.0, 10.0, 25.0, 0.1, 100.0), 25.0, 0.001)
	assert_eq(CombatMath.next_meter(90.0, 10.0, 25.0, 1.0, 100.0), 100.0)


func test_flee_chance_clamped() -> void:
	assert_almost_eq(CombatMath.flee_chance(0.6, 12, 10), 0.7, 0.001)
	assert_eq(CombatMath.flee_chance(0.6, 100, 0), 0.95)
	assert_eq(CombatMath.flee_chance(0.6, 0, 100), 0.15)


func test_average_speed_living_only() -> void:
	var dead := CombatFixtures.enemy(2, 1, 1, 10, ItemData.EffectElement.NONE, 50.0)
	dead.current_hp = 0
	var list: Array[Combatant] = [CombatFixtures.enemy(0, 1, 1, 10, ItemData.EffectElement.NONE, 8.0), CombatFixtures.enemy(1, 1, 1, 10, ItemData.EffectElement.NONE, 12.0), dead, CombatFixtures.party(0)]
	assert_eq(CombatMath.average_speed(list, false), 10)
	assert_eq(CombatMath.average_speed([] as Array[Combatant], false), 0)


func test_as_fraction() -> void:
	assert_almost_eq(CombatMath.as_fraction(0.2), 0.2, 0.001)
	assert_almost_eq(CombatMath.as_fraction(50.0), 0.5, 0.001)
	assert_eq(CombatMath.as_fraction(500.0), 1.0)


func test_element_round_trip() -> void:
	for t: String in ["BLADE", "RANGED", "MAGIC", "BASH"]:
		assert_eq(CombatMath.attack_type_from_element(CombatMath.element_for_attack_type(t)), t)
	assert_eq(CombatMath.element_for_attack_type("UNARMED"), ItemData.EffectElement.BASH)


func test_modifier_stat_name() -> void:
	assert_eq(CombatMath.modifier_stat_name(StatusEffectData.ModifierStat.DEF), &"defense")
	assert_eq(CombatMath.modifier_stat_name(StatusEffectData.ModifierStat.HP), &"")


# --- throwing (ItemData.is_throwable) ---------------------------------------
func test_throw_hit_chance_scales_with_dex_and_clamps() -> void:
	assert_almost_eq(CombatMath.throw_hit_chance(10, 10.0), 0.80, 0.001)
	assert_almost_eq(CombatMath.throw_hit_chance(14, 10.0), 0.90, 0.001)
	assert_almost_eq(CombatMath.throw_hit_chance(30, 5.0), CombatMath.THROW_MAX_HIT, 0.001)
	assert_almost_eq(CombatMath.throw_hit_chance(3, 20.0), CombatMath.THROW_MIN_HIT, 0.001)


func test_throw_crit_chance_from_dex() -> void:
	assert_almost_eq(CombatMath.throw_crit_chance(12), 0.12, 0.001)
	assert_almost_eq(CombatMath.throw_crit_chance(99), CombatMath.THROW_MAX_CRIT, 0.001)


func test_throw_damage_formula() -> void:
	# STR-scaled: (4 x 2 + 14) x (1 + 14 x 0.05) = 22 x 1.7 = 37.4 ; - def 6 x 0.5 = 34.4 -> 34
	assert_eq(CombatMath.throw_damage(4, 14, CombatFixtures.enemy(0, 0, 6), 1.5), 34)
	# weakness (RANGED) x1.5
	var weak := CombatFixtures.enemy(0, 0, 6, 40, ItemData.EffectElement.RANGED)
	assert_eq(CombatMath.throw_damage(4, 14, weak, 1.5, ItemData.EffectElement.RANGED), 52)
	assert_eq(CombatMath.throw_damage(1, 1, CombatFixtures.enemy(0, 0, 500), 1.5), 1, "min 1")


func test_throw_beats_a_normal_attack() -> void:
	# A STR 14 thrower's Steel Shuriken (power 4) vs a STR 20 + weapon 8 melee swing, same armour.
	var foe := CombatFixtures.enemy(0, 0, 10)
	var melee: int = CombatMath.physical_damage(CombatFixtures.party(0, 28), foe, "BLADE", false, 1.5)
	assert_gt(CombatMath.throw_damage(4, 14, foe, 1.5), melee)


# --- opening initiative (ambush) ---------------------------------------------
func test_opening_meter_is_speed_times_five_until_the_cap() -> void:
	assert_eq(CombatMath.opening_meter(13.0, false, 100.0), 65.0)
	assert_eq(CombatMath.opening_meter(20.0, false, 100.0), 100.0)
	assert_eq(CombatMath.opening_meter(4.0, true, 100.0), 100.0)


func test_back_is_turned_only_when_the_enemy_is_behind() -> void:
	var north := Vector2i(0, -1)
	assert_true(CombatMath.back_is_turned(north, Vector2i(0, 1))) # south, behind
	assert_false(CombatMath.back_is_turned(north, Vector2i(0, -1))) # in front
	assert_false(CombatMath.back_is_turned(north, Vector2i(1, 0))) # flank
	assert_true(CombatMath.back_is_turned(north, Vector2i(1, 1))) # behind and aside
	assert_false(CombatMath.back_is_turned(north, Vector2i.ZERO))


func test_meeting_ambush_flags_only_surprisers_and_does_not_stick() -> void:
	var wraith := EnemyData.new()
	wraith.can_surprise_player = true
	var slime := EnemyData.new()
	slime.can_surprise_player = false
	var group: Array[Resource] = [wraith, slime]
	CombatMath.apply_meeting_ambush(group, true)
	assert_true(CombatMath.seizes_opening_initiative(group[0]))
	assert_false(CombatMath.seizes_opening_initiative(group[1]))
	assert_false(wraith.has_meta(CombatMath.AMBUSH_META))
	CombatMath.apply_meeting_ambush(group, false)
	assert_false(CombatMath.seizes_opening_initiative(group[0]))


func test_only_an_ambush_that_can_surprise_seizes_initiative() -> void:
	var ghost := EnemyData.new()
	ghost.can_surprise_player = true
	assert_false(CombatMath.seizes_opening_initiative(ghost))
	ghost.set_meta(CombatMath.AMBUSH_META, true)
	assert_true(CombatMath.seizes_opening_initiative(ghost))
	ghost.can_surprise_player = false
	assert_false(CombatMath.seizes_opening_initiative(ghost))
	assert_false(CombatMath.seizes_opening_initiative(null))


func test_item_throw_helpers() -> void:
	var star := ItemData.new()
	star.is_throwable = true
	star.is_consumable = true
	star.attack_bonus = 4
	assert_eq(star.get_battle_target_type(), ItemData.TargetType.SINGLE_ENEMY, "thrown at one enemy by default")
	assert_true(star.can_be_used(true))
	assert_false(star.can_be_used(false), "not usable outside battle")
	assert_eq(star.get_throw_power(), 4)
	star.target_type = ItemData.TargetType.ALL_ENEMIES
	assert_eq(star.get_battle_target_type(), ItemData.TargetType.ALL_ENEMIES, "exploding potions hit everyone")
	var shuriken: ItemData = load("res://Data/Items/Equipment/WeapGhostbladeRegularAmmo.tres")
	assert_true(shuriken.is_throwable)
	var kunai: ItemData = load("res://Data/Items/Equipment/WeapKunai.tres") as ItemData
	assert_true(kunai.is_throwable)
	assert_eq(kunai.get_throw_anim(), "knife_throw")
	var knife: ItemData = load("res://Data/Items/Equipment/WeapThrowingKnife.tres") as ItemData
	assert_true(knife.is_throwable)
	assert_eq(knife.get_throw_anim(), "knife_throw")
	assert_eq(shuriken.get_throw_anim(), "star_throw")
