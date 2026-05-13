extends Node
class_name WorldEncounterModule

signal encounter_detected(encountered: Array)
signal enemy_acted

const ENEMY_GROUP := &"grid_enemies"

var _enemies: Array = []
var _grid_module: WorldGridModule
var _world_root: Node
var _player


func configure(world_root: Node, player, grid_module: WorldGridModule) -> void:
	_world_root = world_root
	_player = player
	_grid_module = grid_module


func get_enemies() -> Array:
	return _enemies


func wire_enemies() -> void:
	collect()

	for enemy in _enemies:
		if enemy.movement_controller == null:
			continue
		var captured_enemy = enemy
		enemy.movement_controller.passability_fn = func(cell: Vector2i) -> bool:
			return _enemy_cell_passable(captured_enemy, cell)
		if not enemy.movement_controller.action_completed.is_connected(_on_enemy_action_completed.bind(enemy)):
			enemy.movement_controller.action_completed.connect(_on_enemy_action_completed.bind(enemy))


func collect() -> void:
	if _world_root == null:
		return

	_enemies.clear()

	for node in _world_root.get_tree().get_nodes_in_group(ENEMY_GROUP):
		if node == null:
			continue
		if node.get_tree() != _world_root.get_tree():
			continue
		if not node.has_method("tick_ai"):
			continue
		_enemies.append(node)

	# Fallback discovery for enemies present in the tree but not yet in group.
	for node in _world_root.find_children("*", "Node", true, false):
		if node == null or node == _world_root or node == _player:
			continue
		if not node.has_method("tick_ai"):
			continue
		if _enemies.has(node):
			continue
		_enemies.append(node)


func tick_step_echo() -> void:
	if _player == null:
		return

	collect()

	for enemy in _enemies:
		if enemy == null:
			continue
		if not _is_enemy_alive(enemy):
			continue
		enemy.tick_ai(_player)


func check_combat_trigger() -> bool:
	if _player == null or _player.grid_state == null:
		return false

	collect()

	var encountered: Array = []
	for enemy in _enemies:
		if enemy == null or enemy.grid_state == null:
			continue
		if not _is_enemy_alive(enemy):
			continue
		var delta: Vector2i = enemy.grid_state.cell - _player.grid_state.cell
		var manhattan: int = absi(delta.x) + absi(delta.y)
		if manhattan <= 1:
			encountered.append(enemy)

	if encountered.is_empty():
		return false

	encounter_detected.emit(encountered)
	return true


func _enemy_cell_passable(enemy, cell: Vector2i) -> bool:
	if _grid_module != null:
		return _grid_module.is_enemy_cell_passable(enemy, cell, _enemies)
	return true


func _on_enemy_action_completed(_cmd, _new_state, _enemy) -> void:
	enemy_acted.emit()


func _is_enemy_alive(enemy) -> bool:
	if enemy == null:
		return false
	if not is_instance_valid(enemy):
		return false
	if enemy.stats == null:
		return true
	return not enemy.stats.is_dead()
