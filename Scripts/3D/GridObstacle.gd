extends Node3D
class_name GridObstacle

@export var is_blocking: bool = true

func _ready() -> void:
	if not is_blocking:
		return
	call_deferred("_register_obstacle")

func _register_obstacle() -> void:
	var map_mgr: Node3D = get_tree().current_scene.find_child("MapManager", true, false) as Node3D
	if not is_instance_valid(map_mgr):
		map_mgr = get_tree().root.find_child("MapManager", true, false) as Node3D

	if is_instance_valid(map_mgr) and map_mgr.has_method("register_blocked_tile"):
		var grid_pos: Vector3i = map_mgr.call("world_to_grid", global_position) as Vector3i
		map_mgr.call("register_blocked_tile", grid_pos)