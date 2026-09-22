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

## Sound file in res://Audio/Enemies/ to play when an ambush begins
@export var alert_sound_name: String = "ghost-alert"

## Radius (in grid cells) around this ghost node that triggers the haunt zone
@export var haunt_radius_tiles: int = 3

## Base reaction window (seconds) at Level 1 before combat initiates
@export var base_reaction_window: float = 4.0

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
var _is_player_in_zone: bool = false
var _is_ambush_active: bool = false
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
	call_deferred("_setup_ghost_overrides")


func _setup_ghost_overrides() -> void:
	if not is_instance_valid(_parent_enemy):
		return

	# 1. Stop standard overworld movement, patrol, and pursuit AI
	_parent_enemy.set_process(false)

	# 2. Keep 3D model hidden on the overworld map
	if is_instance_valid(_parent_enemy.model_holder):
		_parent_enemy.model_holder.hide()

	# 3. Disable Area3D touch-combat so standard body_entered doesn't trigger
	if is_instance_valid(_parent_enemy.activation_area):
		_parent_enemy.activation_area.monitoring = false
		_parent_enemy.activation_area.monitorable = false

	# 4. Remove from world_enemies group so tile-stepping doesn't trigger a direct bump encounter
	if _parent_enemy.is_in_group(&"world_enemies"):
		_parent_enemy.remove_from_group(&"world_enemies")


func _process(delta: float) -> void:
	if not is_instance_valid(_parent_enemy) or not _parent_enemy.visible:
		return

	_find_player()

	# Check if parent enemy or player is currently engaged in combat
	var player_in_combat: bool = false
	if is_instance_valid(_player_ref) and ("_is_in_combat" in _player_ref):
		player_in_combat = _player_ref.get("_is_in_combat") as bool

	if _parent_enemy.get("_is_in_active_combat") == true or player_in_combat:
		_reset_ambush_state()
		return

	if not is_instance_valid(_player_ref):
		return

	var p_cell: Vector2i = _player_ref.get("current_grid_pos") if ("current_grid_pos" in _player_ref) else Vector2i(-9999, -9999)
	var e_cell: Vector2i = _parent_enemy.get_grid_pos() if _parent_enemy.has_method("get_grid_pos") else Vector2i(0, 0)
	var dist: int = absi(p_cell.x - e_cell.x) + absi(p_cell.y - e_cell.y)

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
	# 🛡️ Guard: If post-combat immunity or active combat is in progress, abort ambush.
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
	_reaction_timer = get_effective_reaction_window()
	_initial_player_yaw = _player_ref.rotation_degrees.y
	if "current_grid_pos" in _player_ref:
		_initial_player_cell = _player_ref.get("current_grid_pos") as Vector2i

	# ⚡ 1. Flash the edge vignette BEFORE playing the alert sound
	_flash_ghost_ambush()

	# 🔊 2. Play ghost alert audio
	if is_instance_valid(AudioManager):
		AudioManager.play_enemy_sound(alert_sound_name)

	if is_instance_valid(GameLogger):
		GameLogger.info("A ghostly presence looms behind you! Turn around quickly! (Reaction time: %.1fs)" % _reaction_timer)
		

func _process_active_ambush(delta: float, current_player_cell: Vector2i) -> void:
	_reaction_timer -= delta

	# Check turn-around evasion
	var current_yaw: float = _player_ref.rotation_degrees.y
	var angle_diff: float = absf(wrapf(current_yaw - _initial_player_yaw, -180.0, 180.0))

	# Player dodges if they rotate >= 135 degrees OR step away from initial ambush cell
	if angle_diff >= 135.0 or current_player_cell != _initial_player_cell:
		if is_instance_valid(GameLogger):
			GameLogger.info("Ghost ambush avoided! You turned around in time.")
		_reset_ambush_state()
		return

	# Timer expired -> Trigger combat
	if _reaction_timer <= 0.0:
		_is_ambush_active = false
		if is_instance_valid(AudioManager):
			AudioManager.play_enemy_sound("ghost_scream")
		if is_instance_valid(GameLogger):
			GameLogger.info("The ghost caught you off-guard! Combat initiated!")
		_flash_ghost_ambush()
		_parent_enemy.trigger_combat_encounter()


func _reset_ambush_state() -> void:
	_is_ambush_active = false
	_reaction_timer = 0.0
	_ambush_interval_timer = get_next_ambush_interval()


func _find_player() -> void:
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group(&"player") as Node3D


# ==============================================================================
# 5. HELPER FORMULAS
# ==============================================================================
func get_effective_reaction_window() -> float:
	return maxf(1.5, base_reaction_window - ((ghost_level - 1) * 0.25))


func get_next_ambush_interval() -> float:
	var scale_factor: float = clampf(1.0 - ((ghost_level - 1) * 0.07), 0.3, 1.0)
	return randf_range(min_interval_seconds, max_interval_seconds) * scale_factor


## Emits a rapid burst of edge vignette flashes via SignalBus
func _flash_ghost_warning() -> void:
	var sb: Node = SignalBus
	if not is_instance_valid(sb) or not sb.has_signal(&"edge_flash_requested"):
		return
	
	# Burst Yellow
	sb.edge_flash_requested.emit(Color("ffff53"), 0.1)
	await get_tree().create_timer(0.2).timeout


## Emits a rapid burst of edge vignette flashes via SignalBus
func _flash_ghost_ambush() -> void:
	var sb: Node = SignalBus
	if not is_instance_valid(sb) or not sb.has_signal(&"edge_flash_requested"):
		return

	# Burst 1: red
	sb.edge_flash_requested.emit(Color("ff1a53"), 0.2)
	await get_tree().create_timer(0.2).timeout
	
	# Burst 2: Crimson red
	sb.edge_flash_requested.emit(Color("ff1a53"), 0.2)
	await get_tree().create_timer(0.2).timeout
	
	# Burst 3: Intense purple warning
	sb.edge_flash_requested.emit(Color("a800ff"), 0.3)
