# res://Scripts/Triggers/NineVoiceTrigger.gd
class_name NineVoiceTrigger
extends Area3D
## One-shot walk-in trigger that asks NineHUD to play a Voice clip via SignalBus.
## Persists through GameState object flags so it only fires once per save.
##
## The party is a Node3D (tweened grid steps), so we check footprint on party_moved
## rather than relying on physics body_entered alone.

@export var object_id: String = "nine_voice_intro"
@export var clip_basename: String = "intro"
@export var trigger_once: bool = true

var _fired: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1

	_load_saved_state()
	if _fired:
		monitoring = false
		return

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if is_instance_valid(SignalBus) and not SignalBus.party_moved.is_connected(_on_party_moved):
		SignalBus.party_moved.connect(_on_party_moved)


func _load_saved_state() -> void:
	if not trigger_once:
		return
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if not is_instance_valid(gs) or not gs.has_method("get_object_state"):
		return
	var state: Dictionary = gs.get_object_state(_map_id(), object_id) as Dictionary
	_fired = bool(state.get("heard", false))


func _on_body_entered(body: Node) -> void:
	if body.is_in_group(&"player") or body is DungeonPlayer:
		_try_fire()


func _on_party_moved(_grid_pos: Vector3i, _facing: Variant) -> void:
	_try_fire()


func _try_fire() -> void:
	if _fired:
		return
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if not is_instance_valid(player):
		return
	if not is_point_inside(player.global_position):
		return

	_fired = true
	if trigger_once:
		_persist_heard()
		set_deferred("monitoring", false)
		if is_instance_valid(SignalBus) and SignalBus.party_moved.is_connected(_on_party_moved):
			SignalBus.party_moved.disconnect(_on_party_moved)

	if is_instance_valid(SignalBus):
		SignalBus.nine_speak_requested.emit(clip_basename)


## True when [param world_pos] is inside the footprint (x / z) of this area's box shapes.
func is_point_inside(world_pos: Vector3) -> bool:
	for child: Node in get_children():
		var cs := child as CollisionShape3D
		if cs == null:
			continue
		if cs.shape is BoxShape3D:
			var local: Vector3 = cs.global_transform.affine_inverse() * world_pos
			var half: Vector3 = (cs.shape as BoxShape3D).size * 0.5
			if absf(local.x) <= half.x and absf(local.z) <= half.z:
				return true
		elif cs.shape is SphereShape3D:
			var radius: float = (cs.shape as SphereShape3D).radius
			var center: Vector3 = cs.global_position
			var delta: Vector3 = world_pos - center
			delta.y = 0.0
			if delta.length() <= radius:
				return true
	return false


func _persist_heard() -> void:
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(gs) and gs.has_method("set_object_state_flag"):
		gs.set_object_state_flag(_map_id(), object_id, "heard", true)


func _map_id() -> String:
	if is_instance_valid(GameState) and GameState.has_method("get_current_map_id"):
		return GameState.get_current_map_id()
	return "GreenGrove"
