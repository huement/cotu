class_name CryptHole
extends DungeonInteractable

## File path filter for target map (.tscn files).
## Set the exact path in the Inspector (must start with res://)
@export_file("*.tscn") var target_dungeon_scene: String = ""

## Marker node in the target map where the party appears (faces the marker's -Z).
@export var arrival_point_name: String = "SpawnPoint"

## Custom prompt text for the confirmation window
@export_multiline var prompt_text: String = "You see a massive stone that appears to be movable. Move it and descend into the depths?"


func interact(_player: Node3D) -> void:
	_open_confirmation_ui()


func _open_confirmation_ui() -> void:
	if is_instance_valid(SignalBus):
		SignalBus.popup_requested.emit(&"CONFIRMATION", {
			"message": prompt_text,
			"confirm_text": "Yes",
			"cancel_text": "No",
			"on_confirm": Callable(self, "_on_descend_confirmed")
		})


func _on_descend_confirmed() -> void:
	# MapTransition swaps the sub-map through MapManager and places the party on
	# `arrival_point_name` in the new map (SpawnPoint by default).
	MapTransition.travel(get_tree(), target_dungeon_scene, arrival_point_name)
