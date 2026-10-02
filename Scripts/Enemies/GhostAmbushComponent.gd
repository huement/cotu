# res://Scripts/Enemies/GhostAmbushComponent.gd
class_name GhostAmbushComponent
extends Node

## Manages invisible proximity zones, heartbeat screen shake, audio alerts,
## and reaction-time combat ambushes for Ghost enemies.

# ==============================================================================
# 1. EXPORTED CONFIGURATION
# ==============================================================================
## Difficulty level (Higher = shorter reaction window & more frequent attacks)
@export_range(1, 10) var ghost_level: int = 1

## Sound file in res://Audio/Enemies/ to play when an ambush warning begins
@export var alert_sound_name: String = "ghost_alert"

## Sound file in res://Audio/Enemies/ to play when an ambush succeeds and combat begins
@export var scream_sound_name: String = "ghost_scream"

## Radius (in grid cells) around this ghost node that triggers the haunt zone
@export var haunt_radius_tiles: int = 3

## Base reaction window (seconds) at Level 1 before combat initiates
@export_range(1.0, 10.0) var base_reaction_window: float = 4.0

## Minimum interval (seconds) between ambush attempts while in the zone
@export var min_interval_seconds: float = 8.0

## Maximum interval (seconds) between ambush attempts while in the zone
@export var max_interval_seconds: float = 14.0

## Subtle screen shake trauma applied periodically while inside the haunt zone
@export_range(0.3, 0.7) var heartbeat_shake_trauma: float = 0.5

# ==============================================================================
# 2. RUNTIME STATE
# ==============================================================================
var _parent_enemy: WorldEnemy
var _player_ref: Node3D
var _haunt_center_cell: Vector2i = Vector2i(-9999, -9999)
var _is_player_in_zone: bool = false
var _is_ambush_active: bool = false
var _ambush_failed_combat_ready: bool = false
var _ambush_interval_timer: float = 0.0
var _reaction_timer: float = 0.0
var _heartbeat_timer: float = 0.0
var _initial_player_yaw: float = 0.0
var _initial_player_cell: Vector2i = Vector2i(-9999, -9999)

# ==============================================================================
# 3. LIFECYCLE & SETUP
# ==============================================================================
func _ready() -> void:
	_parent_enemy = get_parent() as WorldEnemy
	if not is_instance_valid(_parent_enemy):
		push_error("[GhostAmbushComponent] Component must be a child of a WorldEnemy node.")
		return
	
	_ambush_interval_timer = get_next_ambush_interval()

	# Wait for parent WorldEnemy to finish its deferred grid alignment
	while not _parent_enemy.get("_is_initialized"):
		await get_tree().process_frame

	_setup_ghost_overrides()
	

func _setup_ghost_overrides() -> void:
	if not is_instance_valid(_parent_enemy):
		return

	# 1. Store haunt center cell from overworld placement
	_haunt_center_cell = _parent_enemy.get_grid_pos()
	if _haunt_center_cell == Vector2i.ZERO and _parent_enemy.initial_cell != Vector2i.ZERO:
		_haunt_center_cell = _parent_enemy.initial_cell

	# 2. Move parent enemy's registered tile AND physical 3D body off-grid
	_parent_enemy.set("_grid_position", Vector2i(-9999, -9999))
	_parent_enemy.global_position = Vector3(0, -9999, 0)

	# 3. Stop standard overworld AI & movement
	_parent_enemy.set_process(false)

	# 4. Keep 3D model hidden on overworld
	if is_instance_valid(_parent_enemy.model_holder):
		_parent_enemy.model_holder.hide()

	# 5. Disable all collision shapes & layers
	_disable_collisions_recursive(_parent_enemy)

	# 6. Remove from world_enemies group
	if _parent_enemy.is_in_group(&"world_enemies"):
		_parent_enemy.remove_from_group(&"world_enemies")


func _disable_collisions_recursive(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	elif node is CollisionPolygon3D:
		(node as CollisionPolygon3D).disabled = true

	if node is CollisionObject3D:
		var col_obj := node as CollisionObject3D
		col_obj.collision_layer = 0
		col_obj.collision_mask = 0
		if col_obj is Area3D:
			(col_obj as Area3D).monitoring = false
			(col_obj as Area3D).monitorable = false

	for child in node.get_children():
		_disable_collisions_recursive(child)


## Returns true if the ambush reaction window expired and combat is authorized to start
func can_trigger_combat() -> bool:
	return _ambush_failed_combat_ready


func _process(delta: float) -> void:
	if not is_instance_valid(_parent_enemy) or not _parent_enemy.visible or _parent_enemy.is_queued_for_deletion():
		set_process(false)
		return

	_find_player()

	var player_in_combat: bool = false
	if is_instance_valid(_player_ref) and ("_is_in_combat" in _player_ref):
		player_in_combat = _player_ref.get("_is_in_combat") as bool

	if _parent_enemy.get("_is_in_active_combat") == true or player_in_combat:
		_reset_ambush_state()
		return

	if not is_instance_valid(_player_ref):
		return

	var p_cell: Vector2i = _player_ref.get("current_grid_pos") if ("current_grid_pos" in _player_ref) else Vector2i(-9999, -9999)
	var dist: int = absi(p_cell.x - _haunt_center_cell.x) + absi(p_cell.y - _haunt_center_cell.y)

	_is_player_in_zone = (dist <= haunt_radius_tiles)

	if _is_player_in_zone:
		_process_heartbeat(delta)
		if _is_ambush_active:
			_process_active_ambush(delta, p_cell)
		else:
			_process_ambush_cooldown(delta)
	else:
		if _is_ambush_active:
			_reset_ambush_state()


# ==============================================================================
# 4. AMBUSH & REACTION LOGIC
# ==============================================================================
func _process_heartbeat(delta: float) -> void:
	_heartbeat_timer += delta
	if _heartbeat_timer >= 1.5:
		_heartbeat_timer = 0.0
		var sb: Node = SignalBus
		if is_instance_valid(sb) and sb.has_signal(&"camera_shake_requested"):
			sb.camera_shake_requested.emit(heartbeat_shake_trauma)


func _process_ambush_cooldown(delta: float) -> void:
	_ambush_interval_timer -= delta
	if _ambush_interval_timer <= 0.0:
		_trigger_ambush()


func _trigger_ambush() -> void:
	if GameState.post_combat_immunity_timer > 0.0:
		_ambush_interval_timer = get_next_ambush_interval()
		return

	var player_in_combat: bool = false
	if is_instance_valid(_player_ref) and ("_is_in_combat" in _player_ref):
		player_in_combat = _player_ref.get("_is_in_combat") as bool

	if not is_instance_valid(_parent_enemy) or _parent_enemy.get("_is_in_active_combat") == true or player_in_combat:
		_ambush_interval_timer = get_next_ambush_interval()
		return

	_is_ambush_active = true
	_ambush_failed_combat_ready = false
	_reaction_timer = get_effective_reaction_window()
	_initial_player_yaw = _player_ref.rotation_degrees.y
	if "current_grid_pos" in _player_ref:
		_initial_player_cell = _player_ref.get("current_grid_pos") as Vector2i

	_flash_ghost_warning()

	if is_instance_valid(AudioManager):
		AudioManager.play_enemy_sound(alert_sound_name)

	if is_instance_valid(GameLogger):
		GameLogger.combat("A ghostly presence looms behind you! Turn around quickly! (Reaction time: %.1fs)" % _reaction_timer)


func _process_active_ambush(delta: float, current_player_cell: Vector2i) -> void:
	_reaction_timer -= delta

	var current_yaw: float = _player_ref.rotation_degrees.y
	var angle_diff: float = absf(wrapf(current_yaw - _initial_player_yaw, -180.0, 180.0))

	# Dodge condition: Turn around >= 135 degrees OR step away
	if angle_diff >= 135.0 or current_player_cell != _initial_player_cell:
		if is_instance_valid(GameLogger):
			GameLogger.combat("Ghost ambush avoided! You turned around in time.")
		_reset_ambush_state()
		return

	# Timer expired -> Reveal ghost, play scream, and trigger combat
	if _reaction_timer <= 0.0:
		_is_ambush_active = false
		_ambush_failed_combat_ready = true

		if is_instance_valid(_parent_enemy) and is_instance_valid(_parent_enemy.model_holder):
			_parent_enemy.model_holder.show()

		if is_instance_valid(AudioManager):
			var sound_to_play: String = [scream_sound_name, scream_sound_name + "-2"].pick_random()
			AudioManager.play_enemy_sound(sound_to_play)

		if is_instance_valid(GameLogger):
			GameLogger.combat("The ghost caught you off-guard! Combat initiated!")

		_flash_ghost_ambush()

		var sb: Node = SignalBus
		if is_instance_valid(sb) and sb.has_signal(&"camera_shake_requested"):
			sb.camera_shake_requested.emit(0.8)

		_parent_enemy.trigger_combat_encounter()


func _reset_ambush_state() -> void:
	_is_ambush_active = false
	_ambush_failed_combat_ready = false
	_reaction_timer = 0.0
	_ambush_interval_timer = get_next_ambush_interval()
	if is_instance_valid(_parent_enemy) and is_instance_valid(_parent_enemy.model_holder):
		_parent_enemy.model_holder.hide()


func _find_player() -> void:
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group(&"player") as Node3D


# ==============================================================================
# 5. HELPER FORMULAS & VFX
# ==============================================================================
func get_effective_reaction_window() -> float:
	return maxf(1.5, base_reaction_window - ((ghost_level - 1) * 0.25))


func get_next_ambush_interval() -> float:
	var scale_factor: float = clampf(1.0 - ((ghost_level - 1) * 0.07), 0.3, 1.0)
	return randf_range(min_interval_seconds, max_interval_seconds) * scale_factor


func _flash_ghost_warning() -> void:
	var sb: Node = SignalBus
	if not is_instance_valid(sb) or not sb.has_signal(&"edge_flash_requested"):
		return

	sb.edge_flash_requested.emit(Color("ffff53"), 0.15)
	await get_tree().create_timer(0.2).timeout
	sb.edge_flash_requested.emit(Color("ffff53"), 0.15)


func _flash_ghost_ambush() -> void:
	var sb: Node = SignalBus
	if not is_instance_valid(sb) or not sb.has_signal(&"edge_flash_requested"):
		return

	sb.edge_flash_requested.emit(Color("ff1a53"), 0.2)
	await get_tree().create_timer(0.2).timeout
	sb.edge_flash_requested.emit(Color("ff1a53"), 0.2)
	await get_tree().create_timer(0.2).timeout
	sb.edge_flash_requested.emit(Color("a800ff"), 0.3)
	await get_tree().create_timer(0.3).timeout
	sb.edge_flash_requested.emit(Color("ff1a53"), 0.2)
