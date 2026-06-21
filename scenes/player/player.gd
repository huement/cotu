class_name Player
extends GridEntity

## Emitted when the team bumps into solid walls or barriers
signal blocked_feedback_cue(cmd: GridCommand.Type)

## Decoupled signals passing tactical positioning metrics and character state data
signal party_member_damaged(slot_index: int, cat: CatCharacter, amount: int, old_hp: int, new_hp: int)
signal party_member_healed(slot_index: int, cat: CatCharacter, amount: int, old_hp: int, new_hp: int)

@export var camera_height: float = 0.5
@export var camera_retreat_distance: float = 0.0
@export var input_actions_enabled: bool = true
@export var debug_log_input_actions: bool = false

@onready var _camera: Camera3D = $Camera3D

var _active_tween: Tween
var _blocked_tween: Tween
var inventory: Resource # Assigned to your custom Inventory resource container

func _ready() -> void:
	super()
	_sync_camera_height()
	
	# Hook up underlying navigation listeners
	if movement_controller:
		movement_controller.action_started.connect(_on_action_started)
		movement_controller.movement_outcome.connect(_on_movement_outcome)

# =============================================================================
# ⚔️ 6-SLOT PARTY DAMAGE & UTILITY CONTROLLERS
# =============================================================================

## Inflicts damage onto a specific slot index and updates global tracking logs
func damage_character_slot(slot_index: int, amount: int) -> void:
	if slot_index < 0 or slot_index >= 6:
		push_error("Target slot out of combat bounds: %d" % slot_index)
		return
		
	var cat: CatCharacter = GameState.party[slot_index]
	if cat == null:
		return # No cat allocated to this slot to receive the blow
		
	var old_hp: int = cat.current_hp
	cat.current_hp = max(0, cat.current_hp - amount)
	var new_hp: int = cat.current_hp
	
	print("Combat Log: %s in Slot %d took %d damage (%d -> %d)" % [cat.name, slot_index, amount, old_hp, new_hp])
	
	# Broadcast locally and to global UI listeners
	party_member_damaged.emit(slot_index, cat, amount, old_hp, new_hp)
	SignalBus.party_member_stats_changed.emit(slot_index, cat)
	SignalBus.game_log_emitted.emit("%s took [color=red]%d[/color] damage!" % [cat.name, amount])

## Restores life metrics to a targeted party slot index
func heal_character_slot(slot_index: int, amount: int) -> void:
	if slot_index < 0 or slot_index >= 6:
		return
		
	var cat: CatCharacter = GameState.party[slot_index]
	if cat == null:
		return
		
	var old_hp: int = cat.current_hp
	cat.current_hp = min(cat.max_hp, cat.current_hp + amount)
	var new_hp: int = cat.current_hp
	
	party_member_healed.emit(slot_index, cat, amount, old_hp, new_hp)
	SignalBus.party_member_stats_changed.emit(slot_index, cat)
	SignalBus.game_log_emitted.emit("%s healed for [color=green]%d[/color] HP." % [cat.name, amount])

## Target Rule: Selects a random living slot from the Front Row (Slots 0-2)
func damage_random_front_row_member(amount: int) -> void:
	var living_front_indices: Array[int] = []
	for i in range(3):
		if GameState.party[i] != null and GameState.party[i].current_hp > 0:
			living_front_indices.append(i)
			
	if not living_front_indices.is_empty():
		var chosen_slot: int = living_front_indices[randi() % living_front_indices.size()]
		damage_character_slot(chosen_slot, amount)
	else:
		# Fallback to back row if the front row has fallen
		damage_random_back_row_member(amount)

## Target Rule: Selects a random living slot from the Back Row (Slots 3-5)
func damage_random_back_row_member(amount: int) -> void:
	var living_back_indices: Array[int] = []
	for i in range(3, 6):
		if GameState.party[i] != null and GameState.party[i].current_hp > 0:
			living_back_indices.append(i)
			
	if not living_back_indices.is_empty():
		var chosen_slot: int = living_back_indices[randi() % living_back_indices.size()]
		damage_character_slot(chosen_slot, amount)

## AoE Rule: Applies a damage modifier to every deployed space cat uniformly
func damage_entire_party(amount: int) -> void:
	SignalBus.game_log_emitted.emit("[color=orange]An area-of-effect hazard strikes the squad![/color]")
	for i in range(6):
		if GameState.party[i] != null:
			damage_character_slot(i, amount)

# =============================================================================
# 🎒 INVENTORY PIPELINES
# =============================================================================

func add_item(item: Resource) -> bool:
	if inventory == null or not inventory.has_method("add_item"):
		return false
	return inventory.add_item(item)

func remove_item(item: Resource) -> bool:
	if inventory == null or not inventory.has_method("remove_item"):
		return false
	return inventory.remove_item(item)

# =============================================================================
# 🗺️ INPUT AND INTERPOLATION CALCULATION METHODS
# =============================================================================

func pause_exploration_commands() -> void:
	input_actions_enabled = false
	pause_commands()

func resume_exploration_commands() -> void:
	input_actions_enabled = true
	resume_commands()

func execute_action(action: StringName) -> bool:
	if not input_actions_enabled:
		return false

	var cmd: int = _command_for_action(action)
	if cmd == INVALID_COMMAND:
		return false

	var executed: bool = execute_command(cmd as GridCommand.Type)
	if debug_log_input_actions:
		print("[PlayerInput] action=%s executed=%s busy=%s" % [action, executed, movement_controller.is_busy])

	return executed

func _unhandled_input(event: InputEvent) -> void:
	if not input_actions_enabled:
		return

	if event is InputEventKey and event.echo:
		return

	var action: StringName = _find_pressed_action(event)
	if action == StringName():
		return

	execute_action(action)
	get_viewport().set_input_as_handled()

func _apply_canonical_transform() -> void:
	super()
	_sync_camera_height()

func _on_action_started(_cmd: GridCommand.Type, previous_state: GridState, new_state: GridState, duration: float) -> void:
	if movement_config == null or not movement_config.smooth_mode or duration <= 0.0:
		return

	_cancel_blocked_feedback()

	if is_instance_valid(_active_tween):
		_active_tween.kill()

	var start_pos: Vector3 = GridMapper.cell_to_world(previous_state.cell, movement_config.cell_size, 0.0)
	var target_pos: Vector3 = GridMapper.cell_to_world(new_state.cell, movement_config.cell_size, 0.0)
	var start_yaw: float = -float(previous_state.facing) * 90.0
	var target_yaw: float = _resolve_target_yaw(start_yaw, -float(new_state.facing) * 90.0)

	global_position = start_pos
	rotation_degrees.y = start_yaw

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(self, "global_position", target_pos, duration)
	_active_tween.parallel().tween_method(_set_yaw, start_yaw, target_yaw, duration)

func _on_action_completed(cmd: GridCommand.Type, new_state: GridState) -> void:
	_cancel_blocked_feedback()

	if is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null

	super(cmd, new_state)

	if debug_log_input_actions:
		print("[PlayerState] cell=%s facing=%s world_pos=%s yaw=%.1f" % [
			grid_state.cell,
			_facing_to_name(grid_state.facing),
			global_position,
			rotation_degrees.y,
		])

func _on_movement_outcome(outcome: Variant) -> void:
	if movement_config == null or not movement_config.blocked_feedback_enabled:
		return

	# Duck-typing dynamically checks properties against your framework's original definitions
	if outcome.outcome_type != MovementOutcome.TYPE_BLOCKED:
		return

	if outcome.phase != MovementOutcome.PHASE_DECISION:
		return

	_play_blocked_feedback(outcome.command)

func _set_yaw(value: float) -> void:
	rotation_degrees.y = value

func _sync_camera_height() -> void:
	if _camera == null:
		return
	_camera.position = Vector3(0.0, camera_height, camera_retreat_distance)

func _resolve_target_yaw(start_yaw: float, base_target_yaw: float) -> float:
	var delta: float = fmod(base_target_yaw - start_yaw + 540.0, 360.0) - 180.0
	return start_yaw + delta

func _find_pressed_action(event: InputEvent) -> StringName:
	var actions: Array[StringName] = [
		&"move_forward",
		&"move_back",
		&"move_left",
		&"move_right",
		&"turn_left",
		&"turn_right",
	]

	for action in actions:
		if event.is_action_pressed(action):
			return action

	return StringName()

func _cancel_blocked_feedback() -> void:
	if is_instance_valid(_blocked_tween):
		_blocked_tween.kill()
	_blocked_tween = null

func _play_blocked_feedback(cmd: GridCommand.Type) -> void:
	if movement_config == null:
		return

	if movement_config.blocked_bump_distance <= 0.0 or movement_config.blocked_bump_duration <= 0.0:
		return

	if cmd != GridCommand.Type.STEP_FORWARD:
		_cancel_blocked_feedback()
		global_position = GridMapper.cell_to_world(grid_state.cell, movement_config.cell_size, 0.0)
		blocked_feedback_cue.emit(cmd)
		return

	_cancel_blocked_feedback()

	var base_pos: Vector3 = GridMapper.cell_to_world(grid_state.cell, movement_config.cell_size, 0.0)
	global_position = base_pos

	var facing_vec: Vector2i = GridDefinitions.facing_to_vec2i(grid_state.facing)
	var bump_dir: Vector3 = Vector3(float(facing_vec.x), 0.0, float(facing_vec.y)).normalized()
	if bump_dir == Vector3.ZERO:
		return

	var bump_target: Vector3 = base_pos + bump_dir * movement_config.blocked_bump_distance
	var half_duration: float = maxf(movement_config.blocked_bump_duration * 0.5, 0.001)
	var immediate_nudge: float = minf(movement_config.blocked_bump_distance * 0.1, 0.01)
	global_position = base_pos + bump_dir * immediate_nudge

	_blocked_tween = create_tween()
	_blocked_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_blocked_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_blocked_tween.tween_property(self, "global_position", bump_target, half_duration)
	_blocked_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_blocked_tween.tween_property(self, "global_position", base_pos, half_duration)
	_blocked_tween.finished.connect(_on_blocked_feedback_finished)

func _on_blocked_feedback_finished() -> void:
	_blocked_tween = null

func _command_for_action(action: StringName) -> int:
	match action:
		&"move_forward":
			return GridCommand.Type.STEP_FORWARD
		&"move_back":
			return GridCommand.Type.STEP_BACK
		&"move_left":
			return GridCommand.Type.MOVE_LEFT
		&"move_right":
			return GridCommand.Type.MOVE_RIGHT
		&"turn_left":
			return GridCommand.Type.TURN_LEFT
		&"turn_right":
			return GridCommand.Type.TURN_RIGHT
		_:
			return INVALID_COMMAND

func _facing_to_name(facing: GridDefinitions.Facing) -> String:
	match facing:
		GridDefinitions.Facing.NORTH:
			return "NORTH"
		GridDefinitions.Facing.EAST:
			return "EAST"
		GridDefinitions.Facing.SOUTH:
			return "SOUTH"
		GridDefinitions.Facing.WEST:
			return "WEST"
		_:
			return "UNKNOWN"
