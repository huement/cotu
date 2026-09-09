extends Node3D
class_name MapManager

## The main GridMap node containing your painted dungeon architecture.
@export var dungeon_grid: GridMap
@export var active_map_instance: Node3D
@export var default_map_scene: PackedScene
@export var ceiling_tile_scene: PackedScene = preload("res://Scenes/CeilingTile.tscn") 
@export var ceiling_height: float = 2.0

## Maps out standard cardinal direction vectors to help calculate steps.
const DIRECTION_MAP: Dictionary = { "NORTH": Vector3i(0, 0, -1), "SOUTH": Vector3i(0, 0, 1), "EAST": Vector3i(1, 0, 0), "WEST": Vector3i(-1, 0, 0) }


func _ready() -> void:
	if default_map_scene:
		switch_map_from_resource(default_map_scene)
	elif not dungeon_grid:
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

	if active_map_instance is GridMap:
		dungeon_grid = active_map_instance as GridMap
	elif active_map_instance.has_node("GridMap3D"):
		dungeon_grid = active_map_instance.get_node("GridMap3D") as GridMap


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


## Checks if a target grid cell contains a blocking wall tile or enemy at ground level.
func is_tile_blocked(grid_position: Vector3i) -> bool:
	GameLogger.nav('IS TILE BLOCK FIRED')
	if not dungeon_grid:
		return true

	var ground_cell: Vector3i = Vector3i(grid_position.x, 0, grid_position.z)
	var item_index: int = dungeon_grid.get_cell_item(ground_cell)

	# Check for static wall geometry
	if item_index != GridMap.INVALID_CELL_ITEM:
		if is_instance_valid(dungeon_grid.mesh_library):
			var item_name: String = dungeon_grid.mesh_library.get_item_name(item_index).to_lower()
			GameLogger.nav('BLOCKED INSTANCE %s' % item_name)
			if item_name.contains("wall"):
				return true # Block movement only if tile is explicitly a wall

	# Check for dynamic enemies at target grid position in active map
	var enemy: Node3D = get_enemy_at_grid_pos(grid_position)
	return is_instance_valid(enemy)


## Returns an enemy node located at the specified 3D grid coordinate if present.
func get_enemy_at_grid_pos(grid_position: Vector3i) -> Node3D:
	var target_2d: Vector2i = Vector2i(grid_position.x, grid_position.z)
	var enemies_node: Node = null

	# Resolve Enemies container from the active instantiated map scene first
	if is_instance_valid(active_map_instance):
		enemies_node = active_map_instance.get_node_or_null("Enemies")
	if not is_instance_valid(enemies_node):
		enemies_node = get_tree().root.find_child("Enemies", true, false)

	if is_instance_valid(enemies_node):
		for child: Node in enemies_node.get_children():
			var enemy: Node3D = child as Node3D
			if not is_instance_valid(enemy) or not enemy.visible:
				continue

			# Verify match via enemy script method OR 3D transform conversion
			var script_grid_pos: Vector2i = enemy.get_grid_pos() if enemy.has_method("get_grid_pos") else Vector2i(9999, 9999)
			var transform_grid_pos: Vector3i = world_to_grid(enemy.global_position)
			var transform_2d: Vector2i = Vector2i(transform_grid_pos.x, transform_grid_pos.z)

			if script_grid_pos == target_2d or transform_2d == target_2d:
				return enemy

	return null


## Returns the 2D grid coordinates of the SpawnPoint node in the active map, or a default fallback.
func get_active_spawn_grid_pos() -> Vector2i:
	if is_instance_valid(active_map_instance):
		var spawn_node: Node3D = active_map_instance.get_node_or_null("SpawnPoint") as Node3D
		if spawn_node and is_instance_valid(dungeon_grid):
			var local_pos: Vector3 = dungeon_grid.to_local(spawn_node.global_position)
			var map_pos: Vector3i = dungeon_grid.local_to_map(local_pos)
			return Vector2i(map_pos.x, map_pos.z)
	return Vector2i(2, 1) # Default fallback cell


## Convenience helper to check if the space cat party can step forward based on direction.
func can_party_move(current_world_pos: Vector3, facing_direction: String) -> bool:
	var current_grid: Vector3i = world_to_grid(current_world_pos)

	if not DIRECTION_MAP.has(facing_direction):
		push_warning("MapManager: Invalid direction string passed: " + facing_direction)
		return false

	var direction_vector: Vector3i = DIRECTION_MAP[facing_direction]
	var target_grid: Vector3i = current_grid + direction_vector

	return not is_tile_blocked(target_grid)


func switch_map(scene_path: String) -> void:
	var map_resource: PackedScene = load(scene_path) as PackedScene
	if not map_resource:
		push_error("MapManager: Failed to load map scene at " + scene_path)
		return

	if is_instance_valid(active_map_instance):
		active_map_instance.queue_free()

	active_map_instance = map_resource.instantiate() as Node3D
	add_child(active_map_instance)

	if active_map_instance is GridMap:
		dungeon_grid = active_map_instance as GridMap
	else:
		dungeon_grid = active_map_instance.get_node("GridMap3D") as GridMap

func _spawn_ceiling_tile(grid_pos: Vector2i) -> void:
	if ceiling_tile_scene == null:
		return

	var ceiling_instance: Node3D = ceiling_tile_scene.instantiate() as Node3D
	var world_x: float = grid_pos.x * 2.0
	var world_z: float = grid_pos.y * 2.0

	ceiling_instance.position = Vector3(world_x, ceiling_height, world_z)
	add_child(ceiling_instance)
