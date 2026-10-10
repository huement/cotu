# res://Scripts/Environment/Windmill.gd
class_name Windmill
extends Node3D

@export var is_locked: bool = true
@export var title: String = "OLD WINDMILL"

@export_multiline var locked_message: String = "The windmill door is locked tight with a rusted iron padlock."
@export_multiline var unlocked_message: String = "You search the windmill. The ancient wooden gears groan as they slowly turn."

func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"searchable")

## Called when the player inspects or searches the windmill.
func interact(_player: Node = null) -> String:
	var message: String = locked_message if is_locked else unlocked_message
	
	# Open Universal Popup Modal
	var sb: Node = SignalBus if is_instance_valid(SignalBus) else get_tree().root.get_node_or_null("SignalBus")
	if is_instance_valid(sb) and sb.has_signal(&"popup_requested"):
		sb.popup_requested.emit(&"LORE_POPUP", {
			"title": title,
			"body": message,
			"aura_type": "none"
		})
		
	GameLogger.info("Windmill inspected (Locked: %s): %s" % [is_locked, message])
	return message

## Alias for interact
func inspect(player: Node = null) -> String:
	return interact(player)

## Unlocks the windmill
func unlock() -> void:
	is_locked = false
	GameLogger.info("Windmill has been unlocked.")

## Relocks the windmill
func lock() -> void:
	is_locked = true
	GameLogger.info("Windmill has been locked.")
