extends Node3D
class_name MapManager

## The main GridMap node
@export var dungeon_grid: GridMap
@export var floor_grid: GridMap
@export var active_map_instance: Node3D
@export var default_map_scene: PackedScene
@export var ceiling_tile_scene: PackedScene = preload("res://Scenes/CeilingTile.tscn") 
@export var ceiling_height: float = 2.0
@export var default_bgm_track: String = "Environment/forest-creepy"

@export var map_type: String = "forest"
@export var grid_map: GridMap

## Maps out standard cardinal direction vectors to help calculate steps.
const DIRECTION_MAP: Dictionary = {
	"NORTH": Vector3i(0, 0, -1),
	"SOUTH": Vector3i(0, 0, 1),
	"EAST": Vector3i(1, 0, 0),
	"WEST": Vector3i(-1, 0, 0)
}

var _blocked_tiles: Dictionary = {}

func _ready() -> void:
	if default_map_scene:
		switch_map_from_resource(default_map_scene)
	else:
		_resolve_active_wall_map()

	if not dungeon_grid:
		push_error("MapManager: GridMap reference is missing in the Inspector!")
	else:
		print("MapManager: Space-Dungeon grid system online.")


func switch_map_from_resource(map_resource: PackedScene) -> void:
	if not map_resource:
		push_error("MapManager: Invalid PackedScene passed to switch_map_from_resource.")
		return

	if is_instance_valid(active_map_instance):
		active_map_instance.queue_free()

	active_map_instance = map_resource.instantiate() as Node3D
	add_child(active_map_instance)

	_resolve_dungeon_grid(active_map_instance)
	_notify_player_map_changed()
	_apply_map_audio(active_map_instance)


func switch_map(scene_path: String) -> void:
	var map_resource: PackedScene = load(scene_path) as PackedScene
	if not map_resource:
		push_error("MapManager: Failed to load map scene at " + scene_path)
		return

	if is_instance_valid(active_map_instance):
		active_map_instance.queue_free()

	active_map_instance = map_resource.instantiate() as Node3D
	add_child(active_map_instance)

	_resolve_dungeon_grid(active_map_instance)
	_notify_player_map_changed()
	GameLogger.info("SWITCH MAP FIRED. NOW STARTING AUDIO")
	_apply_map_audio(active_map_instance)


func _notify_player_map_changed() -> void:
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if is_instance_valid(player) and player.has_method("refresh_for_new_map"):
		player.call("refresh_for_new_map")


## Helper method to resolve dungeon_grid and floor_grid across level scene structures
func _resolve_dungeon_grid(map_instance: Node3D) -> void:
	if not is_instance_valid(map_instance):
		return

	# Resolve Wall Map (blocking geometry)
	if map_instance is GridMap:
		dungeon_grid = map_instance as GridMap
	elif map_instance.has_node("%WallMap"):
		dungeon_grid = map_instance.get_node("%WallMap") as GridMap
	elif map_instance.has_node("WallMap"):
		dungeon_grid = map_instance.get_node("WallMap") as GridMap
	elif map_instance.has_node("GridMap"):
		dungeon_grid = map_instance.get_node("GridMap") as GridMap
	elif map_instance.has_node("GridMap3D"):
		dungeon_grid = map_instance.get_node("GridMap3D") as GridMap

	# Resolve Floor Map (ground tiles & water)
	if map_instance.has_node("%FloorMap"):
		floor_grid = map_instance.get_node("%FloorMap") as GridMap
	elif map_instance.has_node("FloorMap"):
		floor_grid = map_instance.get_node("FloorMap") as GridMap
	else:
		floor_grid = null

	# Update active map_type for audio/footsteps
	if "map_type" in map_instance and not str(map_instance.get("map_type")).is_empty():
		map_type = str(map_instance.get("map_type"))
	elif map_instance.has_meta("map_type"):
		map_type = str(map_instance.get_meta("map_type"))
	elif "dungeon" in map_instance.name.to_lower():
		map_type = "dungeon"
	else:
		map_type = "forest"


## Evaluates and triggers background music for the newly loaded map instance.
func _apply_map_audio(map_instance: Node) -> void:
	if not is_instance_valid(AudioManager):
		return

	var track_name: String = default_bgm_track

	if is_instance_valid(map_instance):
		if "bgm_track_name" in map_instance and not str(map_instance.get("bgm_track_name")).is_empty():
			track_name = str(map_instance.get("bgm_track_name"))

	AudioManager.play_bgm(track_name)


## Converts an absolute 3D world position into 3D GridMap integer coordinates.
func world_to_grid(world_position: Vector3) -> Vector3i:
	if not dungeon_grid:
		return Vector3i.ZERO
	return dungeon_grid.local_to_map(dungeon_grid.to_local(world_position))


## Converts 3D GridMap integer coordinates back into absolute 3D world positions.
func grid_to_world(grid_position: Vector3i) -> Vector3:
	if not dungeon_grid:
		return Vector3.ZERO
	return dungeon_grid.to_global(dungeon_grid.map_to_local(grid_position))


## Checks if a target grid cell contains a blocking wall tile, water, enemy, or 3D physics obstacle.
func is_tile_blocked(grid_position: Vector3i) -> bool:
	if _blocked_tiles.get(grid_position, false):
		return true

	var ground_cell := Vector3i(grid_position.x, 0, grid_position.z)

	# 1. Check WallMap for trees or walls
	if is_instance_valid(dungeon_grid):
		var wall_item_index: int = dungeon_grid.get_cell_item(ground_cell)
		if wall_item_index != GridMap.INVALID_CELL_ITEM:
			if dungeon_grid.name == "WallMap" or dungeon_grid.name == "%WallMap":
				return true

			if is_instance_valid(dungeon_grid.mesh_library):
				var wall_item_name: String = dungeon_grid.mesh_library.get_item_name(wall_item_index).to_lower()
				if wall_item_name.contains("wall") or wall_item_name.contains("placeholder"):
					return true

	# 2. Check FloorMap for river/water tiles
	if is_instance_valid(floor_grid):
		var floor_item_index: int = floor_grid.get_cell_item(ground_cell)
		if floor_item_index != GridMap.INVALID_CELL_ITEM and is_instance_valid(floor_grid.mesh_library):
			var floor_item_name: String = floor_grid.mesh_library.get_item_name(floor_item_index).to_lower()
			if floor_item_name.contains("river") or floor_item_name.contains("water"):
				return true

	# 3. Check for dynamic enemies
	var enemy: Node3D = get_enemy_at_grid_pos(grid_position)
	if is_instance_valid(enemy):
		return true

	# 4. Check for blocking interactable objects
	var interactable: DungeonInteractable = get_interactable_at_grid_pos(grid_position)
	if is_instance_valid(interactable) and interactable.is_blocking:
		return true

	# 5. Check for 3D physics obstacles (e.g. BigTimber trees, barrels, StaticBody3D props)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state:
		var target_world_pos: Vector3 = grid_to_world(grid_position)
		var shape_query := PhysicsShapeQueryParameters3D.new()
		var box_shape := BoxShape3D.new()
		# Reduced from 1.6 to 1.0 to check only the cell core
		box_shape.size = Vector3(1.0, 2.0, 1.0)
		shape_query.shape = box_shape
		shape_query.transform = Transform3D(Basis.IDENTITY, target_world_pos + Vector3(0.0, 1.0, 0.0))
		shape_query.collision_mask = 1 # Layer 1 for StaticBody3D

		var hits: Array[Dictionary] = space_state.intersect_shape(shape_query)
		if not hits.is_empty():
			return true

	return false


## Returns an enemy node located at the specified 3D grid coordinate if present.
func get_enemy_at_grid_pos(grid_position: Vector3i) -> Node3D:
	var target_2d: Vector2i = Vector2i(grid_position.x, grid_position.z)
	var enemies_node: Node = null

	if is_instance_valid(active_map_instance):
		enemies_node = active_map_instance.get_node_or_null("Enemies")
	if not is_instance_valid(enemies_node):
		enemies_node = get_tree().root.find_child("Enemies", true, false)

	if is_instance_valid(enemies_node):
		for child: Node in enemies_node.get_children():
			var enemy: Node3D = child as Node3D
			if not is_instance_valid(enemy) or not enemy.visible:
				continue

			var script_grid_pos: Vector2i = enemy.get_grid_pos() if enemy.has_method("get_grid_pos") else Vector2i(9999, 9999)
			var transform_grid_pos: Vector3i = world_to_grid(enemy.global_position)
			var transform_2d: Vector2i = Vector2i(transform_grid_pos.x, transform_grid_pos.z)

			if script_grid_pos == target_2d or transform_2d == target_2d:
				return enemy

	return null


## Returns the 2D grid coordinates of the SpawnPoint node in the active map, or a default fallback.
func get_active_spawn_grid_pos() -> Vector2i:
	if is_instance_valid(active_map_instance):
		var spawn_node: Node3D = active_map_instance.get_node_or_null("PlayerSpawn") as Node3D
		if not spawn_node:
			spawn_node = active_map_instance.get_node_or_null("SpawnPoint") as Node3D

		if spawn_node and is_instance_valid(dungeon_grid):
			var local_pos: Vector3 = dungeon_grid.to_local(spawn_node.global_position)
			var map_pos: Vector3i = dungeon_grid.local_to_map(local_pos)
			return Vector2i(map_pos.x, map_pos.z)

	return Vector2i(0, 0)


## Convenience helper to check if the space cat party can step forward based on direction.
func can_party_move(current_world_pos: Vector3, facing_direction: String) -> bool:
	var current_grid: Vector3i = world_to_grid(current_world_pos)

	if not DIRECTION_MAP.has(facing_direction):
		push_warning("MapManager: Invalid direction string passed: " + facing_direction)
		return false

	var direction_vector: Vector3i = DIRECTION_MAP[facing_direction]
	var target_grid: Vector3i = current_grid + direction_vector

	return not is_tile_blocked(target_grid)


func _spawn_ceiling_tile(grid_position: Vector2i) -> void:
	if ceiling_tile_scene == null:
		return

	var ceiling_instance: Node3D = ceiling_tile_scene.instantiate() as Node3D
	var world_x: float = grid_position.x * 2.0
	var world_z: float = grid_position.y * 2.0

	ceiling_instance.position = Vector3(world_x, ceiling_height, world_z)
	add_child(ceiling_instance)


## Returns an interactable node located at the specified 3D grid coordinate if present.
func get_interactable_at_grid_pos(grid_position: Vector3i) -> DungeonInteractable:
	var target_2d := Vector2i(grid_position.x, grid_position.z)
	var nodes: Array[Node] = get_tree().get_nodes_in_group(&"dungeon_interactables")

	for node in nodes:
		var interactable := node as DungeonInteractable
		if is_instance_valid(interactable) and interactable.visible:
			if interactable.get_grid_pos() == target_2d:
				return interactable

	return null


func register_blocked_tile(grid_position: Vector3i) -> void:
	_blocked_tiles[grid_position] = true


func _resolve_active_wall_map() -> void:
	if is_instance_valid(active_map_instance):
		_resolve_dungeon_grid(active_map_instance)
	elif get_child_count() > 0:
		_resolve_dungeon_grid(get_child(0) as Node3D)


func get_current_map_type() -> String:
	return map_type
