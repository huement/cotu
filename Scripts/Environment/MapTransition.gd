class_name MapTransition
extends RefCounted
## Moves the party between sub-maps through MapManager (e.g. GloomReach <-> cave levels).
## The world scene (Player, HUD, MapManager) stays loaded; only the active map is swapped.

const DEFAULT_ARRIVAL: String = "SpawnPoint"

## One-shot "come back here" for test areas (debug menu > BATTLE TEST ARENA): while the party is in
## `_return_from`, ANY exit (stairs, crypt hole, gate...) takes it back to `_return_to` instead of the
## exit's own target. Cleared once used, or when the party ends up anywhere else.
static var _return_from: String = ""
static var _return_to: Dictionary = {}


## `location` is a GameState.capture_location() dictionary (map_scene_path, player_cell, player_facing).
static func set_return_point(from_scene: String, location: Dictionary) -> void:
	_return_from = from_scene
	_return_to = location.duplicate()


static func clear_return_point() -> void:
	_return_from = ""
	_return_to = {}


static func has_return_point() -> bool:
	return not _return_to.is_empty()


## Swaps the active map to `scene_path` and puts the party on the marker named
## `arrival_point_name` (a Node3D in the target map). The marker's -Z axis is the
## direction the party will face. Falls back to the map's SpawnPoint.
## Autosaves after arriving (outside battle), so a reload / game over resumes at the map entrance.
static func travel(tree: SceneTree, scene_path: String, arrival_point_name: String = DEFAULT_ARRIVAL) -> bool:
	if has_return_point():
		if _current_map_path(tree) == _return_from:
			return _travel_back(tree)
		clear_return_point() # left the test area some other way
	var ok: bool = _travel(tree, scene_path, arrival_point_name)
	if ok and is_instance_valid(GameState) and not SessionFlow.is_in_battle():
		GameState.save_game()
	return ok


static func _travel(tree: SceneTree, scene_path: String, arrival_point_name: String) -> bool:
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
	# Arrival markers carry per-map eye_height (GreenGrove / FeroShaw use 1.0; dungeons 1.5).
	# refresh_for_new_map() only sees a node literally named "SpawnPoint", so re-apply from arrival.
	player.apply_eye_height_from(arrival)
	return true


static func _current_map_path(tree: SceneTree) -> String:
	var map_mgr: MapManager = tree.root.find_child("MapManager", true, false) as MapManager
	if is_instance_valid(map_mgr) and is_instance_valid(map_mgr.active_map_instance):
		return map_mgr.active_map_instance.scene_file_path
	return ""


## Returns the party to the saved return point (exact tile + facing), then autosaves there.
static func _travel_back(tree: SceneTree) -> bool:
	var loc: Dictionary = _return_to
	clear_return_point()
	var map_mgr: MapManager = tree.root.find_child("MapManager", true, false) as MapManager
	var path: String = str(loc.get("map_scene_path", ""))
	if not is_instance_valid(map_mgr) or path.is_empty() or not ResourceLoader.exists(path):
		return false
	map_mgr.switch_map(path)
	var player: DungeonPlayer = tree.get_first_node_in_group(&"player") as DungeonPlayer
	if is_instance_valid(player) and loc.has("player_cell"):
		player.restore_location(loc["player_cell"] as Vector2i, str(loc.get("player_facing", "NORTH")))
	if is_instance_valid(GameState) and not SessionFlow.is_in_battle():
		GameState.save_game()
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
