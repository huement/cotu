extends Node
class_name WorldEventBus

signal overlay_restart_requested
signal overlay_return_to_title_requested
signal run_outcome_success_reached
signal run_outcome_failure_reached
signal encounter_detected(encountered: Array)
signal enemy_acted
signal player_action_completed(new_state: GridState)


func emit_overlay_restart_requested() -> void:
	overlay_restart_requested.emit()


func emit_overlay_return_to_title_requested() -> void:
	overlay_return_to_title_requested.emit()


func emit_run_outcome_success_reached() -> void:
	run_outcome_success_reached.emit()


func emit_run_outcome_failure_reached() -> void:
	run_outcome_failure_reached.emit()


func emit_encounter_detected(encountered: Array) -> void:
	encounter_detected.emit(encountered)


func emit_enemy_acted() -> void:
	enemy_acted.emit()


func emit_player_action_completed(_cmd: GridCommand.Type, new_state: GridState) -> void:
	player_action_completed.emit(new_state)
