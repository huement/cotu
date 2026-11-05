class_name MapTransition
extends RefCounted
## Moves the party between sub-maps through MapManager (e.g. GloomReach <-> cave levels).
## The world scene (Player, HUD, MapManager) stays loaded; only the active map is swapped.

const DEFAULT_ARRIVAL: String = "SpawnPoint"


## Swaps the active map to `scene_path` and puts the party on the marker named
## `arrival_point_name` (a Node3D in the target map). The marker's -Z axis is the
## direction the party will face. Falls back to the map's SpawnPoint.
static func travel(tree: SceneTree, scene_path: String, arrival_point_name: String = DEFAULT_ARRIVAL) -> bool:
	if scene_path.is_empty():
		push_warning("MapTransition: No target scene specified.")
		return false

	var map_mgr: MapManager = tree.root.find_child("MapManager", true, false) as MapManager
	if not is_instance_valid(map_mgr):
		push_error("MapTransition: MapManager node not found in scene tree!")
		return false

	# switch_map() also calls player.refresh_for_new_map(), which places the party
	# on the new map's SpawnPoint (position, facing and eye height).
	map_mgr.switch_map(scene_path)

	var new_map: Node3D = map_mgr.active_map_instance
	if not is_instance_valid(new_map):
		return false

	var arrival: Node3D = _find_arrival(new_map, arrival_point_name)
	if not is_instance_valid(arrival):
		return true

	var player: DungeonPlayer = tree.get_first_node_in_group(&"player") as DungeonPlayer
	if not is_instance_valid(player):
		return true

	var forward: Vector3 = -arrival.global_basis.z
	player.teleport_to(arrival.global_position, arrival.global_position + forward)
	return true


static func _find_arrival(map_root: Node3D, arrival_point_name: String) -> Node3D:
	var point_name: String = arrival_point_name if not arrival_point_name.is_empty() else DEFAULT_ARRIVAL
	var arrival: Node3D = map_root.get_node_or_null(NodePath(point_name)) as Node3D
	if not is_instance_valid(arrival):
		arrival = map_root.find_child(point_name, true, false) as Node3D
	if not is_instance_valid(arrival) and point_name != DEFAULT_ARRIVAL:
		push_warning("MapTransition: Arrival point '%s' not found in %s, using SpawnPoint." % [point_name, map_root.name])
		arrival = map_root.get_node_or_null(NodePath(DEFAULT_ARRIVAL)) as Node3D
	return arrival
