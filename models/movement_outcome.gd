class_name MovementOutcome
extends RefCounted

const TYPE_MOVED := "moved"
const TYPE_BLOCKED := "blocked"
const TYPE_TURNED := "turned"

const PHASE_DECISION := "decision"
const PHASE_START := "start"
const PHASE_COMPLETE := "complete"

var command: GridCommand.Type
var outcome_type: String
var phase: String
var state_before: GridState
var state_after: GridState
var duration: float


func _init(
	new_command: GridCommand.Type,
	new_outcome_type: String,
	new_phase: String,
	new_state_before: GridState,
	new_state_after: GridState,
	new_duration: float
) -> void:
	command = new_command
	outcome_type = new_outcome_type
	phase = new_phase
	state_before = GridState.new(new_state_before.cell, new_state_before.facing)
	state_after = GridState.new(new_state_after.cell, new_state_after.facing)
	duration = maxf(new_duration, 0.0)
