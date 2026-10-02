extends Node3D
class_name DungeonPlayer

## Cardinal direction state tracking for retro grid exploration.
enum Facing {
	NORTH,
	WEST,
	SOUTH,
	EAST,
}

@onready var camera: Camera3D = $Camera3D as Camera3D
@onready var grid_movement: GridMovementComponent = %GridMovementComponent as GridMovementComponent
@export var initial_cell: Vector2i = Vector2i(2, 1)
@export var initial_facing: Facing = Facing.NORTH
@export var use_editor_spawn: bool = false
@export var movement_duration: float = 0.2
@export var rotation_duration: float = 0.15
@export var eye_height: float = 2
@export var max_shake_offset: Vector3 = Vector3(0.15, 0.15, 0.05)
@export var shake_decay: float = 3.0
@export var back_hold_to_turn_duration: float = 0.4 # How long to hold back to trigger a 180 turn.

# -- Back Button Hold-to-Turn State --
var _is_back_held: bool = false
var _back_held_start_time: float = 0.0
var _back_turn_triggered: bool = false
# ------------------------------------

var _trauma: float = 0.0

#var grid_map: GridMap
var grid_map: GridMap
var map_manager: MapManager

var current_grid_pos: Vector2i = Vector2i.ZERO
var current_facing: Facing = Facing.NORTH
var is_moving: bool = false
var _is_in_combat: bool = false

var _last_proximity_tier: int = 0

func _ready() -> void:
	add_to_group(&"player") # Ensures WorldEnemy can locate player's current_grid_pos
	call_deferred("_initialize_player")
	_connect_to_signal_bus()

	if is_instance_valid(grid_movement):
		grid_movement.step_completed.connect(_on_component_step_completed)
		grid_movement.turn_completed.connect(_on_component_turn_completed)


func _connect_to_signal_bus() -> void:
	var sb: Node = SignalBus
	if is_instance_valid(sb):
		if not sb.combat_started.is_connected(_on_combat_started):
			sb.combat_started.connect(_on_combat_started)
		if not sb.combat_ended.is_connected(_on_combat_ended):
			sb.combat_ended.connect(_on_combat_ended)
		if not sb.camera_shake_requested.is_connected(add_trauma):
			sb.camera_shake_requested.connect(add_trauma)


func _initialize_player() -> void:
	var world_root: Node3D = get_parent() as Node3D
	map_manager = world_root.get_node_or_null("MapManager") as MapManager

	# 1. Resolve GridMap across all scene structures
	grid_map = world_root.get_node_or_null("GridMap") as GridMap
	if not grid_map:
		grid_map = world_root.get_node_or_null("FloorMap") as GridMap
	if not grid_map and map_manager and is_instance_valid(map_manager.dungeon_grid):
		grid_map = map_manager.dungeon_grid
	if not grid_map and map_manager and is_instance_valid(map_manager.floor_grid):
		grid_map = map_manager.floor_grid
	if not grid_map and map_manager and is_instance_valid(map_manager.active_map_instance):
		var active_map: Node3D = map_manager.active_map_instance
		if active_map is GridMap:
			grid_map = active_map as GridMap
		else:
			grid_map = active_map.get_node_or_null("%FloorMap") as GridMap
			if not grid_map:
				grid_map = active_map.get_node_or_null("%WallMap") as GridMap
			if not grid_map:
				grid_map = active_map.get_node_or_null("FloorMap") as GridMap
			if not grid_map:
				grid_map = active_map.get_node_or_null("GridMap") as GridMap

	# Fallback search if GridMap is nested or named differently
	if not grid_map:
		var found_gridmaps: Array[Node] = world_root.find_children("*", "GridMap", true, false)
		if not found_gridmaps.is_empty():
			grid_map = found_gridmaps[0] as GridMap

	# Guard: Stop early if no GridMap node is present in the scene tree
	if not is_instance_valid(grid_map):
		push_error("Player: GridMap could not be resolved from World or MapManager!")
		return

	# TEMPORARY FALLBACK: Hardcoded BGM playback for testing.
	if is_instance_valid(AudioManager):
		AudioManager.play_bgm("Environment/forest-creepy")

	# Resolve spawn position AND facing angle from SpawnPoint node first
	var spawn_point: Node3D = null
	if map_manager and is_instance_valid(map_manager.active_map_instance):
		spawn_point = map_manager.active_map_instance.get_node_or_null("SpawnPoint") as Node3D
	else:
		spawn_point = world_root.get_node_or_null("SpawnPoint") as Node3D

	if spawn_point:
		current_grid_pos = _world_to_cell(spawn_point.global_position)
		current_facing = _angle_to_facing(spawn_point.global_rotation_degrees.y)
	elif use_editor_spawn:
		current_grid_pos = _world_to_cell(global_position)
		current_facing = _angle_to_facing(global_rotation_degrees.y)
	else:
		current_grid_pos = initial_cell
		current_facing = initial_facing

	_apply_canonical_transform()
	_eye_height_setup(spawn_point, world_root)


# Determine eye height dynamically per map (checking metadata AND script properties)
func _eye_height_setup(spawn_point: Node3D, world_root: Node3D) -> void:
	var active_height: float = eye_height # Default fallback
	if spawn_point:
		if spawn_point.has_meta("eye_height"):
			active_height = float(spawn_point.get_meta("eye_height"))
		elif "eye_height" in spawn_point:
			active_height = float(spawn_point.get("eye_height"))
	elif map_manager and is_instance_valid(map_manager.active_map_instance):
		var active_map: Node3D = map_manager.active_map_instance
		if active_map.has_meta("eye_height"):
			active_height = float(active_map.get_meta("eye_height"))
		elif "eye_height" in active_map:
			active_height = float(active_map.get("eye_height"))
	elif world_root.has_meta("eye_height"):
		active_height = float(world_root.get_meta("eye_height"))

	GameLogger.info("Player: SpawnPoint eye_height: %s" % active_height)
	camera.position = Vector3(0.0, active_height, 0.0)
	camera.rotation_degrees = Vector3.ZERO
	camera.make_current()


func _physics_process(_delta: float) -> void:
	if not grid_map:
		return

	rotation_degrees.x = 0.0
	rotation_degrees.z = 0.0
	if not is_moving:
		_apply_canonical_transform()


func _process(delta: float) -> void:
	# -- NEW: Check for holding the back button to trigger a 180-degree turn --
	if _is_back_held and not _back_turn_triggered:
		var hold_time: float = (Time.get_ticks_msec() - _back_held_start_time) / 1000.0
		if hold_time >= back_hold_to_turn_duration:
			_back_turn_triggered = true
			# Prevent the release from also firing a step-back command
			_is_back_held = false
			
			if is_instance_valid(AudioManager) and AudioManager.has_method("play_turn_around_sound"):
				AudioManager.play_turn_around_sound()
			grid_movement.try_turn(self, 180.0)
	# -------------------------------------------------------------------------

	if _trauma > 0.0:
		_trauma = lerpf(_trauma, 0.0, shake_decay * delta)
		var shake_power: float = _trauma * _trauma
		
		var offset: Vector3 = max_shake_offset
		offset.x *= shake_power * randf_range(-1.0, 1.0)
		offset.y *= shake_power * randf_range(-1.0, 1.0)
		offset.z *= shake_power * randf_range(-1.0, 1.0)
		
		camera.h_offset = offset.x
		camera.v_offset = offset.y
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


# ==============================================================================
# MOVEMENT & INPUT HANDLING MAIN
# ==============================================================================
func _input(event: InputEvent) -> void:
	# 🛑 LOCKOUT GUARD: Block forward, strafe, backward, and turning while in combat
	if _is_in_combat or not is_instance_valid(grid_movement) or grid_movement.is_moving:
		return

	# / Key or "interact" action checks the tile directly in front of the player
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SLASH):
		_try_interact_facing_tile()
		return

	# --- Simplified Hold-to-Turn Input Handling ---
	if event.is_action_pressed("move_backward"):
		# A turn may have already been triggered by _process if the button was held long enough.
		# In that case, _back_turn_triggered would be true. We reset for a new press.
		_is_back_held = true
		_back_held_start_time = Time.get_ticks_msec()
		_back_turn_triggered = false
		return

	if event.is_action_released("move_backward"):
		# If the button is released and a turn hasn't happened, it was a tap. Step back.
		if _is_back_held and not _back_turn_triggered:
			grid_movement.try_step(self, Vector3.BACK, _get_cardinal_string())
		
		# Reset state for the next press cycle
		_is_back_held = false
		_back_turn_triggered = false
		return
	# ---------------------------------------------

	if event.is_action_pressed("move_forward"):
		grid_movement.try_step(self, Vector3.FORWARD, _get_cardinal_string())
	elif event.is_action_pressed("strafe_left"):
		grid_movement.try_step(self, Vector3.LEFT, _get_cardinal_string())
	elif event.is_action_pressed("strafe_right"):
		grid_movement.try_step(self, Vector3.RIGHT, _get_cardinal_string())
	elif event.is_action_pressed("turn_left"):
		grid_movement.try_turn(self, 90.0)
	elif event.is_action_pressed("turn_right"):
		grid_movement.try_turn(self, -90.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_M: # Press 'M' to switch between Main Dungeon and Testbed
				if map_manager:
					var testbed_scene: PackedScene = load("res://Scenes/dungeon_testbed.tscn")
					map_manager.switch_map_from_resource(testbed_scene)
					grid_map = map_manager.dungeon_grid
					print("Map swapped to Testbed!")
			KEY_T: # Press 'T' to test FIRE VFX & Shake
				SignalBus.camera_shake_requested.emit(0.5)
				SignalBus.edge_flash_requested.emit(Color(0.15, 1.0, 0.15), 0.35)
			KEY_Y: # Press 'Y' to test WATER VFX & Shake
				SignalBus.camera_shake_requested.emit(1)
				SignalBus.edge_flash_requested.emit(Color(1.0, 0.15, 0.15), 0.95)


# ==============================================================================
# COMBAT SIGNAL CALLBACKS
# ==============================================================================
## 🎯 Updated parameter to Variant to accept both single resources and enemy arrays
func _on_combat_started(_enemy_data_or_group: Variant, _player_party: Array, _enemy_facing: String) -> void:
	_is_in_combat = true


func _on_combat_ended(_victory: bool) -> void:
	_is_in_combat = false


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


# ==============================================================================
# MOVEMENT HELPERS
# ==============================================================================
func _get_movement_offset(input_direction: Vector3) -> Vector2i:
	var forward_vector: Vector2i = Vector2i.ZERO
	var right_vector: Vector2i = Vector2i.ZERO

	match current_facing:
		Facing.NORTH:
			forward_vector = Vector2i(0, -1)
			right_vector = Vector2i(1, 0)
		Facing.WEST:
			forward_vector = Vector2i(-1, 0)
			right_vector = Vector2i(0, -1)
		Facing.SOUTH:
			forward_vector = Vector2i(0, 1)
			right_vector = Vector2i(-1, 0)
		Facing.EAST:
			forward_vector = Vector2i(1, 0)
			right_vector = Vector2i(0, 1)

	if input_direction == Vector3.FORWARD:
		return forward_vector
	if input_direction == Vector3.BACK:
		return -forward_vector
	if input_direction == Vector3.RIGHT:
		return right_vector
	if input_direction == Vector3.LEFT:
		return -right_vector
	return Vector2i.ZERO


func _execute_grid_step(input_direction: Vector3) -> void:
	var coordinate_offset: Vector2i = _get_movement_offset(input_direction)
	var target_grid_pos: Vector2i = current_grid_pos + coordinate_offset
	var target_grid_3d: Vector3i = Vector3i(target_grid_pos.x, 0, target_grid_pos.y)

	if _is_cell_blocked(target_grid_3d):
		# 🎯 BUMP ENCOUNTER: Check if the blocking tile contains a WorldEnemy!
		if is_instance_valid(map_manager) and map_manager.has_method("get_enemy_at_grid_pos"):
			var enemy_node: Node3D = map_manager.get_enemy_at_grid_pos(target_grid_3d) as Node3D
			if is_instance_valid(enemy_node) and enemy_node.has_method("trigger_combat_encounter"):
				enemy_node.call("trigger_combat_encounter")
				return

		print("Movement blocked by structural layout block.")
		return

	is_moving = true

	var target_world_pos: Vector3 = _cell_to_world(target_grid_pos)
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", target_world_pos, movement_duration) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	current_grid_pos = target_grid_pos
	_apply_canonical_transform()
	is_moving = false

	if is_instance_valid(SignalBus):
		SignalBus.party_moved.emit(Vector3i(current_grid_pos.x, 0, current_grid_pos.y), _get_cardinal_string())

	_on_grid_step_completed()


func _execute_grid_rotation(angle_offset: float) -> void:
	is_moving = true

	var target_rotation: float = rotation_degrees.y + angle_offset
	var tween: Tween = create_tween()
	tween.tween_property(self, "rotation_degrees:y", target_rotation, rotation_duration) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	rotation_degrees.y = wrapf(rotation_degrees.y, 0.0, 360.0)
	var rounded_angle: int = roundi(rotation_degrees.y)

	match rounded_angle:
		0, 360:
			current_facing = Facing.NORTH
		90:
			current_facing = Facing.WEST
		180:
			current_facing = Facing.SOUTH
		270:
			current_facing = Facing.EAST

	is_moving = false


func _apply_canonical_transform() -> void:
	global_position = _cell_to_world(current_grid_pos)
	rotation_degrees.x = 0.0
	rotation_degrees.z = 0.0
	rotation_degrees.y = _facing_to_angle(current_facing)


func _facing_to_angle(facing: Facing) -> float:
	match facing:
		Facing.NORTH: return 0.0
		Facing.WEST: return 90.0
		Facing.SOUTH: return 180.0
		Facing.EAST: return 270.0
	return 0.0


func _angle_to_facing(angle_deg: float) -> Facing:
	var wrapped: float = wrapf(angle_deg, 0.0, 360.0)
	var rounded: int = roundi(wrapped)
	match rounded:
		0, 360: return Facing.NORTH
		90: return Facing.WEST
		180: return Facing.SOUTH
		270: return Facing.EAST
		_:
			var quadrant: int = posmod(roundi(angle_deg / 90.0), 4)
			match quadrant:
				0: return Facing.NORTH
				1: return Facing.WEST
				2: return Facing.SOUTH
				3: return Facing.EAST
	return Facing.NORTH


func _cell_to_world(cell: Vector2i) -> Vector3:
	if not is_instance_valid(grid_map):
		return Vector3(cell.x * 2.0, 0.0, cell.y * 2.0)
	var local_pos: Vector3 = grid_map.map_to_local(Vector3i(cell.x, 0, cell.y))
	local_pos.y = 0.0
	return grid_map.to_global(local_pos)


func _world_to_cell(world_pos: Vector3) -> Vector2i:
	if not is_instance_valid(grid_map):
		return Vector2i.ZERO
	var local_pos: Vector3 = grid_map.to_local(world_pos)
	var map_pos: Vector3i = grid_map.local_to_map(local_pos)
	return Vector2i(map_pos.x, map_pos.z)


func _is_cell_blocked(grid_pos: Vector3i) -> bool:
	# 1. Check if MapManager or GridMap reports a structural wall tile
	if map_manager and map_manager.is_tile_blocked(grid_pos):
		return true

	if is_instance_valid(grid_map):
		var item_index: int = grid_map.get_cell_item(grid_pos)
		if item_index != GridMap.INVALID_CELL_ITEM:
			return true

	# 2. 3D Physics Volume Query: Detect instantiated StaticBody3D obstacles (BigTimber trees, props)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space_state:
		return false

	var target_world_pos: Vector3 = _cell_to_world(Vector2i(grid_pos.x, grid_pos.z))

	var shape_query := PhysicsShapeQueryParameters3D.new()
	var box_shape := BoxShape3D.new()
	# Check a 1.6 x 2.0 x 1.6 volume centered in the target cell
	box_shape.size = Vector3(1.6, 2.0, 1.6)
	shape_query.shape = box_shape
	shape_query.transform = Transform3D(Basis.IDENTITY, target_world_pos + Vector3(0.0, 1.0, 0.0))
	shape_query.collision_mask = 1 # Layer 1 for StaticBody3D objects

	var hits: Array[Dictionary] = space_state.intersect_shape(shape_query)
	for hit: Dictionary in hits:
		var collider: Object = hit.get("collider")
		if collider and collider != self:
			return true

	return false


func _get_cardinal_string() -> String:
	match current_facing:
		Facing.NORTH:
			return "NORTH"
		Facing.WEST:
			return "WEST"
		Facing.SOUTH:
			return "SOUTH"
		Facing.EAST:
			return "EAST"
	return "NORTH"


## Evaluates whether a living enemy is in an adjacent cardinal grid cell.
func _is_enemy_adjacent() -> bool:
	var enemies_container: Node = get_node_or_null("../Enemies")
	if not is_instance_valid(enemies_container):
		return false

	var step_size: float = grid_map.cell_size.x if is_instance_valid(grid_map) else 2.0
	var player_pos: Vector3 = global_position

	for child: Node in enemies_container.get_children():
		var enemy_node: Node3D = child as Node3D
		if not is_instance_valid(enemy_node) or not enemy_node.visible:
			continue

		var offset: Vector3 = enemy_node.global_position - player_pos
		var abs_x: float = absf(offset.x)
		var abs_z: float = absf(offset.z)

		var is_adjacent_x: bool = absf(abs_x - step_size) < 0.4 and abs_z < 0.4
		var is_adjacent_z: bool = absf(abs_z - step_size) < 0.4 and abs_x < 0.4

		if is_adjacent_x or is_adjacent_z:
			return true

	return false


## Called when the player finishes stepping to a new grid cell
func _on_component_step_completed(world_position: Vector3) -> void:
	var grid_3d: Vector3i = Vector3i.ZERO
	if map_manager:
		grid_3d = map_manager.world_to_grid(world_position)
		current_grid_pos = Vector2i(grid_3d.x, grid_3d.z)

	if is_instance_valid(SignalBus):
		SignalBus.party_moved.emit(Vector3i(current_grid_pos.x, 0, current_grid_pos.y), _get_cardinal_string())

	_on_grid_step_completed(grid_3d)


## Called when the player finishes stepping to a new grid cell
func _on_grid_step_completed(grid_3d: Vector3i = Vector3i.ZERO) -> void:
	# 1. Detect surface and play dynamic footstep sound
	if is_instance_valid(AudioManager):
		var current_map_type: String = map_manager.get_current_map_type() if is_instance_valid(map_manager) else "dungeon"
		var surface_type: String = _get_surface_type_at_position(grid_3d)
		AudioManager.play_walking_sound(current_map_type, surface_type)

	# 2. Check nearby enemy distance and evaluate proximity alerts
	_check_enemy_proximity()

	if _is_enemy_adjacent():
		GameLogger.combat("_is_enemy_adjacent")
		SignalBus.edge_flash_requested.emit(Color(1.0, 0.15, 0.15), 0.35)


func _on_step_completed(target_grid_pos: Vector3i) -> void:
	var map_type: String = map_manager.get_current_map_type() if map_manager else "dungeon"
	var surface_type: String = _get_surface_type_at_position(target_grid_pos)
	GameLogger.info("_on_step_completed surface_type: " + surface_type	)
	AudioManager.play_walking_sound(map_type, surface_type)


func _on_component_turn_completed(_direction: Vector3) -> void:
	var rounded_angle: int = roundi(wrapf(rotation_degrees.y, 0.0, 360.0))
	match rounded_angle:
		0, 360:
			current_facing = Facing.NORTH
		90:
			current_facing = Facing.WEST
		180:
			current_facing = Facing.SOUTH
		270:
			current_facing = Facing.EAST


## Queries MapManager for an interactable object in the facing tile or current tile
func _try_interact_facing_tile() -> bool:
	var map_mgr: Node3D = get_tree().current_scene.find_child("MapManager", true, false) as Node3D
	if not is_instance_valid(map_mgr):
		map_mgr = get_tree().root.find_child("MapManager", true, false) as Node3D

	if not is_instance_valid(map_mgr) or not map_mgr.has_method("get_interactable_at_grid_pos"):
		return false

	# 1. Check tile directly in front of the player (facing wall/chest)
	var facing_offset: Vector2i = _get_movement_offset(Vector3.FORWARD)
	var target_cell: Vector2i = current_grid_pos + facing_offset
	var target_3d := Vector3i(target_cell.x, 0, target_cell.y)

	var interactable: DungeonInteractable = map_mgr.get_interactable_at_grid_pos(target_3d) as DungeonInteractable
	if is_instance_valid(interactable):
		interactable.interact(self)
		return true

	# 2. Fallback check: Current standing cell (for wall objects placed on tile edge)
	var current_3d := Vector3i(current_grid_pos.x, 0, current_grid_pos.y)
	interactable = map_mgr.get_interactable_at_grid_pos(current_3d) as DungeonInteractable
	if is_instance_valid(interactable):
		interactable.interact(self)
		return true

	return false


func _get_surface_type_at_position(grid_pos: Vector3i) -> String:
	if not is_instance_valid(map_manager):
		return ""
		
	# Floor tiles sit on floor_grid; fallback to dungeon_grid if floor_grid isn't separate
	var target_grid: GridMap = map_manager.floor_grid if is_instance_valid(map_manager.floor_grid) else map_manager.dungeon_grid
	if not is_instance_valid(target_grid):
		return ""
		
	var cell_item: int = target_grid.get_cell_item(grid_pos)
	
	# If no item on floor_grid at this position, check dungeon_grid
	if cell_item == GridMap.INVALID_CELL_ITEM and is_instance_valid(map_manager.dungeon_grid) and target_grid != map_manager.dungeon_grid:
		target_grid = map_manager.dungeon_grid
		cell_item = target_grid.get_cell_item(grid_pos)
		
	if cell_item == GridMap.INVALID_CELL_ITEM:
		return ""
		
	var mesh_library: MeshLibrary = target_grid.mesh_library
	if not is_instance_valid(mesh_library):
		return ""
		
	var item_name: String = mesh_library.get_item_name(cell_item).to_lower()
	
	# Match tile GLB mesh names to audio surface keys
	if "bridge" in item_name or "path_wood" in item_name or "path_stone" in item_name:
		if "stone" in item_name:
			return "bridge_stone"
		elif "wood" in item_name:
			return "bridge_wood"
		return "bridge_wood"
		
	if "grass" in item_name:
		return "ground_grass"
	elif "path" in item_name:
		return "ground_path"
		
	return ""


# Scans all active enemies in the dungeon, calculates grid distance, and triggers clickers / HUD alerts
func _check_enemy_proximity() -> void:
	var nearby_enemy_types: Array[String] = []
	var min_grid_dist: int = 999

	var enemy_nodes: Array[Node] = get_tree().get_nodes_in_group(&"world_enemies")
	if enemy_nodes.is_empty():
		_last_proximity_tier = 0
		if is_instance_valid(AudioManager):
			AudioManager.sync_nearby_enemy_loops(nearby_enemy_types)
		if get_tree().root.has_node("SignalBus"):
			SignalBus.enemy_proximity_changed.emit(999, 0)
		return

	for node in enemy_nodes:
		var enemy_node := node as Node3D
		if not is_instance_valid(enemy_node) or not enemy_node.visible:
			continue

		# 👻 GHOST EXEMPTION: Ignore invisible ambush ghosts for HUD alert meter & clickers
		if enemy_node.has_node("GhostAmbushComponent"):
			continue

		var enemy_cell: Vector2i = Vector2i.ZERO
		if enemy_node.has_method("get_grid_pos"):
			enemy_cell = enemy_node.get_grid_pos()
		else:
			enemy_cell = _world_to_cell(enemy_node.global_position)

		var grid_dist: int = absi(enemy_cell.x - current_grid_pos.x) + absi(enemy_cell.y - current_grid_pos.y)

		if grid_dist < min_grid_dist:
			min_grid_dist = grid_dist

		# Collect unique enemy_type keys within hearing range (<= 6 tiles)
		if grid_dist <= 6:
			var e_type: String = ""
			if "enemy_type" in enemy_node and not str(enemy_node.get("enemy_type")).is_empty():
				e_type = str(enemy_node.get("enemy_type")).to_lower()
			elif "enemy_data" in enemy_node and is_instance_valid(enemy_node.get("enemy_data")):
				e_type = str(enemy_node.get("enemy_data").get("enemy_type")).to_lower()

			if not e_type.is_empty() and not nearby_enemy_types.has(e_type):
				nearby_enemy_types.append(e_type)

	# Proximity Alert Tiers (Clickers & Alarms)
	var current_tier: int = 0
	if min_grid_dist <= 2:
		current_tier = 2
	elif min_grid_dist <= 5:
		current_tier = 1

	if current_tier != _last_proximity_tier:
		_last_proximity_tier = current_tier
		if current_tier > 0 and is_instance_valid(AudioManager):
			AudioManager.play_proximity_clicker(current_tier)

	# Sync single-instance ambient loop per enemy type
	if is_instance_valid(AudioManager):
		AudioManager.sync_nearby_enemy_loops(nearby_enemy_types)

	if get_tree().root.has_node("SignalBus"):
		GameLogger.combat("ALERT PROXIMITY %d TIER %d" % [min_grid_dist, current_tier])
		SignalBus.enemy_proximity_changed.emit(min_grid_dist, current_tier)
