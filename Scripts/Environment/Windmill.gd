# res://Scripts/Environment/Windmill.gd
class_name Windmill
extends Node3D
## The old windmill. Locked (and still) until something calls unlock() - e.g. the Masoleum
## combination lock. Unlocked, it spins and becomes an entrance: searching it offers to climb
## down into `target_scene` (like a CryptHole). The unlock is remembered in GameState.

@export var object_id: String = "windmill_01"
@export var is_locked: bool = true
@export var title: String = "OLD WINDMILL"

@export_multiline var locked_message: String = "The windmill door is locked tight with a rusted iron padlock."
@export_multiline var unlocked_message: String = "You search the windmill. The ancient wooden gears groan as they slowly turn."

@export_group("Entrance")
## Where the unlocked windmill leads (empty = it just shows unlocked_message).
@export_file("*.tscn") var target_scene: String = ""
## Marker in the target map where the party appears.
@export var arrival_point_name: String = "SpawnPoint"
@export_multiline var enter_prompt: String = "Beneath the turning gears, a trapdoor stands open over a ladder into the dark. Climb down?"

@export_group("Animation Correction")
## Pitch offset in degrees to correct 3D export tilt when playing animations (usually 90.0 or -90.0)
@export var animation_pitch_offset: float = -90.0
## Seconds the sails take to reach full speed after unlocking.
@export var spin_up_seconds: float = 4.0

var _anim_player: AnimationPlayer = null


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"searchable")
	_apply_rotation_correction()
	_load_saved_state()
	if not is_locked:
		_start_spinning(false)


func _load_saved_state() -> void:
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if not is_instance_valid(gs) or not gs.has_method("get_object_state"):
		return
	var state: Dictionary = gs.get_object_state(_get_map_id(), object_id) as Dictionary
	if bool(state.get("unlocked", false)):
		is_locked = false


## Wraps the animated GLB node in a correction pivot to counteract GLTF export axis tilt
func _apply_rotation_correction() -> void:
	_anim_player = _find_animation_player(self)
	if not _anim_player:
		return
	var model_node: Node3D = _find_model_node(_anim_player)
	if model_node and model_node != self and animation_pitch_offset != 0.0:
		var pivot: Node3D = Node3D.new()
		pivot.name = "AnimationCorrectionPivot"
		add_child(pivot)
		model_node.reparent(pivot)
		pivot.rotation_degrees.x = animation_pitch_offset
	if _anim_player.has_animation("Move"):
		var anim: Animation = _anim_player.get_animation("Move")
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
		# Show the sails at rest (first frame) until unlocked.
		_anim_player.play("Move")
		_anim_player.seek(0.0, true)
		_anim_player.pause()


func _start_spinning(spin_up: bool) -> void:
	if not _anim_player or not _anim_player.has_animation("Move"):
		return
	_anim_player.play("Move")
	if spin_up and spin_up_seconds > 0.0:
		_anim_player.speed_scale = 0.05
		create_tween().tween_property(_anim_player, "speed_scale", 1.0, spin_up_seconds) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		_anim_player.speed_scale = 1.0


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found:
			return found
	return null


func _find_model_node(anim_player: AnimationPlayer) -> Node3D:
	var current: Node = anim_player
	while current and current.get_parent() != self:
		current = current.get_parent()
	return current as Node3D


## Called when the player inspects or searches the windmill.
func interact(_player: Node = null) -> String:
	if not is_locked and not target_scene.is_empty():
		if is_instance_valid(SignalBus):
			SignalBus.popup_requested.emit(&"CONFIRMATION", {
				"title": title,
				"message": enter_prompt,
				"confirm_text": "Climb down",
				"cancel_text": "Not yet",
				"on_confirm": Callable(self, "_on_enter_confirmed")
			})
		return enter_prompt

	var message: String = locked_message if is_locked else unlocked_message
	var sb: Node = SignalBus if is_instance_valid(SignalBus) else get_tree().root.get_node_or_null("SignalBus")
	if is_instance_valid(sb) and sb.has_signal(&"popup_requested"):
		sb.popup_requested.emit(&"LORE_POPUP", {
			"title": title,
			"body": message,
			"aura_type": "none"
		})
	GameLogger.info("Windmill inspected (Locked: %s): %s" % [is_locked, message])
	return message


func inspect(player: Node = null) -> String:
	return interact(player)


func _on_enter_confirmed() -> void:
	MapTransition.travel(get_tree(), target_scene, arrival_point_name)


## Unlocks the windmill: the sails spin up and it becomes an entrance. Saved in GameState.
func unlock() -> void:
	if not is_locked:
		return
	is_locked = false
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(gs) and gs.has_method("set_object_state_flag"):
		gs.set_object_state_flag(_get_map_id(), object_id, "unlocked", true)
	_start_spinning(true)
	if is_instance_valid(SignalBus) and SignalBus.has_signal(&"show_toast"):
		SignalBus.show_toast.emit("Somewhere nearby, the old windmill creaks to life...", false)
	GameLogger.info("Windmill has been unlocked.")


func lock() -> void:
	is_locked = true
	if _anim_player:
		_anim_player.pause()
	GameLogger.info("Windmill has been locked.")


func _get_map_id() -> String:
	return GameState.get_current_map_id()
