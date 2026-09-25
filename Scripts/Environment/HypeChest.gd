# res://Scripts/Environment/HypeChest.gd
class_name HypeChest
extends DungeonInteractable

## Optional LootTable resource to roll random loot
@export var loot_table: Resource

## Guaranteed items inside this chest (weapons, gear, etc.)
@export var guaranteed_items: Array[ItemData] = []

## Gold currency rewarded upon opening
@export var gold_amount: int = 100

## Aura effect preset to trigger when inspected ("good", "bad", "none")
@export_enum("good", "bad", "none") var aura_type: String = "good"

var is_opened: bool = false
var is_looted: bool = false
var stored_loot: Array[ItemData] = []


func _ready() -> void:
	super._ready()
	_load_saved_state()


func _load_saved_state() -> void:
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if not is_instance_valid(gs) or not gs.has_method("get_object_state"):
		return

	var map_id: String = _get_current_map_id()
	var state: Dictionary = gs.get_object_state(map_id, object_id) as Dictionary

	if state.has("is_opened"):
		is_opened = bool(state["is_opened"])
	if state.has("is_looted"):
		is_looted = bool(state["is_looted"])


func interact(_player: Node3D) -> void:
	var map_id: String = _get_current_map_id()

	if is_looted:
		if is_instance_valid(SignalBus) and SignalBus.has_signal(&"show_toast"):
			SignalBus.show_toast.emit("The hype chest is empty.", false)
		return

	if not is_opened:
		is_opened = true
		var gs: Node = get_tree().root.get_node_or_null("GameState")
		if is_instance_valid(gs) and gs.has_method("set_object_state_flag"):
			gs.set_object_state_flag(map_id, object_id, "is_opened", true)
		_generate_loot_contents()

	_open_loot_ui()


func _generate_loot_contents() -> void:
	stored_loot.clear()

	for item in guaranteed_items:
		if is_instance_valid(item):
			stored_loot.append(item.duplicate() as ItemData)

	if is_instance_valid(loot_table) and loot_table.has_method("roll_table"):
		var rolled: Array = loot_table.call("roll_table") as Array
		for rolled_item in rolled:
			if rolled_item is ItemData:
				stored_loot.append(rolled_item as ItemData)


func _open_loot_ui() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_environment("open-chest")

	if is_instance_valid(SignalBus):
		# Gold screen flash
		SignalBus.edge_flash_requested.emit(Color(1.0, 0.84, 0.0, 0.9), 0.6)
		# Request chest popup with good aura payload
		SignalBus.popup_requested.emit(&"CHEST_LOOT", {
			"chest": self,
			"loot": stored_loot,
			"gold": gold_amount,
			"object_id": object_id,
			"aura_type": aura_type
		})


func mark_as_looted() -> void:
	is_looted = true
	stored_loot.clear()
	var map_id: String = _get_current_map_id()
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(gs) and gs.has_method("set_object_state_flag"):
		gs.set_object_state_flag(map_id, object_id, "is_looted", true)
		if gs.has_method("save_game"):
			gs.save_game()