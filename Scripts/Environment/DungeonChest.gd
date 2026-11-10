# res://Scripts/Environment/DungeonChest.gd
class_name DungeonChest
extends DungeonInteractable

## Optional LootTable resource to roll random loot
@export var loot_table: Resource

## Guaranteed items inside this chest
@export var guaranteed_items: Array[ItemData] = []

## Gold currency rewarded upon opening
@export var gold_amount: int = 0

## Node reference for the lid mesh/pivot to rotate when opened (fallback if no AnimationPlayer)
@export var lid_node: Node3D

## Angle in degrees to rotate the lid open (-80° on X axis). Used only when no open animation exists.
@export var open_angle_deg: float = -80.0

## Animation name on the chest GLB AnimationPlayer (chest.glb ships "open" / "close" / "open-close").
@export var open_animation: String = "open"

var is_opened: bool = false
var is_looted: bool = false
var stored_loot: Array[ItemData] = []
var _anim_player: AnimationPlayer = null


func _ready() -> void:
	super._ready()
	_auto_detect_animation_player()
	_auto_detect_lid_node()
	_load_saved_state()


func _auto_detect_animation_player() -> void:
	_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer


func _auto_detect_lid_node() -> void:
	if is_instance_valid(lid_node):
		return
	# GLB lid is often lowercase "lid"; find_child patterns are case-sensitive.
	for child: Node in find_children("*", "Node3D", true, false):
		var n3: Node3D = child as Node3D
		if not is_instance_valid(n3):
			continue
		if n3.name.to_lower() == "lid" or "lid" in n3.name.to_lower():
			lid_node = n3
			return


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

	if is_opened:
		_snap_lid_open()


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


## Plays the GLB "open" clip when present; otherwise tweens lid_node by open_angle_deg.
func _animate_open_lid() -> void:
	if _play_open_animation(false):
		return
	if not is_instance_valid(lid_node):
		return
	var tween: Tween = create_tween()
	tween.tween_property(lid_node, "rotation_degrees:x", open_angle_deg, 0.4) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


## Instantly shows the opened pose (saved chests that were already opened).
func _snap_lid_open() -> void:
	if _play_open_animation(true):
		return
	if is_instance_valid(lid_node):
		lid_node.rotation_degrees.x = open_angle_deg


## Returns true when the AnimationPlayer handled the open pose.
func _play_open_animation(snap_to_end: bool) -> bool:
	if not is_instance_valid(_anim_player):
		return false
	var anim_name: String = open_animation.strip_edges()
	if anim_name.is_empty() or not _anim_player.has_animation(anim_name):
		return false
	var anim: Animation = _anim_player.get_animation(anim_name)
	_anim_player.play(anim_name)
	if snap_to_end and is_instance_valid(anim):
		_anim_player.seek(anim.length, true)
		_anim_player.pause()
	return true


## Generates and stores the loot array if not already rolled
func _generate_loot_contents() -> void:
	stored_loot.clear()

	for item in guaranteed_items:
		if not is_instance_valid(item):
			continue
		_append_resolved_item(item as ItemData)

	if is_instance_valid(loot_table) and loot_table.has_method("roll_table"):
		var rolled: Array = loot_table.call("roll_table") as Array
		for rolled_item in rolled:
			if rolled_item is ItemData:
				_append_resolved_item(rolled_item as ItemData)

	_append_party_gear_drops()


## Duplicates normal items; expands PartyGear tokens into live party gear.
func _append_resolved_item(item: ItemData) -> void:
	if PartyGearLoot.is_party_gear_token(item):
		stored_loot.append_array(PartyGearLoot.resolve_token(item))
		return
	stored_loot.append(item.duplicate() as ItemData)


## Pulls rolls from any PartyGearDrop (or roll_loot) children attached to this chest.
func _append_party_gear_drops() -> void:
	for child: Node in get_children():
		if not child.has_method("roll_loot"):
			continue
		var rolled_gear: Variant = child.call("roll_loot")
		if not (rolled_gear is Array):
			continue
		for gear_item: Variant in rolled_gear as Array:
			if gear_item is ItemData:
				stored_loot.append(gear_item as ItemData)


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
