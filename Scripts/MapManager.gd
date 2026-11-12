extends Node3D
class_name MapManager

## The main GridMap node
@export var dungeon_grid: GridMap
@export var floor_grid: GridMap
## Optional second floor layer named "Bridges" (same 2 m grid as FloorMap). A bridge tile
## over a river/water cell makes that cell walkable.
var bridge_grid: GridMap = null
@export var active_map_instance: Node3D
## DEV START map. Only used when "Dev Start Override" below is on; a normal game always
## begins on GameState.NEW_GAME_MAP (or wherever the save was made).
@export var default_map_scene: PackedScene
## DEV START switch. ON: running the project (in the editor) skips the main menu and drops the
## test party (Data/default_save.tres) on "Default Map Scene". OFF: the game starts at the main
## menu like it does for a player. Ignored in exported builds - those always start at the menu.
@export var dev_start_override: bool = false
@export var ceiling_tile_scene: PackedScene = preload("res://Scenes/CeilingTile.tscn") 
@export var ceiling_height: float = 2.0
@export var default_bgm_track: String = "Environment/forest-creepy"

@export var map_type: String = "forest"
@export var grid_map: GridMap

@export_group("Level Title")
## Seconds to wait after a map loads before showing the title banner.
@export var level_title_delay: float = 2.0
## Seconds the banner stays visible before fading out.
@export var level_title_hold: float = 3.0
## Pool for LevelTitleTrigger.play_new_area_sound — one is picked at random per map load.
@export var new_area_sounds: Array[AudioStream] = [
	preload("res://Audio/Environment/new-area.mp3"),
	preload("res://Audio/Environment/new-area-2.mp3"),
	preload("res://Audio/Environment/new-area-3.mp3"),
]

## Maps out standard cardinal direction vectors to help calculate steps.
const DIRECTION_MAP: Dictionary = {
	"NORTH": Vector3i(0, 0, -1),
	"SOUTH": Vector3i(0, 0, 1),
	"EAST": Vector3i(1, 0, 0),
	"WEST": Vector3i(-1, 0, 0)
}

const GROUP_LEVEL_TITLE: StringName = &"level_title"

var _blocked_tiles: Dictionary = {}
## [GridMap, cell] wall registrations received while a map is being added (see _install_map).
var _pending_grid_blocks: Array = []
var _is_installing_map: bool = false
var _level_title_token: int = 0
## Dev start: open default_map_scene instead of the normal start map.
var _use_dev_map: bool = false
## The world was opened without a session; the main menu is about to replace it.
var _leaving_for_menu: bool = false

## Runs before any _ready() in the world (HUD, Player), so the party is in place when they start.
func _enter_tree() -> void:
	_leaving_for_menu = false
	var dev_allowed: bool = dev_start_override and OS.has_feature("editor")
	if GameState.session_active:
		_use_dev_map = dev_allowed and GameState.dev_session
	elif dev_allowed:
		GameState.begin_dev_session()
		_use_dev_map = true
	else:
		# World opened without a session (e.g. "Run Current Scene" with dev start off): go to the menu.
		_leaving_for_menu = true
		get_tree().change_scene_to_file.call_deferred(SessionFlow.MAIN_MENU_SCENE)


func _ready() -> void:
	if _leaving_for_menu:
		return
	var start_map: PackedScene = default_map_scene if _use_dev_map and default_map_scene != null else load(GameState.NEW_GAME_MAP) as PackedScene
	var saved: Dictionary = GameState.consume_pending_location() if is_instance_valid(GameState) else {}
	var saved_path: String = str(saved.get("map_scene_path", ""))
	if not saved_path.is_empty() and ResourceLoader.exists(saved_path):
		# Continue a save: open the map the party was on, then put them back on their tile.
		switch_map(saved_path)
		_restore_saved_position.call_deferred(saved)
	elif start_map:
		if not saved_path.is_empty():
			push_warning("MapManager: saved map '%s' is missing - starting on the default map." % saved_path)
		switch_map_from_resource(start_map)
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

	_unload_active_map()
	_install_map(map_resource.instantiate() as Node3D)
	_sync_world_environment(active_map_instance)
	_notify_player_map_changed()
	_apply_map_audio(active_map_instance)
	_present_level_title(active_map_instance)


func switch_map(scene_path: String) -> void:
	var map_resource: PackedScene = load(scene_path) as PackedScene
	if not map_resource:
		push_error("MapManager: Failed to load map scene at " + scene_path)
		return

	_unload_active_map()
	_install_map(map_resource.instantiate() as Node3D)
	_sync_world_environment(active_map_instance)
	_notify_player_map_changed()
	GameLogger.info("SWITCH MAP FIRED. NOW STARTING AUDIO")
	_apply_map_audio(active_map_instance)
	_present_level_title(active_map_instance)


## Drops the previous map's WorldEnvironment immediately so outdoor (fog-off) settings
## cannot linger into the next map while queue_free is still pending.
func _unload_active_map() -> void:
	if not is_instance_valid(active_map_instance):
		return
	# Stop outdoor day/night before the map is freed — it was retargeted at the root
	# WorldEnvironment and would keep rewriting ambient (and fight the next map's fog).
	for child: Node in active_map_instance.get_children():
		if child is DayNightCycle:
			var cycle: DayNightCycle = child as DayNightCycle
			cycle.set_process(false)
			cycle.world_environment = null
	var old_we: WorldEnvironment = _find_world_environment(active_map_instance)
	if is_instance_valid(old_we):
		active_map_instance.remove_child(old_we)
		old_we.free()
	active_map_instance.queue_free()
	active_map_instance = null
	bridge_grid = null
	floor_grid = null
	dungeon_grid = null


## Godot only allows one WorldEnvironment in the active tree. world.tscn already has one, so
## map fog/sky was losing to the root (or to a second empty map WE after a null-out). Copy the
## map Environment onto the root, then remove the map-local WorldEnvironment entirely.
func _sync_world_environment(map_instance: Node3D) -> void:
	var root: Node = get_tree().current_scene
	if not is_instance_valid(root):
		return
	var root_we: WorldEnvironment = root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var map_we: WorldEnvironment = _find_world_environment(map_instance)
	if not is_instance_valid(map_we) or map_we.environment == null:
		return
	if is_instance_valid(root_we):
		# Duplicate so DayNightCycle / unload can't mutate the packed scene SubResource, and so
		# freeing the map WE never drops the active fog/sky settings.
		root_we.environment = map_we.environment.duplicate() as Environment
	map_instance.remove_child(map_we)
	map_we.free()
	# Day/night on outdoor maps still holds a NodePath to the (now-gone) map WE — re-point it.
	_retarget_day_night_environment(map_instance, root_we)


func _find_world_environment(host: Node) -> WorldEnvironment:
	if not is_instance_valid(host):
		return null
	for child: Node in host.get_children():
		if child is WorldEnvironment:
			return child as WorldEnvironment
	return null


func _retarget_day_night_environment(map_instance: Node3D, root_we: WorldEnvironment) -> void:
	if not is_instance_valid(map_instance) or not is_instance_valid(root_we):
		return
	for child: Node in map_instance.get_children():
		if child is DayNightCycle:
			(child as DayNightCycle).world_environment = root_we


func _restore_saved_position(saved: Dictionary) -> void:
	var player: DungeonPlayer = get_tree().get_first_node_in_group(&"player") as DungeonPlayer
	if not is_instance_valid(player):
		return
	# New game: start on a named marker (e.g. GreenGrove's SpawnPointNewGame) instead of a saved cell.
	var marker_name: String = str(saved.get("spawn_marker", ""))
	if not marker_name.is_empty():
		var marker: Node3D = active_map_instance.get_node_or_null(NodePath(marker_name)) as Node3D if is_instance_valid(active_map_instance) else null
		if marker != null:
			player.move_to_marker(marker)
		else:
			push_warning("MapManager: spawn marker '%s' not found - using the map's SpawnPoint." % marker_name)
		return
	player.restore_location(saved.get("player_cell", Vector2i.ZERO) as Vector2i, str(saved.get("player_facing", "NORTH")))


## Adds a freshly instanced map and resolves its grids. Wall layers register their blocked cells in
## their own _ready() (during add_child) - BEFORE this map's FloorMap is known - so those registrations
## are queued and converted to nav cells only once the grids are resolved. (Converting them early used
## the previous map's FloorMap, or none at all on the first map, which blocked random "invisible" tiles.)
func _install_map(map_instance: Node3D) -> void:
	_blocked_tiles.clear()
	_pending_grid_blocks.clear()
	_is_installing_map = true
	active_map_instance = map_instance
	add_child(active_map_instance)
	_resolve_dungeon_grid(active_map_instance)
	_is_installing_map = false
	for pending: Array in _pending_grid_blocks:
		if is_instance_valid(pending[0]):
			register_blocked_grid_cell(pending[0] as GridMap, pending[1] as Vector3i)
	_pending_grid_blocks.clear()


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

	# Resolve optional Bridges layer (bridges over FloorMap water)
	if map_instance.has_node("%Bridges"):
		bridge_grid = map_instance.get_node("%Bridges") as GridMap
	elif map_instance.has_node("Bridges"):
		bridge_grid = map_instance.get_node("Bridges") as GridMap
	else:
		bridge_grid = null

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


## Shows the map's level title once after a short delay. Cancels any prior in-flight title.
func _present_level_title(map_instance: Node3D) -> void:
	_level_title_token += 1
	var token: int = _level_title_token
	_present_level_title_async(map_instance, token)


func _present_level_title_async(map_instance: Node3D, token: int) -> void:
	if not is_instance_valid(map_instance):
		return

	var marker: Node = _find_level_title_marker(map_instance)
	var title_text: String = map_instance.name
	var play_sound: bool = true
	if is_instance_valid(marker):
		if "level_title" in marker and not str(marker.get("level_title")).strip_edges().is_empty():
			title_text = str(marker.get("level_title"))
		if "play_new_area_sound" in marker:
			play_sound = bool(marker.get("play_new_area_sound"))

	if level_title_delay > 0.0:
		await get_tree().create_timer(level_title_delay).timeout
	if token != _level_title_token or not is_instance_valid(map_instance) or map_instance != active_map_instance:
		return

	var hud: Node = _find_level_hud_label()
	if is_instance_valid(hud) and hud.has_method("show_level_banner"):
		hud.call("show_level_banner", title_text)

	if play_sound:
		_play_level_title_sound(_pick_new_area_sound())

	if level_title_hold > 0.0:
		await get_tree().create_timer(level_title_hold).timeout
	if token != _level_title_token:
		return

	if is_instance_valid(hud) and hud.has_method("hide_level_banner"):
		hud.call("hide_level_banner")


func _find_level_title_marker(map_instance: Node3D) -> Node:
	if not is_instance_valid(map_instance):
		return null
	for node: Node in get_tree().get_nodes_in_group(GROUP_LEVEL_TITLE):
		if is_instance_valid(node) and (map_instance.is_ancestor_of(node) or node == map_instance):
			return node
	return _find_level_title_marker_recursive(map_instance)


func _find_level_title_marker_recursive(node: Node) -> Node:
	if "level_title" in node and node != active_map_instance:
		return node
	for child: Node in node.get_children():
		var found: Node = _find_level_title_marker_recursive(child)
		if is_instance_valid(found):
			return found
	return null


func _find_level_hud_label() -> Node:
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if is_instance_valid(player):
		var under_player: Node = player.find_child("LevelHUDLabel", true, false)
		if is_instance_valid(under_player):
			return under_player
	return get_tree().root.find_child("LevelHUDLabel", true, false)


func _pick_new_area_sound() -> AudioStream:
	var pool: Array[AudioStream] = []
	for stream: AudioStream in new_area_sounds:
		if stream != null:
			pool.append(stream)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


func _play_level_title_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	var audio_player := AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.stream = stream
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)


# ==============================================================================
# NAVIGATION GRID
# Movement, enemy positions and blocked tiles all use ONE grid: the map's FloorMap
# (always the 2 m player grid), or the dungeon GridMap when there is no FloorMap.
# Wall layers (WallMap, WallMap2...) may be scaled/offset freely; they are converted
# to navigation cells through world positions.
# ==============================================================================
func get_nav_grid() -> GridMap:
	if is_instance_valid(floor_grid):
		return floor_grid
	return dungeon_grid


## World position of a navigation cell's center. Height follows the cell-centered
## convention (half a cell above the floor) so existing enemy vertical_offsets are unchanged.
func nav_cell_to_world(cell: Vector3i) -> Vector3:
	var grid: GridMap = get_nav_grid()
	if not is_instance_valid(grid):
		return Vector3(cell.x * 2.0 + 1.0, 1.0, cell.z * 2.0 + 1.0)
	var local_pos: Vector3 = grid.map_to_local(cell)
	if not grid.cell_center_y:
		local_pos.y += grid.cell_size.y * 0.5
	return grid.to_global(local_pos)


## Converts a cell of ANY GridMap (e.g. a scaled WallMap) into the navigation cell under its center.
func grid_cell_to_nav_cell(grid: GridMap, cell: Vector3i) -> Vector3i:
	var nav: GridMap = get_nav_grid()
	if not is_instance_valid(grid) or grid == nav:
		return Vector3i(cell.x, 0, cell.z)
	var world: Vector3 = grid.to_global(grid.map_to_local(cell))
	var nav_cell: Vector3i = world_to_grid(world)
	return Vector3i(nav_cell.x, 0, nav_cell.z)


## Converts a navigation cell into the matching cell of another GridMap (e.g. a scaled WallMap).
func nav_cell_to_grid_cell(grid: GridMap, nav_cell: Vector3i) -> Vector3i:
	var nav: GridMap = get_nav_grid()
	if not is_instance_valid(grid) or not is_instance_valid(nav) or grid == nav:
		return Vector3i(nav_cell.x, 0, nav_cell.z)
	var world: Vector3 = nav.to_global(nav.map_to_local(Vector3i(nav_cell.x, 0, nav_cell.z)))
	var local: Vector3 = grid.to_local(world)
	var cell: Vector3i = grid.local_to_map(local)
	return Vector3i(cell.x, 0, cell.z)


## Blocks every navigation cell covered by `cell` of `grid` (handles scaled wall layers).
func register_blocked_grid_cell(grid: GridMap, cell: Vector3i) -> void:
	if _is_installing_map:
		_pending_grid_blocks.append([grid, cell]) # converted once the new map's FloorMap is resolved
		return
	var nav: GridMap = get_nav_grid()
	if not is_instance_valid(grid) or not is_instance_valid(nav) or grid == nav:
		register_blocked_tile(Vector3i(cell.x, 0, cell.z))
		return

	var center: Vector3 = grid.to_global(grid.map_to_local(cell))
	var grid_scale: Vector3 = grid.global_basis.get_scale()
	var half: Vector3 = grid.cell_size * grid_scale * 0.5
	var lo: Vector3i = world_to_grid(center - half)
	var hi: Vector3i = world_to_grid(center + half)
	var any: bool = false
	for x in range(mini(lo.x, hi.x), maxi(lo.x, hi.x) + 1):
		for z in range(mini(lo.z, hi.z), maxi(lo.z, hi.z) + 1):
			var nav_center: Vector3 = nav.to_global(nav.map_to_local(Vector3i(x, 0, z)))
			if absf(nav_center.x - center.x) <= half.x + 0.01 and absf(nav_center.z - center.z) <= half.z + 0.01:
				register_blocked_tile(Vector3i(x, 0, z))
				any = true
	if not any:
		register_blocked_tile(grid_cell_to_nav_cell(grid, cell))


## Converts an absolute 3D world position into navigation grid coordinates.
func world_to_grid(world_position: Vector3) -> Vector3i:
	var grid: GridMap = get_nav_grid()
	if not is_instance_valid(grid):
		return Vector3i.ZERO
	return grid.local_to_map(grid.to_local(world_position))


## Converts navigation grid coordinates back into absolute 3D world positions.
func grid_to_world(grid_position: Vector3i) -> Vector3:
	if not is_instance_valid(get_nav_grid()):
		return Vector3.ZERO
	return nav_cell_to_world(grid_position)


## Checks if a target grid cell contains a blocking wall tile, water, enemy, or 3D physics obstacle.
func is_tile_blocked(grid_position: Vector3i) -> bool:
	return not get_tile_block_reason(grid_position).is_empty()


## Why a tile can't be entered ("" = walkable). Used for movement and for the [NAV] log, e.g.
## "wall tile 'forest_wall' on WallMap", "physics: BigTimbers/BigTimber5 (StaticBody3D)".
func get_tile_block_reason(grid_position: Vector3i) -> String:
	if _blocked_tiles.get(grid_position, false):
		return "tile marked blocked (MapManager._blocked_tiles)"

	var ground_cell := Vector3i(grid_position.x, 0, grid_position.z)

	# 1. Check WallMap for trees or walls
	if is_instance_valid(dungeon_grid):
		var wall_cell: Vector3i = nav_cell_to_grid_cell(dungeon_grid, ground_cell)
		var wall_item_index: int = dungeon_grid.get_cell_item(wall_cell)
		if wall_item_index != GridMap.INVALID_CELL_ITEM:
			var wall_item_name: String = dungeon_grid.mesh_library.get_item_name(wall_item_index) if is_instance_valid(dungeon_grid.mesh_library) else str(wall_item_index)
			if dungeon_grid.name == "WallMap" or dungeon_grid.name == "%WallMap":
				return "wall tile '%s' on %s cell %s" % [wall_item_name, dungeon_grid.name, wall_cell]
			var lower_name: String = wall_item_name.to_lower()
			if lower_name.contains("wall") or lower_name.contains("placeholder"):
				return "wall tile '%s' on %s cell %s" % [wall_item_name, dungeon_grid.name, wall_cell]

	# 2. Check FloorMap for river/water tiles
	if is_instance_valid(floor_grid):
		var floor_item_index: int = floor_grid.get_cell_item(ground_cell)
		if floor_item_index != GridMap.INVALID_CELL_ITEM and is_instance_valid(floor_grid.mesh_library):
			var floor_item_name: String = floor_grid.mesh_library.get_item_name(floor_item_index).to_lower()
			if floor_item_name.contains("river") or floor_item_name.contains("water"):
				if not _has_bridge(ground_cell):
					return "water tile '%s' on %s (no bridge)" % [floor_item_name, floor_grid.name]

	# 3. Check for dynamic enemies
	var enemy: Node3D = get_enemy_at_grid_pos(grid_position)
	if is_instance_valid(enemy):
		return "enemy %s" % _describe_node(enemy)

	# 4. Check for blocking interactable objects
	var interactable: DungeonInteractable = get_interactable_at_grid_pos(grid_position)
	if is_instance_valid(interactable) and interactable.is_blocking:
		return "interactable %s (is_blocking)" % _describe_node(interactable)

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
		for hit: Dictionary in hits:
			var collider: Object = hit.get("collider")
			if collider == floor_grid or (bridge_grid != null and collider == bridge_grid):
				continue
			if collider is Node and (collider as Node).is_in_group(&"player"):
				continue
			return "physics: %s" % _describe_node(collider as Node)

	return ""


## "BigTimbers/BigTimber5/StaticBody3D (StaticBody3D)" - path inside the active map when possible.
func _describe_node(node: Node) -> String:
	if not is_instance_valid(node):
		return "<freed>"
	var path: String = str(active_map_instance.get_path_to(node)) if is_instance_valid(active_map_instance) and active_map_instance.is_ancestor_of(node) else str(node.get_path())
	return "%s (%s)" % [path, node.get_class()]


## True when the Bridges layer has a tile on this ground cell.
func _has_bridge(ground_cell: Vector3i) -> bool:
	return is_instance_valid(bridge_grid) and bridge_grid.get_cell_item(ground_cell) != GridMap.INVALID_CELL_ITEM


## Public: party is standing on (or stepping onto) a Bridges-layer tile.
func is_bridge_at(ground_cell: Vector3i) -> bool:
	return _has_bridge(ground_cell)


## MeshLibrary item name for the Bridges tile at this cell, or "" if none.
func get_bridge_item_name(ground_cell: Vector3i) -> String:
	if not _has_bridge(ground_cell):
		return ""
	var mesh_library: MeshLibrary = bridge_grid.mesh_library
	if not is_instance_valid(mesh_library):
		return ""
	var item_id: int = bridge_grid.get_cell_item(ground_cell)
	return mesh_library.get_item_name(item_id)


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

		if spawn_node and is_instance_valid(get_nav_grid()):
			var map_pos: Vector3i = world_to_grid(spawn_node.global_position)
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
