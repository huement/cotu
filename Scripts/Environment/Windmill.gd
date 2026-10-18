class_name Windmill
extends Node3D

@export var is_locked: bool = true
@export var title: String = "OLD WINDMILL"

@export_multiline var locked_message: String = "The windmill door is locked tight with a rusted iron padlock."
@export_multiline var unlocked_message: String = "You search the windmill. The ancient wooden gears groan as they slowly turn."

@export_group("Animation Correction")
## Pitch offset in degrees to correct 3D export tilt when playing animations (usually 90.0 or -90.0)
@export var animation_pitch_offset: float = -90.0

func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"searchable")
	_apply_rotation_correction_and_play()

## Wraps the animated GLB node in a correction pivot to counteract GLTF export axis tilt
func _apply_rotation_correction_and_play() -> void:
	var anim_player: AnimationPlayer = _find_animation_player(self)
	if not anim_player:
		return

	# Locate the top-level model node instantiated under this Windmill root node
	var model_node: Node3D = _find_model_node(anim_player)
	if model_node and model_node != self and animation_pitch_offset != 0.0:
		var pivot: Node3D = Node3D.new()
		pivot.name = "AnimationCorrectionPivot"
		add_child(pivot)
		model_node.reparent(pivot)
		pivot.rotation_degrees.x = animation_pitch_offset

	if anim_player.has_animation("Move"):
		var anim: Animation = anim_player.get_animation("Move")
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
		anim_player.play("Move")

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

func unlock() -> void:
	is_locked = false
	GameLogger.info("Windmill has been unlocked.")

func lock() -> void:
	is_locked = true
	GameLogger.info("Windmill has been locked.")
