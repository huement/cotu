class_name StoneGate
extends DungeonInteractable

@export_file("*.tscn") var target_dungeon_scene: String = "res://Scenes/dungeon_map.tscn"
## Marker node in the target map where the party appears (faces the marker's -Z).
@export var arrival_point_name: String = "SpawnPoint"
@export_multiline var prompt_text: String = "You see a massive stone that appears to be movable. Move it and descend into the depths?"
## When set, the gate doesn't travel: it just shows this message with an OK button
## (for areas that aren't built yet / hard locks).
@export_multiline var locked_message: String = ""
@export var locked_title: String = "Coming Soon"

@export_group("Zone Unlock")
## Party must reach this level before the gate opens. 0 = no level requirement.
## Checked against GameState.get_party_level() (highest living member).
@export_range(0, 99) var required_level: int = 0
## Shown when the party is underleveled. Empty = a default "need level X" message.
@export_multiline var underleveled_message: String = ""
@export var underleveled_title: String = "Sealed Gate"


func interact(_player: Node3D) -> void:
	_open_confirmation_ui()


## True when the gate will offer travel (not hard-locked and level requirement met).
## Extend later for named zone unlocks / quest flags.
func is_unlocked() -> bool:
	if not locked_message.is_empty():
		return false
	if required_level > 0 and _get_party_level() < required_level:
		return false
	return true


func _open_confirmation_ui() -> void:
	if not locked_message.is_empty():
		_show_message(locked_title, locked_message)
		return
	if required_level > 0 and _get_party_level() < required_level:
		_show_message(underleveled_title, _underleveled_text())
		return
	if is_instance_valid(SignalBus):
		SignalBus.popup_requested.emit(&"CONFIRMATION", {
			"message": prompt_text,
			"confirm_text": "Yes",
			"cancel_text": "No",
			"on_confirm": Callable(self, "_on_descend_confirmed")
		})


func _show_message(title: String, message: String) -> void:
	if is_instance_valid(SignalBus):
		SignalBus.popup_requested.emit(&"CONFIRMATION", {
			"title": title,
			"message": message,
			"confirm_text": "OK",
			"hide_cancel": true,
		})


func _underleveled_text() -> String:
	if not underleveled_message.is_empty():
		return underleveled_message
	var party_level: int = _get_party_level()
	return "An old ward seals this gate. Your party must reach level %d before it will open.\n(Party level: %d)" % [
		required_level, party_level
	]


func _get_party_level() -> int:
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(gs) and gs.has_method("get_party_level"):
		return int(gs.call("get_party_level"))
	return 0


func _on_descend_confirmed() -> void:
	# Re-check in case level/state changed while the popup was open.
	if not is_unlocked():
		return
	var am: Node = get_tree().root.get_node_or_null("AudioManager")
	if is_instance_valid(am):
		am.call("play_environment", "teleport")
	# Swap the sub-map through MapManager and place the party on `arrival_point_name`.
	MapTransition.travel(get_tree(), target_dungeon_scene, arrival_point_name)
