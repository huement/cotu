# res://Scripts/Dungeon/BossExitGate.gd
class_name BossExitGate
extends StaticBody3D
## The boss chamber's north gate (Caps/Cap_N/Blocker). Facing it and pressing interact asks to
## leave the map, then moves the party to `target_scene` on the `arrival_point_name` marker.
## BossChamber fills these in from the boss's CSV row and unlocks it when the boss is beaten.

@export_file("*.tscn") var target_scene: String = ""
@export var arrival_point_name: String = "SpawnPoint"
@export var prompt_message: String = "The gate grinds open onto a passage beyond. Leave this place?"
@export var locked_message: String = "The gate is sealed by a dark force."
@export var no_exit_message: String = "The gate won't budge."
## While locked, interacting only shows `locked_message`.
@export var is_locked: bool = true


func interact(_player: Node3D) -> void:
	if is_locked:
		SignalBus.show_toast.emit(locked_message, false)
		return
	if target_scene.is_empty():
		SignalBus.show_toast.emit(no_exit_message, false)
		return
	SignalBus.popup_requested.emit(&"CONFIRMATION", {
		"message": prompt_message,
		"confirm_text": "Yes",
		"cancel_text": "No",
		"on_confirm": Callable(self, "_on_travel_confirmed"),
	})


func unlock() -> void:
	is_locked = false


func _on_travel_confirmed() -> void:
	MapTransition.travel(get_tree(), target_scene, arrival_point_name)
