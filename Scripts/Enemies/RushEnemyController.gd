# res://Scripts/Enemies/RushEnemyController.gd
class_name RushEnemyController
extends Node3D

## An enemy that bursts out of a wall when the party steps into its TriggerArea, yells,
## sprints at the party and starts a battle on contact.
##
## Placement: put this node on the floor RIGHT IN FRONT of the wall it comes out of, rotated
## so its local +Z (blue arrow) points AWAY from the wall. Then move/resize the child
## TriggerArea box (right-click the instance > Editable Children to edit it in a level).
##
## The battle model is spawned by EnemyVisualManager centered in front of the camera, so it
## doesn't matter which side the rusher came from.

enum AudioMode {
	## One clip (yell + footsteps). The rush is timed so the hit lands as the clip ends.
	CAPTURE_CLIP,
	## Yell first, then loop the running sound until the enemy reaches the party.
	YELL_THEN_RUN_LOOP,
}

enum State { IDLE, EMERGING, TAUNTING, RUSHING, IMPACT, IN_COMBAT, RETREATING, DEFEATED }

const DEFAULT_CAPTURE: AudioStream = preload("res://Audio/Enemies/azure_capture.mp3")
const DEFAULT_YELL: AudioStream = preload("res://Audio/Enemies/azure_yell.mp3")
const DEFAULT_RUN: AudioStream = preload("res://Audio/Enemies/gravel_run.mp3")

@export_group("Encounter")
@export var enemy_data: EnemyData
## How many copies of enemy_data are in the fight (ignored if enemy_group is filled in).
@export_range(1, 6) var pack_size: int = 1
## Optional explicit list of enemies for the battle.
@export var enemy_group: Array[Resource] = []

@export_group("Emerge")
## How far inside the wall the enemy starts before stepping out.
@export var emerge_distance: float = 1.2
@export var emerge_time: float = 0.35
## Time spent yelling / taunting before the sprint (CAPTURE_CLIP mode).
## In YELL_THEN_RUN_LOOP mode the taunt lasts at least as long as the yell sound.
@export var taunt_time: float = 1.2
## Raise/lower the model relative to this node.
@export var model_y_offset: float = 0.0

@export_group("Rush")
@export var audio_mode: AudioMode = AudioMode.CAPTURE_CLIP
@export var capture_sound: AudioStream = DEFAULT_CAPTURE
@export var yell_sound: AudioStream = DEFAULT_YELL
@export var run_loop_sound: AudioStream = DEFAULT_RUN
## Seconds of the capture clip that play AFTER the enemy reaches the party (the impact beat).
@export var capture_tail: float = 0.3
## Sprint speed in YELL_THEN_RUN_LOOP mode (meters per second).
@export var run_speed: float = 6.0
## The enemy stops this far in front of the camera. Keep equal to the enemy's combat_forward_distance.
@export var stop_distance: float = 2.5
## Speed (m/s) at which the sprint animation plays at normal speed.
@export var sprint_anim_reference_speed: float = 4.0
@export_range(-30.0, 12.0, 0.5) var audio_volume_db: float = 0.0
## Positional audio: footsteps get louder as it closes in.
@export var use_3d_audio: bool = true
@export var impact_shake: float = 0.6

@export_group("Torch")
## When the torch mechanic exists: a lit torch makes the enemy stop, sink and skip the battle.
@export var repelled_by_torch: bool = true
@export var sink_time: float = 1.0
## After sinking, the enemy can ambush again the next time the party enters the area.
@export var rearm_after_retreat: bool = true

var _state: State = State.IDLE
var _serial: int = 0
var _home: Vector3 = Vector3.ZERO
var _player: Node3D = null

var _pivot: Node3D = null
var _model: Node3D = null
var _anim: AnimationPlayer = null
var _audio: Node = null # AudioStreamPlayer3D or AudioStreamPlayer
var _area: Area3D = null

var _rush_from: Vector3 = Vector3.ZERO
var _rush_target: Vector3 = Vector3.ZERO
var _rush_elapsed: float = 0.0
var _rush_duration: float = 1.0
var _rush_accelerates: bool = true


func _ready() -> void:
	_area = get_node_or_null("TriggerArea") as Area3D
	_home = global_position
	_pivot = get_node_or_null("ModelPivot") as Node3D
	if not is_instance_valid(_pivot):
		_pivot = Node3D.new()
		_pivot.name = "ModelPivot"
		add_child(_pivot)
	_pivot.visible = false

	_build_model()
	_build_audio()
	_build_enemy_group()

	if is_instance_valid(_area) and not _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.connect(_on_body_entered)
	if is_instance_valid(SignalBus) and not SignalBus.combat_ended.is_connected(_on_combat_ended):
		SignalBus.combat_ended.connect(_on_combat_ended)


# ==============================================================================
# SETUP
# ==============================================================================
func _build_model() -> void:
	if not is_instance_valid(enemy_data) or not is_instance_valid(enemy_data.model_scene):
		push_warning("RushEnemyController '%s': enemy_data has no model_scene." % name)
		return

	_model = enemy_data.model_scene.instantiate() as Node3D
	_pivot.add_child(_model)
	# Same size as the battle model so nothing pops when the fight starts
	_model.scale = enemy_data.model_scale if enemy_data.model_scale != Vector3.ZERO else Vector3.ONE
	# Pivot's -Z looks at the target; most GLBs face +Z, so turn the mesh around (same as battle)
	_model.rotation.y = deg_to_rad(enemy_data.combat_yaw_offset_degrees)
	_model.position.y = model_y_offset

	if is_instance_valid(enemy_data.custom_material):
		_apply_material_recursive(_model, enemy_data.custom_material)

	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)


func _build_audio() -> void:
	var bus: StringName = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
	if use_3d_audio:
		var p3d := AudioStreamPlayer3D.new()
		p3d.unit_size = 8.0
		p3d.max_db = 6.0
		p3d.volume_db = audio_volume_db
		p3d.bus = bus
		_pivot.add_child(p3d)
		_audio = p3d
	else:
		var p2d := AudioStreamPlayer.new()
		p2d.volume_db = audio_volume_db
		p2d.bus = bus
		add_child(p2d)
		_audio = p2d


func _build_enemy_group() -> void:
	if not enemy_group.is_empty() or not is_instance_valid(enemy_data):
		return
	for i in range(pack_size):
		enemy_group.append(enemy_data.duplicate(true) if pack_size > 1 else enemy_data)


# ==============================================================================
# TRIGGER
# ==============================================================================
func _on_body_entered(body: Node) -> void:
	if _state != State.IDLE or not _is_player(body):
		return
	if enemy_group.is_empty():
		push_warning("RushEnemyController '%s': no enemy_data / enemy_group set, so no ambush (would be an empty battle)." % name)
		return
	if bool(CombatManager.get("is_combat_active")):
		return
	if GameState.has_method("can_begin_encounter") and not GameState.can_begin_encounter():
		return
	_start_ambush(body as Node3D)


func _is_player(body: Node) -> bool:
	return body.is_in_group(&"player") or body.name == "Player" or body is DungeonPlayer


func _start_ambush(player: Node3D) -> void:
	_serial += 1
	var serial: int = _serial
	_player = player
	_state = State.EMERGING

	# Freeze the party and stop other enemies from starting a fight mid-rush
	if is_instance_valid(_player) and _player.has_method("set_movement_locked"):
		_player.call("set_movement_locked", true)
	if GameState.has_method("lock_encounters"):
		GameState.lock_encounters(30.0)

	GameLogger.combat("%s bursts out of the rock!" % (enemy_data.enemy_name if is_instance_valid(enemy_data) else name))

	# Start inside the wall and step out of it
	var out_dir: Vector3 = global_basis.z
	out_dir.y = 0.0
	out_dir = out_dir.normalized() if out_dir.length_squared() > 0.0001 else Vector3.BACK
	_pivot.global_position = _home - out_dir * emerge_distance
	_pivot.visible = true
	_face_toward(_player.global_position)
	_play_anim(&"idle", true)

	if audio_mode == AudioMode.CAPTURE_CLIP:
		_play_sound(capture_sound, false)
	else:
		_play_sound(yell_sound, false)

	var tween: Tween = create_tween()
	tween.tween_property(_pivot, "global_position", _home, maxf(0.01, emerge_time)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(emerge_time).timeout
	if serial != _serial:
		return
	if _should_retreat():
		_retreat(serial)
		return

	# Yell / taunt
	_state = State.TAUNTING
	_face_toward(_player.global_position)
	_play_anim(&"taunt", true)
	var taunt: float = taunt_time
	if audio_mode == AudioMode.YELL_THEN_RUN_LOOP and is_instance_valid(yell_sound):
		taunt = maxf(taunt_time, yell_sound.get_length())
	await get_tree().create_timer(taunt).timeout
	if serial != _serial:
		return
	if _should_retreat():
		_retreat(serial)
		return

	_begin_rush()


func _begin_rush() -> void:
	_state = State.RUSHING
	_rush_from = _pivot.global_position
	_rush_target = _compute_rush_target()
	_rush_elapsed = 0.0
	var distance: float = _rush_from.distance_to(_rush_target)

	if audio_mode == AudioMode.CAPTURE_CLIP and is_instance_valid(capture_sound):
		# Arrive so the hit lands capture_tail seconds before the clip ends
		var remaining: float = capture_sound.get_length() - emerge_time - taunt_time - capture_tail
		_rush_duration = maxf(0.6, remaining)
		_rush_accelerates = true
	else:
		_rush_duration = maxf(0.3, distance / maxf(0.5, run_speed))
		_rush_accelerates = false
		_play_sound(run_loop_sound, true)

	_play_anim(&"sprint", true)


## Stops stop_distance in front of the camera, so the runner ends up where the battle model appears.
func _compute_rush_target() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var origin: Vector3 = _player.global_position if is_instance_valid(_player) else _home
	var forward: Vector3 = Vector3.FORWARD
	if is_instance_valid(camera):
		origin = camera.global_position
		forward = -camera.global_basis.z
	elif is_instance_valid(_player):
		forward = -_player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var target: Vector3 = origin + forward * stop_distance
	target.y = _home.y
	return target


func _process(delta: float) -> void:
	if _state != State.RUSHING:
		return

	if _should_retreat():
		_retreat(_serial)
		return

	_rush_elapsed += delta
	var t: float = clampf(_rush_elapsed / _rush_duration, 0.0, 1.0)
	# Capture clip: start slow, build up as the footsteps get louder
	var eased: float = pow(t, 1.6) if _rush_accelerates else t

	var previous: Vector3 = _pivot.global_position
	_pivot.global_position = _rush_from.lerp(_rush_target, eased)
	_face_toward(_rush_target)

	if is_instance_valid(_anim) and delta > 0.0:
		var speed: float = previous.distance_to(_pivot.global_position) / delta
		_anim.speed_scale = clampf(speed / maxf(0.1, sprint_anim_reference_speed), 0.7, 1.8)

	if t >= 1.0:
		_on_reached_party(_serial)


func _on_reached_party(serial: int) -> void:
	_state = State.IMPACT
	if is_instance_valid(_anim):
		_anim.speed_scale = 1.0
	if audio_mode == AudioMode.YELL_THEN_RUN_LOOP:
		_stop_sound()

	var camera: Camera3D = get_viewport().get_camera_3d()
	if is_instance_valid(camera):
		_face_toward(camera.global_position)
	_play_anim(&"attack", false)
	SignalBus.camera_shake_requested.emit(impact_shake)

	await get_tree().create_timer(maxf(0.15, capture_tail)).timeout
	if serial != _serial:
		return
	_start_battle()


func _start_battle() -> void:
	_state = State.IN_COMBAT
	_pivot.visible = false # EnemyVisualManager spawns the battle model centered on the camera
	if GameState.has_method("clear_encounter_lock"):
		GameState.clear_encounter_lock()

	var party_slots: Array = []
	if "current_party" in GameState and GameState.current_party != null and "slots" in GameState.current_party:
		party_slots = GameState.current_party.slots

	GameLogger.combat("%s caught the party! Battle starts." % (enemy_data.enemy_name if is_instance_valid(enemy_data) else name))
	SignalBus.combat_started.emit(enemy_group, party_slots, "SOUTH")


func _on_combat_ended(victory: bool) -> void:
	if _state != State.IN_COMBAT:
		return
	_unlock_player()
	if victory:
		_state = State.DEFEATED
		queue_free()
		return
	# Fled or lost: hide back in the wall. It strikes again next time the party walks in.
	_reset_to_hidden()


# ==============================================================================
# TORCH RETREAT
# ==============================================================================
## Placeholder hook for the torch mechanic. Returns true while the party holds a lit torch.
func _should_retreat() -> bool:
	if not repelled_by_torch:
		return false
	if GameState.has_method("is_torch_lit"):
		return bool(GameState.call("is_torch_lit"))
	if "has_lit_torch" in GameState:
		return bool(GameState.get("has_lit_torch"))
	return false


func _retreat(serial: int) -> void:
	if _state == State.RETREATING:
		return
	_state = State.RETREATING
	_stop_sound()
	if is_instance_valid(_anim):
		_anim.speed_scale = 1.0
	_play_anim(&"idle", true)
	GameLogger.combat("%s recoils from the torchlight and sinks into the ground!" % (enemy_data.enemy_name if is_instance_valid(enemy_data) else name))

	var sunk: Vector3 = _pivot.global_position + Vector3.DOWN * 2.5
	var tween: Tween = create_tween()
	tween.tween_property(_pivot, "global_position", sunk, maxf(0.1, sink_time)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if serial != _serial:
		return

	_unlock_player()
	if GameState.has_method("clear_encounter_lock"):
		GameState.clear_encounter_lock()
	if rearm_after_retreat:
		_reset_to_hidden()
	else:
		queue_free()


# ==============================================================================
# HELPERS
# ==============================================================================
func _reset_to_hidden() -> void:
	_serial += 1
	_state = State.IDLE
	_stop_sound()
	if is_instance_valid(_pivot):
		_pivot.visible = false
		_pivot.global_position = _home
	if is_instance_valid(_anim):
		_anim.speed_scale = 1.0


func _unlock_player() -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	if is_instance_valid(_player) and _player.has_method("set_movement_locked"):
		_player.call("set_movement_locked", false)


func _face_toward(world_point: Vector3) -> void:
	if not is_instance_valid(_pivot):
		return
	var flat: Vector3 = Vector3(world_point.x, _pivot.global_position.y, world_point.z)
	if _pivot.global_position.distance_squared_to(flat) > 0.0004:
		_pivot.look_at(flat, Vector3.UP)


func _play_sound(stream: AudioStream, loop: bool) -> void:
	if not is_instance_valid(_audio) or not is_instance_valid(stream):
		return
	var s: AudioStream = stream
	if loop and "loop" in stream:
		s = stream.duplicate()
		s.set("loop", true)
	_audio.set("stream", s)
	_audio.call("play")


func _stop_sound() -> void:
	if is_instance_valid(_audio):
		_audio.call("stop")


const ANIM_ALIASES: Dictionary = {
	&"idle": [&"idle", &"Idle", &"IDLE"],
	&"taunt": [&"emote-yes", &"emote-no", &"Taunt", &"taunt", &"idle"],
	&"sprint": [&"sprint", &"Sprint", &"run", &"Run", &"walk"],
	&"attack": [&"attack-melee-right", &"attack-kick-right", &"Attack", &"attack"],
}


func _play_anim(key: StringName, loop: bool) -> void:
	if not is_instance_valid(_anim):
		return
	for candidate in ANIM_ALIASES.get(key, [key]):
		var anim_name := StringName(str(candidate))
		if _anim.has_animation(anim_name):
			var anim: Animation = _anim.get_animation(anim_name)
			if is_instance_valid(anim):
				anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
			_anim.play(anim_name)
			return
