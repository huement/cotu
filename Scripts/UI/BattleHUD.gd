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
@onready var elemental_vfx: AnimatedSprite2D = %ElementalVFX as AnimatedSprite2D if has_node("%ElementalVFX") else null
@onready var edge_flash: Control = %EdgeFlash as Control if has_node("%EdgeFlash") else null
@onready var slice_overlay: ColorRect = %SliceOverlay as ColorRect if has_node("%SliceOverlay") else null

var portrait_slots: Array[Node] = []
var _state: CombatState = CombatState.IDLE
var _active_slot_index: int = -1
var _selected_action: StringName = &""
var _pending_target_action: StringName = &""
var _is_auto_battle_on: bool = false
var _buttons_bound: bool = false
var current_turn_slot_index: int = -1

var _enemy_max_hps: Dictionary = {}
var _enemy_current_hps: Dictionary = {}
var _target_button_container: HBoxContainer = null

# ==============================================================================
# ENEMY INFO DROPDOWN PANEL STATE
# ==============================================================================
var _is_info_menu_open: bool = false
var _info_menu_panel: PanelContainer = null
var _info_enemy_vbox: VBoxContainer = null
var _info_enemy_rows: Dictionary = {} # e_id -> Dictionary of {name_label, hp_label, hp_bar, status_label}
var _current_enemy_resources: Array[Resource] = []


func _ready() -> void:
	hide()
	_initialize_portrait_slots()
	_setup_target_button_container()
	_setup_enemy_info_menu()
	_connect_to_signal_bus()
	_bind_action_buttons()

	if is_instance_valid(auto_button):
		auto_button.toggled.connect(_on_auto_button_toggled)
	if is_instance_valid(elemental_vfx):
		elemental_vfx.hide()
		if not elemental_vfx.animation_finished.is_connected(_on_vfx_animation_finished):
			elemental_vfx.animation_finished.connect(_on_vfx_animation_finished)
	if is_instance_valid(SignalBus) and SignalBus.has_signal(&"screen_slice_requested"):
		if not SignalBus.screen_slice_requested.is_connected(play_screen_slice):
			SignalBus.screen_slice_requested.connect(play_screen_slice)


# ==============================================================================
# TOP HEADER CLICK & ENEMY INFO DROPDOWN PANEL
# ==============================================================================
func _setup_enemy_info_menu() -> void:
	var top_header: Control = get_node_or_null("TopHeader") as Control
	if not is_instance_valid(top_header):
		return

	# Enable pointing hand cursor and click listener on the top bar
	top_header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not top_header.gui_input.is_connected(_on_top_header_gui_input):
		top_header.gui_input.connect(_on_top_header_gui_input)

	# Main Dropdown Panel Container
	_info_menu_panel = PanelContainer.new()
	_info_menu_panel.name = "EnemyInfoDropdownPanel"
	_info_menu_panel.clip_contents = true
	add_child(_info_menu_panel)

	# Style dark cyber panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.09, 0.12, 0.94)
	style.border_color = Color(0.08, 0.85, 0.92, 0.8)
	style.set_border_width_all(1)
	style.border_width_top = 0
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_info_menu_panel.add_theme_stylebox_override("panel", style)

	# Anchor directly to top-center of screen (0px down) over topbar
	_info_menu_panel.layout_mode = 1
	_info_menu_panel.anchors_preset = Control.PRESET_CENTER_TOP
	_info_menu_panel.offset_left = -282.0
	_info_menu_panel.offset_top = 0.0
	_info_menu_panel.offset_right = 282.0
	_info_menu_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_info_menu_panel.z_index = 10

	# Outer VBox containing enemy list + bottom accent image
	var outer_vbox := VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 8)
	_info_menu_panel.add_child(outer_vbox)

	# Margin for enemy entries
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 6)
	outer_vbox.add_child(margin)

	_info_enemy_vbox = VBoxContainer.new()
	_info_enemy_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_enemy_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(_info_enemy_vbox)

	# Bottom Accent Image (hud_infomenu_btm.png) - Stretched across full width
	var btm_accent := TextureRect.new()
	btm_accent.name = "BottomAccent"
	btm_accent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btm_accent.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	btm_accent.stretch_mode = TextureRect.STRETCH_SCALE
	btm_accent.custom_minimum_size = Vector2(0, 24)

	var btm_tex: Texture2D = null
	if ResourceLoader.exists("res://ui/BATTLE/hud_infomenu_btm.png"):
		btm_tex = load("res://ui/BATTLE/hud_infomenu_btm.png") as Texture2D

	if is_instance_valid(btm_tex):
		btm_accent.texture = btm_tex

	outer_vbox.add_child(btm_accent)
	_info_menu_panel.hide()


func _on_top_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_info_menu()


func toggle_info_menu() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound("menu-slide")

	_is_info_menu_open = !_is_info_menu_open

	if not is_instance_valid(_info_menu_panel):
		return

	if _is_info_menu_open:
		_rebuild_enemy_info_rows()
		_info_menu_panel.show()

		_info_menu_panel.custom_minimum_size.y = 0.0
		_info_menu_panel.size.y = 0.0
		await get_tree().process_frame

		var target_height: float = maxf(110.0, _info_menu_panel.get_combined_minimum_size().y)

		var tween: Tween = create_tween()
		tween.tween_property(_info_menu_panel, "position:y", 0.0, 0.25) \
			.from(-target_height) \
			.set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)
	else:
		var current_height: float = _info_menu_panel.size.y
		var tween: Tween = create_tween()
		tween.tween_property(_info_menu_panel, "position:y", -current_height, 0.20) \
			.set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN)
		tween.finished.connect(_info_menu_panel.hide, CONNECT_ONE_SHOT)


func _rebuild_enemy_info_rows() -> void:
	if not is_instance_valid(_info_enemy_vbox):
		return

	for child in _info_enemy_vbox.get_children():
		child.queue_free()

	_info_enemy_rows.clear()

	for i in range(_current_enemy_resources.size()):
		var res: Resource = _current_enemy_resources[i]
		var e_id: String = "enemy_%d" % i

		var e_name: String = "CYBER-ZOMBIE CAT"
		if is_instance_valid(res) and "enemy_name" in res and res.get("enemy_name") != null:
			e_name = str(res.get("enemy_name")).to_upper()

		if _current_enemy_resources.size() > 1:
			e_name = "%s %c" % [e_name, 65 + i]

		var cur_hp: int = _enemy_current_hps.get(e_id, 30)
		var max_hp: int = _enemy_max_hps.get(e_id, 30)

		# Enemy Card VBox
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)

		# Top Row: Name + HP
		var top_row := HBoxContainer.new()
		card.add_child(top_row)

		var name_lbl := Label.new()
		name_lbl.text = e_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", Color(0.12, 0.95, 0.98))
		top_row.add_child(name_lbl)

		var hp_bar := ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(100, 16)
		hp_bar.max_value = max_hp
		hp_bar.value = cur_hp
		hp_bar.show_percentage = false
		top_row.add_child(hp_bar)

		var hp_lbl := Label.new()
		hp_lbl.text = " %d/%d" % [cur_hp, max_hp]
		hp_lbl.add_theme_color_override("font_color", Color.WHITE)
		top_row.add_child(hp_lbl)

		# Status & Buff Row (Future Status Effects / Enchantments)
		var status_row := HBoxContainer.new()
		card.add_child(status_row)

		var status_lbl := Label.new()
		status_lbl.text = "STATUS: [ NORMAL ]  |  BUFFS: [ NONE ]"
		status_lbl.add_theme_font_size_override("font_size", 11)
		status_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.82))
		status_row.add_child(status_lbl)

		_info_enemy_vbox.add_child(card)

		# Store row controls for live HP updates
		_info_enemy_rows[e_id] = {
			"hp_label": hp_lbl,
			"hp_bar": hp_bar,
			"status_label": status_lbl,
		}

		# Divider between cards
		if i < _current_enemy_resources.size() - 1:
			var sep := HSeparator.new()
			sep.add_theme_constant_override("separation", 6)
			_info_enemy_vbox.add_child(sep)


# ==============================================================================
# TARGET SELECTION BUTTONS
# ==============================================================================
func _setup_target_button_container() -> void:
	_target_button_container = HBoxContainer.new()
	_target_button_container.name = "TargetButtonContainer"
	_target_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_target_button_container.add_theme_constant_override("separation", 12)
	add_child(_target_button_container)

	_target_button_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_target_button_container.offset_left = -250.0
	_target_button_container.offset_top = -120.0
	_target_button_container.offset_right = 250.0
	_target_button_container.offset_bottom = -70.0
	_target_button_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_target_button_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_target_button_container.hide()


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

	if not sb.combat_started.is_connected(on_combat_started):
		sb.combat_started.connect(on_combat_started)
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
	if not sb.spell_vfx_requested.is_connected(_on_spell_vfx_requested):
		sb.spell_vfx_requested.connect(_on_spell_vfx_requested)


func _on_player_action_selected(_slot_index: int, _action: StringName, _target_index: int) -> void:
	_reset_state()
	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound("hud-button-press")


func _get_alive_enemy_indices() -> Array[int]:
	var alive_indices: Array[int] = []
	for i in range(_enemy_current_hps.size()):
		var e_id: String = "enemy_%d" % i
		if _enemy_current_hps.get(e_id, 0) > 0:
			alive_indices.append(i)
	return alive_indices


func _on_combatant_turn_ready(combatant_id: String, slot_index: int) -> void:
	current_turn_slot_index = slot_index

	if not combatant_id.begins_with("party_slot_"):
		return

	if _is_auto_battle_on:
		var alive_enemies: Array[int] = _get_alive_enemy_indices()
		var auto_target: int = alive_enemies[0] if not alive_enemies.is_empty() else 0
		SignalBus.player_action_selected.emit(slot_index, ACTION_ATTACK, auto_target)
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
		
	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound("hud-button-press")

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

		&"DEFEND", &"GUARD", &"RUN", &"FLEED":
			var current_slot: int = _active_slot_index
			_reset_state()
			SignalBus.player_action_selected.emit(current_slot, action_type, -1)

		_: # Physical Attack
			var alive_enemies: Array[int] = _get_alive_enemy_indices()
			if alive_enemies.size() <= 1:
				var target_idx: int = alive_enemies[0] if not alive_enemies.is_empty() else 0
				var current_slot: int = _active_slot_index
				_reset_state()
				SignalBus.player_action_selected.emit(current_slot, action_type, target_idx)
			else:
				_start_target_selection(action_type, alive_enemies)


func _start_target_selection(action_type: StringName, alive_indices: Array[int]) -> void:
	_state = CombatState.SELECTING_TARGET
	_pending_target_action = action_type

	if is_instance_valid(turn_info_label):
		turn_info_label.text = "SELECT TARGET"

	_clear_target_buttons()

	if is_instance_valid(_target_button_container):
		for enemy_idx in alive_indices:
			var btn := Button.new()
			btn.text = "TARGET ENEMY %c" % (65 + enemy_idx)
			btn.custom_minimum_size = Vector2(140, 36)
			btn.pressed.connect(_on_target_selected.bind(enemy_idx))
			_target_button_container.add_child(btn)

		_target_button_container.show()


func _on_target_selected(enemy_idx: int) -> void:
	var current_slot: int = _active_slot_index
	var action: StringName = _pending_target_action
	_reset_state()
	SignalBus.player_action_selected.emit(current_slot, action, enemy_idx)


func _clear_target_buttons() -> void:
	if is_instance_valid(_target_button_container):
		for child in _target_button_container.get_children():
			child.queue_free()
		_target_button_container.hide()


func _reset_state() -> void:
	for slot in portrait_slots:
		if is_instance_valid(slot) and slot.has_method("set_active"):
			slot.set_active(false)

	_state = CombatState.IDLE
	_active_slot_index = -1
	_selected_action = &""
	_pending_target_action = &""

	_clear_target_buttons()

	if is_instance_valid(action_bar):
		action_bar.hide()
	if is_instance_valid(turn_info_label):
		turn_info_label.text = "WAITING"


func _on_auto_button_toggled(is_on: bool) -> void:
	_is_auto_battle_on = is_on
	if is_instance_valid(auto_button):
		auto_button.modulate = Color.GREEN if is_on else Color.WHITE


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


func _resolve_enemy_resources(payload: Variant) -> Array[Resource]:
	var result: Array[Resource] = []

	if payload is Array:
		for item in (payload as Array):
			if item is Resource:
				result.append(item as Resource)
			elif is_instance_valid(item) and "enemy_group" in item:
				var group_array: Variant = item.get("enemy_group")
				if group_array is Array:
					for sub_item in (group_array as Array):
						if sub_item is Resource:
							result.append(sub_item as Resource)

	elif is_instance_valid(payload):
		if "enemy_group" in payload:
			var group_val: Variant = payload.get("enemy_group")
			if group_val is Array and not (group_val as Array).is_empty():
				for item in (group_val as Array):
					if item is Resource:
						result.append(item as Resource)

		if result.is_empty() and "members" in payload:
			var members_val: Variant = payload.get("members")
			if members_val is Array and not (members_val as Array).is_empty():
				for item in (members_val as Array):
					if item is Resource:
						result.append(item as Resource)

		if result.is_empty() and payload is Resource:
			var target_res: Resource = payload as Resource
			var overworld_enemies: Array[Node] = get_tree().get_nodes_in_group(&"world_enemies")
			if overworld_enemies.is_empty():
				overworld_enemies = get_tree().root.find_children("*", "WorldEnemy", true, false)

			for node in overworld_enemies:
				if is_instance_valid(node) and ("enemy_group" in node):
					var grp: Variant = node.get("enemy_group")
					var n_data: Variant = node.get("data") if "data" in node else null
					var n_edata: Variant = node.get("enemy_data") if "enemy_data" in node else null

					if (grp is Array and (grp as Array).has(target_res)) or n_data == target_res or n_edata == target_res:
						if grp is Array and not (grp as Array).is_empty():
							for item in (grp as Array):
								if item is Resource:
									result.append(item as Resource)
							break

			if result.is_empty():
				var count: int = 1
				if "pack_size" in payload:
					count = max(1, int(payload.get("pack_size")))
				for i in range(count):
					result.append(target_res.duplicate() if count > 1 else target_res)

	return result


func on_combat_started(enemy_payload: Variant, player_party: Array, _enemy_facing: String) -> void:
	show()
	_reset_state()
	_bind_action_buttons()
	setup_party_display(player_party)

	# Reset dropdown menu state
	_is_info_menu_open = false
	if is_instance_valid(_info_menu_panel):
		_info_menu_panel.custom_minimum_size.y = 0.0
		_info_menu_panel.hide()

	_current_enemy_resources = _resolve_enemy_resources(enemy_payload)
	_enemy_max_hps.clear()
	_enemy_current_hps.clear()

	var total_max_hp: int = 0

	for i in range(_current_enemy_resources.size()):
		var res: Resource = _current_enemy_resources[i]
		var e_id: String = "enemy_%d" % i
		var hp: int = 30

		if is_instance_valid(res):
			if "max_health" in res and res.get("max_health") != null:
				hp = int(res.get("max_health"))

		_enemy_max_hps[e_id] = hp
		_enemy_current_hps[e_id] = hp
		total_max_hp += hp

	update_enemy_header_display(_current_enemy_resources)

	if is_instance_valid(enemy_hp_label):
		enemy_hp_label.text = "%d / %d" % [total_max_hp, total_max_hp]


func update_enemy_header_display(enemy_pack: Array[Resource]) -> void:
	if not is_instance_valid(enemy_name_label) or enemy_pack.is_empty():
		return

	var name_counts: Dictionary = {}
	for res in enemy_pack:
		var e_name: String = "CYBER-ZOMBIE CAT"
		if is_instance_valid(res):
			if "enemy_name" in res and res.get("enemy_name") != null:
				e_name = str(res.get("enemy_name")).to_upper()

		name_counts[e_name] = name_counts.get(e_name, 0) + 1

	var display_text: String = ""
	if name_counts.size() == 1:
		var sole_name: String = name_counts.keys()[0] as String
		var count: int = name_counts[sole_name] as int
		if count > 1:
			display_text = "%s (X%d)" % [sole_name, count]
		else:
			display_text = sole_name
	else:
		var formatted_names: Array[String] = []
		for e_name in name_counts.keys():
			var count: int = name_counts[e_name] as int
			if count > 1:
				formatted_names.append("%s (X%d)" % [e_name, count])
			else:
				formatted_names.append(e_name as String)
		display_text = " & ".join(formatted_names)

	enemy_name_label.text = display_text


func _on_enemy_health_changed(enemy_id: String, current_hp: int, max_hp: int) -> void:
	_enemy_current_hps[enemy_id] = current_hp
	_enemy_max_hps[enemy_id] = max_hp

	var total_current: int = 0
	var total_max: int = 0

	for id in _enemy_max_hps:
		total_current += _enemy_current_hps.get(id, 0)
		total_max += _enemy_max_hps.get(id, 0)

	if is_instance_valid(enemy_hp_label):
		enemy_hp_label.text = "%d / %d" % [total_current, total_max]

	# Synchronize live HP in open info card row
	if _info_enemy_rows.has(enemy_id):
		var row: Dictionary = _info_enemy_rows[enemy_id]
		var hp_bar: ProgressBar = row.get("hp_bar") as ProgressBar
		var hp_lbl: Label = row.get("hp_label") as Label

		if is_instance_valid(hp_bar):
			hp_bar.value = current_hp
		if is_instance_valid(hp_lbl):
			hp_lbl.text = " %d/%d" % [max(0, current_hp), max_hp]


func _on_spell_vfx_requested(anim_name: String, element: ItemData.ElementalBase) -> void:
	GameLogger.combat("_on_spell_vfx_requested %s" % [anim_name])
	if is_instance_valid(elemental_vfx) and elemental_vfx.sprite_frames.has_animation(anim_name):
		elemental_vfx.show()
		elemental_vfx.play(anim_name)

	if is_instance_valid(edge_flash) and element != ItemData.ElementalBase.NONE:
		var flash_color: Color = _get_element_color(element)
		edge_flash.modulate = flash_color
		edge_flash.modulate.a = 0.8
		edge_flash.show()

		var tween: Tween = create_tween()
		tween.tween_property(edge_flash, "modulate:a", 0.0, 0.5)
		tween.tween_callback(edge_flash.hide)


func _get_element_color(element: ItemData.ElementalBase) -> Color:
	match element:
		ItemData.ElementalBase.FIRE:
			return Color(1.0, 0.2, 0.1)
		ItemData.ElementalBase.WATER:
			return Color(0.1, 0.5, 1.0)
		ItemData.ElementalBase.EARTH:
			return Color(0.4, 0.7, 0.2)
		ItemData.ElementalBase.AIR:
			return Color(0.6, 0.9, 1.0)
		ItemData.ElementalBase.BOLT:
			return Color(1.0, 0.9, 0.1)
		ItemData.ElementalBase.DARK:
			return Color(0.6, 0.1, 0.8)
		ItemData.ElementalBase.LIFE:
			return Color(0.2, 0.9, 0.4)
		_:
			return Color.WHITE


func _on_vfx_animation_finished() -> void:
	if is_instance_valid(elemental_vfx):
		elemental_vfx.hide()


func _on_combat_ended(_victory: bool) -> void:
	hide()
	_reset_state()
	_is_info_menu_open = false
	if is_instance_valid(_info_menu_panel):
		_info_menu_panel.hide()


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


func play_screen_slice() -> void:
	if not is_instance_valid(slice_overlay) or slice_overlay.material == null:
		return

	var mat := slice_overlay.material as ShaderMaterial
	if mat == null:
		return

	var tween: Tween = create_tween()
	tween.tween_property(mat, "shader_parameter/progress", 1.0, 0.22) \
		.from(0.0) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)

	tween.finished.connect(func() -> void:
		mat.set_shader_parameter("progress", 0.0)
	, CONNECT_ONE_SHOT)
