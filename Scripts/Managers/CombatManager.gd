class_name CombatManager
extends Node

const MAX_TURN_METER: float = 100.0

@export var is_combat_active: bool = false
@export var is_paused_for_input: bool = false

## Dictionary tracking combatant stats: { "id": String, "speed": int, "meter": float, "is_player": bool }
var combatants: Array[Dictionary] = []

func _process(delta: float) -> void:
	if not is_combat_active or is_paused_for_input:
		return
		
	_tick_turn_meters(delta)

func _tick_turn_meters(delta: float) -> void:
	for c in combatants:
		# Meter fills proportionally to speed stat
		var fill_amount: float = c["speed"] * delta * 15.0
		c["meter"] = minf(c["meter"] + fill_amount, MAX_TURN_METER)
		
		# Emit signal for individual UI progress bar updates
		SignalBus.turn_meter_updated.emit(c["id"], c["meter"] / MAX_TURN_METER)
		
		# Check if turn meter is full
		if c["meter"] >= MAX_TURN_METER and not is_paused_for_input:
			_trigger_turn(c)
			break

func _trigger_turn(combatant: Dictionary) -> void:
	if combatant["is_player"]:
		is_paused_for_input = true
		SignalBus.combatant_turn_ready.emit(combatant["id"], true)
	else:
		# Enemy AI turn executes immediately
		_execute_enemy_ai(combatant)

func execute_player_action(combatant_id: String, action_type: GridCommand.Type) -> void:
	# Reset meter after action
	_reset_combatant_meter(combatant_id)
	
	# Request top bar chevrons to flash red (enemy hit) or cyan (hit confirm)
	SignalBus.chevron_flash_requested.emit(false) 
	
	is_paused_for_input = false

func _execute_enemy_ai(combatant: Dictionary) -> void:
	# Enemy attacks a party member
	SignalBus.chevron_flash_requested.emit(true) # Player hit!
	_reset_combatant_meter(combatant["id"])

func _reset_combatant_meter(combatant_id: String) -> void:
	for c in combatants:
		if c["id"] == combatant_id:
			c["meter"] = 0.0
			SignalBus.turn_meter_updated.emit(combatant_id, 0.0)
			break
