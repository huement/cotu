extends Node
class_name CombatRoundManager

signal intent_phase_opened(combatants: Array)
signal intent_submitted(combatant: Node, cmd: GridCommand.Type)
signal round_resolved(intents: Dictionary)

var _combatants: Array = []
var _intents: Dictionary = {}
var _intent_phase_open := false


func start_round(round_combatants: Array) -> void:
	_combatants = []
	_intents.clear()

	for combatant in round_combatants:
		if combatant == null:
			continue
		if _combatants.has(combatant):
			continue
		_combatants.append(combatant)

	_intent_phase_open = not _combatants.is_empty()
	if not _intent_phase_open:
		round_resolved.emit({})
		return

	intent_phase_opened.emit(_combatants.duplicate())


func submit_intent(combatant: Node, cmd: GridCommand.Type) -> bool:
	if not _intent_phase_open:
		return false
	if not _combatants.has(combatant):
		return false
	if _intents.has(combatant):
		return false

	_intents[combatant] = cmd
	intent_submitted.emit(combatant, cmd)

	if _intents.size() >= _combatants.size():
		_resolve_round()

	return true


func is_waiting_for_intents() -> bool:
	return _intent_phase_open


func get_combatants() -> Array:
	return _combatants.duplicate()


func submitted_count() -> int:
	return _intents.size()


func intent_for(combatant: Node) -> Variant:
	return _intents.get(combatant, null)


func _resolve_round() -> void:
	_intent_phase_open = false
	round_resolved.emit(_intents.duplicate())
