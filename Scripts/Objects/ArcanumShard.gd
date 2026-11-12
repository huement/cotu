# res://Scripts/Objects/ArcanumShard.gd
@tool
class_name ArcanumShard
extends Node3D
## Arcanum Shard - raw corrupting energy (Scenes/Objects/ArcanumShard.tscn). A collectible.
##
## LOOK: Shaders/arcanum_shard.gdshader on the crystal + particle emitters + a pulsing light.
## It hovers / turns, the light flickers and a "surge" fires every few seconds.
##
## COLLECTING: no inspect needed. When the party stands next to it:
##   1. the party is frozen, the collection sound plays and the purple/green aura covers the screen,
##   2. a moment later the message box opens (title + message below),
##   3. on OK everything goes back to normal, the shard vanishes and is recorded
##      (ShardLedger -> GameState.collected_shards, saved with the game).
##
## BOSS SHARDS: point `boss` at the level's boss. The shard stays hidden until that boss is
## beaten, then appears where the boss stood. No boss = it is simply there to be found.
##
## In the editor only the material is applied (no motion), so nothing moves under your cursor.

enum State { HIDDEN, IDLE, COLLECTING, GONE }

const COLLECT_SOUND: String = "res://Audio/Items/shard_collection.mp3"
const AURA_SHADER_PATH: String = "res://Shaders/lore_aura_overlay.gdshader"
## Aura colours for shards: purple with a green highlight (also used by UniversalPopup's "shard" aura).
const AURA_COLOR_A: Color = Color(0.5, 0.06, 0.8, 0.85)
const AURA_COLOR_B: Color = Color(0.18, 0.0, 0.4, 0.85)
const AURA_EMISSION: Color = Color(0.3, 1.0, 0.35, 0.7)

@export_group("Shard")
## Unique id of this shard. Must also have a row in ShardLedger.CATALOG (that row names its area).
@export var shard_id: String = "shard_01"
## Only used while the shard has no ShardLedger.CATALOG row: the area it is recorded under.
@export var level_name: String = ""
@export var dialog_title: String = "ARCANUM SHARD"
## The message shown when the shard is collected.
@export_multiline var dialog_text: String = "The shard pulses before you. Its light nearly blinds you. Your containment unit hums and the shard vanishes!"
## How close the party has to be (metres; map cells are 2 m).
@export var trigger_distance: float = 2.6
## Seconds the aura shows before the message box opens.
@export var dialog_delay: float = 1.2

@export_group("Boss")
## Optional. The shard is hidden until this boss is beaten (BossEnemy, DungeonBoss or a blob boss).
@export var boss: NodePath
## Appear where the boss was standing (off = stay where it was placed in the editor).
@export var appear_at_boss: bool = true

@export_group("Look")
## Material put on every mesh of the model. Tweak colours / glow here.
@export var shard_material: ShaderMaterial
## Up/down drift in metres (0 = planted in the ground).
@export var bob_height: float = 0.08
@export var bob_speed: float = 0.9
## Degrees per second around the up axis (0 = no turning).
@export var spin_speed: float = 8.0

@export_group("Surge")
## A surge fires at a random time between these two (seconds). Max 0 = never.
@export var surge_interval_min: float = 4.0
@export var surge_interval_max: float = 9.0
## How long a surge takes to die down.
@export var surge_fade: float = 0.9
## Extra light energy at the peak of a surge.
@export var surge_light_boost: float = 4.0

var state: State = State.IDLE

var _model: Node3D = null
var _light: OmniLight3D = null
var _glow: Node3D = null
var _motes: Node3D = null
var _burst: CPUParticles3D = null
var _boss_node: Node3D = null

var _time: float = 0.0
var _surge: float = 0.0
var _next_surge: float = 0.0
var _base_y: float = 0.0
var _base_light: float = 1.0
var _base_glow_scale: Vector3 = Vector3.ONE
var _check_timer: float = 0.0
## Seconds before the shard can be picked up (lets a boss fight finish wrapping up).
var _arm_delay: float = 0.0
var _aura_layer: CanvasLayer = null
var _aura_rect: ColorRect = null


func _ready() -> void:
	_model = get_node_or_null("arcanum_shard") as Node3D
	_light = get_node_or_null("EnergyLight") as OmniLight3D
	_glow = get_node_or_null("Glow") as Node3D
	_motes = get_node_or_null("Motes") as Node3D
	_burst = get_node_or_null("SurgeBurst") as CPUParticles3D
	_apply_material()
	if Engine.is_editor_hint():
		set_process(false)
		return
	if is_instance_valid(_model):
		_base_y = _model.position.y
	if is_instance_valid(_light):
		_base_light = _light.light_energy
	if is_instance_valid(_glow):
		_base_glow_scale = _glow.scale
	# Shards placed side by side should not move in step.
	_time = randf() * 20.0
	_schedule_surge()
	SignalBus.popup_confirmed.connect(_on_popup_confirmed)
	# Deferred: the map (and its boss / boss room) must finish its own _ready first.
	_setup_state.call_deferred()


# ==============================================================================
# State: hidden until the boss dies -> idle -> collecting -> gone
# ==============================================================================

func _setup_state() -> void:
	if not ShardLedger.is_known(shard_id):
		push_warning("ArcanumShard '%s' (shard_id '%s') has no row in ShardLedger.CATALOG - the shard menu won't list it until it is collected." % [name, shard_id])
	if ShardLedger.is_collected(shard_id):
		_retire_boss()
		state = State.GONE
		queue_free()
		return

	_boss_node = _find_boss() as Node3D
	var saved: Dictionary = GameState.get_object_state(GameState.get_current_map_id(), _state_id())
	if bool(saved.get("revealed", false)):
		# The boss was beaten earlier but the shard was not picked up yet.
		if saved.has("pos"):
			global_position = saved["pos"] as Vector3
		_retire_boss()
		_set_hidden(false)
		return
	if boss.is_empty():
		_set_hidden(false)
		return
	if not is_instance_valid(_boss_node) or _boss_node.is_queued_for_deletion():
		# Boss already gone (beaten before this shard existed in the save): just be there.
		_set_hidden(false)
		return

	_set_hidden(true)
	if _boss_node.has_signal(&"boss_defeated"):
		_boss_node.connect(&"boss_defeated", _on_boss_defeated_signal)
	elif _boss_node.has_signal(&"defeated"):
		_boss_node.connect(&"defeated", _on_boss_defeated_signal)
	else:
		push_warning("ArcanumShard '%s': boss has no 'defeated' / 'boss_defeated' signal - showing the shard." % name)
		_set_hidden(false)


## Bosses pass different arguments with their signal; none are needed here.
func _on_boss_defeated_signal(_a: Variant = null, _b: Variant = null) -> void:
	if state != State.HIDDEN:
		return
	if appear_at_boss and is_instance_valid(_boss_node):
		var spot: Vector3 = _cell_center(_boss_node.global_position)
		global_position = Vector3(spot.x, global_position.y, spot.z)
	var map_id: String = GameState.get_current_map_id()
	GameState.set_object_state_flag(map_id, _state_id(), "revealed", true)
	GameState.set_object_state_flag(map_id, _state_id(), "pos", global_position)
	_set_hidden(false)
	_arm_delay = 1.5
	# Grow out of nothing where the boss fell.
	scale = Vector3.ONE * 0.01
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	surge()


func _set_hidden(hidden: bool) -> void:
	state = State.HIDDEN if hidden else State.IDLE
	visible = not hidden
	for emitter: CPUParticles3D in _emitters():
		emitter.emitting = not hidden


## A revealed / collected shard means its boss is dead: make sure it does not come back on reload.
func _retire_boss() -> void:
	var node: Node = _find_boss()
	if is_instance_valid(node) and not node.is_queued_for_deletion():
		node.queue_free()


## The boss node, or null. `boss` is normally relative to this shard ("../Enemies/Boss"), but a
## path written relative to the level root ("Enemies/Boss") is accepted too: when that was missed
## the boss was never found and the shard showed up before the fight.
func _find_boss() -> Node:
	if boss.is_empty():
		return null
	var node: Node = get_node_or_null(boss)
	if node == null and is_instance_valid(owner):
		node = owner.get_node_or_null(boss)
	if node == null and get_parent() != null:
		node = get_parent().get_node_or_null(boss)
	return node


func _state_id() -> String:
	return "arcanum_shard_" + shard_id


# ==============================================================================
# Frame update: looks + "is the party next to me?"
# ==============================================================================

func _process(delta: float) -> void:
	if state == State.HIDDEN or state == State.GONE:
		return
	_animate(delta)
	if state != State.IDLE:
		return
	_arm_delay = maxf(0.0, _arm_delay - delta)
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 0.15
	if _arm_delay <= 0.0 and _party_is_close():
		_begin_collection()


func _animate(delta: float) -> void:
	_time += delta
	_surge = move_toward(_surge, 0.0, delta / maxf(surge_fade, 0.05))

	if is_instance_valid(_model):
		_model.position.y = _base_y + sin(_time * bob_speed) * bob_height
		_model.rotate_y(deg_to_rad(spin_speed) * delta)
	if is_instance_valid(_motes):
		_motes.rotate_y(0.7 * delta)

	# Uneven flicker: two sines that drift in and out of step.
	var flicker: float = 0.85 + 0.15 * sin(_time * 7.3) * sin(_time * 3.1)
	if is_instance_valid(_light):
		_light.light_energy = _base_light * flicker + _surge * surge_light_boost
	if is_instance_valid(_glow):
		_glow.scale = _base_glow_scale * (0.92 + 0.08 * sin(_time * 2.2) + _surge * 0.6)
	if shard_material != null:
		shard_material.set_shader_parameter(&"surge", _surge)

	if surge_interval_max > 0.0 or state == State.COLLECTING:
		_next_surge -= delta
		if _next_surge <= 0.0:
			surge()


func _party_is_close() -> bool:
	if GameState.current_mode != GameState.Mode.EXPLORING or GameState.awaiting_victory_screen:
		return false
	if SessionFlow.is_in_battle():
		return false
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if not is_instance_valid(player) or bool(player.get("is_moving")):
		return false
	var offset: Vector3 = player.global_position - global_position
	offset.y = 0.0
	return offset.length() <= trigger_distance


# ==============================================================================
# Collection
# ==============================================================================

func _begin_collection() -> void:
	state = State.COLLECTING
	_set_party_locked(true)
	GameState.lock_encounters(60.0)
	AudioManager.play_audio_path(COLLECT_SOUND)
	SignalBus.camera_shake_requested.emit(0.5)
	surge()
	_next_surge = 0.6 # keeps flaring while the party is held
	_show_aura()

	await get_tree().create_timer(maxf(0.0, dialog_delay)).timeout
	if not is_inside_tree() or state != State.COLLECTING:
		return
	SignalBus.popup_requested.emit(&"LORE_POPUP", {
		"title": dialog_title,
		"body": dialog_text,
		"object_id": _state_id(),
		"aura_type": "shard",
		"button_text": "OK",
	})
	_hide_aura() # the message box shows the same aura from here on


func _on_popup_confirmed(action_type: StringName, extra_data: Dictionary) -> void:
	if action_type != &"LORE_POPUP" or state != State.COLLECTING:
		return
	if str(extra_data.get("object_id", "")) != _state_id():
		return
	_finish_collection()


func _finish_collection() -> void:
	state = State.GONE
	_hide_aura()
	ShardLedger.collect(shard_id, level_name)
	_set_party_locked(false)
	GameState.clear_encounter_lock()
	GameState.lock_encounters(2.0)

	# Vanish: one last burst, the crystal collapses into itself, the light dies.
	if is_instance_valid(_burst):
		_burst.restart()
		_burst.emitting = true
	for emitter: CPUParticles3D in _emitters():
		if emitter != _burst:
			emitter.emitting = false
	var tween: Tween = create_tween().set_parallel(true)
	if is_instance_valid(_model):
		tween.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if is_instance_valid(_glow):
		tween.tween_property(_glow, "scale", Vector3.ONE * 0.01, 0.45)
	if is_instance_valid(_light):
		tween.tween_property(_light, "light_energy", 0.0, 0.6)
	await tween.finished
	if is_instance_valid(_model):
		_model.visible = false
	# Let the last sparks fade before the node goes.
	await get_tree().create_timer(1.2).timeout
	queue_free()


func _exit_tree() -> void:
	# Never leave the party frozen if the map is swapped mid-collection.
	if not Engine.is_editor_hint() and state == State.COLLECTING:
		_set_party_locked(false)


func _set_party_locked(locked: bool) -> void:
	var player: Node = get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	if is_instance_valid(player) and player.has_method("set_movement_locked"):
		player.call("set_movement_locked", locked)


# ==============================================================================
# Full-screen aura (same shader as the masks, shard colours)
# ==============================================================================

func _show_aura() -> void:
	if not is_instance_valid(_aura_rect):
		var shader: Shader = load(AURA_SHADER_PATH) as Shader
		if shader == null:
			return
		_aura_layer = CanvasLayer.new()
		_aura_layer.layer = 99 # just under the message box (UniversalPopup = 100)
		add_child(_aura_layer)
		_aura_rect = ColorRect.new()
		_aura_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_aura_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter(&"albedo_color_a", AURA_COLOR_A)
		material.set_shader_parameter(&"albedo_color_b", AURA_COLOR_B)
		material.set_shader_parameter(&"emission_color", AURA_EMISSION)
		_aura_rect.material = material
		_aura_rect.modulate.a = 0.0
		_aura_layer.add_child(_aura_rect)
	_aura_rect.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(_aura_rect, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_aura() -> void:
	if not is_instance_valid(_aura_rect) or not _aura_rect.visible:
		return
	var rect: ColorRect = _aura_rect
	var tween: Tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if is_instance_valid(rect):
			rect.visible = false
	)


# ==============================================================================
# Helpers
# ==============================================================================

## Flare up right now.
func surge() -> void:
	_surge = 1.0
	if is_instance_valid(_burst):
		_burst.restart()
		_burst.emitting = true
	_schedule_surge()


func _schedule_surge() -> void:
	if state == State.COLLECTING:
		_next_surge = 0.6
		return
	_next_surge = randf_range(minf(surge_interval_min, surge_interval_max), maxf(surge_interval_min, surge_interval_max))


func _emitters() -> Array[CPUParticles3D]:
	var out: Array[CPUParticles3D] = []
	for child: Node in get_children():
		if child is CPUParticles3D and child != _burst:
			out.append(child as CPUParticles3D)
	return out


## Centre of the map cell under [param world_pos] (x / z), so the shard sits squarely on a tile.
func _cell_center(world_pos: Vector3) -> Vector3:
	var map_mgr: Node = get_tree().root.find_child("MapManager", true, false)
	if is_instance_valid(map_mgr) and map_mgr.has_method("world_to_grid") and map_mgr.has_method("nav_cell_to_world"):
		var cell: Vector3i = map_mgr.call("world_to_grid", world_pos) as Vector3i
		return map_mgr.call("nav_cell_to_world", Vector3i(cell.x, 0, cell.z)) as Vector3
	return world_pos


func _apply_material() -> void:
	if shard_material == null or not is_instance_valid(_model):
		return
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = shard_material
