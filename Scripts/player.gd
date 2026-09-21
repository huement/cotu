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
@export var double_tap_window: float = 0.35  # Max time (seconds) between 1st tap and 2nd press
@export var hold_turn_threshold: float = 0.25 # Duration (seconds) 2nd press must be held to flip

var _last_backward_tap_time: int = 0
var _back_hold_start_time: int = 0
var _is_waiting_for_back_hold: bool = false
var _back_hold_triggered: bool = false

var _trauma: float = 0.0

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
	grid_map = world_root.get_node_or_null("GridMap") as GridMap
	map_manager = world_root.get_node_or_null("MapManager") as MapManager

	if is_instance_valid(AudioManager):
		AudioManager.play_level_sound("dungeon-creepy-quite")
		
	if not grid_map:
		if map_manager and is_instance_valid(map_manager.dungeon_grid):
			grid_map = map_manager.dungeon_grid
		else:
			push_error("Player: GridMap sibling node could not be resolved from World root!")
			return

	# Resolve spawn position AND facing angle from SpawnPoint node first
	var spawn_point: Node3D = null
	if map_manager and is_instance_valid(map_manager.active_map_instance):
		spawn_point = map_manager.active_map_instance.get_node_or_null("SpawnPoint") as Node3D

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

	camera.position = Vector3(0.0, eye_height, 0.0)
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
	_check_back_hold_turn()
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

	# Release check: If 2nd press was released quickly (not held), treat as a normal 2nd backward step
	if event.is_action_released("move_backward"):
		if _is_waiting_for_back_hold:
			if not _back_hold_triggered and is_instance_valid(grid_movement) and not grid_movement.is_moving:
				grid_movement.try_step(self, Vector3.BACK, _get_cardinal_string())
			_is_waiting_for_back_hold = false
			_back_hold_triggered = false
		return

	if event.is_action_pressed("move_forward"):
		grid_movement.try_step(self, Vector3.FORWARD, _get_cardinal_string())
	elif event.is_action_pressed("move_backward"):
		var current_time: int = Time.get_ticks_msec()
		var time_diff: float = (current_time - _last_backward_tap_time) / 1000.0
		
		if time_diff <= double_tap_window and _last_backward_tap_time > 0:
			# 2nd press in quick succession: Start hold timer instead of stepping immediately
			_is_waiting_for_back_hold = true
			_back_hold_start_time = current_time
			_back_hold_triggered = false
			_last_backward_tap_time = 0
		else:
			# 1st press or window expired: Step backward immediately
			_last_backward_tap_time = current_time
			_is_waiting_for_back_hold = false
			grid_movement.try_step(self, Vector3.BACK, _get_cardinal_string())
	elif event.is_action_pressed("strafe_left"):
		grid_movement.try_step(self, Vector3.LEFT, _get_cardinal_string())
	elif event.is_action_pressed("strafe_right"):
		grid_movement.try_step(self, Vector3.RIGHT, _get_cardinal_string())
	elif event.is_action_pressed("turn_left"):
		grid_movement.try_turn(self, 90.0)
	elif event.is_action_pressed("turn_right"):
		grid_movement.try_turn(self, -90.0)


# ==============================================================================
# COMBAT SIGNAL CALLBACKS
# ==============================================================================
## 🎯 Updated parameter to Variant to accept both single resources and enemy arrays
func _on_combat_started(_enemy_data_or_group: Variant, _player_party: Array) -> void:
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
	var local_pos: Vector3 = grid_map.map_to_local(Vector3i(cell.x, 0, cell.y))
	local_pos.y = 0.0
	return grid_map.to_global(local_pos)


func _world_to_cell(world_pos: Vector3) -> Vector2i:
	var local_pos: Vector3 = grid_map.to_local(world_pos)
	var map_pos: Vector3i = grid_map.local_to_map(local_pos)
	return Vector2i(map_pos.x, map_pos.z)


func _is_cell_blocked(grid_pos: Vector3i) -> bool:
	if map_manager:
		return map_manager.is_tile_blocked(grid_pos)

	var item_index: int = grid_map.get_cell_item(grid_pos)
	return item_index != GridMap.INVALID_CELL_ITEM


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
func _on_grid_step_completed() -> void:
	# 1. Play player footstep sound
	if Engine.has_singleton("AudioManager") or is_instance_valid(AudioManager):
		AudioManager.play_walking_sound("dungeon")

	# 2. Check nearby enemy distance and evaluate proximity alerts
	_check_enemy_proximity()

	if _is_enemy_adjacent():
		GameLogger.combat("_is_enemy_adjacent")
		SignalBus.edge_flash_requested.emit(Color(1.0, 0.15, 0.15), 0.35)


func _on_component_step_completed(world_position: Vector3) -> void:
	if map_manager:
		var grid_3d: Vector3i = map_manager.world_to_grid(world_position)
		current_grid_pos = Vector2i(grid_3d.x, grid_3d.z)

	if is_instance_valid(SignalBus):
		SignalBus.party_moved.emit(Vector3i(current_grid_pos.x, 0, current_grid_pos.y), _get_cardinal_string())

	_on_grid_step_completed()


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


# player.gd (or world.tscn debug controller)
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


func _check_back_hold_turn() -> void:
	if _is_waiting_for_back_hold and not _back_hold_triggered:
		if Input.is_action_pressed("move_backward"):
			var hold_time: float = (Time.get_ticks_msec() - _back_hold_start_time) / 1000.0
			if hold_time >= hold_turn_threshold:
				_back_hold_triggered = true
				_is_waiting_for_back_hold = false
				
				if is_instance_valid(AudioManager):
					if AudioManager.has_method("play_turn_around_sound"):
						AudioManager.play_turn_around_sound()
						
				grid_movement.try_turn(self, 180.0)
		else:
			_is_waiting_for_back_hold = false
