class_name CryptHole
extends DungeonInteractable

## File path filter for target map (.tscn files).
## Set the exact path in the Inspector (must start with res://)
@export_file("*.tscn") var target_dungeon_scene: String = "res://Scenes/dungeon_map.tscn"

## Custom prompt text for the confirmation window
@export_multiline var prompt_text: String = "You see a massive stone that appears to be movable. Move it and descend into the depths?"


func interact(_player: Node3D) -> void:
	_open_confirmation_ui()


func _open_confirmation_ui() -> void:
	if is_instance_valid(SignalBus):
		SignalBus.popup_requested.emit(&"CONFIRMATION", {
			"message": prompt_text,
			"confirm_text": "Yes",
			"cancel_text": "No",
			"on_confirm": Callable(self, "_on_descend_confirmed")
		})


func _on_descend_confirmed() -> void:
	if target_dungeon_scene.is_empty():
		push_warning("CryptHole: No target scene specified in Inspector.")
		return

	var map_mgr: MapManager = get_tree().root.find_child("MapManager", true, false) as MapManager
	if not is_instance_valid(map_mgr):
		push_error("CryptHole: MapManager node not found in scene tree!")
		return

	# 1. Swap the active sub-map using MapManager
	map_mgr.switch_map(target_dungeon_scene)

	# 2. Position player at the newly loaded map's SpawnPoint
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if is_instance_valid(player) and is_instance_valid(map_mgr.active_map_instance):
		var spawn_node: Node3D = map_mgr.active_map_instance.get_node_or_null("SpawnPoint") as Node3D
		if is_instance_valid(spawn_node):
			player.global_position = spawn_node.global_position

			# Update grid coordinates on player / movement component if applicable
			var new_grid: Vector3i = map_mgr.world_to_grid(spawn_node.global_position)
			var grid_2d := Vector2i(new_grid.x, new_grid.z)

			if "current_grid_pos" in player:
				player.set("current_grid_pos", grid_2d)

			var grid_comp: Node = player.get_node_or_null("%GridMovementComponent")
			if is_instance_valid(grid_comp) and "current_grid_pos" in grid_comp:
				grid_comp.set("current_grid_pos", grid_2d)