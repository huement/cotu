# res://Scripts/Objects/Stairs.gd
class_name DungeonStairs
extends DungeonInteractable

## Prompt message to display in the UI confirmation window
@export var prompt_message: String = "Ascend the stairs and leave the dungeon?"

## Target scene file path to load when leaving
@export_file("*.tscn") var target_scene: String = "res://Scenes/Overworld.tscn"

func interact(_player: Node3D) -> void:
	var sb: Node = SignalBus if is_instance_valid(SignalBus) else get_tree().root.get_node_or_null("SignalBus")
	if is_instance_valid(sb) and sb.has_signal(&"popup_requested"):
		sb.popup_requested.emit(&"LEAVE_DUNGEON", {
			"stairs": self,
			"message": prompt_message,
			"target_scene": target_scene
		})