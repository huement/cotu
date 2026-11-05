# res://Scripts/Enemies/BlobBossController.gd
class_name BlobBossController
extends Node3D

const GROUP_WORLD_ENEMIES: StringName = &"world_enemies"
const GROUP_BLOB_BOSS: StringName = &"blob_boss"

# ==============================================================================
# CONFIGURATION & SCALING
# ==============================================================================
@export_group("Encounter Data")
@export var base_data: EnemyData

## Controls visual size and proportionally scales Max HP and Attack Damage
@export_range(0.5, 5.0, 0.1) var boss_scale: float = 1.0:
	set(val):
		boss_scale = maxf(0.1, val)
		if is_node_ready():
			_apply_scale_and_stats()

@export_group("Level")
## Boss level. Every level above 1 scales all stats by the growth rates below.
@export_range(1, 99, 1) var boss_level: int = 1:
	set(val):
		boss_level = maxi(1, val)
		if is_node_ready():
			_apply_scale_and_stats()

@export_group("Minions")
## Bring a pair of smaller blobs that flank the boss (left + right).
@export var has_minions: bool = false
## Minion stats/model. Leave empty to reuse this blob's base_data.
@export var minion_data: EnemyData
## Minion level (scales all of their stats the same way as the boss).
@export_range(1, 99, 1) var minion_level: int = 1
## Visual size of each minion. Does not change their stats.
@export_range(0.3, 5.0, 0.1) var minion_scale: float = 1.0
## Optional display name for minions (e.g. "Blobling"). Empty = data's name.
@export var minion_name_override: String = ""
## Extra gap (world units) between the boss's edge and each minion's edge.
@export var minion_gap: float = 0.6
## Pull minions toward the camera (+) so they stand slightly in front of the boss.
@export var minion_forward_offset: float = 0.0

@export_group("Level Scaling")
## Per-level stat growth (0.2 = +20% per level above 1).
@export var hp_growth_per_level: float = 0.20
@export var damage_growth_per_level: float = 0.12
@export var defense_growth_per_level: float = 0.10
@export var speed_growth_per_level: float = 0.03
@export var reward_growth_per_level: float = 0.15

@export_group("Model Animation")
## Keep the model's own GLB animation looping the whole time (e.g. the Slime Lord's idle).
## Lunges, hit shakes and the death melt still come from VisualJuice.
@export var loop_model_animation: bool = false
## Which animation to loop. Empty = the first one in the model.
@export var model_animation: StringName = &""
## The looping animation already stands some models up (it rotates their spine 90 degrees),
## so the editor-only tilt on the model node is cleared at runtime.
@export var clear_model_tilt_when_animating: bool = true
## Turn to face the party while rising and when the battle starts (models with a front/face).
@export var face_player: bool = false
## Extra yaw if the model's front isn't its +Z axis (e.g. 180 if it shows its back).
@export_range(-180.0, 180.0, 1.0) var facing_yaw_offset_degrees: float = 0.0

@export_group("Stats")
## If true, boss_scale also multiplies HP and damage (Pulsing Sac behaviour).
## Turn off to use base_data stats (plus level) no matter how big the model is.
@export var scale_affects_stats: bool = true

@export_group("Trigger Settings")
## PROXIMITY: rises when the party walks close. SCRIPTED: only rises when emerge_at() is called
## (e.g. by a BossStatue).
@export_enum("Proximity", "Scripted") var trigger_mode: int = 0
## Radius in world units around this node that will trigger the emergence
@export var trigger_distance: float = 8.0

@export_group("Ground Emergence")
## How far underground the blob rests before rising
@export var rise_depth: float = 5.0
## Duration of the rising animation
@export var rise_duration: float = 2.4

@export_group("Earth Shaking Entrance")
## Shake the ground (camera) while this blob rises. Off = no quake.
@export var earth_shake_enabled: bool = true
## SMALL for regular blobs, LARGE for the giant end-of-level blob
@export var earth_shake_size: CameraShake.QuakeSize = CameraShake.QuakeSize.SMALL
## How many (BIG rock -> tremors -> BIG rock -> tremors) cycles to play
@export_range(1, 10, 1) var earth_shake_loops: int = 1
## Seconds after the rise starts before the ground begins shaking
@export var earth_shake_delay: float = 0.0
## Wait for the quake to finish before the battle starts (good for the giant blob)
@export var wait_for_quake_before_combat: bool = false

@export_group("Entrance Audio")
@export var entrance_sound: AudioStream = preload("res://Audio/Enemies/blob_entrance.mp3")
## Delay so the sound lands when the blob is partially out of the ground
@export var entrance_sound_delay: float = 0.5
@export_range(-40.0, 12.0, 0.5) var entrance_sound_volume_db: float = 0.0

@export_group("Combat View")
## Gap between the camera and the FRONT of the blob's body once battle starts.
## Measured to the near edge, so big and small blobs end up equally close.
## The trigger volume can be off to the side of the view, so the fight pose ignores that spot.
@export var combat_view_distance: float = 2.5

# ==============================================================================
# RUNTIME STATE
# ==============================================================================
var current_health: int = 60
var max_health: int = 60
var scaled_damage: int = 10
var enemy_group: Array[Resource] = []

var _is_triggered: bool = false
var _is_in_active_combat: bool = false
var _rest_y: float = 0.0
var _home_position: Vector3 = Vector3.ZERO
var _player_ref: Node3D = null
var _minion_nodes: Array[Node3D] = []
## Index of the boss inside enemy_group (minions sit either side).
var _boss_slot: int = 0

## Emitted right before the boss is removed after losing a battle.
signal defeated

@onready var visual_juice: BlobBossJuice = get_node_or_null("VisualJuice") as BlobBossJuice
@onready var activation_area: Area3D = get_node_or_null("ActivationArea") as Area3D


func _ready() -> void:
	add_to_group(GROUP_BLOB_BOSS)
	add_to_group(GROUP_WORLD_ENEMIES)

	_home_position = global_position
	_rest_y = global_position.y
	# Start submerged and hidden
	global_position.y = _rest_y - rise_depth
	visible = false

	_apply_scale_and_stats()
	_connect_signals()
	if loop_model_animation:
		_start_model_animation_loop()


func _start_model_animation_loop() -> void:
	if not is_instance_valid(visual_juice):
		return
	var anim_player: AnimationPlayer = visual_juice.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not is_instance_valid(anim_player):
		return
	var anim_name: StringName = model_animation
	if anim_name.is_empty() or not anim_player.has_animation(anim_name):
		for candidate: StringName in anim_player.get_animation_list():
			if candidate != &"RESET":
				anim_name = candidate
				break
	if anim_name.is_empty():
		return
	var anim: Animation = anim_player.get_animation(anim_name)
	if is_instance_valid(anim):
		anim.loop_mode = Animation.LOOP_LINEAR
	anim_player.play(anim_name)

	if clear_model_tilt_when_animating:
		for child in visual_juice.get_children():
			if child is Node3D and child.find_child("AnimationPlayer", true, false) != null:
				(child as Node3D).rotation = Vector3.ZERO


## Yaw only (keeps the model's own tilt), so the model's +Z points at the camera.
func _face_camera() -> void:
	if not face_player:
		return
	var camera: Camera3D = _get_camera()
	if not is_instance_valid(camera):
		return
	var to_cam: Vector3 = camera.global_position - global_position
	to_cam.y = 0.0
	if to_cam.length_squared() < 0.0001:
		return
	rotation.y = atan2(to_cam.x, to_cam.z) + deg_to_rad(facing_yaw_offset_degrees)


## SCRIPTED bosses: rise out of the ground at `world_pos` (keeps all the normal rise/quake/combat flow).
func emerge_at(world_pos: Vector3) -> void:
	if _is_triggered or _is_in_active_combat:
		return
	_home_position = world_pos
	_rest_y = world_pos.y
	global_position = Vector3(world_pos.x, _rest_y - rise_depth, world_pos.z)
	_trigger_emergence_sequence()


func _apply_scale_and_stats() -> void:
	var lvl: float = float(boss_level - 1)
	var stat_scale: float = boss_scale if scale_affects_stats else 1.0
	var hp_mult: float = stat_scale * (1.0 + hp_growth_per_level * lvl)
	var dmg_mult: float = stat_scale * (1.0 + damage_growth_per_level * lvl)
	if is_instance_valid(base_data):
		max_health = roundi(float(base_data.max_health) * hp_mult)
		scaled_damage = roundi(float(base_data.attack_damage) * dmg_mult)
	else:
		max_health = roundi(60.0 * hp_mult)
		scaled_damage = roundi(10.0 * dmg_mult)

	current_health = max_health

	if is_instance_valid(visual_juice):
		visual_juice.apply_world_scale(boss_scale)

	_build_runtime_enemy_data()


func _build_runtime_enemy_data() -> void:
	enemy_group.clear()
	if not is_instance_valid(base_data):
		return

	var boss_data: EnemyData = base_data.duplicate(true) as EnemyData
	_apply_level_to_data(boss_data, boss_level)
	# Boss keeps its existing size-based HP/damage on top of level
	boss_data.max_health = max_health
	boss_data.current_health = max_health
	boss_data.attack_damage = scaled_damage
	boss_data.model_scale = base_data.model_scale * boss_scale
	boss_data.combat_forward_distance = combat_view_distance
	boss_data.combat_uses_world_node = true

	if has_minions:
		# Always a pair: [minion L, boss, minion R]
		enemy_group.append(_build_minion_data())
		_boss_slot = 1
		enemy_group.append(boss_data)
		enemy_group.append(_build_minion_data())
	else:
		_boss_slot = 0
		enemy_group.append(boss_data)


func _build_minion_data() -> EnemyData:
	var src: EnemyData = minion_data if is_instance_valid(minion_data) else base_data
	var d: EnemyData = src.duplicate(true) as EnemyData
	_apply_level_to_data(d, minion_level)
	d.model_scale = src.model_scale * minion_scale
	d.combat_forward_distance = combat_view_distance
	d.combat_uses_world_node = true
	if not minion_name_override.is_empty():
		d.enemy_name = minion_name_override
	return d


## Scales every stat on a runtime EnemyData copy by level.
func _apply_level_to_data(d: EnemyData, level: int) -> void:
	var lvl: float = float(maxi(1, level) - 1)
	d.base_level = maxi(1, level)
	d.scale_with_player = false
	d.max_health = roundi(float(d.max_health) * (1.0 + hp_growth_per_level * lvl))
	d.current_health = d.max_health
	d.attack_damage = roundi(float(d.attack_damage) * (1.0 + damage_growth_per_level * lvl))
	d.defense = roundi(float(d.defense) * (1.0 + defense_growth_per_level * lvl))
	d.speed = d.speed * (1.0 + speed_growth_per_level * lvl)
	d.initiative_speed = roundi(float(d.initiative_speed) * (1.0 + speed_growth_per_level * lvl))
	d.max_mana = roundi(float(d.max_mana) * (1.0 + hp_growth_per_level * 0.5 * lvl))
	d.xp_value = roundi(float(d.xp_value) * (1.0 + reward_growth_per_level * lvl))
	d.gold_value = roundi(float(d.gold_value) * (1.0 + reward_growth_per_level * lvl))


func _connect_signals() -> void:
	var sb: Node = SignalBus
	if is_instance_valid(sb):
		if not sb.party_moved.is_connected(_on_party_moved):
			sb.party_moved.connect(_on_party_moved)
		if not sb.combat_started.is_connected(_on_combat_started):
			sb.combat_started.connect(_on_combat_started)
		if not sb.combat_ended.is_connected(_on_combat_ended):
			sb.combat_ended.connect(_on_combat_ended)

	if is_instance_valid(activation_area):
		if not activation_area.body_entered.is_connected(_on_area_body_entered):
			activation_area.body_entered.connect(_on_area_body_entered)


func _on_party_moved(_grid_pos: Vector3i, _facing: String) -> void:
	if trigger_mode != 0 or _is_triggered or _is_in_active_combat:
		return

	_resolve_player_ref()
	if is_instance_valid(_player_ref):
		var dist: float = global_position.distance_to(_player_ref.global_position)
		if dist <= trigger_distance:
			_trigger_emergence_sequence()


func _on_area_body_entered(body: Node) -> void:
	if trigger_mode != 0 or _is_triggered or _is_in_active_combat:
		return
	if body.name == "Player" or body is DungeonPlayer or body.is_in_group(&"player"):
		_player_ref = body as Node3D
		_trigger_emergence_sequence()


func _resolve_player_ref() -> void:
	if is_instance_valid(_player_ref):
		return
	_player_ref = get_tree().get_first_node_in_group(&"player") as Node3D
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().root.find_child("Player", true, false) as Node3D


# ==============================================================================
# EMERGENCE & COMBAT SEQUENCE
# ==============================================================================
func _trigger_emergence_sequence() -> void:
	if _is_triggered:
		return
	_is_triggered = true

	# Block other world encounters for the rise, with a 30s failsafe.
	if is_instance_valid(GameState) and GameState.has_method("lock_encounters"):
		GameState.lock_encounters(30.0)

	# 1. Lock the player immediately so they cannot move during the animation
	_resolve_player_ref()
	if is_instance_valid(_player_ref) and _player_ref.has_method("set_movement_locked"):
		_player_ref.call("set_movement_locked", true)

	# 2. Reveal and start rising
	visible = true
	global_position.y = _rest_y - rise_depth
	_face_camera()

	if is_instance_valid(visual_juice):
		visual_juice.play_idle()

	_spawn_minions()
	_layout_minions(_get_camera())

	_start_earth_shake()
	_play_entrance_sound()

	if is_instance_valid(GameLogger):
		GameLogger.combat("The cavern floor erupts! A massive %s bursts forth!" % [base_data.enemy_name if base_data else "Pulsing Sac"])

	# 3. Animate rising out of the ground
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position:y", _rest_y, rise_duration)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	tween.finished.connect(_on_emergence_complete, CONNECT_ONE_SHOT)


func _on_emergence_complete() -> void:
	global_position.y = _rest_y

	if wait_for_quake_before_combat and earth_shake_enabled:
		var remaining: float = earth_shake_delay \
			+ CameraShake.get_earthquake_duration(earth_shake_size, earth_shake_loops) - rise_duration
		if remaining > 0.0:
			await get_tree().create_timer(remaining).timeout

	# 4. Animation has reached the top: Launch Combat
	_start_combat_encounter()


func _start_earth_shake() -> void:
	if not earth_shake_enabled:
		return
	if earth_shake_delay > 0.0:
		await get_tree().create_timer(earth_shake_delay).timeout
	CameraShake.request_earthquake(get_tree(), earth_shake_size, earth_shake_loops)


func _play_entrance_sound() -> void:
	if entrance_sound == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = entrance_sound
	player.volume_db = entrance_sound_volume_db
	add_child(player)
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	if entrance_sound_delay > 0.0:
		await get_tree().create_timer(entrance_sound_delay).timeout
	if is_instance_valid(player):
		player.play()


func _start_combat_encounter() -> void:
	if _is_in_active_combat:
		return

	if enemy_group.is_empty():
		_build_runtime_enemy_data()

	_place_centered_on_camera()
	_is_in_active_combat = true
	visible = true
	if is_instance_valid(GameState) and GameState.has_method("clear_encounter_lock"):
		GameState.clear_encounter_lock()

	var party_slots: Array = []
	if "current_party" in GameState and GameState.current_party != null:
		if "slots" in GameState.current_party:
			party_slots = GameState.current_party.slots

	SignalBus.combat_started.emit(enemy_group, party_slots, "SOUTH")
	_register_with_visual_manager()


## Lets EnemyVisualManager drive hit shakes / death sinks on our world blobs.
func _register_with_visual_manager() -> void:
	var managers: Array[Node] = get_tree().root.find_children("*", "EnemyVisualManager", true, false)
	if managers.is_empty():
		return
	var evm: Node = managers[0]
	if not evm.has_method("register_world_combat_model"):
		return
	var minion_idx: int = 0
	for i in range(enemy_group.size()):
		var node: Node3D = self
		if i != _boss_slot:
			if minion_idx >= _minion_nodes.size():
				continue
			node = _minion_nodes[minion_idx]
			minion_idx += 1
		if is_instance_valid(node):
			evm.call("register_world_combat_model", "enemy_%d" % i, node)


func _get_camera() -> Camera3D:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		_resolve_player_ref()
		if is_instance_valid(_player_ref):
			camera = _player_ref.find_child("Camera3D", true, false) as Camera3D
	return camera


func _place_centered_on_camera() -> void:
	var camera: Camera3D = _get_camera()
	if not is_instance_valid(camera):
		return

	# Position only. look_at() replaces the basis and flattens the 90° X
	# that stands the mesh up, so the camera looks at the underside.
	var cam_origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	global_position = Vector3(cam_origin.x, _rest_y, cam_origin.z) + (forward * combat_view_distance)
	_face_camera()
	_center_visual_on_camera(camera, forward)
	_layout_minions(camera)


func _center_visual_on_camera(camera: Camera3D, forward: Vector3) -> void:
	var aabb: AABB = _compute_visual_aabb()
	if aabb.size == Vector3.ZERO:
		return

	var cam_origin: Vector3 = camera.global_position
	var right: Vector3 = camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() > 0.0001:
		right = right.normalized()
		var lateral: float = (aabb.get_center() - cam_origin).dot(right)
		global_position -= right * lateral

	aabb = _compute_visual_aabb()
	if aabb.size == Vector3.ZERO:
		return
	var near_dist: float = _near_depth(aabb, cam_origin, forward)
	global_position += forward * (combat_view_distance - near_dist)
	global_position.y = _rest_y


func _compute_visual_aabb(root: Node = null) -> AABB:
	if root == null:
		# Boss only: never include the minions in the boss's bounds
		root = visual_juice if is_instance_valid(visual_juice) else self
	var merged: AABB = AABB()
	var has_any: bool = false
	var visuals: Array[Node] = root.find_children("*", "VisualInstance3D", true, false)
	for child in visuals:
		var vis: VisualInstance3D = child as VisualInstance3D
		if not is_instance_valid(vis):
			continue
		var local_aabb: AABB = vis.get_aabb()
		if local_aabb.size == Vector3.ZERO:
			continue
		var world_aabb: AABB = vis.global_transform * local_aabb
		if not has_any:
			merged = world_aabb
			has_any = true
		else:
			merged = merged.merge(world_aabb)
	return merged if has_any else AABB()


# ==============================================================================
# MINIONS
# ==============================================================================
func _spawn_minions() -> void:
	_clear_minions()
	if not has_minions or not is_instance_valid(visual_juice):
		return
	for side: int in [-1, 1]:
		var minion := Node3D.new()
		minion.name = "BlobMinionLeft" if side < 0 else "BlobMinionRight"
		var juice: BlobBossJuice = visual_juice.duplicate() as BlobBossJuice
		juice.name = "VisualJuice"
		minion.add_child(juice)
		add_child(minion)
		juice.apply_world_scale(minion_scale)
		_minion_nodes.append(minion)


func _clear_minions() -> void:
	for m in _minion_nodes:
		if is_instance_valid(m):
			m.queue_free()
	_minion_nodes.clear()


## Places minions left/right of the boss, spaced by their actual mesh widths.
func _layout_minions(camera: Camera3D) -> void:
	if _minion_nodes.is_empty():
		return

	var right: Vector3 = Vector3.RIGHT
	var toward_cam: Vector3 = Vector3.BACK
	if is_instance_valid(camera):
		right = camera.global_transform.basis.x
		right.y = 0.0
		right = right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT
		toward_cam = camera.global_transform.basis.z
		toward_cam.y = 0.0
		toward_cam = toward_cam.normalized() if toward_cam.length_squared() > 0.0001 else Vector3.BACK

	var boss_aabb: AABB = _compute_visual_aabb()
	var boss_center: Vector3 = boss_aabb.get_center() if boss_aabb.size != Vector3.ZERO else global_position
	var boss_half: float = _half_width_along(boss_aabb, right)
	var boss_depth_half: float = _half_width_along(boss_aabb, toward_cam)

	for i in range(_minion_nodes.size()):
		var minion: Node3D = _minion_nodes[i]
		if not is_instance_valid(minion):
			continue
		var side: float = -1.0 if i == 0 else 1.0
		# Reset first so the measured AABB is relative to a known spot
		minion.global_position = global_position
		var m_aabb: AABB = _compute_visual_aabb(minion)
		var m_half: float = _half_width_along(m_aabb, right)
		var m_center_off: Vector3 = (m_aabb.get_center() - minion.global_position) if m_aabb.size != Vector3.ZERO else Vector3.ZERO
		m_center_off.y = 0.0

		# Line the minion's front edge up with the boss's front edge
		var m_depth_half: float = _half_width_along(m_aabb, toward_cam)
		var target_center: Vector3 = boss_center + right * side * (boss_half + m_half + minion_gap) \
			+ toward_cam * (boss_depth_half - m_depth_half + minion_forward_offset)
		var pos: Vector3 = target_center - m_center_off
		pos.y = global_position.y
		minion.global_position = pos


## Closest point of an AABB to the camera, measured along the flat forward axis.
func _near_depth(aabb: AABB, cam_origin: Vector3, forward: Vector3) -> float:
	var cam_xz := Vector3(cam_origin.x, 0.0, cam_origin.z)
	var center: Vector3 = aabb.get_center()
	center.y = 0.0
	return (center - cam_xz).dot(forward) - _half_width_along(aabb, forward)


func _half_width_along(aabb: AABB, axis: Vector3) -> float:
	if aabb.size == Vector3.ZERO:
		return 1.0
	var e: Vector3 = aabb.size * 0.5
	return absf(e.x * axis.x) + absf(e.y * axis.y) + absf(e.z * axis.z)


func _on_combat_started(combat_enemy_data: Variant, _player_party: Array = [], _enemy_facing: String = "") -> void:
	if not _is_triggered or _is_in_active_combat:
		return
	if _matches_this_enemy(combat_enemy_data):
		_is_in_active_combat = true
		visible = true


func _matches_this_enemy(payload: Variant) -> bool:
	if payload is Array:
		for item in (payload as Array):
			if enemy_group.has(item):
				return true
		return false
	return payload == base_data or enemy_group.has(payload)


func _on_combat_ended(victory: bool) -> void:
	if not _is_in_active_combat:
		return

	_is_in_active_combat = false

	# Unlock player movement when combat concludes
	_resolve_player_ref()
	if is_instance_valid(_player_ref) and _player_ref.has_method("set_movement_locked"):
		_player_ref.call("set_movement_locked", false)

	if victory:
		defeated.emit()
		queue_free()
	else:
		# Player fled or died; sink back into the original trigger spot
		_is_triggered = false
		_clear_minions()
		if is_instance_valid(visual_juice):
			visual_juice.apply_world_scale(boss_scale)
		global_position = _home_position
		global_position.y = _rest_y - rise_depth
		visible = false
