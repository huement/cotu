# res://Scripts/Environment/Masoleum.gd
class_name Masoleum
extends DungeonInteractable

## Display header for the lore popup modal
@export var lore_title: String = "CRYPT INSCRIPTION"

## Multiline narrative log or terminal archive text
@export_multiline var lore_text: String = "The stone is cold and damp. An inscription reads: 'Here lies the fallen, their spirits bound to the stone.'"

## Exploration XP awarded upon first inspection
@export var xp_reward: int = 35

@export_enum("bad", "good", "none") var aura_type: String = "bad"

var is_inspected: bool = false


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"searchable")
	snap_to_floor_center = false # Preserves wall height & transform offset from 3D Editor
	is_blocking = true          # Masoleum blocks movement.
	super._ready()
	_load_saved_state()


func _load_saved_state() -> void:
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if not is_instance_valid(gs) or not gs.has_method("get_object_state"):
		return

	var map_id: String = _get_map_id()
	if map_id.is_empty():
		return

	var state: Dictionary = gs.get_object_state(map_id, object_id) as Dictionary
	if state.has("is_inspected"):
		is_inspected = bool(state["is_inspected"])


func interact(_player: Node3D = null) -> void:
	# 1. Safely play audio only if the method exists
	if is_instance_valid(AudioManager) and AudioManager.has_method(&"play_mask_sound"):
		AudioManager.call(&"play_mask_sound", aura_type)
		
	# 2. Award XP and save state on first inspection
	if not is_inspected:
		is_inspected = true
		var gs: Node = get_tree().root.get_node_or_null("GameState")
		if is_instance_valid(gs):
			var map_id: String = _get_map_id()
			if not map_id.is_empty() and gs.has_method("set_object_state_flag"):
				gs.set_object_state_flag(map_id, object_id, "is_inspected", true)
			if xp_reward > 0 and gs.has_method("add_xp"):
				gs.add_xp(xp_reward)

	# 3. Emit popup request for UI modal
	var sb: Node = SignalBus if is_instance_valid(SignalBus) else get_tree().root.get_node_or_null("SignalBus")
	if is_instance_valid(sb) and sb.has_signal(&"popup_requested"):
		sb.popup_requested.emit(&"LORE_POPUP", {
			"title": lore_title,
			"body": lore_text,
			"object_id": object_id,
			"aura_type": aura_type
		})


## Alias for interact to support search calls
func inspect(player: Node = null) -> void:
	interact(player as Node3D)


## Helper to resolve map ID safely across base class variations
func _get_map_id() -> String:
	if has_method(&"_get_current_map_id"):
		return call(&"_get_current_map_id") as String
	var map_mgr: Node = get_tree().current_scene.find_child("MapManager", true, false)
	if is_instance_valid(map_mgr) and "current_map_id" in map_mgr:
		return str(map_mgr.get("current_map_id"))
	return "default_map"