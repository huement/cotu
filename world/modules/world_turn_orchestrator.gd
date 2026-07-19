extends Node
class_name WorldTurnOrchestrator

const COMBAT_DEFEND_DIVISOR := 2
const COMBAT_USE_ITEM_HEAL_AMOUNT := 2
const PICKUP_GROUP := &"world_pickups"

var _ui_module: WorldUIModule
var _grid_module: WorldGridModule
var _encounter_module: WorldEncounterModule
var _run_outcome_module: WorldRunOutcomeModule
var _world_root: Node
var _player
var _is_gameplay_state_active_fn: Callable
var _is_combat_state_active_fn: Callable
var _end_combat_fn: Callable
var _finish_with_failure_fn: Callable
var _combat_round_manager: CombatRoundManager


func configure(
		ui_module: WorldUIModule,
		grid_module: WorldGridModule,
		encounter_module: WorldEncounterModule,
		run_outcome_module: WorldRunOutcomeModule,
		world_root: Node,
		player,
		is_gameplay_state_active_fn: Callable,
		is_combat_state_active_fn: Callable,
		end_combat_fn: Callable,
		finish_with_failure_fn: Callable) -> void:
	_ui_module = ui_module
	_grid_module = grid_module
	_encounter_module = encounter_module
	_run_outcome_module = run_outcome_module
	_world_root = world_root
	_player = player
	_is_gameplay_state_active_fn = is_gameplay_state_active_fn
	_is_combat_state_active_fn = is_combat_state_active_fn
	_end_combat_fn = end_combat_fn
	_finish_with_failure_fn = finish_with_failure_fn

	if _combat_round_manager == null:
		_combat_round_manager = CombatRoundManager.new()
		add_child(_combat_round_manager)

	if not _combat_round_manager.round_resolved.is_connected(_on_round_resolved):
		_combat_round_manager.round_resolved.connect(_on_round_resolved)


func process_player_action(new_state: GridState) -> void:
	_ui_module.refresh_coords(new_state.cell)
	_ui_module.refresh_minimap(new_state.cell, _grid_module.occupancy())
	_collect_pickups(new_state.cell)
	_encounter_module.collect()

	if not _is_gameplay_active():
		return

	if _run_outcome_module.is_resolved():
		return

	_run_outcome_module.evaluate(new_state.cell)
	if _run_outcome_module.is_resolved():
		return

	if _encounter_module.check_combat_trigger():
		return

	_encounter_module.tick_step_echo()
	_encounter_module.check_combat_trigger()


func _collect_pickups(player_cell: Vector2i) -> void:
	if _world_root == null:
		return

	for node in _world_root.get_tree().get_nodes_in_group(PICKUP_GROUP):
		if node == null:
			continue
		if node.get_tree() != _world_root.get_tree():
			continue
		if not node.has_method("collect_if_player_on_cell"):
			continue
		node.call("collect_if_player_on_cell", _player, player_cell)


func process_enemy_action() -> void:
	if not _is_gameplay_active() or _run_outcome_module.is_resolved():
		return
	_encounter_module.check_combat_trigger()


func start_combat_round(enemies: Array) -> void:
	if _combat_round_manager == null or _player == null:
		return

	var roster: Array = [_player]
	for enemy in enemies:
		if enemy == null or roster.has(enemy):
			continue
		roster.append(enemy)

	_combat_round_manager.start_round(roster)
	_submit_enemy_intents(enemies)


func handle_combat_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.echo:
		return false
	if not _is_combat_active():
		return false

	if event.is_action_pressed("combat_attack"):
		return submit_player_combat_intent(GridCommand.Type.ATTACK)
	if event.is_action_pressed("combat_defend"):
		return submit_player_combat_intent(GridCommand.Type.DEFEND)
	if event.is_action_pressed("combat_use_item"):
		return submit_player_combat_intent(GridCommand.Type.USE_ITEM)

	return false


func submit_player_combat_intent(cmd: GridCommand.Type) -> bool:
	if _combat_round_manager == null or _player == null:
		return false
	if not _is_combat_active() or not _combat_round_manager.is_waiting_for_intents():
		return false
	return _combat_round_manager.submit_intent(_player, cmd)


func is_run_resolved() -> bool:
	return _run_outcome_module.is_resolved()


func _is_gameplay_active() -> bool:
	if _is_gameplay_state_active_fn.is_valid():
		return bool(_is_gameplay_state_active_fn.call())
	return false


func _is_combat_active() -> bool:
	if _is_combat_state_active_fn.is_valid():
		return bool(_is_combat_state_active_fn.call())
	return false


func _submit_enemy_intents(enemies: Array) -> void:
	if _combat_round_manager == null or not _combat_round_manager.is_waiting_for_intents():
		return

	for enemy in enemies:
		if enemy == null or not _combat_round_manager.is_waiting_for_intents():
			continue

		var cmd: int = GridCommand.Type.ATTACK
		if enemy.has_method("choose_combat_intent"):
			cmd = int(enemy.call("choose_combat_intent", _player))

		_combat_round_manager.submit_intent(enemy, cmd as GridCommand.Type)


func _on_round_resolved(_intents: Dictionary) -> void:
	if _player == null or _player.stats == null:
		return

	_resolve_round_damage(_intents)

	if _player.stats.is_dead():
		if _finish_with_failure_fn.is_valid():
			_finish_with_failure_fn.call()
		return

	var remaining_enemies := _alive_combatants()
	if remaining_enemies.is_empty():
		if _end_combat_fn.is_valid():
			_end_combat_fn.call()
		return

	start_combat_round(remaining_enemies)


func _resolve_round_damage(intents: Dictionary) -> void:
	var player_intent: Variant = intents.get(_player, null)
	if player_intent == GridCommand.Type.USE_ITEM:
		_player.stats.heal(COMBAT_USE_ITEM_HEAL_AMOUNT)

	var active_enemies := _alive_combatants()
	if player_intent == GridCommand.Type.ATTACK:
		var target := _find_player_attack_target(active_enemies)
		if target != null and target.stats != null and _is_adjacent(_player, target):
			target.stats.take_damage(_player.stats.attack)

	for enemy in active_enemies:
		var enemy_intent: Variant = intents.get(enemy, null)
		if enemy_intent != GridCommand.Type.ATTACK:
			continue
		if enemy.stats == null:
			continue
		if _is_adjacent(enemy, _player):
			var incoming_damage: int = int(enemy.stats.attack)
			if player_intent == GridCommand.Type.DEFEND:
				incoming_damage = maxi(1, int(ceili(float(incoming_damage) / float(COMBAT_DEFEND_DIVISOR))))
			_player.stats.take_damage(incoming_damage)

	# Keep defeated enemies alive until after test assertions and state transitions.
	# Encounter/passability modules filter dead stats so they no longer influence gameplay.


func _alive_combatants() -> Array:
	var alive: Array = []
	if _combat_round_manager == null:
		return alive

	for enemy in _combat_round_manager.get_combatants():
		if enemy == _player:
			continue
		if enemy == null:
			continue
		if enemy.stats == null or enemy.stats.is_dead():
			continue
		alive.append(enemy)
	return alive


func _find_player_attack_target(enemies: Array) -> Node:
	for enemy in enemies:
		if _is_adjacent(_player, enemy):
			return enemy
	return null


func _is_adjacent(a, b) -> bool:
	if a == null or b == null:
		return false
	if a.grid_state == null or b.grid_state == null:
		return false
	var delta: Vector2i = a.grid_state.cell - b.grid_state.cell
	var manhattan := absi(delta.x) + absi(delta.y)
	return manhattan <= 1
