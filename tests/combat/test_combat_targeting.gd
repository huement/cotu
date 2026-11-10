# res://tests/combat/test_combat_targeting.gd
extends GutTest


var _list: Array[Combatant] = []
var _p0: Combatant
var _p4: Combatant
var _e0: Combatant
var _e1: Combatant


func before_each() -> void:
	_p0 = CombatFixtures.party(0)
	_p4 = CombatFixtures.party(4)
	_e0 = CombatFixtures.enemy(0)
	_e1 = CombatFixtures.enemy(1)
	_list = [_p0, _p4, _e0, _e1]


func test_party_single_enemy_uses_target_index() -> void:
	assert_eq(CombatTargeting.resolve_ability_targets(_list, _p0, CombatFixtures.spell(10, SpellData.TargetType.SINGLE_ENEMY), 1, false), [_e1] as Array[Combatant])


func test_party_dead_target_falls_back_to_first_living_enemy() -> void:
	_e1.current_hp = 0
	assert_eq(CombatTargeting.pick_opponent(_list, _p0, 1), _e0)


func test_pick_opponent_null_when_side_wiped() -> void:
	_e0.current_hp = 0
	_e1.current_hp = 0
	assert_null(CombatTargeting.pick_opponent(_list, _p0, 0))


func test_enemy_attacks_a_living_party_member() -> void:
	_p0.current_hp = 0
	for i: int in 10:
		assert_eq(CombatTargeting.pick_opponent(_list, _e0, 0), _p4)


func test_all_enemy_and_all_ally() -> void:
	_e1.current_hp = 0
	assert_eq(CombatTargeting.resolve_ability_targets(_list, _p0, CombatFixtures.spell(10, SpellData.TargetType.ALL_ENEMY), 0, false), [_e0] as Array[Combatant])
	assert_eq(CombatTargeting.resolve_ability_targets(_list, _p0, CombatFixtures.spell(10, SpellData.TargetType.ALL_ALLY), 0, false), [_p0, _p4] as Array[Combatant])


func test_all_ally_includes_dead_only_for_revives() -> void:
	_p4.current_hp = 0
	assert_eq(CombatTargeting.resolve_ability_targets(_list, _p0, CombatFixtures.spell(10, SpellData.TargetType.ALL_ALLY), 0, false).size(), 1)
	assert_eq(CombatTargeting.resolve_ability_targets(_list, _p0, CombatFixtures.spell(10, SpellData.TargetType.ALL_ALLY), 0, true).size(), 2)


func test_self() -> void:
	assert_eq(CombatTargeting.resolve_ability_targets(_list, _p4, CombatFixtures.spell(10, SpellData.TargetType.SELF), 0, false), [_p4] as Array[Combatant])


func test_party_single_ally_by_slot_falls_back_to_caster() -> void:
	assert_eq(CombatTargeting.resolve_ability_targets(_list, _p0, CombatFixtures.spell(10, SpellData.TargetType.SINGLE_ALLY), 4, false), [_p4] as Array[Combatant])
	assert_eq(CombatTargeting.resolve_ability_targets(_list, _p0, CombatFixtures.spell(10, SpellData.TargetType.SINGLE_ALLY), 2, false), [_p0] as Array[Combatant])


func test_enemy_single_ally_heals_lowest_hp() -> void:
	_e1.current_hp = 5
	assert_eq(CombatTargeting.resolve_ability_targets(_list, _e0, CombatFixtures.spell(10, SpellData.TargetType.SINGLE_ALLY), 0, false), [_e1] as Array[Combatant])


func test_finders() -> void:
	assert_eq(CombatTargeting.find_by_id(_list, "enemy_1"), _e1)
	assert_eq(CombatTargeting.find_by_slot(_list, 4, true), _p4)
	assert_null(CombatTargeting.find_by_slot(_list, 4, false))
