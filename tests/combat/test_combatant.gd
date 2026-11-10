# res://tests/combat/test_combatant.gd
extends GutTest


func test_flat_then_percent() -> void:
	var c := CombatFixtures.party(0, 20)
	c.add_effect(ActiveEffect.new("a", "A", 2, &"STAT_BUFF", &"strength", 10.0))
	c.add_effect(ActiveEffect.new("b", "B", 2, &"STAT_PCT", &"strength", 50.0))
	assert_eq(c.get_effective_strength(), 45) # (20 + 10) * 1.5


func test_same_id_refreshes_instead_of_stacking() -> void:
	var c := CombatFixtures.party(0)
	c.add_effect(ActiveEffect.new("a", "A", 2, &"STAT_BUFF", &"defense", 3.0))
	c.add_effect(ActiveEffect.new("a", "A", 5, &"STAT_BUFF", &"defense", 4.0))
	assert_eq(c.active_effects.size(), 1)
	assert_eq(c.active_effects[0].duration, 5)
	assert_eq(c.get_effective_defense(), 9)


func test_shields_soak_and_expire() -> void:
	var c := CombatFixtures.party(0)
	c.add_effect(ActiveEffect.new("s", "Shield", 3, &"SHIELD", &"", 10.0))
	c.add_effect(ActiveEffect.new("m", "Ward", 3, &"MAGIC_SHIELD", &"", 10.0))
	assert_eq(c.absorb_with_shields(6, false), 0)
	assert_eq(c.absorb_with_shields(8, false), 4) # shield had 4 left, magic shield ignores physical
	assert_eq(c.active_effects.size(), 1)
	assert_eq(c.absorb_with_shields(15, true), 5)
	assert_true(c.active_effects.is_empty())
