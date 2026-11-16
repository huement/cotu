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

@export_group("Entrance")
## Marker in the level the party is moved to when the last tentacle's loot screen closes.
@export var boss_spawn_point_name: String = "SpawnPoint_Boss"
## Played while the boss rises. Empty = Audio/Enemies/lakemonster_entrance.mp3.
@export var entrance_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var entrance_volume_db: float = 0.0
## The entrance lasts as long as the sound (or the rise, whichever is longer), at least this long.
@export var entrance_min_seconds: float = 3.0
## Small pause after the sound before the battle starts.
@export var entrance_tail_seconds: float = 0.4
@export var quake_size: CameraShake.QuakeSize = CameraShake.QuakeSize.LARGE
## Extra camera jolts layered on the quake while he rises (0 = none).
@export_range(0.0, 1.0, 0.05) var rumble_trauma: float = 0.25
## Edge glow: colour (alpha = how strong at its peak) and seconds per breath.
@export var pulse_color: Color = Color(0.9, 0.04, 0.08, 0.7)
@export var pulse_period: float = 2.2
@export_group("")

@export_group("After Victory")
## Villain whose cutscene plays once the loot screen of this fight is closed (Malviathan placed in
## the level with trigger_on_area OFF). Empty = no cutscene.
@export var post_battle_villain: MalviathanController
@export_group("")

@export_group("Boss Rewards")
## Spell Books / Skill Crystals added to the loot when this boss is beaten (shown on the victory screen).
@export_range(0, 10) var reward_spell_books: int = 1
@export_range(0, 10) var reward_skill_crystals: int = 1
@export_group("")

var _enemy_data: EnemyData
var current_health: int = 230
var _is_in_active_combat: bool = false
var _is_revealed: bool = false
var _waiting_for_loot: bool = false
var _waiting_for_cutscene: bool = false
var _entrance_running: bool = false
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
	if action_type != &"BATTLE_VICTORY":
		return
	if _waiting_for_loot:
		_waiting_for_loot = false
		_play_entrance()
	elif _waiting_for_cutscene:
		_waiting_for_cutscene = false
		_start_post_battle_cutscene()


# ==============================================================================
# Entrance: party moved to SpawnPoint_Boss, quake + red breathing edge + roar, then the fight
# ==============================================================================

func _play_entrance() -> void:
	if _is_revealed or _entrance_running:
		return
	_entrance_running = true
	_is_revealed = true

	# 1. Lock the party (and keep wandering crabs out of it).
	GameState.lock_encounters(60.0)
	var player: DungeonPlayer = get_tree().get_first_node_in_group(&"player") as DungeonPlayer
	if is_instance_valid(player):
		player.set_movement_locked(true)
	await get_tree().process_frame # let GameState leave the victory screen first
	if not is_inside_tree():
		return
	while is_instance_valid(player) and player.is_moving:
		await get_tree().process_frame

	# 2. Straight onto the boss spawn point, facing the lake.
	var spawn: Node3D = _find_boss_spawn_point()
	if is_instance_valid(player):
		if is_instance_valid(spawn):
			player.teleport_to(spawn.global_position, global_position)
		else:
			push_warning("TentacleBoss: no '%s' marker in the level - fighting from where the party stands." % boss_spawn_point_name)

	# 3. Quake + breathing red edge. 4. The roar. The boss rises meanwhile.
	var stream: AudioStream = _get_entrance_sound()
	var duration: float = maxf(entrance_min_seconds, rise_duration)
	if stream != null:
		duration = maxf(duration, stream.get_length())
	SignalBus.edge_pulse_requested.emit(pulse_color, pulse_period)
	_start_quake(duration)
	_play_entrance_sound(stream)
	reveal_boss()
	if is_instance_valid(GameLogger):
		GameLogger.combat("The lake heaves. Something enormous is coming up.")

	var elapsed: float = 0.0
	var next_jolt: float = 0.0
	while elapsed < duration and is_inside_tree():
		if rumble_trauma > 0.0 and elapsed >= next_jolt:
			SignalBus.camera_shake_requested.emit(rumble_trauma * randf_range(0.6, 1.0))
			next_jolt = elapsed + randf_range(0.35, 0.7)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if not is_inside_tree():
		return
	if entrance_tail_seconds > 0.0:
		await get_tree().create_timer(entrance_tail_seconds).timeout
		if not is_inside_tree():
			return

	# 5. Fight.
	SignalBus.edge_pulse_requested.emit(pulse_color, 0.0)
	get_tree().call_group(CameraShake.GROUP_CAMERA_SHAKE, &"stop_earthquake")
	_entrance_running = false
	if is_instance_valid(activation_area):
		activation_area.monitoring = true
	trigger_combat_encounter(true)


func _find_boss_spawn_point() -> Node3D:
	var level: Node = owner if is_instance_valid(owner) else get_parent()
	var found: Node3D = null
	if is_instance_valid(level):
		found = level.find_child(boss_spawn_point_name, true, false) as Node3D
	if found == null:
		found = get_tree().root.find_child(boss_spawn_point_name, true, false) as Node3D
	return found


func _get_entrance_sound() -> AudioStream:
	if entrance_sound != null:
		return entrance_sound
	const FALLBACK: String = "res://Audio/Enemies/lakemonster_entrance.mp3"
	if ResourceLoader.exists(FALLBACK):
		return load(FALLBACK) as AudioStream
	return null


func _play_entrance_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	var audio := AudioStreamPlayer.new()
	audio.stream = stream
	audio.volume_db = entrance_volume_db
	audio.bus = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
	# Parented to the level, not the boss: the boss hides itself when the battle starts.
	var holder: Node = get_parent() if is_instance_valid(get_parent()) else self
	holder.add_child(audio)
	audio.finished.connect(audio.queue_free, CONNECT_ONE_SHOT)
	audio.play()


func _start_quake(duration: float) -> void:
	var loop_len: float = CameraShake.get_earthquake_duration(quake_size, 1)
	var loops: int = maxi(1, ceili(duration / maxf(0.1, loop_len)))
	CameraShake.request_earthquake(get_tree(), quake_size, loops)


func reveal_boss() -> void:
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


# ==============================================================================
# After the fight: loot screen -> villain cutscene (party left at 1% HP / Mana)
# ==============================================================================

func _start_post_battle_cutscene() -> void:
	if is_instance_valid(post_battle_villain) and post_battle_villain.is_inside_tree():
		# The cutscene locks the party itself and unlocks it when it ends.
		await post_battle_villain.start_cutscene()
	else:
		_unlock_player()
	if destroy_on_victory and is_inside_tree():
		queue_free()


func _unlock_player() -> void:
	var player: DungeonPlayer = get_tree().get_first_node_in_group(&"player") as DungeonPlayer
	if is_instance_valid(player):
		player.set_movement_locked(false)


func _on_body_entered(body: Node) -> void:
	if not _is_revealed or _is_in_active_combat or _entrance_running:
		return
	if body.is_in_group(&"player") or body.name == "Player" or body is CharacterBody3D:
		trigger_combat_encounter()


## force = the scripted entrance: skip the post-victory immunity / encounter locks.
func trigger_combat_encounter(force: bool = false) -> void:
	if not _is_revealed or _is_in_active_combat:
		return
	if force:
		GameState.clear_encounter_lock()
		GameState.post_combat_immunity_timer = 0.0
	elif is_instance_valid(GameState) and GameState.has_method("can_begin_encounter") and not GameState.can_begin_encounter():
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

	GameState.register_boss_rewards(reward_spell_books, reward_skill_crystals)
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
		# Stay alive (hidden) until the loot screen closes, then hand over to the villain cutscene.
		visible = false
		_waiting_for_cutscene = true
	else:
		visible = true
		_unlock_player()


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
