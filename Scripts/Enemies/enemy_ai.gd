# res://Scripts/Enemies/enemy_ai.gd
class_name EnemyAI
extends Node

## Sentinel value for invalid commands
const NO_COMMAND: GridCommand.Type = GridCommand.Type.NONE


## Calculates the dominant axis step vector towards the target cell
func get_step_vector(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var delta: Vector2i = to_cell - from_cell
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO

	if absi(delta.x) >= absi(delta.y):
		return Vector2i(signi(delta.x), 0)
	else:
		return Vector2i(0, signi(delta.y))


## Determines grid movement toward the target during dungeon exploration
func choose_command(enemy: Node3D, player_party: Node3D) -> GridCommand.Type:
	if not _validate_entities(enemy, player_party):
		return NO_COMMAND

	var enemy_cell: Vector2i = enemy.grid_state.cell
	var player_cell: Vector2i = player_party.grid_state.cell
	var step: Vector2i = get_step_vector(enemy_cell, player_cell)

	if step == Vector2i.ZERO:
		return NO_COMMAND

	# Translate step vector into relative command
	var preferred_command: GridCommand.Type = _step_vector_to_command(enemy.grid_state.facing, step)

	# Validate if step direction is blocked by wall geometry
	if enemy.has_method("is_path_blocked") and enemy.is_path_blocked(preferred_command):
		var delta: Vector2i = player_cell - enemy_cell
		var fallback_step: Vector2i = Vector2i(0, signi(delta.y)) if step.y == 0 else Vector2i(signi(delta.x), 0)
		return _step_vector_to_command(enemy.grid_state.facing, fallback_step)

	return preferred_command


## Chooses action during Phased Combat based on distance & Wizardry row rules
func choose_combat_intent(e_data: EnemyData, distance_in_tiles: int) -> Dictionary:
	var intent: Dictionary = {
		"action_type": GridCommand.Type.ATTACK,
		"target_row": "FRONT",
		"skill_to_use": null
	}

	if e_data == null:
		return intent

	if distance_in_tiles > 1:
		if e_data.can_cast_spells:
			intent["action_type"] = GridCommand.Type.CAST_SPELL
			intent["target_row"] = "BACK"
		else:
			intent["action_type"] = GridCommand.Type.WAIT
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


## Calculates the best unblocked step vector towards a target cell, falling back to secondary axis if blocked by a wall
func get_smart_step(from_cell: Vector2i, to_cell: Vector2i, is_blocked_callable: Callable) -> Vector2i:
	var delta: Vector2i = to_cell - from_cell
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO

	var primary_step := Vector2i.ZERO
	var secondary_step := Vector2i.ZERO

	if absi(delta.x) >= absi(delta.y):
		primary_step = Vector2i(signi(delta.x), 0)
		secondary_step = Vector2i(0, signi(delta.y))
	else:
		primary_step = Vector2i(0, signi(delta.y))
		secondary_step = Vector2i(signi(delta.x), 0)

	# 1. Try primary axis
	if primary_step != Vector2i.ZERO and not is_blocked_callable.call(from_cell + primary_step):
		return primary_step

	# 2. Try secondary axis if primary is wall-blocked
	if secondary_step != Vector2i.ZERO and not is_blocked_callable.call(from_cell + secondary_step):
		return secondary_step

	return Vector2i.ZERO
