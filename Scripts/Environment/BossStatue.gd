# res://Scripts/Environment/BossStatue.gd
class_name BossStatue
extends WallMask

## A lore object (works exactly like the Bastet mask: message, aura shader, creepy sound)
## that summons a boss when its message is closed:
##   1. The ground starts to quake (travel_quake_loops) and the screen fades out.
##   2. The party is moved to `fight_start`, turned to face `boss_spawn`, and the screen fades in.
##   3. The boss rises out of the ground at `boss_spawn` with its own earthquake, then the battle starts.
## Once the boss is beaten the statue is just a lore object.

@export_group("Boss Encounter")
## The boss to summon (e.g. SlimeLord). Its trigger mode should be "Scripted".
@export var boss: BlobBossController
## Where the boss rises (e.g. the BossSpawnArea node).
@export var boss_spawn: Node3D
## Where the party is moved to (e.g. the BossFightStartingPoint node). They will face the boss.
@export var fight_start: Node3D
## Earthquake while the party is being moved (the boss adds its own while rising).
@export var travel_quake_size: CameraShake.QuakeSize = CameraShake.QuakeSize.LARGE
@export_range(0, 5, 1) var travel_quake_loops: int = 1
@export var fade_time: float = 0.5
@export var fade_color: Color = Color.BLACK
## Minimum pause between arriving and the boss starting to rise.
@export var pause_before_rise: float = 0.3

var _awaiting_close: bool = false
var _sequence_running: bool = false
var _boss_defeated: bool = false
var _fade_rect: ColorRect = null


func _ready() -> void:
	super._ready()

	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(gs) and gs.has_method("get_object_state"):
		var state: Dictionary = gs.get_object_state(_get_current_map_id(), object_id) as Dictionary
		_boss_defeated = bool(state.get("boss_defeated", false))

	if _boss_defeated:
		if is_instance_valid(boss):
			boss.queue_free()
	elif is_instance_valid(boss):
		boss.defeated.connect(_on_boss_defeated)

	if not SignalBus.popup_confirmed.is_connected(_on_popup_confirmed):
		SignalBus.popup_confirmed.connect(_on_popup_confirmed)
	if not SignalBus.combat_ended.is_connected(_on_combat_ended):
		SignalBus.combat_ended.connect(_on_combat_ended)


func interact(player: Node3D) -> void:
	super.interact(player) # Message popup, aura shader, mask sound, first-time XP
	if not _boss_defeated and not _sequence_running and is_instance_valid(boss):
		_awaiting_close = true


func _on_popup_confirmed(action_type: StringName, extra_data: Dictionary) -> void:
	if action_type != &"LORE_POPUP" or not _awaiting_close:
		return
	if str(extra_data.get("object_id", "")) != object_id:
		return
	_awaiting_close = false
	_run_boss_sequence()


func _run_boss_sequence() -> void:
	if not is_instance_valid(boss) or not is_instance_valid(boss_spawn) or not is_instance_valid(fight_start):
		push_warning("BossStatue '%s': boss, boss_spawn and fight_start must all be set." % name)
		return
	_sequence_running = true

	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if is_instance_valid(player) and player.has_method("set_movement_locked"):
		player.call("set_movement_locked", true)
	if GameState.has_method("lock_encounters"):
		GameState.lock_encounters(60.0)

	GameLogger.combat("%s: the ground begins to shake..." % lore_title)

	# 1. First quake while the party is pulled to the arena
	if travel_quake_loops > 0:
		CameraShake.request_earthquake(get_tree(), travel_quake_size, travel_quake_loops)
	await _fade_to(1.0)

	# 2. Move the party and face the boss
	if is_instance_valid(player) and player.has_method("teleport_to"):
		player.call("teleport_to", fight_start.global_position, boss_spawn.global_position)
	await _fade_to(0.0)

	# 3. Let the travel quake finish, then the boss rises (with its own quake loops)
	var quake_left: float = 0.0
	if travel_quake_loops > 0:
		quake_left = CameraShake.get_earthquake_duration(travel_quake_size, travel_quake_loops) - fade_time * 2.0
	await get_tree().create_timer(maxf(pause_before_rise, quake_left)).timeout

	if is_instance_valid(boss):
		boss.emerge_at(boss_spawn.global_position)


## Fleeing or losing lets the party try again by touching the statue.
func _on_combat_ended(_victory: bool) -> void:
	_sequence_running = false


func _on_boss_defeated() -> void:
	_boss_defeated = true
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(gs) and gs.has_method("set_object_state_flag"):
		gs.set_object_state_flag(_get_current_map_id(), object_id, "boss_defeated", true)


func _fade_to(alpha: float) -> void:
	if not is_instance_valid(_fade_rect):
		var layer := CanvasLayer.new()
		layer.layer = 95
		add_child(layer)
		_fade_rect = ColorRect.new()
		_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
		layer.add_child(_fade_rect)
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", alpha, maxf(0.01, fade_time))
	await tween.finished
