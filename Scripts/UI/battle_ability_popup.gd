# res://Scripts/UI/battle_ability_popup.gd
class_name BattleAbilityPopup
extends CanvasLayer

enum Page { ABILITY_SELECT, TARGET_SELECT }
enum AbilityTab { SKILLS, SPELLS }

# --- Scene Unique Node References (% Prefix) ---
@onready var background_dimmer: ColorRect = $BackgroundDimmer
@onready var panel_container: PanelContainer = $PanelContainer
@onready var title_label: Label = %TitleLabel

# Page 1: Ability Select Nodes
@onready var page_ability_select: VBoxContainer = %PageAbilitySelect
@onready var skills_tab_btn: Button = %SkillsTabBtn
@onready var spells_tab_btn: Button = %SpellsTabBtn
@onready var ability_scroll_list: VBoxContainer = %AbilityScrollList
@onready var selected_ability_label: Label = %SelectedAbilityLabel
@onready var ability_desc_label: Label = %AbilityDescLabel
@onready var page1_cancel_btn: Button = %Page1CancelBtn
@onready var page1_next_btn: Button = %Page1NextBtn

# Page 2: Target Select Nodes
@onready var page_target_select: VBoxContainer = %PageTargetSelect
@onready var target_grid_container: GridContainer = %TargetGridContainer
@onready var page2_back_btn: Button = %Page2BackBtn
@onready var page2_confirm_btn: Button = %Page2ConfirmBtn

# --- Runtime State ---
var _active_cat: CatCharacter = null
var _active_slot_index: int = -1
var _current_page: Page = Page.ABILITY_SELECT
var _current_tab: AbilityTab = AbilityTab.SKILLS
var _selected_ability: Resource = null # SkillData or SpellData
var _selected_target_id: String = ""
var _selected_target_index: int = -1
var _combatants_list: Array = [] # Combatant data passed from CombatManager


func _ready() -> void:
	_close_popup()

	# Connect Tab Controls
	if skills_tab_btn: skills_tab_btn.pressed.connect(_on_tab_changed.bind(AbilityTab.SKILLS))
	if spells_tab_btn: spells_tab_btn.pressed.connect(_on_tab_changed.bind(AbilityTab.SPELLS))

	# Connect Navigation Buttons
	if page1_cancel_btn: page1_cancel_btn.pressed.connect(_close_popup)
	if page1_next_btn: page1_next_btn.pressed.connect(_go_to_target_page)
	if page2_back_btn: page2_back_btn.pressed.connect(_go_to_ability_page)
	if page2_confirm_btn: page2_confirm_btn.pressed.connect(_confirm_and_emit_action)

	# SignalBus Connection
	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		if not bus.has_user_signal("battle_ability_popup_requested"):
			bus.popup_requested.connect(_on_popup_requested)


## PUBLIC API: Opens the modal for a specific cat and combat state
func open_ability_menu(cat: CatCharacter, slot_index: int, combatants_data: Array) -> void:
	_active_cat = cat
	_active_slot_index = slot_index
	_combatants_list = combatants_data
	_selected_ability = null
	_selected_target_id = ""
	_selected_target_index = -1

	# Default to Skills if available, otherwise Spells
	if is_instance_valid(cat) and cat.known_skills.is_empty() and not cat.known_spells.is_empty():
		_current_tab = AbilityTab.SPELLS
	else:
		_current_tab = AbilityTab.SKILLS

	_go_to_ability_page()
	show()
	if background_dimmer: background_dimmer.show()
	if panel_container: panel_container.show()


func _on_popup_requested(action_type: StringName, data: Dictionary = {}) -> void:
	if action_type == &"BATTLE_ABILITIES":
		var cat: CatCharacter = data.get("character", null) as CatCharacter
		var slot_idx: int = data.get("slot_index", -1)
		var combatants: Array = data.get("combatants", [])
		if is_instance_valid(cat):
			open_ability_menu(cat, slot_idx, combatants)


# =============================================================================
# 🟢 STEP 1: ABILITY SELECTION PAGE
# =============================================================================

func _go_to_ability_page() -> void:
	_current_page = Page.ABILITY_SELECT
	if title_label: title_label.text = "TACTICAL ABILITY SELECTION"

	if page_ability_select: page_ability_select.show()
	if page_target_select: page_target_select.hide()

	_update_tab_buttons_ui()
	_render_ability_list()
	_update_ability_preview()


func _on_tab_changed(tab: AbilityTab) -> void:
	_current_tab = tab
	_selected_ability = null
	_update_tab_buttons_ui()
	_render_ability_list()
	_update_ability_preview()


func _update_tab_buttons_ui() -> void:
	if skills_tab_btn:
		skills_tab_btn.text = "[ SKILLS ]" if _current_tab == AbilityTab.SKILLS else "  SKILLS  "
		skills_tab_btn.modulate = Color(0.0, 1.0, 0.8) if _current_tab == AbilityTab.SKILLS else Color(0.5, 0.6, 0.7, 0.5)

	if spells_tab_btn:
		spells_tab_btn.text = "[ SPELLS ]" if _current_tab == AbilityTab.SPELLS else "  SPELLS  "
		spells_tab_btn.modulate = Color(0.0, 1.0, 0.8) if _current_tab == AbilityTab.SPELLS else Color(0.5, 0.6, 0.7, 0.5)


func _render_ability_list() -> void:
	if not ability_scroll_list: return

	for child in ability_scroll_list.get_children():
		child.queue_free()

	if not is_instance_valid(_active_cat): return

	var items_to_render: Array = _active_cat.known_skills if _current_tab == AbilityTab.SKILLS else _active_cat.known_spells

	if items_to_render.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No %s registered." % ["skills" if _current_tab == AbilityTab.SKILLS else "spells"]
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		ability_scroll_list.add_child(empty_lbl)
		return

	for res in items_to_render:
		var btn := _create_ability_row_button(res)
		ability_scroll_list.add_child(btn)


func _create_ability_row_button(ability_res: Resource) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 36)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE

	var name_str: String = ability_res.get("skill_name") if "skill_name" in ability_res else (ability_res.get("spell_name") if "spell_name" in ability_res else "Ability")
	var cost_val: int = ability_res.get("energy_cost") if "energy_cost" in ability_res else 0

	btn.text = "  %s (Cost: %d EN)" % [name_str.to_upper(), cost_val]

	# Check if character has enough energy
	var current_en: int = _active_cat.current_energy
	if current_en < cost_val:
		btn.disabled = true
		btn.text += " [LOW ENERGY]"

	# Styling
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.12, 0.15, 0.9)
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(0.0, 0.8, 0.7, 0.4)

	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.12, 0.22, 0.28, 0.9)
	style_hover.border_color = Color(0.0, 1.0, 0.8, 0.9)

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8))

	btn.pressed.connect(func() -> void:
		_selected_ability = ability_res
		_update_ability_preview()
	)

	return btn


func _update_ability_preview() -> void:
	if is_instance_valid(_selected_ability):
		var name_str: String = _selected_ability.get("skill_name") if "skill_name" in _selected_ability else (_selected_ability.get("spell_name") if "spell_name" in _selected_ability else "")
		var desc_str: String = _selected_ability.get("description") if "description" in _selected_ability else ""
		var cost_val: int = _selected_ability.get("energy_cost") if "energy_cost" in _selected_ability else 0

		if selected_ability_label: selected_ability_label.text = "%s [COST: %d EN]" % [name_str.to_upper(), cost_val]
		if ability_desc_label: ability_desc_label.text = desc_str
		if page1_next_btn: page1_next_btn.disabled = false
	else:
		if selected_ability_label: selected_ability_label.text = "SELECT AN ABILITY ABOVE"
		if ability_desc_label: ability_desc_label.text = "Choose a skill or spell from the list to view specifications and select a target."
		if page1_next_btn: page1_next_btn.disabled = true


# =============================================================================
# 🎯 STEP 2: TARGET SELECTION PAGE (2 Columns: [ ICON ][ Name / HP ])
# =============================================================================

func _go_to_target_page() -> void:
	if not is_instance_valid(_selected_ability): return

	_current_page = Page.TARGET_SELECT
	if title_label: title_label.text = "SELECT TARGET UNIT"

	if page_ability_select: page_ability_select.hide()
	if page_target_select: page_target_select.show()

	_render_target_grid()
	_update_target_confirm_ui()


func _render_target_grid() -> void:
	if not target_grid_container: return

	for child in target_grid_container.get_children():
		child.queue_free()

	# Determine if targeting Enemies or Allies based on Ability TargetType
	var target_type_val = _selected_ability.get("target_type")
	var is_ally_target: bool = _is_ally_targeting(target_type_val)

	var valid_targets: Array = []
	for c in _combatants_list:
		var is_player: bool = c.get("is_player") if "is_player" in c else false
		var hp: int = c.get("current_hp") if "current_hp" in c else 0

		# Filter living allies or living enemies
		if is_ally_target and is_player and hp > 0:
			valid_targets.append(c)
		elif not is_ally_target and not is_player and hp > 0:
			valid_targets.append(c)

	if valid_targets.is_empty():
		# Fallback to all combatants
		valid_targets = _combatants_list

	for c in valid_targets:
		var card := _create_target_card_button(c)
		target_grid_container.add_child(card)


## Creates 2-column layout: [ ICON ][ VBox(Title, HP) ]
func _create_target_card_button(combatant: Object) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(175, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE

	var c_id: String = combatant.get("id") if "id" in combatant else ""
	var c_name: String = str(combatant.get("name")).to_upper() if "name" in combatant else "TARGET"
	var c_hp: int = int(combatant.get("current_hp")) if "current_hp" in combatant else 0
	var c_max_hp: int = int(combatant.get("max_hp")) if "max_hp" in combatant else 1
	var c_slot: int = int(combatant.get("slot_index")) if "slot_index" in combatant else 0
	var c_ref: Resource = combatant.get("ref") as Resource if "ref" in combatant else null

	# Outer Margin
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	btn.add_child(margin)

	# Column 1 & Column 2 Container
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	# --- COLUMN 1: [ ICON ] ---
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if is_instance_valid(c_ref):
		if "portrait" in c_ref and c_ref.get("portrait") is Texture2D:
			icon_rect.texture = c_ref.get("portrait")
		elif "portrait_path" in c_ref and ResourceLoader.exists(str(c_ref.get("portrait_path"))):
			icon_rect.texture = load(str(c_ref.get("portrait_path"))) as Texture2D

	hbox.add_child(icon_rect)

	# --- COLUMN 2: [ Details (Row 1: Title | Row 2: HP) ] ---
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Row 1: Title
	var title_lbl := Label.new()
	title_lbl.text = c_name
	title_lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8))
	title_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(title_lbl)

	# Row 2: HP Text
	var hp_lbl := Label.new()
	hp_lbl.text = "HP: %d / %d" % [c_hp, c_max_hp]
	hp_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hp_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(hp_lbl)

	hbox.add_child(vbox)

	# Button Style
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.06, 0.1, 0.14, 0.9)
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(0.0, 0.8, 0.7, 0.4)

	btn.add_theme_stylebox_override("normal", style_normal)

	btn.pressed.connect(func() -> void:
		_selected_target_id = c_id
		_selected_target_index = c_slot
		_highlight_target_button(btn)
		_update_target_confirm_ui()
	)

	return btn


func _highlight_target_button(selected_btn: Button) -> void:
	for child in target_grid_container.get_children():
		if child is Button:
			var style := child.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
			if child == selected_btn:
				style.bg_color = Color(0.12, 0.3, 0.35, 0.95)
				style.border_color = Color(0.0, 1.0, 0.8, 1.0)
			else:
				style.bg_color = Color(0.06, 0.1, 0.14, 0.9)
				style.border_color = Color(0.0, 0.8, 0.7, 0.4)
			child.add_theme_stylebox_override("normal", style)


func _update_target_confirm_ui() -> void:
	if page2_confirm_btn:
		page2_confirm_btn.disabled = _selected_target_id.is_empty()


func _is_ally_targeting(target_type_val) -> bool:
	var type_str: String = str(target_type_val).to_upper()
	return "ALLY" in type_str or "PARTY" in type_str or "SELF" in type_str or type_str == "2" or type_str == "3" or type_str == "4"


# =============================================================================
# 🚀 CONFIRMATION & EXECUTION
# =============================================================================

func _confirm_and_emit_action() -> void:
	if not is_instance_valid(_selected_ability) or _selected_target_index == -1:
		return

	var action_type: StringName = &"SKILL" if _current_tab == AbilityTab.SKILLS else &"SPELL"

	# Deduct energy cost from character vitals
	var cost_val: int = _selected_ability.get("energy_cost") if "energy_cost" in _selected_ability else 0
	if is_instance_valid(_active_cat):
		_active_cat.current_energy = max(0, _active_cat.current_energy - cost_val)

	# Broadcast turn action payload through SignalBus
	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		bus.player_action_selected.emit(_active_slot_index, action_type, _selected_target_index)
		print("BattleAbilityPopup: Executed ", action_type, " on target index ", _selected_target_index)

	_close_popup()


func _close_popup() -> void:
	hide()
	if background_dimmer: background_dimmer.hide()
	if panel_container: panel_container.hide()
	_selected_ability = null
	_selected_target_id = ""
	_selected_target_index = -1
