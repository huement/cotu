# res://Scripts/Environment/WallMask.gd
class_name WallMask
extends DungeonInteractable

## Display header for the lore popup modal
@export var lore_title: String = "ANCIENT MASK INSCRIPTION"

## Multiline narrative log or terminal archive text
@export_multiline var lore_text: String = "The metallic surface hums with faint residual energy. Scratched runic figures line the jaw..."

## Exploration XP awarded upon first inspection
@export var xp_reward: int = 25

@export_enum("bad", "good", "none") var aura_type: String = "bad"

var is_inspected: bool = false


func _ready() -> void:
	snap_to_floor_center = false # Preserves wall height & transform offset from 3D Editor
	is_blocking = false          # Wall objects do not block walking into the corridor tile
	super._ready()
	_load_saved_state()


func _load_saved_state() -> void:
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if not is_instance_valid(gs) or not gs.has_method("get_object_state"):
		return

	var map_id: String = _get_current_map_id()
	var state: Dictionary = gs.get_object_state(map_id, object_id) as Dictionary

	if state.has("is_inspected"):
		is_inspected = bool(state["is_inspected"])


func interact(_player: Node3D) -> void:
	var map_id: String = _get_current_map_id()

	if not is_inspected:
		is_inspected = true
		var gs: Node = get_tree().root.get_node_or_null("GameState")
		if is_instance_valid(gs):
			if gs.has_method("set_object_state_flag"):
				gs.set_object_state_flag(map_id, object_id, "is_inspected", true)
			if xp_reward > 0 and gs.has_method("add_xp"):
				gs.add_xp(xp_reward)

	SignalBus.popup_requested.emit(&"LORE_POPUP", {
		"title": lore_title,
		"body": lore_text,
		"object_id": object_id,
		"aura_type": aura_type
	})
