# res://Scripts/Environment/DungeonChest.gd
class_name DungeonChest
extends DungeonInteractable

## Optional LootTable resource to roll random loot
@export var loot_table: Resource

## Guaranteed items inside this chest
@export var guaranteed_items: Array[ItemData] = []

## Gold currency rewarded upon opening
@export var gold_amount: int = 0

## Node reference for the lid mesh/pivot to rotate when opened
@export var lid_node: Node3D

## Angle in degrees to rotate the lid open (-80° on X axis)
@export var open_angle_deg: float = -80.0

var is_opened: bool = false
var is_looted: bool = false
var stored_loot: Array[ItemData] = []


func _ready() -> void:
	super._ready()
	_auto_detect_lid_node()
	_load_saved_state()


func _auto_detect_lid_node() -> void:
	if not is_instance_valid(lid_node):
		var candidate: Node3D = find_child("*Lid*", true, false) as Node3D
		if is_instance_valid(candidate):
			lid_node = candidate


## Restores opened/looted visual and data state from GameState persistence
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

	if is_opened and is_instance_valid(lid_node):
		lid_node.rotation_degrees.x = open_angle_deg


## Triggered when the player interacts with this chest
func interact(_player: Node3D) -> void:
	var map_id: String = _get_current_map_id()

	if is_looted:
		SignalBus.show_toast.emit("The chest is empty.", false)
		return

	if not is_opened:
		_animate_open_lid()
		is_opened = true

		# Emit a bright, strong Gold edge flash (0.6s duration, 90% opacity)
		if is_instance_valid(SignalBus):
			SignalBus.edge_flash_requested.emit(Color(1.0, 0.84, 0.0, 0.9), 0.6)

		var gs: Node = get_tree().root.get_node_or_null("GameState")
		if is_instance_valid(gs) and gs.has_method("set_object_state_flag"):
			gs.set_object_state_flag(map_id, object_id, "is_opened", true)
		_generate_loot_contents()

	_open_loot_ui()


## Rotates the 3D lid mesh open smoothly
func _animate_open_lid() -> void:
	if not is_instance_valid(lid_node):
		return

	var tween: Tween = create_tween()
	tween.tween_property(lid_node, "rotation_degrees:x", open_angle_deg, 0.4) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


## Generates and stores the loot array if not already rolled
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
	SignalBus.popup_requested.emit(&"CHEST_LOOT", {
		"chest": self,
		"loot": stored_loot,
		"gold": gold_amount,
		"object_id": object_id
	})


## Called by the Loot UI when all items are collected or accepted
func mark_as_looted() -> void:
	is_looted = true
	stored_loot.clear()
	var map_id: String = _get_current_map_id()
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(gs) and gs.has_method("set_object_state_flag"):
		gs.set_object_state_flag(map_id, object_id, "is_looted", true)
		if gs.has_method("save_game"):
			gs.save_game()
