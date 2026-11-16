# res://Scripts/Enemies/GhostAmbushComponent.gd
class_name GhostAmbushComponent
extends Node

## Invisible haunt zones, heartbeat shake, and a reaction-time jump scare.
##
## A ghost owns a wide diamond of tiles around its placed cell. Soon after the party steps
## inside, it warns them (yellow edge flash + alert). The only dodge is turning around
## (≥ 135°). Walking does not cancel it: a step is ~0.2 s and the party is almost always
## moving, so a "leave the cell" dodge meant the ghost never caught anyone.
## Leaving the haunt, or another ghost already striking, does cancel it.
##
## When the window runs out the ghost appears on the open cell behind the party (scream,
## inverted-screen pulse, shake). BattleFacing spins the party around and a second pulse
## hits as the fight opens.
##
## Battle stats come from EnGhost (a real fight even at stat_multiplier 0.6).
## `ghost_level` only changes how fast and how often the haunt strikes.
## A haunt that lands is an ambush: the ghost's turn meter starts full, so it acts first.
## Other enemies ambush only when the party meets them with its back turned, and only if
## EnemyData.can_surprise_player is set. Looking at them (or meeting on the flank) is a normal fight.
##
## Turn timing the window is built around: hold-back-to-180 is 0.4 s before the 0.15 s
## turn tween, and the dodge registers at 135° (~0.5 s of committed input). Two quick
## 90° turns are faster. Level 1 gives a little over a second.

# ==============================================================================
# 1. EXPORTED CONFIGURATION
# ==============================================================================
## Difficulty level (Higher = shorter reaction window & more frequent attacks)
@export_range(1, 10) var ghost_level: int = 1

## Sound file in res://Audio/Enemies/ to play when an ambush warning begins
@export var alert_sound_name: String = "ghost_alert"

## Sound file in res://Audio/Enemies/ to play when an ambush succeeds and combat begins
@export var scream_sound_name: String = "ghost_scream"

## Radius (in grid cells, Manhattan) around this ghost that triggers the haunt zone.
## 15 tiles is most of a dungeon floor, so walking the crypt means walking the haunt.
@export var haunt_radius_tiles: int = DEFAULT_HAUNT_RADIUS

## Reaction window (seconds) at level 1. Just long enough to spin around on purpose.
@export_range(0.7, 4.0) var base_reaction_window: float = 1.15

## Seconds after the party is in the haunt before the next strike is attempted.
@export var min_interval_seconds: float = 1.2

## Upper bound of that wait. Kept short so a fast party cannot cross the haunt first.
@export var max_interval_seconds: float = 2.2

## Subtle screen shake trauma applied periodically while inside the haunt zone
@export_range(0.3, 0.7) var heartbeat_shake_trauma: float = 0.5

## Inverted-screen pulse when the ghost appears and again when the battle starts.
@export var scare_screen_pulse: bool = true

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
## True from the moment the ghost is revealed until the battle has started (or was refused).
var _is_revealing: bool = false
## True while the ghost is out of hiding because of a jump scare (until it hides again).
var _has_revealed: bool = false

const OFF_GRID_CELL: Vector2i = Vector2i(-9999, -9999)
const OFF_GRID_POSITION: Vector3 = Vector3(0, -9999, 0)
## Default haunt. Placed ghosts and the dungeon builder should match this.
const DEFAULT_HAUNT_RADIUS: int = 15
const TURN_AROUND_DEGREES: float = 135.0
## Shortest reaction window, still enough for two quick 90° turns.
const MIN_REACTION_SECONDS: float = 0.7
const REACTION_STEP_PER_LEVEL: float = 0.08
## Outer fraction of the haunt stays quiet so a 15-tile zone is not a constant earthquake.
const HEARTBEAT_QUIET_FRACTION: float = 0.35
const HEARTBEAT_FAR_SECONDS: float = 1.35
const HEARTBEAT_NEAR_SECONDS: float = 0.42
const HEARTBEAT_AMBUSH_SECONDS: float = 0.28

# ==============================================================================
# 3. LIFECYCLE & SETUP
# ==============================================================================
func _ready() -> void:
	_parent_enemy = get_parent() as WorldEnemy
	if not is_instance_valid(_parent_enemy):
		push_error("[GhostAmbushComponent] Component must be a child of a WorldEnemy node.")
		return
	
	add_to_group(&"ghost_ambush")
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
	_park_off_grid()

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
	if not is_instance_valid(_parent_enemy) or _parent_enemy.is_queued_for_deletion():
		set_process(false)
		return
	# Hidden = mid-battle (or ambush in progress). Don't stop processing for good: after a
	# lost or fled battle the ghost must be able to haunt again.
	if _is_revealing or not _parent_enemy.visible:
		return
	# Back on the map after a lost / fled battle: vanish again and resume haunting.
	if _has_revealed and _parent_enemy.get("_is_in_active_combat") != true:
		_has_revealed = false
		_reset_ambush_state()
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
		_process_heartbeat(delta, dist)
		if _is_ambush_active:
			_process_active_ambush(delta)
		else:
			_process_ambush_cooldown(delta)
	elif _is_ambush_active:
		if is_instance_valid(GameLogger):
			GameLogger.combat("Ghost ambush avoided! You left the haunt.")
		_reset_ambush_state()


# ==============================================================================
# 4. AMBUSH & REACTION LOGIC
# ==============================================================================
func _process_heartbeat(delta: float, dist: int) -> void:
	var interval: float = heartbeat_interval(dist, haunt_radius_tiles, _is_ambush_active)
	if interval < 0.0:
		_heartbeat_timer = 0.0
		return
	_heartbeat_timer += delta
	if _heartbeat_timer < interval:
		return
	_heartbeat_timer = 0.0
	var trauma: float = heartbeat_shake_trauma
	if _is_ambush_active:
		trauma = minf(0.85, heartbeat_shake_trauma + 0.3)
	var sb: Node = SignalBus
	if is_instance_valid(sb) and sb.has_signal(&"camera_shake_requested"):
		sb.camera_shake_requested.emit(trauma)


func _process_ambush_cooldown(delta: float) -> void:
	_ambush_interval_timer -= delta
	if _ambush_interval_timer <= 0.0:
		_trigger_ambush()


func _trigger_ambush() -> void:
	if is_instance_valid(GameState) and GameState.has_method("can_begin_encounter") and not GameState.can_begin_encounter():
		_ambush_interval_timer = get_next_ambush_interval()
		return

	var player_in_combat: bool = false
	if is_instance_valid(_player_ref) and ("_is_in_combat" in _player_ref):
		player_in_combat = _player_ref.get("_is_in_combat") as bool

	if not is_instance_valid(_parent_enemy) or _parent_enemy.get("_is_in_active_combat") == true or player_in_combat:
		_ambush_interval_timer = get_next_ambush_interval()
		return

	# One ghost strikes at a time. The other waits a beat instead of double-warning.
	if _another_ghost_is_striking():
		_ambush_interval_timer = 0.6
		return

	_is_ambush_active = true
	_ambush_failed_combat_ready = false
	_reaction_timer = get_effective_reaction_window()
	_initial_player_yaw = _player_ref.rotation_degrees.y
	_heartbeat_timer = HEARTBEAT_AMBUSH_SECONDS

	_flash_ghost_warning()

	if is_instance_valid(AudioManager):
		AudioManager.play_enemy_sound(alert_sound_name)

	if is_instance_valid(GameLogger):
		GameLogger.combat("A ghostly presence looms behind you! Turn around quickly! (Reaction time: %.1fs)" % _reaction_timer)


func _process_active_ambush(delta: float) -> void:
	_reaction_timer -= delta

	var current_yaw: float = _player_ref.rotation_degrees.y
	var angle_diff: float = absf(wrapf(current_yaw - _initial_player_yaw, -180.0, 180.0))

	# Dodge is a turn-around only. Stepping used to count, and a 0.2 s step
	# cancelled every ambush before the window could run out.
	if player_turned_around(angle_diff):
		if is_instance_valid(GameLogger):
			GameLogger.combat("Ghost ambush avoided! You turned around in time.")
		_reset_ambush_state()
		return

	# Timer expired -> Reveal ghost, play scream, and trigger combat
	if _reaction_timer <= 0.0:
		_is_ambush_active = false
		_ambush_failed_combat_ready = true

		_spring_jump_scare()


func _reset_ambush_state() -> void:
	_is_ambush_active = false
	_ambush_failed_combat_ready = false
	_reaction_timer = 0.0
	_ambush_interval_timer = get_next_ambush_interval()
	if is_instance_valid(_parent_enemy) and is_instance_valid(_parent_enemy.model_holder):
		_parent_enemy.model_holder.hide()
	# Back into hiding (matters after a lost / fled battle, when the ghost was revealed).
	if is_instance_valid(_parent_enemy) and _parent_enemy.get("_is_in_active_combat") != true:
		_park_off_grid()


func _park_off_grid() -> void:
	if not is_instance_valid(_parent_enemy):
		return
	_parent_enemy.set("_grid_position", OFF_GRID_CELL)
	_parent_enemy.global_position = OFF_GRID_POSITION


# ==============================================================================
# 4b. JUMP SCARE
# ==============================================================================
## Reveals the ghost behind the party, then starts the battle (the party turns to face it).
func _spring_jump_scare() -> void:
	_is_revealing = true
	_has_revealed = true
	_reveal_behind_player()

	if is_instance_valid(AudioManager):
		var sound_to_play: String = [scream_sound_name, scream_sound_name + "-2"].pick_random()
		AudioManager.play_enemy_sound(sound_to_play)
	if is_instance_valid(GameLogger):
		GameLogger.combat("The ghost caught you off-guard! Combat initiated!")
	if scare_screen_pulse:
		GhostScareFX.play(get_tree(), 1, 0.85, 0.05)
	_flash_ghost_ambush()
	var sb: Node = SignalBus
	if is_instance_valid(sb) and sb.has_signal(&"camera_shake_requested"):
		sb.camera_shake_requested.emit(0.8)

	# Turns the party round (BattleFacing) toward the ghost's new cell, then starts the battle.
	await _parent_enemy.trigger_combat_encounter()
	if not is_instance_valid(_parent_enemy):
		return
	var started: bool = _parent_enemy.get("_is_in_active_combat") == true
	if started and scare_screen_pulse:
		GhostScareFX.play(get_tree(), 2, 1.0, 0.07)
	_is_revealing = false
	if not started:
		_reset_ambush_state() # encounter refused (another fight / cooldown): hide again


## Puts the ghost on the open cell behind the party (else left, else right, else on the party's
## own cell), facing the party, and shows its model.
func _reveal_behind_player() -> void:
	if not is_instance_valid(_parent_enemy) or not is_instance_valid(_player_ref):
		return
	var party_cell: Vector2i = _player_ref.get("current_grid_pos") as Vector2i
	var forward: Vector2i = Vector2i(0, -1)
	if _player_ref is DungeonPlayer:
		forward = BattleFacing._facing_dir(_player_ref as DungeonPlayer)
	var back: Vector2i = -forward
	var left: Vector2i = Vector2i(forward.y, -forward.x)
	var right: Vector2i = -left

	var ghost_cell: Vector2i = party_cell
	for dir: Vector2i in [back, left, right]:
		if not BattleFacing._is_cell_blocked(get_tree(), party_cell + dir):
			ghost_cell = party_cell + dir
			break

	var pos: Vector3 = _parent_enemy.call("_cell_to_world", ghost_cell) as Vector3
	if ghost_cell == party_cell:
		# Nowhere open around us: loom right at the party's back instead.
		pos += Vector3(back.x, 0.0, back.y) * 0.9
	_parent_enemy.set("_grid_position", ghost_cell)
	_parent_enemy.global_position = pos

	var to_party: Vector2i = party_cell - ghost_cell
	if to_party == Vector2i.ZERO:
		to_party = forward
	var facing: int = int(_parent_enemy.call("_vec_to_facing", to_party))
	_parent_enemy.set("_current_facing", facing)
	if is_instance_valid(_parent_enemy.model_holder):
		_parent_enemy.model_holder.rotation_degrees.y = float(_parent_enemy.call("_facing_to_angle", facing))
		_parent_enemy.model_holder.show()


func _find_player() -> void:
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group(&"player") as Node3D


# ==============================================================================
# 5. HELPER FORMULAS & VFX
# ==============================================================================
func get_effective_reaction_window() -> float:
	return reaction_window(base_reaction_window, ghost_level)


func get_next_ambush_interval() -> float:
	var scale_factor: float = clampf(1.0 - ((ghost_level - 1) * 0.07), 0.45, 1.0)
	return maxf(0.8, randf_range(min_interval_seconds, max_interval_seconds) * scale_factor)


## Seconds the party has to spin around before this level of ghost catches them.
static func reaction_window(base_window: float, level: int) -> float:
	var steps: int = maxi(level, 1) - 1
	return maxf(MIN_REACTION_SECONDS, base_window - (float(steps) * REACTION_STEP_PER_LEVEL))


## True when the party has spun far enough to face the thing behind them.
static func player_turned_around(angle_diff: float) -> bool:
	return angle_diff >= TURN_AROUND_DEGREES


## Seconds between heartbeats. Negative means the party is in the quiet outer ring.
static func heartbeat_interval(dist: int, radius: int, ambush_active: bool) -> float:
	if ambush_active:
		return HEARTBEAT_AMBUSH_SECONDS
	var span: float = float(maxi(radius, 1))
	var closeness: float = 1.0 - clampf(float(dist) / span, 0.0, 1.0)
	if closeness < HEARTBEAT_QUIET_FRACTION:
		return -1.0
	var t: float = (closeness - HEARTBEAT_QUIET_FRACTION) / (1.0 - HEARTBEAT_QUIET_FRACTION)
	return lerpf(HEARTBEAT_FAR_SECONDS, HEARTBEAT_NEAR_SECONDS, t)


func _another_ghost_is_striking() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"ghost_ambush"):
		if node == self:
			continue
		var other: GhostAmbushComponent = node as GhostAmbushComponent
		if other != null and other.is_striking():
			return true
	return false


func is_striking() -> bool:
	return _is_ambush_active or _is_revealing


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
