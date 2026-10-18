# res://Scripts/Enemies/world_enemy.gd
class_name OutdoorEnemy
extends Node3D

## Enemy data resource(s) for combat encounter
@export var enemy_data: Resource
@export var enemy_group: Array[Resource] = []

## Enemy type identifier used by AudioManager for sound loops (e.g. "minotaur")
@export var enemy_type: String = "minotaur"

## Uniform scale multiplier applied to the enemy 3D model
@export var model_scale: Vector3 = Vector3(0.08, 0.08, 0.08)

## Movement speed interval (seconds between grid steps)
@export var movement_speed: float = 2.5

## If true, this enemy only appears at night and burrows into the ground during the day
@export var is_night_only: bool = true

## Depth (meters below ground) when submerged
@export var burrow_depth: float = 3.5

## Duration of burrow/emerge animation in seconds
@export var transition_duration: float = 1.2

@export var is_active: bool = true

const ANIM_MAPPINGS: Dictionary = {
	&"idle": [&"Armature|idle", &"IDLE", &"Idle", &"idle", &"idle_loop", &"Idle_Loop"],
	&"walk": [&"Armature|Walk", &"WALK", &"Walk", &"walk", &"walking", &"Walking", &"walk_loop", &"Walk_Loop", &"Run", &"run"]
}

const PATROL_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), # North
	Vector2i(1, 0),  # East
	Vector2i(0, 1),  # South
	Vector2i(-1, 0)  # West
]

var _origin_y: float = 0.0
var _current_tween: Tween = null
var _interaction_area: Area3D = null
var _static_body: StaticBody3D = null
var _move_timer: float = 0.0
var _is_moving: bool = false
var _patrol_index: int = 0
var _is_in_active_combat: bool = false

func _ready() -> void:
	add_to_group(&"world_enemies")
	_origin_y = global_position.y
	_interaction_area = find_child("Area3D", true, false) as Area3D
	_static_body = find_child("StaticBody3D", true, false) as StaticBody3D
	
	var model_node: Node3D = find_child("Model", true, false) as Node3D
	if is_instance_valid(model_node):
		model_node.scale = model_scale

	# Duplicate template resource so this instance has an independent HP pool
	if is_instance_valid(enemy_data):
		enemy_data = enemy_data.duplicate(true)
		if "current_hp" in enemy_data and "max_hp" in enemy_data:
			enemy_data.set("current_hp", enemy_data.get("max_hp"))
		elif "current_health" in enemy_data and "max_health" in enemy_data:
			enemy_data.set("current_health", enemy_data.get("max_health"))

	if enemy_group.is_empty() and is_instance_valid(enemy_data):
		enemy_group.append(enemy_data)
		
	if enemy_type.is_empty() and is_instance_valid(enemy_data) and "enemy_type" in enemy_data:
		enemy_type = str(enemy_data.get("enemy_type"))
		
	_connect_signals()
	_evaluate_time_state(_check_initial_is_night())
	_play_animation(&"idle", true)

func set_spawn_position(pos: Vector3) -> void:
	global_position = pos
	_origin_y = pos.y
	_evaluate_time_state(_check_initial_is_night())

func get_grid_pos() -> Vector2i:
	return Vector2i(roundi(global_position.x / 2.0), roundi(global_position.z / 2.0))

func _connect_signals() -> void:
	if is_instance_valid(_interaction_area):
		if not _interaction_area.body_entered.is_connected(_on_body_entered):
			_interaction_area.body_entered.connect(_on_body_entered)
		if not _interaction_area.area_entered.is_connected(_on_area_entered):
			_interaction_area.area_entered.connect(_on_area_entered)

	var sb: Node = SignalBus if is_instance_valid(SignalBus) else get_node_or_null("/root/SignalBus")
	if is_instance_valid(sb):
		if sb.has_signal(&"day_night_changed") and not sb.day_night_changed.is_connected(_on_day_night_changed):
			sb.day_night_changed.connect(_on_day_night_changed)
		if sb.has_signal(&"combat_started") and not sb.combat_started.is_connected(_on_combat_started):
			sb.combat_started.connect(_on_combat_started)
		if sb.has_signal(&"combat_ended") and not sb.combat_ended.is_connected(_on_combat_ended):
			sb.combat_ended.connect(_on_combat_ended)

func _check_initial_is_night() -> bool:
	var game_state: Node = get_node_or_null("/root/GameState")
	if is_instance_valid(game_state) and "current_time_period" in game_state:
		return str(game_state.current_time_period) == "NIGHT"
	return false

func _on_day_night_changed(is_night: bool) -> void:
	if is_night_only:
		_evaluate_time_state(is_night)

func _evaluate_time_state(is_night: bool) -> void:
	if not is_night_only or is_night:
		_emerge_from_ground()
	else:
		_burrow_into_ground()

func _process(delta: float) -> void:
	if not is_active or not visible or _is_moving or _is_in_active_combat:
		return

	if not enemy_type.is_empty():
		_check_audio_proximity()

	# Continuously check player distance every frame regardless of direction/angle
	_check_player_distance()

	_move_timer += delta
	if _move_timer >= movement_speed:
		_move_timer = 0.0
		_step_patrol()

func _step_patrol() -> void:
	if randf() < 0.4:
		_patrol_index = randi() % PATROL_OFFSETS.size()

	var offset: Vector2i = PATROL_OFFSETS[_patrol_index]
	var target_pos: Vector3 = global_position + Vector3(offset.x * 2.0, 0.0, offset.y * 2.0)
	target_pos.y = _origin_y

	var model_node: Node3D = find_child("Model", true, false) as Node3D
	if is_instance_valid(model_node):
		var look_target := Vector3(target_pos.x, model_node.global_position.y, target_pos.z)
		if look_target.distance_squared_to(model_node.global_position) > 0.01:
			model_node.look_at(look_target, Vector3.UP)
			model_node.rotate_object_local(Vector3.UP, PI)

	_is_moving = true
	_play_animation(&"walk", true)

	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, 0.6) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)

	tween.finished.connect(func() -> void:
		_is_moving = false
		_play_animation(&"idle", true)
		_check_player_distance()
	, CONNECT_ONE_SHOT)

func _check_player_distance() -> void:
	if _is_in_active_combat or not is_active or not visible:
		return

	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if not is_instance_valid(player):
		player = get_viewport().get_camera_3d()

	if is_instance_valid(player):
		var dist: float = global_position.distance_to(player.global_position)
		if dist <= 2.5:
			trigger_combat_encounter()

func _check_audio_proximity() -> void:
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if not is_instance_valid(player):
		player = get_viewport().get_camera_3d()
	
	if is_instance_valid(player):
		var dist: float = global_position.distance_to(player.global_position)
		var audio_mgr: Node = get_node_or_null("/root/AudioManager")
		if is_instance_valid(audio_mgr) and audio_mgr.has_method("sync_nearby_enemy_loops"):
			if dist <= 12.0:
				var nearby_types: Array[String] = [enemy_type]
				audio_mgr.sync_nearby_enemy_loops(nearby_types)

func _on_body_entered(body: Node) -> void:
	if not is_active or _is_in_active_combat:
		return
	if body.is_in_group(&"player") or body.name == "Player" or body.name.begins_with("Player") or body is CharacterBody3D:
		trigger_combat_encounter()

func _on_area_entered(area: Area3D) -> void:
	if not is_active or _is_in_active_combat:
		return
	var parent_node: Node = area.get_parent()
	if area.is_in_group(&"player") or (is_instance_valid(parent_node) and parent_node.is_in_group(&"player")):
		trigger_combat_encounter()

func trigger_combat_encounter() -> void:
	if _is_in_active_combat or not is_active or not visible:
		return

	var cm: Node = get_tree().root.get_node_or_null("CombatManager")
	if is_instance_valid(cm):
		if cm.get("is_combat_active") or ("is_transitioning_out" in cm and cm.get("is_transitioning_out")):
			return

	_is_in_active_combat = true
	hide()

	if enemy_group.is_empty() and is_instance_valid(enemy_data):
		enemy_group.append(enemy_data)

	var party_slots: Array = []
	var gs: Node = get_node_or_null("/root/GameState")
	if is_instance_valid(gs) and "current_party" in gs and gs.current_party != null:
		if "slots" in gs.current_party:
			party_slots = gs.current_party.slots

	var sb: Node = SignalBus if is_instance_valid(SignalBus) else get_node_or_null("/root/SignalBus")
	if is_instance_valid(sb) and sb.has_signal(&"combat_started"):
		sb.combat_started.emit(enemy_group, party_slots, "SOUTH")

func _on_combat_started(enemy_payload: Variant, _party: Array, _enemy_facing: String) -> void:
	if not visible or _is_in_active_combat:
		return

	var is_target: bool = false
	if enemy_payload is Array:
		var payload_array: Array = enemy_payload as Array
		if payload_array == enemy_group:
			is_target = true
		else:
			for item in payload_array:
				if item == self or enemy_group.has(item):
					is_target = true
					break
	elif enemy_payload is Object and is_instance_valid(enemy_payload):
		if enemy_payload == self or enemy_group.has(enemy_payload):
			is_target = true

	if is_target:
		_is_in_active_combat = true
		hide()

func _on_combat_ended(victory: bool) -> void:
	if not _is_in_active_combat:
		return

	if victory:
		queue_free()
	else:
		_is_in_active_combat = false
		show()

func _burrow_into_ground() -> void:
	if _current_tween and _current_tween.is_running():
		_current_tween.kill()

	is_active = false
	if is_in_group(&"world_enemies"):
		remove_from_group(&"world_enemies")
	if is_instance_valid(_interaction_area):
		_interaction_area.monitoring = false
		_interaction_area.monitorable = false
	if is_instance_valid(_static_body):
		_static_body.process_mode = PROCESS_MODE_DISABLED

	_current_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_current_tween.tween_property(self, "global_position:y", _origin_y - burrow_depth, transition_duration)
	_current_tween.tween_callback(func() -> void:
		visible = false
	)

func _emerge_from_ground() -> void:
	if _current_tween and _current_tween.is_running():
		_current_tween.kill()

	visible = true
	_current_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(self, "global_position:y", _origin_y, transition_duration)
	_current_tween.tween_callback(func() -> void:
		is_active = true
		if not is_in_group(&"world_enemies"):
			add_to_group(&"world_enemies")
		if is_instance_valid(_interaction_area):
			_interaction_area.monitoring = true
			_interaction_area.monitorable = true
		if is_instance_valid(_static_body):
			_static_body.process_mode = PROCESS_MODE_INHERIT
		_play_animation(&"idle", true)
		_check_player_distance()
	)

func _play_animation(action_key: StringName, loop: bool = true) -> void:
	var anim_player: AnimationPlayer = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not is_instance_valid(anim_player):
		return

	var resolved_anim: StringName = _resolve_animation_name(anim_player, action_key)
	if resolved_anim.is_empty():
		return

	var anim: Animation = anim_player.get_animation(resolved_anim)
	if is_instance_valid(anim):
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE

	if anim_player.current_animation != resolved_anim:
		anim_player.play(resolved_anim)

func _resolve_animation_name(anim_player: AnimationPlayer, action_key: StringName) -> StringName:
	var candidates: Array = ANIM_MAPPINGS.get(action_key, [action_key])

	for candidate in candidates:
		var cand_name := StringName(str(candidate))
		if anim_player.has_animation(cand_name):
			return cand_name

	var available: PackedStringArray = anim_player.get_animation_list()
	for candidate in candidates:
		var cand_str: String = str(candidate).to_lower()
		for anim_name in available:
			if cand_str in anim_name.to_lower():
				return StringName(anim_name)

	return &""
