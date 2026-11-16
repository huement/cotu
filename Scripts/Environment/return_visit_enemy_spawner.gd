# res://Scripts/Environment/return_visit_enemy_spawner.gd
class_name ReturnVisitEnemySpawner
extends Node3D

## Spawns world enemies only after the first visit to this map.
## First enter: safe tutorial walk. Later enters: N random drones.

@export_group("Identity")
@export var map_id: String = "GreenGrove"
@export var tracker_object_id: String = "visit_tracker"

@export_group("GridMap References")
@export var floor_map: GridMap
@export var wall_maps: Array[GridMap] = []
@export var spawn_point: Node3D

@export_group("Spawn Configuration")
@export var enemy_scene: PackedScene
@export var spawn_count: int = 3
@export var valid_floor_item_ids: Array[int] = [1, 46]
@export var min_enemy_spacing: float = 5.0
@export var player_safe_radius: float = 8.0
@export var Y_offset: float = 0.0

var _spawned_enemies: Array[Node3D] = []


func _ready() -> void:
	await get_tree().process_frame
	_handle_visit()


func _handle_visit() -> void:
	var visit_count: int = _read_visit_count()
	if visit_count > 0:
		_spawn_enemies()
	_write_visit_count(visit_count + 1)


func _read_visit_count() -> int:
	if not is_instance_valid(GameState):
		return 0
	var state: Dictionary = GameState.get_object_state(map_id, tracker_object_id)
	return int(state.get("count", 0))


func _write_visit_count(count: int) -> void:
	if not is_instance_valid(GameState):
		return
	GameState.set_object_state_flag(map_id, tracker_object_id, "count", count)


func _spawn_enemies() -> void:
	if not is_instance_valid(floor_map) or not is_instance_valid(enemy_scene):
		push_warning("ReturnVisitEnemySpawner: missing floor_map or enemy_scene.")
		return

	var positions: Array[Vector3] = _pick_spawn_positions(spawn_count)
	for pos: Vector3 in positions:
		var enemy: Node3D = enemy_scene.instantiate() as Node3D
		if not is_instance_valid(enemy):
			continue
		add_child(enemy)
		var spawn_pos: Vector3 = pos + Vector3(0.0, Y_offset, 0.0)
		if enemy.has_method("set_spawn_position"):
			enemy.call("set_spawn_position", spawn_pos)
		else:
			enemy.global_position = spawn_pos
		_spawned_enemies.append(enemy)


func _pick_spawn_positions(count: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var used_cells: Array[Vector3i] = floor_map.get_used_cells()
	var candidate_cells: Array[Vector3i] = []
	var player_spawn_pos: Vector3 = spawn_point.global_position if is_instance_valid(spawn_point) else global_position

	for cell: Vector3i in used_cells:
		var item_id: int = floor_map.get_cell_item(cell)
		if not valid_floor_item_ids.has(item_id):
			continue
		if _is_cell_blocked_by_wall(cell):
			continue
		var world_pos: Vector3 = floor_map.to_global(floor_map.map_to_local(cell))
		if world_pos.distance_to(player_spawn_pos) < player_safe_radius:
			continue
		candidate_cells.append(cell)

	candidate_cells.shuffle()
	var min_spacing_sq: float = min_enemy_spacing * min_enemy_spacing

	for cell: Vector3i in candidate_cells:
		if result.size() >= count:
			break
		var world_pos: Vector3 = floor_map.to_global(floor_map.map_to_local(cell))
		var too_close: bool = false
		for existing: Vector3 in result:
			if world_pos.distance_squared_to(existing) < min_spacing_sq:
				too_close = true
				break
		if too_close:
			continue
		result.append(world_pos)

	return result


func _is_cell_blocked_by_wall(cell: Vector3i) -> bool:
	for wmap: GridMap in wall_maps:
		if is_instance_valid(wmap) and wmap.get_cell_item(cell) != GridMap.INVALID_CELL_ITEM:
			return true
	return false
