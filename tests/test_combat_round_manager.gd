extends GutTest


func _spawn_manager() -> CombatRoundManager:
	var manager := CombatRoundManager.new()
	add_child_autofree(manager)
	return manager


func _spawn_combatant(combatant_name: String) -> Node:
	var combatant := Node.new()
	combatant.name = combatant_name
	add_child_autofree(combatant)
	return combatant


func test_start_round_opens_intent_phase_with_non_empty_roster() -> void:
	var manager := _spawn_manager()
	var a := _spawn_combatant("A")
	var b := _spawn_combatant("B")

	watch_signals(manager)
	manager.start_round([a, b])

	assert_true(manager.is_waiting_for_intents())
	assert_eq(manager.get_combatants().size(), 2)
	assert_signal_emitted(manager, "intent_phase_opened")


func test_start_round_with_empty_roster_resolves_immediately() -> void:
	var manager := _spawn_manager()
	watch_signals(manager)

	manager.start_round([])

	assert_false(manager.is_waiting_for_intents())
	assert_signal_emitted(manager, "round_resolved")


func test_submit_intent_rejects_non_combatants_and_duplicates() -> void:
	var manager := _spawn_manager()
	var a := _spawn_combatant("A")
	var outsider := _spawn_combatant("Outsider")

	manager.start_round([a])

	assert_false(manager.submit_intent(outsider, GridCommand.Type.ATTACK))
	assert_true(manager.submit_intent(a, GridCommand.Type.ATTACK))
	assert_false(manager.submit_intent(a, GridCommand.Type.DEFEND))


func test_round_resolves_once_all_combatants_submit() -> void:
	var manager := _spawn_manager()
	var a := _spawn_combatant("A")
	var b := _spawn_combatant("B")

	watch_signals(manager)
	manager.start_round([a, b])

	assert_true(manager.submit_intent(a, GridCommand.Type.ATTACK))
	assert_true(manager.is_waiting_for_intents())
	assert_eq(manager.submitted_count(), 1)

	assert_true(manager.submit_intent(b, GridCommand.Type.DEFEND))
	assert_false(manager.is_waiting_for_intents())
	assert_eq(manager.intent_for(a), GridCommand.Type.ATTACK)
	assert_eq(manager.intent_for(b), GridCommand.Type.DEFEND)
	assert_signal_emitted(manager, "round_resolved")
