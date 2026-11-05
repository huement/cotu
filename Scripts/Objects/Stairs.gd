# res://Scripts/Objects/Stairs.gd
class_name DungeonStairs
extends DungeonInteractable

## Prompt message to display in the UI confirmation window
@export var prompt_message: String = "Ascend the stairs and leave the dungeon?"

## Target scene file path to load when leaving
@export_file("*.tscn") var target_scene: String = "res://Scenes/Overworld.tscn"

## When true, the stairs swap sub-maps through MapManager (e.g. cave levels <-> GloomReach)
## instead of replacing the whole running scene with `target_scene`.
@export var use_map_manager: bool = false

## Marker node in the target map where the party appears (only with use_map_manager).
@export var arrival_point_name: String = "SpawnPoint"

func interact(_player: Node3D) -> void:
	if use_map_manager:
		_request_map_travel()
		return

	var sb: Node = SignalBus if is_instance_valid(SignalBus) else get_tree().root.get_node_or_null("SignalBus")
	if is_instance_valid(sb) and sb.has_signal(&"popup_requested"):
		sb.popup_requested.emit(&"LEAVE_DUNGEON", {
			"stairs": self,
			"message": prompt_message,
			"target_scene": target_scene
		})


func _request_map_travel() -> void:
	if is_instance_valid(SignalBus):
		SignalBus.popup_requested.emit(&"CONFIRMATION", {
			"message": prompt_message,
			"confirm_text": "Yes",
			"cancel_text": "No",
			"on_confirm": Callable(self, "_on_travel_confirmed")
		})


func _on_travel_confirmed() -> void:
	MapTransition.travel(get_tree(), target_scene, arrival_point_name)
