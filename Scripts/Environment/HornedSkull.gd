# res://Scripts/Environment/HornedSkull.gd
class_name HornedSkull
extends DungeonInteractable

## Creepy lore prop: proximity or inspect triggers lore-aura, a boss sting, and a cube image flash.

@export_group("Lore")
@export var lore_title: String = "HORNED SKULL"
@export_multiline var lore_text: String = "The horned skull stares through you. Something behind the eyes wants out."
@export var xp_reward: int = 25
@export_enum("bad", "good", "none") var aura_type: String = "bad"
@export var show_lore_popup_on_inspect: bool = true

@export_group("Scare FX")
@export var flash_texture: Texture2D = preload("res://resources/Lore/cube.png")
@export var scare_music_path: String = "res://Audio/Enemies_Boss/die-die-die.mp3"
@export var shake_trauma: float = 0.6
@export var aura_hold_seconds: float = 3.4
## If true, scare only fires once per run (saved as triggered).
@export var trigger_once: bool = true

@export_group("Proximity")
@export var proximity_radius: float = 3.25:
	set(value):
		proximity_radius = value
		_apply_proximity_radius()

var is_inspected: bool = false
var has_triggered_scare: bool = false
var _area: Area3D


func _ready() -> void:
	snap_to_floor_center = false
	is_blocking = false
	super._ready()
	_load_saved_state()
	_setup_proximity_area()


func _setup_proximity_area() -> void:
	_area = get_node_or_null("Area3D") as Area3D
	if not is_instance_valid(_area):
		_area = Area3D.new()
		_area.name = "Area3D"
		add_child(_area)
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var shape := SphereShape3D.new()
		shape.radius = proximity_radius
		col.shape = shape
		_area.add_child(col)

	_area.monitoring = true
	_area.monitorable = false
	_area.collision_layer = 0
	_area.collision_mask = 1
	_apply_proximity_radius()

	if not _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.connect(_on_body_entered)


func _apply_proximity_radius() -> void:
	if not is_inside_tree():
		return
	var col: CollisionShape3D = get_node_or_null("Area3D/CollisionShape3D") as CollisionShape3D
	if not is_instance_valid(col):
		return
	if col.shape is SphereShape3D:
		(col.shape as SphereShape3D).radius = proximity_radius
	elif col.shape is CylinderShape3D:
		(col.shape as CylinderShape3D).radius = proximity_radius


func _load_saved_state() -> void:
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if not is_instance_valid(gs) or not gs.has_method("get_object_state"):
		return

	var map_id: String = _get_current_map_id()
	var state: Dictionary = gs.get_object_state(map_id, object_id) as Dictionary
	if state.has("is_inspected"):
		is_inspected = bool(state["is_inspected"])
	if state.has("has_triggered_scare"):
		has_triggered_scare = bool(state["has_triggered_scare"])


func _on_body_entered(body: Node) -> void:
	if not _is_player(body):
		return
	_trigger_scare(false)


func interact(player: Node3D) -> void:
	_trigger_scare(true)
	if show_lore_popup_on_inspect:
		_open_lore_popup()
	if not is_inspected:
		_mark_inspected()


func inspect(player: Node = null) -> void:
	interact(player as Node3D)


func _trigger_scare(from_inspect: bool) -> void:
	# Proximity is one-shot; inspect always re-fires the full scare.
	if not from_inspect and trigger_once and has_triggered_scare:
		return

	if not has_triggered_scare:
		has_triggered_scare = true
		_persist_scare_flag()

	_emit_scare_fx(true)


func _emit_scare_fx(play_music: bool) -> void:
	if play_music and is_instance_valid(AudioManager) and AudioManager.has_method(&"play_audio_path"):
		AudioManager.play_audio_path(scare_music_path)

	if is_instance_valid(SignalBus) and SignalBus.has_signal(&"lore_scare_requested"):
		SignalBus.lore_scare_requested.emit({
			"aura_type": aura_type,
			"flash_texture": flash_texture,
			"flash_texture_path": "res://resources/Lore/cube.png",
			"shake_trauma": shake_trauma,
			"aura_hold": aura_hold_seconds,
			"object_id": object_id,
		})


func _open_lore_popup() -> void:
	if not is_instance_valid(SignalBus) or not SignalBus.has_signal(&"popup_requested"):
		return
	if is_instance_valid(AudioManager) and AudioManager.has_method(&"play_mask_sound"):
		AudioManager.play_mask_sound(aura_type)
	SignalBus.popup_requested.emit(&"LORE_POPUP", {
		"title": lore_title,
		"body": lore_text,
		"object_id": object_id,
		"aura_type": "none", # Scare FX owns the aura so popup does not double it
	})


func _mark_inspected() -> void:
	is_inspected = true
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if not is_instance_valid(gs):
		return
	var map_id: String = _get_current_map_id()
	if gs.has_method("set_object_state_flag"):
		gs.set_object_state_flag(map_id, object_id, "is_inspected", true)
	if xp_reward > 0 and gs.has_method("add_xp"):
		gs.add_xp(xp_reward)


func _persist_scare_flag() -> void:
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(gs) and gs.has_method("set_object_state_flag"):
		gs.set_object_state_flag(_get_current_map_id(), object_id, "has_triggered_scare", true)


func _is_player(body: Node) -> bool:
	return body.is_in_group(&"player") or body.name == "Player" or body is DungeonPlayer
