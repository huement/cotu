class_name EnemyAI
extends Node

const NO_COMMAND := -1


func choose_command(enemy, player) -> int:
	if enemy == null or player == null:
		return NO_COMMAND
	if enemy.grid_state == null or player.grid_state == null:
		return NO_COMMAND

	var enemy_cell: Vector2i = enemy.grid_state.cell
	var player_cell: Vector2i = player.grid_state.cell
	var delta: Vector2i = player_cell - enemy_cell
	if delta == Vector2i.ZERO:
		return NO_COMMAND

	var step := Vector2i.ZERO
	if absi(delta.x) >= absi(delta.y):
		step = Vector2i(signi(delta.x), 0)
	else:
		step = Vector2i(0, signi(delta.y))

	return _step_vector_to_command(enemy.grid_state.facing, step)


func choose_combat_intent(enemy, player) -> int:
	if enemy == null or player == null:
		return NO_COMMAND
	return GridCommand.Type.ATTACK


func _step_vector_to_command(facing: GridDefinitions.Facing, step: Vector2i) -> int:
	if step == Vector2i.ZERO:
		return NO_COMMAND

	var forward := GridDefinitions.facing_to_vec2i(facing)
	var right := GridDefinitions.facing_to_vec2i(GridDefinitions.rotate_right(facing))

	if step == forward:
		return GridCommand.Type.STEP_FORWARD
	if step == -forward:
		return GridCommand.Type.STEP_BACK
	if step == -right:
		return GridCommand.Type.MOVE_LEFT
	if step == right:
		return GridCommand.Type.MOVE_RIGHT

	return NO_COMMAND
