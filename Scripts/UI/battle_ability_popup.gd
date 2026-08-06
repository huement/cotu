# res://Scripts/UI/battle_ability_popup.gd
class_name BattleAbilityPopup
extends CanvasLayer

enum Page {
	ABILITY_SELECT,
	TARGET_SELECT,
}
enum AbilityTab {
	SKILLS,
	SPELLS,
}

@onready var background_dimmer: ColorRect = $BackgroundDimmer
@onready var panel_container: PanelContainer = $PanelContainer
@onready var title_label: Label = %TitleLabel
@onready var character_label: Label = %CharacterLabel

@onready var page_ability_select: VBoxContainer = %PageAbilitySelect
@onready var skills_tab_btn: Button = %SkillsTabBtn
@onready var spells_tab_btn: Button = %SpellsTabBtn
@onready var ability_scroll_list: VBoxContainer = %AbilityScrollList
@onready var selected_ability_label: Label = %SelectedAbilityLabel
@onready var ability_desc_label: Label = %AbilityDescLabel
@onready var page1_cancel_btn: Button = %Page1CancelBtn
@onready var page1_next_btn: Button = %Page1NextBtn

@onready var page_target_select: VBoxContainer = %PageTargetSelect
@onready var target_grid_container: GridContainer = %TargetGridContainer
@onready var page2_back_btn: Button = %Page2BackBtn
@onready var page2_confirm_btn: Button = %Page2ConfirmBtn

var _active_cat: CatCharacter = null
var _active_slot_index: int = -1
var _current_page: Page = Page.ABILITY_SELECT
var _current_tab: AbilityTab = AbilityTab.SKILLS
var _selected_ability: Resource = null
var _selected_target_id: String = ""
var _selected_target_index: int = -1
var _combatants_list: Array = []


func _ready() -> void:
	_close_popup()

	if is_instance_valid(skills_tab_btn):
		skills_tab_btn.pressed.connect(_on_tab_changed.bind(AbilityTab.SKILLS))
	if is_instance_valid(spells_tab_btn):
		spells_tab_btn.pressed.connect(_on_tab_changed.bind(AbilityTab.SPELLS))

	if is_instance_valid(page1_cancel_btn):
		page1_cancel_btn.pressed.connect(_close_popup)
	if is_instance_valid(page1_next_btn):
		page1_next_btn.pressed.connect(_go_to_target_page)
	if is_instance_valid(page2_back_btn):
		page2_back_btn.pressed.connect(_go_to_ability_page)
	if is_instance_valid(page2_confirm_btn):
		page2_confirm_btn.pressed.connect(_confirm_and_emit_action)

	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		if not bus.has_user_signal("battle_ability_popup_requested"):
			bus.popup_requested.connect(_on_popup_requested)


func open_ability_menu(cat: CatCharacter, slot_index: int, combatants_data: Array) -> void:
	_active_cat = cat
	_active_slot_index = slot_index
	_combatants_list = combatants_data
	_selected_ability = null
	_selected_target_id = ""
	_selected_target_index = -1

	if is_instance_valid(character_label):
		var c_name: String = ""
		if is_instance_valid(cat):
			if "character_name" in cat and not str(cat.get("character_name")).is_empty():
				c_name = str(cat.get("character_name"))
			elif "name" in cat and not str(cat.get("name")).is_empty():
				c_name = str(cat.get("name"))
		character_label.text = c_name.to_upper() if not c_name.is_empty() else "UNKNOWN"

	var has_skills: bool = is_instance_valid(cat) and "known_skills" in cat and not cat.known_skills.is_empty()
	var has_spells: bool = is_instance_valid(cat) and "known_spells" in cat and not cat.known_spells.is_empty()

	if not has_skills and has_spells:
		_current_tab = AbilityTab.SPELLS
	else:
		_current_tab = AbilityTab.SKILLS

	_go_to_ability_page()
	show()
	if is_instance_valid(background_dimmer):
		background_dimmer.show()
	if is_instance_valid(panel_container):
		panel_container.show()


func _on_popup_requested(action_type: StringName, data: Dictionary = { }) -> void:
	if action_type == &"BATTLE_ABILITIES":
		var cat: CatCharacter = data.get("character", null) as CatCharacter
		var slot_idx: int = data.get("slot_index", -1)
		var combatants: Array = data.get("combatants", [])
		if is_instance_valid(cat):
			open_ability_menu(cat, slot_idx, combatants)


func _go_to_ability_page() -> void:
	_current_page = Page.ABILITY_SELECT
	if is_instance_valid(title_label):
		title_label.text = "TACTICAL ABILITY SELECTION"

	if is_instance_valid(page_ability_select):
		page_ability_select.show()
	if is_instance_valid(page_target_select):
		page_target_select.hide()

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
	if is_instance_valid(skills_tab_btn):
		skills_tab_btn.text = "[ SKILLS ]" if _current_tab == AbilityTab.SKILLS else "  SKILLS  "
		skills_tab_btn.modulate = Color(0.0, 1.0, 0.8) if _current_tab == AbilityTab.SKILLS else Color(0.5, 0.6, 0.7, 0.5)

	if is_instance_valid(spells_tab_btn):
		spells_tab_btn.text = "[ SPELLS ]" if _current_tab == AbilityTab.SPELLS else "  SPELLS  "
		spells_tab_btn.modulate = Color(0.0, 1.0, 0.8) if _current_tab == AbilityTab.SPELLS else Color(0.5, 0.6, 0.7, 0.5)


func _render_ability_list() -> void:
	if not is_instance_valid(ability_scroll_list):
		return

	for child: Node in ability_scroll_list.get_children():
		child.queue_free()

	if not is_instance_valid(_active_cat):
		return

	var items_to_render: Array = []
	if _current_tab == AbilityTab.SKILLS:
		if "known_skills" in _active_cat and _active_cat.known_skills is Array:
			items_to_render = _active_cat.known_skills
		elif "skills" in _active_cat and _active_cat.skills is Array:
			items_to_render = _active_cat.skills
	else:
		if "known_spells" in _active_cat and _active_cat.known_spells is Array:
			items_to_render = _active_cat.known_spells
		elif "spells" in _active_cat and _active_cat.spells is Array:
			items_to_render = _active_cat.spells

	if items_to_render.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No %s registered." % ["skills" if _current_tab == AbilityTab.SKILLS else "spells"]
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		ability_scroll_list.add_child(empty_lbl)
		return

	for res: Variant in items_to_render:
		if is_instance_valid(res as Resource):
			var btn: Button = _create_ability_row_button(res as Resource)
			ability_scroll_list.add_child(btn)


func _create_ability_row_button(ability_res: Resource) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, 36)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE

	var name_str: String = ""
	if "spell_name" in ability_res and not str(ability_res.get("spell_name")).is_empty():
		name_str = str(ability_res.get("spell_name"))
	elif "skill_name" in ability_res and not str(ability_res.get("skill_name")).is_empty():
		name_str = str(ability_res.get("skill_name"))
	elif "name" in ability_res:
		name_str = str(ability_res.get("name"))
	else:
		name_str = "Ability"

	var cost_val: int = 0
	if "energy_cost" in ability_res:
		cost_val = int(ability_res.get("energy_cost"))
	elif "mana_cost" in ability_res:
		cost_val = int(ability_res.get("mana_cost"))
	elif "mp_cost" in ability_res:
		cost_val = int(ability_res.get("mp_cost"))

	btn.text = "  %s (Cost: %d EN)" % [name_str.to_upper(), cost_val]

	var current_en: int = 0
	if "current_energy" in _active_cat:
		current_en = int(_active_cat.get("current_energy"))
	elif "current_mp" in _active_cat:
		current_en = int(_active_cat.get("current_mp"))
	elif "current_mana" in _active_cat:
		current_en = int(_active_cat.get("current_mana"))

	if current_en < cost_val:
		btn.disabled = true
		btn.text += " [LOW ENERGY]" if _current_tab == AbilityTab.SKILLS else " [LOW MANA]"

	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.12, 0.15, 0.9)
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(0.0, 0.8, 0.7, 0.4)

	var style_hover: StyleBoxFlat = style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.12, 0.22, 0.28, 0.9)
	style_hover.border_color = Color(0.0, 1.0, 0.8, 0.9)

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8))

	btn.pressed.connect(
		func() -> void:
			_selected_ability = ability_res
			_update_ability_preview(),
	)

	return btn


func _update_ability_preview() -> void:
	if is_instance_valid(_selected_ability):
		var name_str: String = ""
		if "spell_name" in _selected_ability and not str(_selected_ability.get("spell_name")).is_empty():
			name_str = str(_selected_ability.get("spell_name"))
		elif "skill_name" in _selected_ability and not str(_selected_ability.get("skill_name")).is_empty():
			name_str = str(_selected_ability.get("skill_name"))
		elif "name" in _selected_ability:
			name_str = str(_selected_ability.get("name"))

		var desc_str: String = str(_selected_ability.get("description")) if "description" in _selected_ability else ""
		var cost_val: int = 0
		if "energy_cost" in _selected_ability:
			cost_val = int(_selected_ability.get("energy_cost"))
		elif "mana_cost" in _selected_ability:
			cost_val = int(_selected_ability.get("mana_cost"))
		elif "mp_cost" in _selected_ability:
			cost_val = int(_selected_ability.get("mp_cost"))

		if is_instance_valid(selected_ability_label):
			selected_ability_label.text = "%s [COST: %d EN]" % [name_str.to_upper(), cost_val]
		if is_instance_valid(ability_desc_label):
			ability_desc_label.text = desc_str
		if is_instance_valid(page1_next_btn):
			page1_next_btn.disabled = false
	else:
		if is_instance_valid(selected_ability_label):
			selected_ability_label.text = "SELECT AN ABILITY ABOVE"
		if is_instance_valid(ability_desc_label):
			ability_desc_label.text = "Choose a skill or spell from the list to view specifications and select a target."
		if is_instance_valid(page1_next_btn):
			page1_next_btn.disabled = true


func _selected_ability_title() -> String:
	if is_instance_valid(_selected_ability):
		if "spell_name" in _selected_ability and not str(_selected_ability.get("spell_name")).is_empty():
			return str(_selected_ability.get("spell_name"))
		if "skill_name" in _selected_ability and not str(_selected_ability.get("skill_name")).is_empty():
			return str(_selected_ability.get("skill_name"))
		if "name" in _selected_ability:
			return str(_selected_ability.get("name"))
	return "UNKNOWN_ABILITY"


func _selected_ability_label() -> String:
	var result_string: String = ""
	var is_ally_target: bool = _is_ally_targeting(_selected_ability)
	if is_instance_valid(_selected_ability):
		if is_ally_target:
			result_string = "SELECT [ALLY] TARGETS"
		else:
			result_string = "SELECT [ENEMY] TARGETS"
	return result_string


func _selected_ability_target_label(ability_res: Resource) -> String:
	var raw_type: Variant = ability_res.get("target_type") if "target_type" in ability_res else ability_res.get("target")
	GameLogger.combat("SELECTED TARGET | %s" % str(raw_type))
	if is_instance_valid(_selected_ability):
		return str(_selected_ability.get("target_type"))
	return "UNKNOWN_TARGET"


func _go_to_target_page() -> void:
	if not is_instance_valid(_selected_ability):
		return

	GameLogger.combat("Battle Ability For | %s" % _selected_ability_title())
	GameLogger.combat("TARGETING | %s" % _selected_ability_target_label(_selected_ability))

	_current_page = Page.TARGET_SELECT

	if is_instance_valid(title_label):
		title_label.text = _selected_ability_label()

	if is_instance_valid(page_ability_select):
		page_ability_select.hide()
	if is_instance_valid(page_target_select):
		page_target_select.show()

	_render_target_grid()
	_update_target_confirm_ui()


func _render_target_grid() -> void:
	if not is_instance_valid(target_grid_container):
		return

	for child: Node in target_grid_container.get_children():
		child.queue_free()

	if not is_instance_valid(_selected_ability):
		return

	var is_ally_target: bool = _is_ally_targeting(_selected_ability)

	var valid_targets: Array = []
	for c: Variant in _combatants_list:
		if not is_instance_valid(c):
			continue

		var is_player: bool = c.get("is_player") if "is_player" in c else false
		var hp: int = c.get("current_hp") if "current_hp" in c else 0

		if is_ally_target and is_player and hp > 0:
			valid_targets.append(c)
		elif not is_ally_target and not is_player and hp > 0:
			valid_targets.append(c)

	if valid_targets.is_empty():
		for c: Variant in _combatants_list:
			if not is_instance_valid(c):
				continue
			var is_player: bool = c.get("is_player") if "is_player" in c else false
			if is_ally_target and is_player:
				valid_targets.append(c)
			elif not is_ally_target and not is_player:
				valid_targets.append(c)

	for c: Variant in valid_targets:
		var card: Button = _create_target_card_button(c)
		target_grid_container.add_child(card)


func _create_target_card_button(combatant: Object) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(175, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE

	var c_id: String = combatant.get("id") if "id" in combatant else ""
	var c_name: String = str(combatant.get("name")).to_upper() if "name" in combatant else "TARGET"
	var c_hp: int = int(combatant.get("current_hp")) if "current_hp" in combatant else 0
	var c_max_hp: int = int(combatant.get("max_hp")) if "max_hp" in combatant else 1
	var c_slot: int = int(combatant.get("slot_index")) if "slot_index" in combatant else 0
	var c_ref: Resource = combatant.get("ref") as Resource if "ref" in combatant else null

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	btn.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if is_instance_valid(c_ref):
		if "portrait" in c_ref and c_ref.get("portrait") is Texture2D:
			icon_rect.texture = c_ref.get("portrait") as Texture2D
		elif "portrait_path" in c_ref and ResourceLoader.exists(str(c_ref.get("portrait_path"))):
			icon_rect.texture = load(str(c_ref.get("portrait_path"))) as Texture2D

	hbox.add_child(icon_rect)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var title_lbl: Label = Label.new()
	title_lbl.text = c_name
	title_lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8))
	title_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(title_lbl)

	var hp_lbl: Label = Label.new()
	hp_lbl.text = "HP: %d / %d" % [c_hp, c_max_hp]
	hp_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hp_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(hp_lbl)

	hbox.add_child(vbox)

	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.06, 0.1, 0.14, 0.9)
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(0.0, 0.8, 0.7, 0.4)

	btn.add_theme_stylebox_override("normal", style_normal)

	btn.pressed.connect(
		func() -> void:
			_selected_target_id = c_id
			_selected_target_index = c_slot
			_highlight_target_button(btn)
			_update_target_confirm_ui(),
	)

	return btn


func _highlight_target_button(selected_btn: Button) -> void:
	for child: Node in target_grid_container.get_children():
		if child is Button:
			var style: StyleBoxFlat = child.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
			if child == selected_btn:
				style.bg_color = Color(0.12, 0.3, 0.35, 0.95)
				style.border_color = Color(0.0, 1.0, 0.8, 1.0)
			else:
				style.bg_color = Color(0.06, 0.1, 0.14, 0.9)
				style.border_color = Color(0.0, 0.8, 0.7, 0.4)
			child.add_theme_stylebox_override("normal", style)


func _update_target_confirm_ui() -> void:
	if is_instance_valid(page2_confirm_btn):
		page2_confirm_btn.disabled = _selected_target_id.is_empty()


func _is_ally_targeting(ability_res: Resource) -> bool:
	if not is_instance_valid(ability_res):
		return false

	# 1. Check explicit String / StringName representation if present
	var raw_type: Variant = ability_res.get("target_type") if "target_type" in ability_res else ability_res.get("target")
	if raw_type is String or raw_type is StringName:
		var type_str: String = str(raw_type).to_upper()
		if "ENEMY" in type_str or "ENEMIES" in type_str:
			return false
		if "PARTY" in type_str or "MEMBER" in type_str or "ALLY" in type_str or "ALLIES" in type_str or "SELF" in type_str:
			return true

	# 2. Check effect category / type string (e.g., HEAL, BUFF, DAMAGE)
	if "effect_type" in ability_res:
		var eff_str: String = str(ability_res.get("effect_type")).to_upper()
		if eff_str == "HEAL" or eff_str == "BUFF" or eff_str == "RESTORE":
			return true
		if eff_str == "DAMAGE" or eff_str == "DEBUFF" or eff_str == "ATTACK":
			return false

	# 3. Check ability effect numerical properties
	var heal_val: int = 0
	if "heal_amount" in ability_res:
		heal_val = int(ability_res.get("heal_amount"))
	elif "health_restore" in ability_res:
		heal_val = int(ability_res.get("health_restore"))
	elif "heal" in ability_res:
		heal_val = int(ability_res.get("heal"))

	var damage_val: int = 0
	if "damage" in ability_res:
		damage_val = int(ability_res.get("damage"))
	elif "damage_amount" in ability_res:
		damage_val = int(ability_res.get("damage_amount"))
	elif "base_damage" in ability_res:
		damage_val = int(ability_res.get("base_damage"))

	if heal_val > 0 and damage_val == 0:
		return true
	if damage_val > 0 and heal_val == 0:
		return false

	# 4. Integer Enum check (distinguish ItemData vs SpellData/SkillData)
	if raw_type is int or raw_type is float:
		var val: int = int(raw_type)
		# For SpellData & SkillData generated by DataCompiler:
		# 0 = SINGLE_ENEMY, 1 = ALL_ENEMIES, 2 = SINGLE_PARTY_MEMBER / SINGLE_ALLY, 3 = ALL_PARTY, 4 = NONE / SELF
		if "item_id" in ability_res or "equipment_slot" in ability_res:
			# ItemData Enum Order: 0: SINGLE_PARTY_MEMBER, 1: ALL_PARTY, 2: SINGLE_ENEMY, 3: ALL_ENEMIES, 4: NONE
			return val == 0 or val == 1 or val == 4
		else:
			# SpellData / SkillData Enum Order: 0: SINGLE_ENEMY, 1: ALL_ENEMIES, 2: SINGLE_PARTY_MEMBER, 3: ALL_PARTY, 4: NONE
			return val == 2 or val == 3 or val == 4

	# 5. Name/ID Keyword Fallback
	var ability_name: String = ""
	if "spell_name" in ability_res:
		ability_name = str(ability_res.get("spell_name")).to_lower()
	elif "skill_name" in ability_res:
		ability_name = str(ability_res.get("skill_name")).to_lower()
	elif "name" in ability_res:
		ability_name = str(ability_res.get("name")).to_lower()

	if "heal" in ability_name or "purr" in ability_name or "cure" in ability_name or "buff" in ability_name or "mist" in ability_name or "smoke" in ability_name:
		return true
	if "dart" in ability_name or "bolt" in ability_name or "fire" in ability_name or "claw" in ability_name or "dissolve" in ability_name or "slash" in ability_name or "strike" in ability_name:
		return false

	return false


func _confirm_and_emit_action() -> void:
	if not is_instance_valid(_selected_ability) or _selected_target_index == -1:
		return

	var action_type: StringName = &"SKILL" if _current_tab == AbilityTab.SKILLS else &"SPELL"

	var cost_val: int = 0
	if "energy_cost" in _selected_ability:
		cost_val = int(_selected_ability.get("energy_cost"))
	elif "mana_cost" in _selected_ability:
		cost_val = int(_selected_ability.get("mana_cost"))
	elif "mp_cost" in _selected_ability:
		cost_val = int(_selected_ability.get("mp_cost"))

	if is_instance_valid(_active_cat):
		var new_val: int = 0
		if "current_energy" in _active_cat:
			new_val = max(0, int(_active_cat.get("current_energy")) - cost_val)
			_active_cat.set("current_energy", new_val)
		elif "current_mp" in _active_cat:
			new_val = max(0, int(_active_cat.get("current_mp")) - cost_val)
			_active_cat.set("current_mp", new_val)
		elif "current_mana" in _active_cat:
			new_val = max(0, int(_active_cat.get("current_mana")) - cost_val)
			_active_cat.set("current_mana", new_val)

		if get_tree().root.has_node("SignalBus"):
			SignalBus.character_mana_changed.emit(_active_slot_index, new_val)

	var target_mgr: Node = get_tree().root.get_node_or_null("TargetSelectionManager")
	if is_instance_valid(target_mgr) and target_mgr.has_method("set_pending_ability"):
		target_mgr.call("set_pending_ability", _selected_ability)

	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		bus.player_action_selected.emit(_active_slot_index, action_type, _selected_target_index)
		GameLogger.combat("BattleAbilityPopup: Executed %s on target index %d" % [action_type, _selected_target_index])

	_close_popup()


func _close_popup() -> void:
	hide()
	if is_instance_valid(background_dimmer):
		background_dimmer.hide()
	if is_instance_valid(panel_container):
		panel_container.hide()
	_selected_ability = null
	_selected_target_id = ""
	_selected_target_index = -1
