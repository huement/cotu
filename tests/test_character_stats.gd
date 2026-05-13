extends GutTest


func test_init_fills_hp_to_max() -> void:
	var s := CharacterStats.new(10, 2, 0)
	assert_eq(s.health, 10)
	assert_eq(s.max_health, 10)


func test_take_damage_reduces_hp() -> void:
	var s := CharacterStats.new(10, 2, 0)
	s.take_damage(3)
	assert_eq(s.health, 7)


func test_take_damage_minimum_one_after_defence() -> void:
	var s := CharacterStats.new(10, 2, 5)
	# damage=3, defence=5 → dealt=max(3-5,1)=1
	s.take_damage(3)
	assert_eq(s.health, 9)


func test_take_damage_clamps_to_zero() -> void:
	var s := CharacterStats.new(10, 2, 0)
	s.take_damage(999)
	assert_eq(s.health, 0)


func test_take_damage_emits_damaged_signal() -> void:
	var s := CharacterStats.new(10, 2, 0)
	watch_signals(s)
	s.take_damage(4)
	assert_signal_emitted_with_parameters(s, "damaged", [4, 10, 6])


func test_heal_increases_hp() -> void:
	var s := CharacterStats.new(10, 2, 0)
	s.take_damage(5)
	s.heal(3)
	assert_eq(s.health, 8)


func test_heal_clamps_to_max_health() -> void:
	var s := CharacterStats.new(10, 2, 0)
	s.take_damage(2)
	s.heal(999)
	assert_eq(s.health, 10)


func test_heal_emits_healed_signal() -> void:
	var s := CharacterStats.new(10, 2, 0)
	s.take_damage(5)
	watch_signals(s)
	s.heal(3)
	assert_signal_emitted_with_parameters(s, "healed", [3, 5, 8])


func test_heal_does_not_emit_when_already_full() -> void:
	var s := CharacterStats.new(10, 2, 0)
	watch_signals(s)
	s.heal(5)
	assert_signal_not_emitted(s, "healed")


func test_is_dead_false_when_alive() -> void:
	var s := CharacterStats.new(10, 2, 0)
	assert_false(s.is_dead())


func test_is_dead_true_when_hp_zero() -> void:
	var s := CharacterStats.new(10, 2, 0)
	s.take_damage(999)
	assert_true(s.is_dead())


func test_fill_restores_full_hp() -> void:
	var s := CharacterStats.new(10, 2, 0)
	s.take_damage(5)
	s.fill()
	assert_eq(s.health, 10)


func test_fill_does_not_emit_when_already_full() -> void:
	var s := CharacterStats.new(10, 2, 0)
	watch_signals(s)
	s.fill()
	assert_signal_not_emitted(s, "healed")
