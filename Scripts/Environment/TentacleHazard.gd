# res://Scripts/Environment/TentacleHazard.gd
class_name TentacleHazard
extends Node3D

## Environmental hazard: stays frozen until the party comes close, then lashes out.
## A random party member takes damage, the screen gets one big slash, and a toast pops up.
## It is NOT an enemy: it can't be fought or killed, no battle ever starts. Just avoid it.

@export_group("Trigger")
## How close (meters) the party has to get before it strikes.
@export var trigger_radius: float = 2.5:
	set(value):
		trigger_radius = value
		_apply_trigger_radius()
## Keep striking every `cooldown` seconds while the party stays in range.
@export var repeat_while_inside: bool = true
@export var cooldown: float = 3.0

@export_group("Damage")
@export var min_damage: int = 4
@export var max_damage: int = 9
## How many different party members get hit per strike.
@export_range(1, 6) var targets_per_strike: int = 1
## If false, a hit never drops anyone below 1 HP (no deaths outside of battle).
@export var can_knock_out: bool = false

@export_group("Animation & FX")
## Playback speed of the strike animation (the model's own animation).
@export var animation_speed: float = 1.6
## Seconds from the start of the animation until the hit lands.
@export var hit_delay: float = 0.35
@export var camera_shake: float = 0.7
@export var slash_duration: float = 0.7
@export var edge_flash_color: Color = Color(0.9, 0.1, 0.05, 0.8)
## Optional sound played when it strikes (3D, from the tentacle).
@export var strike_sound: AudioStream
@export_range(-30.0, 12.0, 0.5) var strike_volume_db: float = 0.0
## Used in the log, e.g. "A rock tentacle lashes out!"
@export var hazard_name: String = "A rock tentacle"

var _anim: AnimationPlayer = null
var _anim_name: StringName = &""
var _area: Area3D = null
var _audio: AudioStreamPlayer3D = null
var _player_inside: bool = false
var _is_striking: bool = false


func _ready() -> void:
	_area = get_node_or_null("TriggerArea") as Area3D
	_apply_trigger_radius()

	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if is_instance_valid(_anim):
		for anim_name: StringName in _anim.get_animation_list():
			if anim_name != &"RESET":
				_anim_name = anim_name
				break
		if not _anim_name.is_empty():
			var anim: Animation = _anim.get_animation(_anim_name)
			if is_instance_valid(anim):
				anim.loop_mode = Animation.LOOP_NONE
			_anim.animation_finished.connect(_on_animation_finished)
	_freeze_pose()

	if is_instance_valid(strike_sound):
		_audio = AudioStreamPlayer3D.new()
		_audio.stream = strike_sound
		_audio.volume_db = strike_volume_db
		_audio.unit_size = 6.0
		_audio.bus = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
		add_child(_audio)

	if is_instance_valid(_area):
		_area.body_entered.connect(_on_body_entered)
		_area.body_exited.connect(_on_body_exited)


func _apply_trigger_radius() -> void:
	if not is_inside_tree():
		return
	var col: CollisionShape3D = get_node_or_null("TriggerArea/CollisionShape3D") as CollisionShape3D
	if is_instance_valid(col) and col.shape is SphereShape3D:
		(col.shape as SphereShape3D).radius = trigger_radius


## Holds the first frame of the animation so it looks completely still.
func _freeze_pose() -> void:
	if not is_instance_valid(_anim) or _anim_name.is_empty():
		return
	_anim.speed_scale = 1.0
	_anim.play(_anim_name)
	_anim.seek(0.0, true)
	_anim.pause()


func _on_body_entered(body: Node) -> void:
	if not _is_player(body):
		return
	_player_inside = true
	if not _is_striking:
		_strike()


func _on_body_exited(body: Node) -> void:
	if _is_player(body):
		_player_inside = false


func _is_player(body: Node) -> bool:
	return body.is_in_group(&"player") or body.name == "Player" or body is DungeonPlayer


func _strike() -> void:
	if bool(CombatManager.get("is_combat_active")):
		return
	_is_striking = true

	if is_instance_valid(_anim) and not _anim_name.is_empty():
		_anim.speed_scale = animation_speed
		_anim.play(_anim_name)
		_anim.seek(0.0, true)
	if is_instance_valid(_audio):
		_audio.play()

	await get_tree().create_timer(maxf(0.0, hit_delay)).timeout
	if not is_inside_tree():
		return
	_land_hit()

	# Wait for the animation to finish (or a fallback) and then the cooldown
	var anim_left: float = 0.6
	if is_instance_valid(_anim) and not _anim_name.is_empty():
		var length: float = _anim.get_animation(_anim_name).length / maxf(0.1, animation_speed)
		anim_left = maxf(0.0, length - hit_delay)
	await get_tree().create_timer(anim_left + maxf(0.0, cooldown)).timeout
	if not is_inside_tree():
		return

	_is_striking = false
	if repeat_while_inside and _player_inside:
		_strike()


func _land_hit() -> void:
	GameLogger.combat("%s lashes out at the party!" % hazard_name)
	SignalBus.hazard_slash_requested.emit()
	SignalBus.camera_shake_requested.emit(camera_shake)
	SignalBus.edge_flash_requested.emit(edge_flash_color, 0.4)

	var victims: Array[int] = _pick_victims()
	if victims.is_empty():
		SignalBus.show_toast.emit("%s lashes out... and misses!" % hazard_name, false)
		return

	var slots: Array = GameState.current_party.slots
	for slot_idx: int in victims:
		var cat: CatCharacter = slots[slot_idx] as CatCharacter
		var damage: int = randi_range(mini(min_damage, max_damage), maxi(min_damage, max_damage))
		if not can_knock_out:
			damage = mini(damage, cat.current_hp - 1)
		if damage <= 0:
			SignalBus.show_toast.emit("%s barely dodges the tentacle!" % cat.name, false)
			continue

		cat.take_damage(damage)
		SignalBus.character_health_changed.emit(slot_idx, cat.current_hp)
		var msg: String = "⚡ %s took %d damage!" % [cat.name, damage]
		GameLogger.combat(msg)
		SignalBus.show_toast.emit(msg, true)
		if cat.current_hp <= 0:
			SignalBus.show_toast.emit("💀 %s HAS FALLEN!" % cat.name.to_upper(), true)


## Random living party members (slot indices), up to targets_per_strike.
func _pick_victims() -> Array[int]:
	var alive: Array[int] = []
	if not ("current_party" in GameState) or GameState.current_party == null:
		return alive
	var slots: Array = GameState.current_party.slots
	for i in range(slots.size()):
		var cat: CatCharacter = slots[i] as CatCharacter
		if is_instance_valid(cat) and cat.current_hp > 0:
			alive.append(i)
	alive.shuffle()
	return alive.slice(0, mini(targets_per_strike, alive.size()))


func _on_animation_finished(_finished: StringName) -> void:
	_freeze_pose()
