# res://Scripts/Environment/night_enemy_spawner.gd
class_name NightEnemySpawner
extends Node3D

@export_group("GridMap References")
@export var floor_map: GridMap
@export var wall_maps: Array[GridMap] = []
@export var spawn_point: Node3D

@export_group("Spawn Configuration")
@export var enemy_scene: PackedScene

## Tile item IDs valid for spawning (1 = Grass, 46 = Dirt)
@export var valid_floor_item_ids: Array[int] = [1, 46]

## Number of valid floor tiles required per enemy (e.g., 1 per 35 tiles)
@export var density_tile_ratio: int = 35
@export var min_enemies: int = 4
@export var max_enemies: int = 12

## Minimum distance in meters between spawned enemies for even spacing
@export var min_enemy_spacing: float = 6.0

## Safe radius in meters around player spawn point
@export var player_safe_radius: float = 6.0

## Vertical Y offset above floor
@export var Y_offset: float = 0.0

var _spawned_enemies: Array[Node3D] = []

func _ready() -> void:
	await get_tree().process_frame
	_initialize_spawns()
	_connect_signals()

func _connect_signals() -> void:
	var sb: Node = SignalBus if is_instance_valid(SignalBus) else get_node_or_null("/root/SignalBus")
	if is_instance_valid(sb) and sb.has_signal(&"day_night_changed"):
		if not sb.day_night_changed.is_connected(_on_day_night_changed):
			sb.day_night_changed.connect(_on_day_night_changed)

func _initialize_spawns() -> void:
	if not is_instance_valid(floor_map) or not is_instance_valid(enemy_scene):
		return

	var valid_positions: Array[Vector3] = _calculate_evenly_spaced_positions()
	var is_night: bool = _check_is_night()

	for pos in valid_positions:
		var spawn_pos: Vector3 = pos + Vector3(0.0, Y_offset, 0.0)
		var enemy: Node3D = enemy_scene.instantiate() as Node3D
		add_child(enemy)
		
		if enemy.has_method("set_spawn_position"):
			enemy.call("set_spawn_position", spawn_pos)
		else:
			enemy.global_position = spawn_pos
			
		_spawned_enemies.append(enemy)

	_update_enemies_time_state(is_night)

func _calculate_evenly_spaced_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var used_cells: Array[Vector3i] = floor_map.get_used_cells()
	var valid_cells: Array[Vector3i] = []

	for cell in used_cells:
		var item_id: int = floor_map.get_cell_item(cell)
		if valid_floor_item_ids.has(item_id):
			if not _is_cell_blocked_by_wall(cell):
				valid_cells.append(cell)

	if valid_cells.is_empty():
		return result

	var target_count: int = clamp(valid_cells.size() / density_tile_ratio, min_enemies, max_enemies)
	var player_spawn_pos: Vector3 = spawn_point.global_position if is_instance_valid(spawn_point) else global_position

	# Filter out cells within the player's safe radius before we begin.
	var candidate_cells: Array[Vector3i] = []
	for cell in valid_cells:
		var world_pos: Vector3 = floor_map.to_global(floor_map.map_to_local(cell))
		if world_pos.distance_to(player_spawn_pos) >= player_safe_radius:
			candidate_cells.append(cell)

	candidate_cells.shuffle()

	if candidate_cells.is_empty():
		return result

	# Add the first spawn point randomly from the valid candidates.
	result.append(floor_map.to_global(floor_map.map_to_local(candidate_cells.pop_front())))

	# This approach attempts to spread enemies out by iteratively finding the best-of-N-samples
	# position that is furthest from all previously spawned enemies. This is a form of 
	# accelerated poisson-disc sampling that produces more uniform layouts.
	var sample_size: int = 30
	var min_spacing_sq: float = min_enemy_spacing * min_enemy_spacing

	while result.size() < target_count and not candidate_cells.is_empty():
		var best_candidate_index: int = -1
		var best_candidate_pos: Vector3
		var best_min_dist_sq: float = -1.0
		
		var num_samples: int = min(sample_size, candidate_cells.size())
		
		# Sample a subset of candidates to find the one that is furthest away from existing points.
		for i in range(num_samples):
			var sample_cell: Vector3i = candidate_cells[i]
			var sample_pos: Vector3 = floor_map.to_global(floor_map.map_to_local(sample_cell))
			
			var current_min_dist_sq: float = INF
			for existing_pos in result:
				current_min_dist_sq = min(current_min_dist_sq, sample_pos.distance_squared_to(existing_pos))

			# If this sample is the best (furthest away) so far, record it.
			if current_min_dist_sq > best_min_dist_sq:
				best_min_dist_sq = current_min_dist_sq
				best_candidate_pos = sample_pos
				best_candidate_index = i

		# If a suitable candidate was found (i.e., it meets min spacing), add it.
		if best_candidate_index != -1 and best_min_dist_sq >= min_spacing_sq:
			result.append(best_candidate_pos)
			candidate_cells.remove_at(best_candidate_index)
		else:
			# If no suitable point was found in the sample set, the area is likely too
			# crowded to continue. We stop here to avoid placing enemies too close.
			break
			
	return result

func _is_cell_blocked_by_wall(cell: Vector3i) -> bool:
	for wmap in wall_maps:
		if is_instance_valid(wmap) and wmap.get_cell_item(cell) != GridMap.INVALID_CELL_ITEM:
			return true
	return false

func _check_is_night() -> bool:
	var game_state: Node = get_node_or_null("/root/GameState")
	if is_instance_valid(game_state) and "current_time_period" in game_state:
		return str(game_state.current_time_period) == "NIGHT"
	return false

func _on_day_night_changed(is_night: bool) -> void:
	_update_enemies_time_state(is_night)

func _update_enemies_time_state(is_night: bool) -> void:
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy) and enemy.has_method("_evaluate_time_state"):
			enemy.call("_evaluate_time_state", is_night)