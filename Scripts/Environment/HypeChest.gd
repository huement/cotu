# res://Scripts/Environment/HypeChest.gd
class_name HypeChest
extends DungeonChest

## Aura effect preset to trigger when inspected ("good", "bad", "none")
@export_enum("good", "bad", "none") var aura_type: String = "good"


func interact(_player: Node3D) -> void:
	var map_id: String = _get_current_map_id()

	if is_looted:
		SignalBus.show_toast.emit("The hype chest is empty.", false)
		return

	if not is_opened:
		_animate_open_lid()
		is_opened = true

		if is_instance_valid(SignalBus):
			SignalBus.edge_flash_requested.emit(Color(1.0, 0.84, 0.0, 0.9), 0.6)

		var gs: Node = get_tree().root.get_node_or_null("GameState")
		if is_instance_valid(gs) and gs.has_method("set_object_state_flag"):
			gs.set_object_state_flag(map_id, object_id, "is_opened", true)
		_generate_loot_contents()

	_open_loot_ui()


func _open_loot_ui() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_environment("open-chest")

	SignalBus.popup_requested.emit(&"CHEST_LOOT", {
		"chest": self,
		"loot": stored_loot,
		"gold": gold_amount,
		"object_id": object_id,
		"aura_type": aura_type
	})
