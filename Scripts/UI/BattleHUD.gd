# res://Scripts/UI/BattleHUD.gd
class_name BattleHUD
extends Control

enum CombatState { IDLE, AWAITING_ACTION, SELECTING_TARGET }

const ACTION_ATTACK: StringName = &"ATTACK"

@onready var enemy_name_label: Label = %EnemyNameLabel as Label
@onready var enemy_hp_label: Label = %EnemyHPLabel as Label
@onready var turn_character_label: Label = %TurnCharacter as Label
@onready var turn_info_label: Label = %TurnInfo as Label

@onready var left_chevrons: TextureRect = %LeftChevrons as TextureRect
@onready var right_chevrons: TextureRect = %RightChevrons as TextureRect
@onready var auto_button: TextureButton = %AutoButton as TextureButton

@onready var party_left: VBoxContainer = %PartyLeft as VBoxContainer
@onready var party_right: VBoxContainer = %PartyRight as VBoxContainer
@onready var action_bar: Control = %ActionBar as Control

var portrait_slots: Array[Node] = []
var _state: CombatState = CombatState.IDLE
var _active_slot_index: int = -1
var _selected_action: StringName = &""
var _is_auto_battle_on: bool = false


func _ready() -> void:
	hide()
	_initialize_portrait_slots()
	_connect_to_signal_bus()
	_bind_action_buttons()

	if is_instance_valid(auto_button):
		auto_button.toggled.connect(_on_auto_button_toggled)

func _bind_action_buttons() -> void:
	if not is_instance_valid(action_bar):
		return

	var buttons: Array[Node] = action_bar.find_children("*", "BaseButton", true, false)

	for node: Node in buttons:
		var btn: BaseButton = node as BaseButton
		var action_type: StringName = &"ATTACK"

		if "action_type" in btn:
			action_type = btn.get("action_type") as StringName
		else:
			var b_name: String = btn.name.to_upper()
			if "DEFEND" in b_name: action_type = &"DEFEND"
			elif "MAGIC" in b_name or "SPELL" in b_name or "SKILL" in b_name: action_type = &"SPELL"
			elif "ITEM" in b_name: action_type = &"ITEM"
			elif "RUN" in b_name or "FLEE" in b_name: action_type = &"RUN"

		if not btn.pressed.is_connected(_on_action_button_pressed):
			btn.pressed.connect(_on_action_button_pressed.bind(action_type, btn.name))

func _connect_to_signal_bus() -> void:
	var sb: Node = SignalBus
	if not is_instance_valid(sb): return

	if not sb.combat_started.is_connected(_on_combat_started):
		sb.combat_started.connect(_on_combat_started)
	if not sb.combat_ended.is_connected(_on_combat_ended):
		sb.combat_ended.connect(_on_combat_ended)
	if not sb.combatant_turn_ready.is_connected(_on_combatant_turn_ready):
		sb.combatant_turn_ready.connect(_on_combatant_turn_ready)
	if not sb.enemy_health_changed.is_connected(_on_enemy_health_changed):
		sb.enemy_health_changed.connect(_on_enemy_health_changed)
	if not sb.chevron_flash_requested.is_connected(_on_chevron_flash):
		sb.chevron_flash_requested.connect(_on_chevron_flash)

func _on_combatant_turn_ready(combatant_id: String, slot_index: int) -> void:
	if not combatant_id.begins_with("party_slot_"): return

	if _is_auto_battle_on:
		SignalBus.player_action_selected.emit(slot_index, ACTION_ATTACK, 0)
		return

	_state = CombatState.AWAITING_ACTION
	_active_slot_index = slot_index

	# 1. Highlight Active Portrait Frame
	for i: int in range(portrait_slots.size()):
		if is_instance_valid(portrait_slots[i]) and portrait_slots[i].has_method("set_active"):
			portrait_slots[i].set_active(i == slot_index)

	# 2. Resolve Active Cat Name
	var cat_name: String = "COMMANDER WHISKERS"
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	
	if is_instance_valid(gs) and "current_party" in gs and gs.current_party:
		var slots: Array = gs.current_party.get("slots") as Array
		if slot_index < slots.size() and is_instance_valid(slots[slot_index]):
			var cat_res: Resource = slots[slot_index] as Resource
			if "name" in cat_res and cat_res.get("name") != null:
				cat_name = str(cat_res.get("name")).to_upper()
			elif "character_name" in cat_res and cat_res.get("character_name") != null:
				cat_name = str(cat_res.get("character_name")).to_upper()

	# 3. Update Labels
	if is_instance_valid(turn_character_label):
		turn_character_label.text = cat_name

	if is_instance_valid(turn_info_label):
		turn_info_label.text = "ACTIVE"

	# 4. Display Action Bar
	if is_instance_valid(action_bar):
		action_bar.show()

func _on_action_button_pressed(action_type: StringName, button_name: String) -> void:
	if _state != CombatState.AWAITING_ACTION: return

	# FIX: Save active slot, reset UI state FIRST, then emit the action signal!
	var current_slot: int = _active_slot_index
	_reset_state()
	SignalBus.player_action_selected.emit(current_slot, action_type, 0)

func _reset_state() -> void:
	for slot in portrait_slots:
		if is_instance_valid(slot) and slot.has_method("set_active"):
			slot.set_active(false)

	_state = CombatState.IDLE
	_active_slot_index = -1
	_selected_action = &""

	if is_instance_valid(action_bar):
		action_bar.hide()
		
	if is_instance_valid(turn_info_label):
		turn_info_label.text = "WAITING"

func _on_auto_button_toggled(is_on: bool) -> void:
	_is_auto_battle_on = is_on
	if is_instance_valid(auto_button):
		auto_button.modulate = Color.GREEN if is_on else Color.WHITE

func _on_enemy_health_changed(current_hp: int, max_hp: int) -> void:
	if is_instance_valid(enemy_hp_label):
		enemy_hp_label.text = "%d / %d" % [current_hp, max_hp]

func _on_chevron_flash(is_player_hit: bool) -> void:
	var flash_color: Color = Color.RED if is_player_hit else Color.ORANGE
	var tween: Tween = create_tween().set_parallel(true)
	if is_instance_valid(left_chevrons): 
		left_chevrons.modulate = flash_color
		tween.tween_property(left_chevrons, "modulate", Color.WHITE, 0.4)
	if is_instance_valid(right_chevrons):
		right_chevrons.modulate = flash_color
		tween.tween_property(right_chevrons, "modulate", Color.WHITE, 0.4)

# res://Scripts/UI/BattleHUD.gd
func _initialize_portrait_slots() -> void:
	portrait_slots.clear()
	portrait_slots.resize(6)

	var all_portraits: Array[Node] = []
	if is_instance_valid(party_left): all_portraits.append_array(party_left.get_children())
	if is_instance_valid(party_right): all_portraits.append_array(party_right.get_children())

	for i: int in range(all_portraits.size()):
		var portrait: Node = all_portraits[i]
		if not is_instance_valid(portrait): continue

		# Force explicit slot_index mapping (0..5)
		var idx: int = i
		if "slot_index" in portrait:
			var set_idx: Variant = portrait.get("slot_index")
			if typeof(set_idx) == TYPE_INT and set_idx >= 0 and set_idx < 6:
				idx = int(set_idx)

		portrait.set("slot_index", idx)
		if idx < 6:
			portrait_slots[idx] = portrait

func setup_party_display(party_members: Array) -> void:
	if portrait_slots.is_empty(): _initialize_portrait_slots()

	for i: int in range(portrait_slots.size()):
		var slot_node: Node = portrait_slots[i]
		if not is_instance_valid(slot_node): continue

		# Guarantee slot index alignment
		if "slot_index" in slot_node:
			slot_node.set("slot_index", i)

		if i < party_members.size() and is_instance_valid(party_members[i]):
			if slot_node.has_method("setup_slot"):
				slot_node.call("setup_slot", party_members[i])
		else:
			if slot_node.has_method("setup_slot"):
				slot_node.call("setup_slot", null)

## support both single resources and enemy arrays
func _on_combat_started(enemy_data_or_group: Variant, player_party: Array) -> void:
	# 1. Normalize incoming parameter to an Array[Resource]
	var enemy_group: Array[Resource] = []
	if enemy_data_or_group is Array:
		enemy_group = enemy_data_or_group as Array[Resource]
	elif enemy_data_or_group is Resource:
		enemy_group.append(enemy_data_or_group as Resource)

	if enemy_group.is_empty():
		return

	# 2. Get the lead enemy resource to display stats in top banner
	var primary_enemy: Resource = enemy_group[0]
	if is_instance_valid(primary_enemy):
		_update_enemy_banner_ui(primary_enemy)

	# 🎯 3. RESTORED: Populate the 6 party slot portraits!
	setup_party_display(player_party)

	show()

## Updates the top UI banner with enemy stats
func _update_enemy_banner_ui(enemy_resource: Resource) -> void:
	var e_name: String = str(enemy_resource.get("enemy_name")) if enemy_resource.get("enemy_name") != null else "CYBER-ZOMBIE CAT"
	var e_max_hp: int = int(enemy_resource.get("max_health")) if "max_health" in enemy_resource else 30
	var e_hp: int = int(enemy_resource.get("current_health")) if "current_health" in enemy_resource else e_max_hp

	if is_instance_valid(enemy_name_label):
		enemy_name_label.text = e_name.to_upper()
		
	if is_instance_valid(enemy_hp_label):
		enemy_hp_label.text = "%d / %d" % [e_hp, e_max_hp]
		
func _on_combat_ended(_victory: bool) -> void:
	hide()
	_reset_state()
