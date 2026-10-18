# res://Scripts/Enemies/TentacleBossController.gd
class_name TentacleBossController
extends Node3D

const GROUP_LAKE_BOSS: StringName = &"lake_boss"

@export var data: EnemyData:
	get:
		return _enemy_data
	set(val):
		_enemy_data = val
		if _enemy_data:
			current_health = _enemy_data.max_health
		_update_enemy_group()

@export var destroy_on_victory: bool = true
@export var rise_depth: float = 6.0
@export var rise_duration: float = 2.8

var _enemy_data: EnemyData
var current_health: int = 230
var _is_in_active_combat: bool = false
var _is_revealed: bool = false
var _waiting_for_loot: bool = false
var enemy_group: Array[Resource] = []

@onready var visual_juice: Node3D = $VisualJuice
@onready var activation_area: Area3D = get_node_or_null("ActivationArea") as Area3D

var _anim_player: AnimationPlayer


func _ready() -> void:
	add_to_group(GROUP_LAKE_BOSS)
	visible = false
	if is_instance_valid(activation_area):
		activation_area.monitoring = false
	if _enemy_data:
		current_health = _enemy_data.max_health
	_update_enemy_group()
	_setup_animation_player()
	_connect_signals()


func _update_enemy_group() -> void:
	enemy_group.clear()
	if not is_instance_valid(_enemy_data):
		return

	var res: EnemyData = _enemy_data.duplicate(true) as EnemyData
	if "model_scene" in _enemy_data and _enemy_data.get("model_scene") != null:
		res.set("model_scene", _enemy_data.get("model_scene"))
	if "texture_path" in _enemy_data and not str(_enemy_data.get("texture_path")).is_empty():
		res.set("texture_path", _enemy_data.get("texture_path"))
	enemy_group.append(res)


func _connect_signals() -> void:
	var sb: Node = SignalBus
	if is_instance_valid(sb):
		if not sb.combat_started.is_connected(_on_combat_started):
			sb.combat_started.connect(_on_combat_started)
		if not sb.combat_ended.is_connected(_on_combat_ended):
			sb.combat_ended.connect(_on_combat_ended)
		if not sb.popup_confirmed.is_connected(_on_popup_confirmed):
			sb.popup_confirmed.connect(_on_popup_confirmed)

	if is_instance_valid(activation_area):
		if not activation_area.body_entered.is_connected(_on_body_entered):
			activation_area.body_entered.connect(_on_body_entered)


func _setup_animation_player() -> void:
	_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer


func play_idle() -> void:
	if not is_instance_valid(_anim_player):
		return

	var clip: StringName = _resolve_clip([&"idle", &"Idle", &"ArmatureAction", &"Armature|ArmatureAction"])
	if clip.is_empty():
		var available: PackedStringArray = _anim_player.get_animation_list()
		if available.is_empty():
			return
		clip = StringName(available[0])

	var anim: Animation = _anim_player.get_animation(clip)
	if is_instance_valid(anim):
		anim.loop_mode = Animation.LOOP_LINEAR
	_anim_player.play(clip)


func play_attack() -> void:
	if not is_instance_valid(_anim_player):
		return

	var clip: StringName = _resolve_clip([&"attack", &"Attack", &"ArmatureAction", &"Armature|ArmatureAction"])
	if clip.is_empty():
		play_idle()
		return

	_anim_player.play(clip)
	if not _anim_player.animation_finished.is_connected(_on_animation_finished):
		_anim_player.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)


func _resolve_clip(candidates: Array) -> StringName:
	if not is_instance_valid(_anim_player):
		return &""
	for candidate in candidates:
		var name := StringName(str(candidate))
		if _anim_player.has_animation(name):
			return name
	return &""


func _on_animation_finished(_anim_name: StringName) -> void:
	play_idle()


func get_grid_pos() -> Vector2i:
	var map_mgr: Node = get_tree().root.find_child("MapManager", true, false)
	if is_instance_valid(map_mgr) and map_mgr.has_method("world_to_grid"):
		var cell: Vector3i = map_mgr.call("world_to_grid", global_position) as Vector3i
		return Vector2i(cell.x, cell.z)
	return Vector2i(roundi(global_position.x / 2.0), roundi(global_position.z / 2.0))


func queue_reveal_after_loot() -> void:
	if _is_revealed or _waiting_for_loot:
		return
	_waiting_for_loot = true
	if is_instance_valid(GameLogger):
		GameLogger.combat("Lake tentacles cleared. The boss will rise after loot is claimed.")


func _on_popup_confirmed(action_type: StringName, _extra_data: Dictionary) -> void:
	if action_type != &"BATTLE_VICTORY" or not _waiting_for_loot:
		return
	_waiting_for_loot = false
	reveal_boss()


func reveal_boss() -> void:
	if _is_revealed:
		return

	_is_revealed = true
	visible = true
	if not is_in_group(&"world_enemies"):
		add_to_group(&"world_enemies")
	play_idle()

	var rest_y: float = global_position.y
	global_position.y = rest_y - rise_depth
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position:y", rest_y, rise_duration) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_rise_finished, CONNECT_ONE_SHOT)

	if is_instance_valid(GameLogger):
		GameLogger.combat("The lake surface breaks — the sea monster rises.")


func _on_rise_finished() -> void:
	if is_instance_valid(activation_area):
		activation_area.monitoring = true


func _on_body_entered(body: Node) -> void:
	if not _is_revealed or _is_in_active_combat:
		return
	if body.is_in_group(&"player") or body.name == "Player" or body is CharacterBody3D:
		trigger_combat_encounter()


func trigger_combat_encounter() -> void:
	if not _is_revealed or _is_in_active_combat:
		return
	if "post_combat_immunity_timer" in GameState and GameState.post_combat_immunity_timer > 0.0:
		return

	var cm: Node = get_tree().root.get_node_or_null("CombatManager")
	if is_instance_valid(cm):
		if cm.get("is_combat_active") or ("is_transitioning_out" in cm and cm.get("is_transitioning_out")):
			return

	if enemy_group.is_empty():
		_update_enemy_group()

	_is_in_active_combat = true
	visible = false

	var party_slots: Array = []
	if "current_party" in GameState and GameState.current_party != null:
		if "slots" in GameState.current_party:
			party_slots = GameState.current_party.slots

	if is_instance_valid(GameLogger):
		GameLogger.combat("Player engaged the sea monster at cell Vector2i%s" % get_grid_pos())

	SignalBus.combat_started.emit(enemy_group, party_slots, "SOUTH")


func trigger_battle() -> void:
	trigger_combat_encounter()


func _payload_matches_this_pack(combat_enemy_data: Variant) -> bool:
	if combat_enemy_data is Array:
		var arr: Array = combat_enemy_data as Array
		if arr == enemy_group:
			return true
		for item in arr:
			if enemy_group.has(item):
				return true
		return false

	if is_instance_valid(combat_enemy_data):
		if combat_enemy_data == data or enemy_group.has(combat_enemy_data):
			return true
	return false


func _on_combat_started(combat_enemy_data: Variant, _player_party: Array = [], _enemy_facing: String = "") -> void:
	if not _is_revealed or _is_in_active_combat or not visible:
		return
	if _payload_matches_this_pack(combat_enemy_data):
		_is_in_active_combat = true
		visible = false


func _on_combat_ended(victory: bool) -> void:
	if not _is_in_active_combat:
		return

	_is_in_active_combat = false

	if victory:
		if destroy_on_victory:
			queue_free()
		else:
			visible = false
	else:
		visible = true


func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	on_take_hit()
	if current_health <= 0:
		on_defeated()


func on_take_hit() -> void:
	if visual_juice and visual_juice.has_method("play_hit_shake"):
		visual_juice.call("play_hit_shake")


func on_defeated() -> void:
	if visual_juice and visual_juice.has_method("play_death_sink"):
		visual_juice.call("play_death_sink")
