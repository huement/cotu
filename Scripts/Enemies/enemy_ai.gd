class_name EnemyAI
extends Node

## Sentinel value for invalid commands
const NO_COMMAND: GridCommand.Type = GridCommand.Type.NONE


## Determines grid movement toward the target during dungeon exploration
func choose_command(enemy: Node3D, player_party: Node3D) -> GridCommand.Type:
	if not _validate_entities(enemy, player_party):
		return NO_COMMAND

	var enemy_cell: Vector2i = enemy.grid_state.cell
	var player_cell: Vector2i = player_party.grid_state.cell
	var delta: Vector2i = player_cell - enemy_cell

	if delta == Vector2i.ZERO:
		return NO_COMMAND

	# Primary step direction along dominant axis
	var step: Vector2i = Vector2i.ZERO
	if absi(delta.x) >= absi(delta.y):
		step = Vector2i(signi(delta.x), 0)
	else:
		step = Vector2i(0, signi(delta.y))

	# Translate step vector into relative command
	var preferred_command: GridCommand.Type = _step_vector_to_command(enemy.grid_state.facing, step)

	# Validate if step direction is blocked by wall geometry
	if enemy.has_method("is_path_blocked") and enemy.is_path_blocked(preferred_command):
		# Fallback to secondary axis if primary path is blocked
		var fallback_step: Vector2i = Vector2i(0, signi(delta.y)) if step.y == 0 else Vector2i(signi(delta.x), 0)
		return _step_vector_to_command(enemy.grid_state.facing, fallback_step)

	return preferred_command


## Chooses action during Phased Combat based on distance & Wizardry row rules
func choose_combat_intent(enemy_data: EnemyData, distance_in_tiles: int) -> Dictionary:
	# Returns an action intent payload for the CombatManager
	var intent: Dictionary = {
		"action_type": GridCommand.Type.ATTACK,
		"target_row": "FRONT", # Default to Front Row (Slots 1-3)
		"skill_to_use": null
	}

	if enemy_data == null:
		return intent

	# Wizardry Row Logic: Ranged/Spells target Back Row if Front Row is occupied
	if distance_in_tiles > 1:
		if enemy_data.has_spells:
			intent["action_type"] = GridCommand.Type.CAST_SPELL
			intent["target_row"] = "BACK" # Targets Slots 4-6
		else:
			intent["action_type"] = GridCommand.Type.WAIT # Move closer next phase
	else:
		intent["action_type"] = GridCommand.Type.ATTACK
		intent["target_row"] = "FRONT"

	return intent


func _step_vector_to_command(facing: GridDefinitions.Facing, step: Vector2i) -> GridCommand.Type:
	if step == Vector2i.ZERO:
		return NO_COMMAND

	var forward: Vector2i = GridDefinitions.facing_to_vec2i(facing)
	var right: Vector2i = GridDefinitions.facing_to_vec2i(GridDefinitions.rotate_right(facing))

	if step == forward:
		return GridCommand.Type.STEP_FORWARD
	if step == -forward:
		return GridCommand.Type.STEP_BACK
	if step == -right:
		return GridCommand.Type.MOVE_LEFT
	if step == right:
		return GridCommand.Type.MOVE_RIGHT

	return NO_COMMAND


func _validate_entities(enemy: Node3D, player: Node3D) -> bool:
	if enemy == null or player == null:
		return false
	if not ("grid_state" in enemy) or not ("grid_state" in player):
		return false
	return enemy.grid_state != null and player.grid_state != null
