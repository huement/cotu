# res://Scripts/UI/BattleHUD.gd
class_name BattleHUD
extends Control

enum CombatState {
	IDLE,
	AWAITING_ACTION,
	SELECTING_TARGET,
}

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
var _buttons_bound: bool = false
var current_turn_slot_index: int = -1


func _ready() -> void:
	hide()
	_initialize_portrait_slots()
	_connect_to_signal_bus()
	_bind_action_buttons()

	if is_instance_valid(auto_button):
		auto_button.toggled.connect(_on_auto_button_toggled)


func _bind_action_buttons() -> void:
	if _buttons_bound or not is_instance_valid(action_bar):
		return

	_buttons_bound = true
	var buttons: Array[Node] = action_bar.find_children("*", "BaseButton", true, false)

	for node: Node in buttons:
		var btn: BaseButton = node as BaseButton
		if is_instance_valid(auto_button) and btn == auto_button:
			continue

		var action_type: StringName = &"ATTACK"

		if "action_type" in btn:
			action_type = btn.get("action_type") as StringName
		else:
			var b_name: String = btn.name.to_upper()
			if "DEFEND" in b_name:
				action_type = &"DEFEND"
			elif "MAGIC" in b_name or "SPELL" in b_name or "SKILL" in b_name:
				action_type = &"SPELL"
			elif "ITEM" in b_name:
				action_type = &"ITEM"
			elif "RUN" in b_name or "FLEE" in b_name:
				action_type = &"RUN"

		btn.pressed.connect(_on_action_button_pressed.bind(action_type, btn.name))


func _connect_to_signal_bus() -> void:
	var sb: Node = SignalBus
	if not is_instance_valid(sb):
		return

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
	if not sb.player_action_selected.is_connected(_on_player_action_selected):
		sb.player_action_selected.connect(_on_player_action_selected)


func _on_player_action_selected(_slot_index: int, _action: StringName, _target_index: int) -> void:
	_reset_state()


func _on_combatant_turn_ready(combatant_id: String, slot_index: int) -> void:
	current_turn_slot_index = slot_index

	if not combatant_id.begins_with("party_slot_"):
		return

	if _is_auto_battle_on:
		SignalBus.player_action_selected.emit(slot_index, ACTION_ATTACK, 0)
		return

	_state = CombatState.AWAITING_ACTION
	_active_slot_index = slot_index

	for i: int in range(portrait_slots.size()):
		if is_instance_valid(portrait_slots[i]) and portrait_slots[i].has_method("set_active"):
			portrait_slots[i].set_active(i == slot_index)

	var cat_name: String = "COMMANDER WHISKERS"
	var gs: Node = get_tree().root.get_node_or_null("GameState")

	if is_instance_valid(gs) and "current_party" in gs and gs.current_party:
		var slots: Array = gs.current_party.get("slots") as Array
		if slot_index >= 0 and slot_index < slots.size() and is_instance_valid(slots[slot_index]):
			var cat_res: Resource = slots[slot_index] as Resource
			if "name" in cat_res and cat_res.get("name") != null:
				cat_name = str(cat_res.get("name")).to_upper()
			elif "character_name" in cat_res and cat_res.get("character_name") != null:
				cat_name = str(cat_res.get("character_name")).to_upper()

	if is_instance_valid(turn_character_label):
		turn_character_label.text = cat_name
	if is_instance_valid(turn_info_label):
		turn_info_label.text = "ACTIVE"
	if is_instance_valid(action_bar):
		action_bar.show()


func _on_action_button_pressed(action_type: StringName, _button_name: String) -> void:
	if _state != CombatState.AWAITING_ACTION:
		return

	match action_type:
		&"SPELL", &"SKILL":
			var gs: Node = get_tree().root.get_node_or_null("GameState")
			var cm: Node = get_tree().root.get_node_or_null("CombatManager")

			var active_cat: CatCharacter = null
			if is_instance_valid(gs) and "current_party" in gs and gs.current_party:
				var slots: Array = gs.current_party.get("slots") as Array
				if _active_slot_index >= 0 and _active_slot_index < slots.size():
					active_cat = slots[_active_slot_index] as CatCharacter

			var combatants_list: Array = []
			if is_instance_valid(cm) and "combatants" in cm:
				combatants_list = cm.get("combatants") as Array

			SignalBus.popup_requested.emit(&"BATTLE_ABILITIES", { "character": active_cat, "slot_index": _active_slot_index, "combatants": combatants_list })

		&"ITEM":
			var gs: Node = get_tree().root.get_node_or_null("GameState")
			var inv: Inventory = gs.get("inventory") as Inventory if is_instance_valid(gs) and "inventory" in gs else null
			var cm: Node = get_tree().root.get_node_or_null("CombatManager")
			var combatants_list: Array = []
			if is_instance_valid(cm) and "combatants" in cm:
				combatants_list = cm.get("combatants") as Array

			GameLogger.combat("BATTLE ITEM ACTION triggered for slot %d" % [_active_slot_index])

			SignalBus.popup_requested.emit(&"BATTLE_ITEMS", { "slot_index": _active_slot_index, "inventory": inv, "combatants": combatants_list })

		_:
			var current_slot: int = _active_slot_index
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


func _on_enemy_health_changed(_enemy_id: String, current_hp: int, max_hp: int) -> void:
	if is_instance_valid(enemy_hp_label):
		enemy_hp_label.text = "%d / %d" % [max(0, current_hp), max_hp]


func _on_chevron_flash(is_player_hit: bool) -> void:
	var flash_color: Color = Color.RED if is_player_hit else Color.ORANGE
	var tween: Tween = create_tween().set_parallel(true)
	if is_instance_valid(left_chevrons):
		left_chevrons.modulate = flash_color
		tween.tween_property(left_chevrons, "modulate", Color.WHITE, 0.4)
	if is_instance_valid(right_chevrons):
		right_chevrons.modulate = flash_color
		tween.tween_property(right_chevrons, "modulate", Color.WHITE, 0.4)


func _initialize_portrait_slots() -> void:
	portrait_slots.clear()
	portrait_slots.resize(6)

	var all_portraits: Array[Node] = []
	if is_instance_valid(party_left):
		all_portraits.append_array(party_left.get_children())
	if is_instance_valid(party_right):
		all_portraits.append_array(party_right.get_children())

	for portrait: Node in all_portraits:
		if "slot_index" in portrait:
			var idx: int = portrait.get("slot_index")
			if idx >= 0 and idx < 6:
				portrait_slots[idx] = portrait


func _on_combat_started(enemy_data_or_group: Variant, player_party: Array) -> void:
	show()
	_reset_state()
	_bind_action_buttons()
	setup_party_display(player_party)

	var enemy_resources: Array = []
	if enemy_data_or_group is Array:
		enemy_resources = enemy_data_or_group as Array
	elif enemy_data_or_group is Resource:
		enemy_resources.append(enemy_data_or_group as Resource)

	if not enemy_resources.is_empty() and is_instance_valid(enemy_resources[0]):
		var lead_enemy: Resource = enemy_resources[0] as Resource
		var raw_name = lead_enemy.get("enemy_name")
		var e_name: String = str(raw_name) if raw_name != null else "Cyber-Zombie Cat"
		if enemy_resources.size() > 1:
			e_name += " (x%d)" % enemy_resources.size()

		var raw_hp = lead_enemy.get("max_health")
		var max_hp: int = int(raw_hp) if raw_hp != null else 30

		if is_instance_valid(enemy_name_label):
			enemy_name_label.text = e_name.to_upper()
		if is_instance_valid(enemy_hp_label):
			enemy_hp_label.text = "%d / %d" % [max_hp, max_hp]


func _on_combat_ended(_victory: bool) -> void:
	hide()
	_reset_state()


func setup_party_display(party_members: Array) -> void:
	if portrait_slots.is_empty():
		_initialize_portrait_slots()

	for i: int in range(portrait_slots.size()):
		var slot_node: Node = portrait_slots[i]
		if not is_instance_valid(slot_node):
			continue

		if i < party_members.size() and is_instance_valid(party_members[i]):
			if slot_node.has_method("setup_slot"):
				slot_node.call("setup_slot", party_members[i])
		else:
			if slot_node.has_method("setup_slot"):
				slot_node.call("setup_slot", null)


func _on_defend_button_pressed() -> void:
	if current_turn_slot_index < 0:
		return

	# Emit DEFEND action to CombatManager
	SignalBus.player_action_selected.emit(current_turn_slot_index, &"DEFEND", -1)


func _on_run_button_pressed() -> void:
	if current_turn_slot_index < 0:
		return

	# Emit RUN action to CombatManager
	SignalBus.player_action_selected.emit(current_turn_slot_index, &"RUN", -1)
