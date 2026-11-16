# res://Scripts/Enemies/FloorTileAmbushSpawner.gd
class_name FloorTileAmbushSpawner
extends Node3D

## While the party walks on matching FloorMap tiles, every `steps_per_roll` steps
## roll `spawn_chance` to emerge a chase rusher (RushEnemyController, no player freeze).
## Swap `rusher_scene` to reuse on other maps / enemy types.

@export_group("Floor")
@export var floor_map: GridMap
## MeshLibrary item name substring, e.g. "floor-concrete" (also matches "cave-floor-concrete").
@export var floor_tile_name: String = "floor-concrete"

@export_group("Rusher")
@export var rusher_scene: PackedScene
@export_range(1, 8) var max_active: int = 2
## Preferred Chebyshev distance (tiles) from the player for the emerge cell.
@export_range(1, 8) var spawn_min_tiles: int = 2
@export_range(1, 10) var spawn_max_tiles: int = 4

@export_group("Odds")
## Count only steps taken while standing on a matching floor tile.
@export_range(1, 20) var steps_per_roll: int = 4
@export_range(0.0, 1.0, 0.01) var spawn_chance: float = 0.20

var _matching_item_ids: Array[int] = []
var _steps_on_tile: int = 0
var _active: Array[RushEnemyController] = []
var _map_manager: Node = null
var _player: Node3D = null


func _ready() -> void:
	if not is_instance_valid(floor_map):
		floor_map = get_parent().get_node_or_null("FloorMap") as GridMap
	_resolve_tile_ids()
	_map_manager = _find_map_manager()
	var sb: Node = SignalBus
	if is_instance_valid(sb) and sb.has_signal(&"party_moved"):
		if not sb.party_moved.is_connected(_on_party_moved):
			sb.party_moved.connect(_on_party_moved)


func _resolve_tile_ids() -> void:
	_matching_item_ids.clear()
	if not is_instance_valid(floor_map) or not is_instance_valid(floor_map.mesh_library):
		return
	var needle: String = floor_tile_name.strip_edges().to_lower()
	if needle.is_empty():
		return
	var lib: MeshLibrary = floor_map.mesh_library
	for item_id: int in lib.get_item_list():
		var item_name: String = lib.get_item_name(item_id).to_lower()
		if needle in item_name:
			_matching_item_ids.append(item_id)
	if _matching_item_ids.is_empty():
		push_warning("FloorTileAmbushSpawner '%s': no FloorMap items match '%s'." % [name, floor_tile_name])


func _on_party_moved(grid_pos: Vector3i, _facing: Variant) -> void:
	_prune_active()
	if not _can_spawn():
		return
	if not _is_matching_floor_cell(Vector2i(grid_pos.x, grid_pos.z)):
		return

	_steps_on_tile += 1
	if _steps_on_tile < steps_per_roll:
		return
	_steps_on_tile = 0

	if randf() > spawn_chance:
		return
	_spawn_rusher(Vector2i(grid_pos.x, grid_pos.z))


func _can_spawn() -> bool:
	if not is_instance_valid(rusher_scene):
		return false
	if _matching_item_ids.is_empty():
		return false
	if _active.size() >= max_active:
		return false
	if bool(CombatManager.get("is_combat_active")):
		return false
	if GameState.has_method("can_begin_encounter") and not GameState.can_begin_encounter():
		return false
	return true


func _spawn_rusher(player_cell: Vector2i) -> void:
	_player = _find_player()
	if not is_instance_valid(_player):
		return

	var spawn_cell: Vector2i = _pick_spawn_cell(player_cell)
	var rusher: Node = rusher_scene.instantiate()
	if not rusher is RushEnemyController:
		push_warning("FloorTileAmbushSpawner: rusher_scene root must use RushEnemyController.")
		rusher.queue_free()
		return

	var controller: RushEnemyController = rusher as RushEnemyController
	var spawn_parent: Node = get_parent()
	if not is_instance_valid(spawn_parent):
		spawn_parent = self
	spawn_parent.add_child(controller)

	var world: Vector3 = _cell_to_world(spawn_cell)
	world.y = 0.0
	controller.global_position = world

	_active.append(controller)
	if not controller.ambush_finished.is_connected(_on_ambush_finished):
		controller.ambush_finished.connect(_on_ambush_finished.bind(controller))

	controller.start_ambush_at(_player)


func _on_ambush_finished(_caught: bool, controller: RushEnemyController) -> void:
	_active.erase(controller)


func _prune_active() -> void:
	var kept: Array[RushEnemyController] = []
	for rusher: RushEnemyController in _active:
		if is_instance_valid(rusher):
			kept.append(rusher)
	_active = kept


func _pick_spawn_cell(player_cell: Vector2i) -> Vector2i:
	var candidates: Array[Vector2i] = []
	var min_d: int = mini(spawn_min_tiles, spawn_max_tiles)
	var max_d: int = maxi(spawn_min_tiles, spawn_max_tiles)
	for dx: int in range(-max_d, max_d + 1):
		for dz: int in range(-max_d, max_d + 1):
			var dist: int = maxi(absi(dx), absi(dz))
			if dist < min_d or dist > max_d:
				continue
			var cell := Vector2i(player_cell.x + dx, player_cell.y + dz)
			if _is_matching_floor_cell(cell):
				candidates.append(cell)
	if not candidates.is_empty():
		return candidates[randi() % candidates.size()]

	# Fallback: offset behind the player even if the tile name doesn't match.
	var facing: Vector2i = _player_facing_offset()
	var behind: Vector2i = player_cell - facing * maxi(2, min_d)
	if behind == player_cell:
		behind = player_cell + Vector2i(0, maxi(2, min_d))
	return behind


func _is_matching_floor_cell(cell: Vector2i) -> bool:
	if not is_instance_valid(floor_map) or _matching_item_ids.is_empty():
		return false
	var item_id: int = floor_map.get_cell_item(Vector3i(cell.x, 0, cell.y))
	return _matching_item_ids.has(item_id)


func _cell_to_world(cell: Vector2i) -> Vector3:
	var cell3 := Vector3i(cell.x, 0, cell.y)
	if is_instance_valid(_map_manager) and _map_manager.has_method("nav_cell_to_world"):
		return _map_manager.call("nav_cell_to_world", cell3) as Vector3
	if is_instance_valid(floor_map):
		return floor_map.to_global(floor_map.map_to_local(cell3))
	return Vector3(cell.x * 2.0 + 1.0, 0.0, cell.y * 2.0 + 1.0)


func _player_facing_offset() -> Vector2i:
	if not is_instance_valid(_player):
		return Vector2i(0, 1)
	if "current_facing" in _player:
		# DungeonPlayer.Facing: NORTH=0, WEST=1, SOUTH=2, EAST=3
		match int(_player.get("current_facing")):
			0:
				return Vector2i(0, -1) # NORTH
			1:
				return Vector2i(-1, 0) # WEST
			2:
				return Vector2i(0, 1) # SOUTH
			3:
				return Vector2i(1, 0) # EAST
	var forward: Vector3 = -_player.global_transform.basis.z
	if absf(forward.x) > absf(forward.z):
		return Vector2i(1 if forward.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if forward.z > 0.0 else -1)


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
