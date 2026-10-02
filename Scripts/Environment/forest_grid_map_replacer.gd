extends GridMap

@export var forest_item_id: int = 0
@export var forest_chunk_scene: PackedScene = preload("res://Scenes/Environment/forest_wall-mixed_chunk.tscn")

func _ready() -> void:
	_replace_forest_placeholders()

func _replace_forest_placeholders() -> void:
	var map_manager: MapManager = get_parent() as MapManager
	if not map_manager:
		map_manager = get_tree().root.find_child("MapManager", true, false) as MapManager

	var used_cells: Array[Vector3i] = get_used_cells()

	for cell in used_cells:
		if get_cell_item(cell) == forest_item_id:
			# Register cell as blocked in MapManager so player movement respects tree walls
			if is_instance_valid(map_manager):
				map_manager.register_blocked_tile(cell)

			var local_pos: Vector3 = map_to_local(cell)

			# Remove placeholder tile from GridMap
			set_cell_item(cell, INVALID_CELL_ITEM)

			# Spawn MultiMesh tree chunk
			var chunk: Node3D = forest_chunk_scene.instantiate() as Node3D
			add_child(chunk)
			chunk.position = Vector3(local_pos.x, 0.0, local_pos.z)
