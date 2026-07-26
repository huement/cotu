# res://Scripts/UI/BattleHUD.gd
class_name BattleHUD
extends Control

## The BattleHUD is the central UI controller during combat. It displays enemy
## and party status, but more importantly, it listens for a combatant's turn
## and manages the player's action/target selection process via a state machine.
## It also includes an optional auto-battle feature.

# =============================================================================
# 1. STATE & CONFIGURATION
# =============================================================================

## Manages the UI flow for player input during combat.
## IDLE: No input required. Awaiting turn.
## AWAITING_ACTION: A party member's turn is ready. Displaying action buttons.
## SELECTING_TARGET: An action has been chosen. Awaiting target selection.
enum CombatState { IDLE, AWAITING_ACTION, SELECTING_TARGET }

const COLOR_NORMAL: Color = Color("23f0c7")
const COLOR_PLAYER_HIT: Color = Color("ff2a6d")
const COLOR_ENEMY_HIT: Color = Color("ffae00")
const ACTION_ATTACK: StringName = &"ATTACK"


# =============================================================================
# 2. SCENE UNIQUE NODE DEPENDENCIES
# =============================================================================

# Static Displays
@onready var enemy_name_label: Label = %EnemyNameLabel as Label
@onready var enemy_hp_label: Label = %EnemyHPLabel as Label
@onready var left_chevrons: TextureRect = %LeftChevrons as TextureRect
@onready var right_chevrons: TextureRect = %RightChevrons as TextureRect
@onready var auto_button: TextureButton = %AutoButton as TextureButton

# Party Portrait Containers
@onready var party_left: VBoxContainer = %PartyLeft as VBoxContainer
@onready var party_right: VBoxContainer = %PartyRight as VBoxContainer

# Action Controller
@onready var battle_action_bar: BattleActionBar = %ActionBar as BattleActionBar


# =============================================================================
# 3. RUNTIME VARIABLES
# =============================================================================

var portrait_slots: Array[Node] = []
var _state: CombatState = CombatState.IDLE
var _active_slot_index: int = -1
var _selected_action: StringName = &""
var _is_auto_battle_on: bool = false


# =============================================================================
# 4. GODOT LIFECYCLE & INITIALIZATION
# =============================================================================

func _ready() -> void:
	hide()
	_initialize_portrait_slots()
	_connect_to_signal_bus()

	if is_instance_valid(battle_action_bar) and battle_action_bar.has_signal("action_selected"):
		battle_action_bar.action_selected.connect(_on_action_selected)
	
	if is_instance_valid(auto_button):
		auto_button.toggled.connect(_on_auto_button_toggled)


func _connect_to_signal_bus() -> void:
	var sb: Node = SignalBus
	if not is_instance_valid(sb):
		return

	sb.chevron_flash_requested.connect(_on_chevron_flash)
	sb.enemy_health_changed.connect(_on_enemy_health_changed)
	sb.combat_started.connect(_on_combat_started)
	sb.combat_ended.connect(_on_combat_ended)
	sb.combatant_turn_ready.connect(_on_combatant_turn_ready)


# =============================================================================
# 5. TURN & ACTION HANDLING (STATE MACHINE)
# =============================================================================

# res://Scripts/UI/BattleHUD.gd

## ENTRY POINT: Called when a player character's turn is ready.
func _on_combatant_turn_ready(combatant_id: String, slot_index: int) -> void:
	if not combatant_id.begins_with("party_slot_"):
		return

	# If auto-battle is on, immediately emit basic attack command
	if _is_auto_battle_on:
		SignalBus.player_action_selected.emit(slot_index, ACTION_ATTACK, 0)
		return

	_state = CombatState.AWAITING_ACTION
	_active_slot_index = slot_index

	# Highlight the active character's portrait.
	if portrait_slots.size() > slot_index and is_instance_valid(portrait_slots[slot_index]):
		if portrait_slots[slot_index].has_method("set_active"):
			portrait_slots[slot_index].set_active(true)

	if is_instance_valid(battle_action_bar):
		battle_action_bar.show_for_character(slot_index)


## Called when a valid target (enemy or party member) is clicked.
func _on_target_selected(target_index: int) -> void:
	if _state != CombatState.SELECTING_TARGET:
		return

	if _active_slot_index == -1 or _selected_action == &"":
		push_error("Cannot execute action, required data is missing.")
		_reset_state()
		return

	# 🎯 EMIT ACTION VIA SIGNALBUS
	SignalBus.player_action_selected.emit(_active_slot_index, _selected_action, target_index)
	_reset_state()

## Called by the BattleActionBar when the player clicks an action button.
func _on_action_selected(action: StringName) -> void:
	if _state != CombatState.AWAITING_ACTION:
		return

	_selected_action = action
	_state = CombatState.SELECTING_TARGET
	print("Action '%s' selected. Awaiting target." % _selected_action)
	_on_target_selected(0) # Assume enemy is always target 0 for now.

## Resets the UI and state machine to an idle state after an action.
func _reset_state() -> void:
	# De-highlight any active character portraits.
	if _active_slot_index != -1 and portrait_slots.size() > _active_slot_index and is_instance_valid(portrait_slots[_active_slot_index]):
		if portrait_slots[_active_slot_index].has_method("set_active"):
			portrait_slots[_active_slot_index].set_active(false)

	_state = CombatState.IDLE
	_active_slot_index = -1
	_selected_action = &""

	if is_instance_valid(battle_action_bar):
		battle_action_bar.hide()


# =============================================================================
# 6. AUTO-BATTLE
# =============================================================================

## Toggles the auto-battle state when the %AutoButton is pressed.
func _on_auto_button_toggled(is_on: bool) -> void:
	_is_auto_battle_on = is_on
	auto_button.modulate = Color.GREEN if is_on else Color.WHITE


# =============================================================================
# 7. UI DISPLAY & FEEDBACK
# =============================================================================

func _initialize_portrait_slots() -> void:
	portrait_slots.clear()
	portrait_slots.resize(6)

	if is_instance_valid(party_left):
		for child: Node in party_left.get_children():
			if "slot_index" in child:
				var idx: int = child.get("slot_index")
				if idx >= 0 and idx < 6:
					portrait_slots[idx] = child

	if is_instance_valid(party_right):
		for child: Node in party_right.get_children():
			if "slot_index" in child:
				var idx: int = child.get("slot_index")
				if idx >= 0 and idx < 6:
					portrait_slots[idx] = child

func setup_party_display(party_members: Array) -> void:
	if portrait_slots.is_empty():
		_initialize_portrait_slots()

	for i: int in range(6):
		var slot_node: Node = portrait_slots[i]
		if not is_instance_valid(slot_node) or not slot_node.has_method("setup_slot"):
			continue

		if i < party_members.size() and party_members[i] != null:
			slot_node.call("setup_slot", party_members[i])
		else:
			slot_node.call("setup_slot", null)

func _on_combat_started(enemy_data: Resource = null, player_party: Array = []) -> void:
	show()

	var active_party: Array = player_party
	if active_party.is_empty() and Engine.has_singleton("GameState"):
		if GameState.current_party:
			active_party = GameState.current_party.slots
	
	setup_party_display(active_party)

	if is_instance_valid(enemy_data):
		# 1. Fetch enemy name safely (Object.get only accepts 1 parameter)
		var raw_name = enemy_data.get("enemy_name")
		var e_name: String = str(raw_name) if raw_name != null else "???"
		if is_instance_valid(enemy_name_label): 
			enemy_name_label.text = e_name.to_upper()
		
		# 2. Fetch enemy max health safely
		var raw_hp = enemy_data.get("max_health")
		var max_hp: int = int(raw_hp) if raw_hp != null else 1
		if is_instance_valid(enemy_hp_label): 
			enemy_hp_label.text = "%d / %d" % [max_hp, max_hp]

func _on_combat_ended(_victory: bool) -> void:
	hide()
	_reset_state()

func _on_chevron_flash(is_player_hit: bool) -> void:
	var flash_color: Color = COLOR_PLAYER_HIT if is_player_hit else COLOR_ENEMY_HIT
	var tween: Tween = create_tween().set_parallel(true)
	
	if is_instance_valid(left_chevrons): 
		left_chevrons.modulate = flash_color
		tween.tween_property(left_chevrons, "modulate", COLOR_NORMAL, 0.4)
	
	if is_instance_valid(right_chevrons): 
		right_chevrons.modulate = flash_color
		tween.tween_property(right_chevrons, "modulate", COLOR_NORMAL, 0.4)

func _on_enemy_health_changed(current_hp: int, max_hp: int) -> void:
	if is_instance_valid(enemy_hp_label):
		enemy_hp_label.text = "%d / %d" % [current_hp, max_hp]
