# res://Scripts/UI/SkillSpellDetailPopup.gd
extends CanvasLayer
class_name SkillSpellDetailPopup

@onready var background_dimmer: ColorRect = %BackgroundDimmer as ColorRect
@onready var panel_container: PanelContainer = %PanelContainer as PanelContainer

# Page 1 Nodes (Detail View)
@onready var page_detail: VBoxContainer = %PageDetail as VBoxContainer
@onready var icon_rect: TextureRect = %IconRect as TextureRect
@onready var name_label: Label = %NameLabel as Label
@onready var desc_label: Label = %DescLabel as Label
@onready var cost_label: Label = %CostLabel as Label
@onready var elem_label: Label = %ElemLabel as Label
@onready var duration_label: Label = %DurationLabel as Label
@onready var scales_with_label: Label = %ScaleLabel as Label
@onready var effect_label: Label = %EffectLabel as Label
@onready var target_label: Label = %TargetLabel as Label
@onready var status_effect: Label = %StatusLabel as Label
@onready var cast_button: Button = %CastButton as Button
@onready var requirement_badge: PanelContainer = %RequirementBadge as PanelContainer
@onready var requirement_label: Label = %RequirementLabel as Label
@onready var close_button: Button = %CloseButton as Button

# SKILL SPECIFIC
@onready var type_label: Label = %TypeLabel as Label

# Page 2 Nodes (Target Selection View)
@onready var page_target: VBoxContainer = %PageTarget as VBoxContainer
@onready var target_header_label: Label = %TargetHeaderLabel as Label
@onready var target_grid_container: GridContainer = %TargetGridContainer as GridContainer
@onready var target_back_btn: Button = %TargetBackBtn as Button
@onready var target_confirm_btn: Button = %TargetConfirmBtn as Button

var _active_resource: Resource = null
var _active_cat: CatCharacter = null
var _selected_target_cat: CatCharacter = null


func _ready() -> void:
	_hide_popup()

	if close_button and not close_button.pressed.is_connected(_hide_popup):
		close_button.pressed.connect(_hide_popup)
	if cast_button and not cast_button.pressed.is_connected(_go_to_target_page):
		cast_button.pressed.connect(_go_to_target_page)
	if target_back_btn and not target_back_btn.pressed.is_connected(_go_to_detail_page):
		target_back_btn.pressed.connect(_go_to_detail_page)
	if target_confirm_btn and not target_confirm_btn.pressed.is_connected(_execute_field_ability):
		target_confirm_btn.pressed.connect(_execute_field_ability)

	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		bus.popup_requested.connect(_on_popup_requested)


func _on_popup_requested(action_type: StringName, data: Dictionary = { }) -> void:
	if action_type == &"ABILITY_INFO":
		var res: Resource = data.get("resource", null) as Resource
		var cat: CatCharacter = data.get("character", null) as CatCharacter
		if is_instance_valid(res):
			open_detail(res, cat)


## Displays detailed specifications for a SpellData or SkillData resource
func open_detail(res: Resource, cat: CatCharacter = null) -> void:
	_active_resource = res
	_active_cat = cat
	_selected_target_cat = null

	_go_to_detail_page()
	_populate_ability_stats()

	show()
	if background_dimmer:
		background_dimmer.show()
	if panel_container:
		panel_container.show()


func _go_to_detail_page() -> void:
	if page_detail:
		page_detail.show()
	if page_target:
		page_target.hide()


func _populate_ability_stats() -> void:
	if not is_instance_valid(_active_resource):
		return

	var char_class_name: String = ""
	var char_race_name: String = ""
	var char_level: int = 1

	if is_instance_valid(_active_cat):
		char_level = _active_cat.level
		if "profession" in _active_cat and _active_cat.profession:
			char_class_name = _active_cat.profession.profession_name
		elif "character_class" in _active_cat and _active_cat.character_class:
			char_class_name = _active_cat.character_class.class_name

		if "breed" in _active_cat and _active_cat.breed:
			char_race_name = _active_cat.breed.breed_name
		elif "character_race" in _active_cat and _active_cat.character_race:
			char_race_name = _active_cat.character_race.race_name

	if _active_resource is SpellData:
		var spell := _active_resource as SpellData
		if name_label:
			name_label.text = spell.spell_name.to_upper()
		if desc_label:
			desc_label.text = spell.description
		if icon_rect and spell.icon:
			icon_rect.texture = spell.icon

		if cost_label:
			cost_label.text = "CAST COST: %d MP" % spell.energy_cost
		if elem_label:
			elem_label.text = "BASE TYPE: %s" % ItemData.EffectElement.keys()[spell.element]
		if duration_label:
			duration_label.text = "DURATION: %d TURNS" % spell.duration
		if scales_with_label:
			scales_with_label.text = "SCALES WITH: %s" % spell.stat_scaling
		if effect_label:
			effect_label.text = "EFFECT TYPE: %s" % SpellData.EffectType.keys()[spell.effect_type]
		if target_label:
			target_label.text = "TARGET: %s" % SpellData.TargetType.keys()[spell.target_type]

		_render_status_effect_ui(spell.status_effect)

		var is_allowed: bool = spell.is_class_allowed(char_class_name)
		var meets_req: bool = char_level >= spell.requirement
		var is_field_castable: bool = spell.effect_type in [SpellData.EffectType.HEAL, SpellData.EffectType.BUFF, SpellData.EffectType.UTILITY]

		_configure_bottom_bar(is_allowed, meets_req, is_field_castable, spell.requirement, "[ CAST ]")

	elif _active_resource is SkillData:
		var skill := _active_resource as SkillData
		if name_label:
			name_label.text = skill.skill_name.to_upper()
		if desc_label:
			desc_label.text = skill.description
		if icon_rect and skill.icon:
			icon_rect.texture = skill.icon

		if cost_label:
			cost_label.text = "CAST COST: %d MP" % skill.energy_cost
		if elem_label:
			elem_label.text = "BASE TYPE: %s" % (ItemData.EffectElement.keys()[skill.element] if "element" in skill else "NONE")
		if duration_label:
			duration_label.text = "ACCURACY: %d%%" % skill.accuracy
		if effect_label:
			effect_label.text = "EFFECT TYPE: %s" % SkillData.EffectType.keys()[skill.effect_type]
		if type_label:
			type_label.text = "SKILL TYPE: %s" % SkillData.SkillType.keys()[skill.skill_type]

		_render_status_effect_ui(skill.status_effect if "status_effect" in skill else "NONE")

		var is_class_ok: bool = skill.is_class_allowed(char_class_name)
		var is_race_ok: bool = skill.is_race_allowed(char_race_name)
		var is_field_castable: bool = skill.skill_type != SkillData.SkillType.COMBAT

		_configure_bottom_bar(is_class_ok and is_race_ok, true, is_field_castable, 1, "[ USE ]")


func _render_status_effect_ui(status_effect_id: String) -> void:
	var status_label := %StatusLabel as Label
	var status_icon := %StatusIconRect as TextureRect if has_node("%StatusIconRect") else null

	if status_effect_id.is_empty() or status_effect_id.to_upper() == "NONE":
		if status_label:
			status_label.text = "STATUS EFFECT:\nNONE"
			status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.6))
		if status_icon:
			status_icon.visible = false
	else:
		var info: Dictionary = StatusEffectDatabase.get_effect_info(status_effect_id)
		if not info.is_empty():
			if status_label:
				status_label.text = "STATUS EFFECT:\n%s (%dT)" % [info["name"].to_upper(), info["duration"]]
				var text_color: Color = Color(0.27, 0.90, 0.53, 1.0) if info["is_positive"] else Color(1.0, 0.35, 0.35, 1.0)
				status_label.add_theme_color_override("font_color", text_color)

			if status_icon and info["icon"] != null:
				status_icon.texture = info["icon"] as Texture2D
				status_icon.visible = true
		else:
			if status_label:
				status_label.text = "STATUS EFFECT:\n%s" % status_effect_id.to_upper()
				status_label.add_theme_color_override("font_color", Color(0, 0.95, 1, 1))


func _configure_bottom_bar(is_allowed: bool, meets_req: bool, is_field_usable: bool, req_level: int, button_text: String) -> void:
	if not is_allowed:
		if cast_button:
			cast_button.hide()
		if requirement_badge:
			requirement_badge.show()
		if requirement_label:
			requirement_label.text = "CLASS RESTRICTED"
	elif not meets_req:
		if cast_button:
			cast_button.hide()
		if requirement_badge:
			requirement_badge.show()
		if requirement_label:
			requirement_label.text = "AVAILABLE | LVL %d" % req_level
	elif not is_field_usable:
		if cast_button:
			cast_button.hide()
		if requirement_badge:
			requirement_badge.show()
		if requirement_label:
			requirement_label.text = "COMBAT ONLY"
	else:
		if cast_button:
			cast_button.text = button_text
			cast_button.show()
		if requirement_badge:
			requirement_badge.hide()


## Page 2: Target Selection Page
func _go_to_target_page() -> void:
	if page_detail:
		page_detail.hide()
	if page_target:
		page_target.show()

	for child in target_grid_container.get_children():
		child.queue_free()

	if target_header_label:
		target_header_label.text = "SELECT TARGET FOR %s" % (name_label.text if name_label else "ABILITY")

	if get_tree().root.has_node("GameState"):
		var gs: Node = get_tree().root.get_node("GameState")
		if "current_party" in gs and gs.current_party:
			for member in gs.current_party.slots:
				if is_instance_valid(member):
					var card := _create_target_card(member)
					target_grid_container.add_child(card)

	_update_confirm_button()


func _create_target_card(cat: CatCharacter) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(180, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var text_val: String = "%s\nHP: %d/%d" % [cat.name.to_upper(), cat.current_hp, cat.max_hp]
	btn.text = text_val
	btn.add_theme_font_size_override("font_size", 11)

	btn.pressed.connect(
		func() -> void:
			_selected_target_cat = cat
			_highlight_target_card(btn)
			_update_confirm_button(),
	)
	return btn


func _highlight_target_card(selected_btn: Button) -> void:
	for child in target_grid_container.get_children():
		if child is Button:
			child.modulate = Color(1.0, 1.0, 1.0, 1.0) if child == selected_btn else Color(0.5, 0.5, 0.5, 0.6)


func _update_confirm_button() -> void:
	if target_confirm_btn:
		target_confirm_btn.disabled = not is_instance_valid(_selected_target_cat)


func _execute_field_ability() -> void:
	if not is_instance_valid(_active_resource) or not is_instance_valid(_selected_target_cat):
		return

	var cost: int = _active_resource.energy_cost if "energy_cost" in _active_resource else 0
	if is_instance_valid(_active_cat):
		_active_cat.current_energy = max(0, _active_cat.current_energy - cost)

	if _active_resource is SpellData:
		var spell := _active_resource as SpellData
		if spell.effect_type == SpellData.EffectType.HEAL:
			var heal_amount: int = spell.calculate_potency(_active_cat.intelligence if "intelligence" in _active_cat else 10)
			_selected_target_cat.current_hp = min(_selected_target_cat.max_hp, _selected_target_cat.current_hp + heal_amount)

	_emit_field_action_log()
	_hide_popup()


func _emit_field_action_log() -> void:
	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		var action_name: String = _active_resource.spell_name if _active_resource is SpellData else _active_resource.skill_name
		bus.log_message_emitted.emit("Casted %s on %s!" % [action_name.to_upper(), _selected_target_cat.name.to_upper()], "#00FFCC")


func _hide_popup() -> void:
	hide()
	if background_dimmer:
		background_dimmer.hide()
	if panel_container:
		panel_container.hide()
	_active_resource = null
	_active_cat = null
	_selected_target_cat = null
