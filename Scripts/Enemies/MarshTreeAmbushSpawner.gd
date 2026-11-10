# res://Scripts/Enemies/MarshTreeAmbushSpawner.gd
class_name MarshTreeAmbushSpawner
extends Node3D

## Watches MarshTimber children under this node. When the player lingers near a tree,
## waits a random delay then spawns a MarshTreeRusher that chases without freezing.

const MARSH_YELL: AudioStream = preload("res://Audio/Enemies/marsh_yell.mp3")

@export var rusher_scene: PackedScene = preload("res://Scenes/Enemies/MarshTreeRusher.tscn")
@export_range(1, 8) var proximity_tiles: int = 3
@export var min_delay_seconds: float = 1.0
@export var max_delay_seconds: float = 5.0
@export var tree_cooldown_seconds: float = 25.0
@export var poll_interval_seconds: float = 0.2

var _trees: Array[Node3D] = []
var _pending_timers: Dictionary = {} # Node3D -> float remaining
var _cooldowns: Dictionary = {} # Node3D -> float remaining
var _active_rusher: RushEnemyController = null
var _active_tree: Node3D = null
var _poll_timer: float = 0.0
var _map_manager: Node = null
var _player: Node3D = null


func _ready() -> void:
	_cache_trees()
	_map_manager = _find_map_manager()


func _cache_trees() -> void:
	_trees.clear()
	for child in get_children():
		if child is Node3D and String(child.name).begins_with("MarshTimber"):
			_trees.append(child as Node3D)


func _process(delta: float) -> void:
	_tick_cooldowns(delta)
	_poll_timer -= delta
	if _poll_timer > 0.0:
		return
	_poll_timer = poll_interval_seconds
	_update_ambush_logic(poll_interval_seconds)


func _tick_cooldowns(delta: float) -> void:
	var expired: Array = []
	for tree in _cooldowns.keys():
		_cooldowns[tree] = float(_cooldowns[tree]) - delta
		if float(_cooldowns[tree]) <= 0.0:
			expired.append(tree)
	for tree in expired:
		_cooldowns.erase(tree)


func _update_ambush_logic(step: float) -> void:
	if is_instance_valid(_active_rusher):
		return
	if bool(CombatManager.get("is_combat_active")):
		_clear_pending()
		return
	if GameState.has_method("can_begin_encounter") and not GameState.can_begin_encounter():
		_clear_pending()
		return

	_player = _find_player()
	if not is_instance_valid(_player):
		_clear_pending()
		return

	var player_cell: Vector2i = _player_cell()
	var near_trees: Array[Node3D] = []
	for tree in _trees:
		if not is_instance_valid(tree):
			continue
		if _cooldowns.has(tree):
			_pending_timers.erase(tree)
			continue
		if _chebyshev(player_cell, _world_to_cell(tree.global_position)) <= proximity_tiles:
			near_trees.append(tree)
		else:
			_pending_timers.erase(tree)

	if near_trees.is_empty():
		return

	# Prefer a tree that already has a ticking timer; otherwise start one.
	var ready_tree: Node3D = null
	for tree in near_trees:
		if _pending_timers.has(tree):
			_pending_timers[tree] = float(_pending_timers[tree]) - step
			if float(_pending_timers[tree]) <= 0.0:
				ready_tree = tree
				break
		else:
			_pending_timers[tree] = randf_range(min_delay_seconds, max_delay_seconds)

	if not is_instance_valid(ready_tree):
		return

	_pending_timers.erase(ready_tree)
	_spawn_rusher(ready_tree)


func _spawn_rusher(tree: Node3D) -> void:
	if not is_instance_valid(rusher_scene) or not is_instance_valid(_player):
		return

	var rusher: Node = rusher_scene.instantiate()
	if not rusher is RushEnemyController:
		push_warning("MarshTreeAmbushSpawner: rusher_scene root must use RushEnemyController.")
		rusher.queue_free()
		return

	var controller: RushEnemyController = rusher as RushEnemyController
	if controller.alt_emerge_sounds.is_empty():
		controller.alt_emerge_sounds = [MARSH_YELL]
	var spawn_parent: Node = get_parent()
	if not is_instance_valid(spawn_parent):
		spawn_parent = self
	spawn_parent.add_child(controller)

	var spawn_pos: Vector3 = tree.global_position
	spawn_pos.y = 0.0
	controller.global_position = spawn_pos

	_active_rusher = controller
	_active_tree = tree
	_clear_pending()

	if not controller.ambush_finished.is_connected(_on_ambush_finished):
		controller.ambush_finished.connect(_on_ambush_finished)

	controller.start_ambush_at(_player)


func _on_ambush_finished(_caught: bool) -> void:
	if is_instance_valid(_active_tree):
		_cooldowns[_active_tree] = tree_cooldown_seconds
	_active_tree = null
	_active_rusher = null


func _clear_pending() -> void:
	_pending_timers.clear()


func _player_cell() -> Vector2i:
	if is_instance_valid(_player) and "current_grid_pos" in _player:
		return _player.get("current_grid_pos") as Vector2i
	return _world_to_cell(_player.global_position)


func _world_to_cell(world: Vector3) -> Vector2i:
	if is_instance_valid(_map_manager) and _map_manager.has_method("world_to_grid"):
		var cell3: Vector3i = _map_manager.call("world_to_grid", world) as Vector3i
		return Vector2i(cell3.x, cell3.z)
	# Fallback: project tiles are 2m wide.
	return Vector2i(int(round(world.x / 2.0)), int(round(world.z / 2.0)))


func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _find_player() -> Node3D:
	var existing: Node = get_tree().get_first_node_in_group(&"player")
	if is_instance_valid(existing) and existing is Node3D:
		return existing as Node3D
	var root: Node = get_tree().root
	if is_instance_valid(root):
		var found: Node = root.find_child("Player", true, false)
		if is_instance_valid(found) and found is Node3D:
			return found as Node3D
	return null


func _find_map_manager() -> Node:
	var root: Node = get_tree().root
	if not is_instance_valid(root):
		return null
	return root.find_child("MapManager", true, false)
