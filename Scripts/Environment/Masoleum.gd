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

@export_group("Puzzle")
## When set, searching opens a combination lock (CodeLockPanel) instead of the lore popup.
## Its length is the number of dials. Empty = plain lore object (old behaviour).
@export var puzzle_code: String = ""
@export var puzzle_title: String = "ANCIENT LOCK"
@export_multiline var puzzle_hint: String = ""
## Node unlocked by the right code (anything with an unlock() method, e.g. the Windmill).
@export var unlocks: NodePath
## Shown when searching again after the puzzle is solved.
@export_multiline var solved_text: String = "The stone seal hangs open. Somewhere nearby, old gears groan as they turn."
## XP for solving the puzzle.
@export var puzzle_xp_reward: int = 60

var is_inspected: bool = false
var is_solved: bool = false
var _lock_panel: CodeLockPanel = null


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
	if state.has("puzzle_solved"):
		is_solved = bool(state["puzzle_solved"])


func interact(_player: Node3D = null) -> void:
	if not puzzle_code.is_empty():
		_interact_puzzle()
		return
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


# ==============================================================================
# PUZZLE
# ==============================================================================
func _interact_puzzle() -> void:
	if is_solved:
		_show_lore(puzzle_title, solved_text)
		return
	if is_instance_valid(_lock_panel):
		return
	if is_instance_valid(AudioManager) and AudioManager.has_method(&"play_mask_sound"):
		AudioManager.call(&"play_mask_sound", aura_type)
	var hint: String = puzzle_hint if not puzzle_hint.is_empty() else lore_text
	_lock_panel = CodeLockPanel.open(get_tree(), puzzle_code, puzzle_title, hint)
	_lock_panel.solved.connect(_on_puzzle_solved)


func _on_puzzle_solved() -> void:
	is_solved = true
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(gs):
		var map_id: String = _get_map_id()
		if gs.has_method("set_object_state_flag"):
			gs.set_object_state_flag(map_id, object_id, "puzzle_solved", true)
		if puzzle_xp_reward > 0 and gs.has_method("add_xp"):
			gs.add_xp(puzzle_xp_reward)
	var target: Node = get_node_or_null(unlocks)
	if is_instance_valid(target) and target.has_method("unlock"):
		target.call("unlock")
	elif not unlocks.is_empty():
		push_warning("Masoleum: '%s' has no unlock() method (check the 'unlocks' path)." % unlocks)
	if is_instance_valid(SignalBus):
		SignalBus.camera_shake_requested.emit(0.45)


func _show_lore(title: String, body: String) -> void:
	if is_instance_valid(SignalBus) and SignalBus.has_signal(&"popup_requested"):
		SignalBus.popup_requested.emit(&"LORE_POPUP", {
			"title": title,
			"body": body,
			"object_id": object_id,
			"aura_type": "none"
		})


## Alias for interact to support search calls
func inspect(player: Node = null) -> void:
	interact(player as Node3D)


## Helper to resolve map ID safely across base class variations
func _get_map_id() -> String:
	if has_method(&"_get_current_map_id"):
		return call(&"_get_current_map_id") as String
	return GameState.get_current_map_id()
