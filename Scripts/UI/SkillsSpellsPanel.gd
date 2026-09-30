# res://Scripts/UI/SkillsSpellsPanel.gd
extends VBoxContainer
class_name SkillsSpellsPanel

@onready var skills_button: Button = %SkillsButton as Button
@onready var spells_button: Button = %SpellsButton as Button
@onready var toolbar_container: HBoxContainer = %ToolbarContainer as HBoxContainer
@onready var list_container: VBoxContainer = %ListContainer as VBoxContainer

@export var entry_scene: PackedScene = preload("res://Scenes/UI/SkillSpellEntry.tscn")

enum Mode {
	SKILLS,
	SPELLS,
}
var current_mode: Mode = Mode.SKILLS
var current_cat: CatCharacter = null


func _ready() -> void:
	if skills_button and not skills_button.pressed.is_connected(_on_skills_tab_pressed):
		skills_button.pressed.connect(_on_skills_tab_pressed)
	if spells_button and not spells_button.pressed.is_connected(_on_spells_tab_pressed):
		spells_button.pressed.connect(_on_spells_tab_pressed)

	_update_tab_ui()


func display_character_abilities(cat: CatCharacter) -> void:
	current_cat = cat
	_render_list()


func _on_skills_tab_pressed() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_button_press()
	current_mode = Mode.SKILLS
	_update_tab_ui()
	_render_list()


func _on_spells_tab_pressed() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_button_press()
	current_mode = Mode.SPELLS
	_update_tab_ui()
	_render_list()


func _update_tab_ui() -> void:
	if skills_button:
		skills_button.text = "[ SKILLS ]" if current_mode == Mode.SKILLS else "  SKILLS  "
		skills_button.modulate = Color(0.0, 1.0, 0.8, 1.0) if current_mode == Mode.SKILLS else Color(0.5, 0.6, 0.7, 0.5)

	if spells_button:
		spells_button.text = "[ SPELLS ]" if current_mode == Mode.SPELLS else "  SPELLS  "
		spells_button.modulate = Color(0.0, 1.0, 0.8, 1.0) if current_mode == Mode.SPELLS else Color(0.5, 0.6, 0.7, 0.5)

	_update_toolbar()


func _update_toolbar() -> void:
	if not toolbar_container:
		return

	for child in toolbar_container.get_children():
		child.queue_free()

	var btn_title: String = "[ ALL SKILLS ]" if current_mode == Mode.SKILLS else "[ ALL SPELLS ]"
	var popup_key: StringName = &"ALL_SKILLS" if current_mode == Mode.SKILLS else &"ALL_SPELLS"

	var config_btn := _create_toolbar_button(btn_title, Color(0.0, 0.9, 0.8, 1.0))
	config_btn.pressed.connect(
		func() -> void:
			if is_instance_valid(AudioManager):
				AudioManager.play_button_press()
			if get_tree().root.has_node("SignalBus"):
				var bus: Node = get_tree().root.get_node("SignalBus")
				bus.popup_requested.emit(popup_key, { "character": current_cat, "mode": current_mode }),
	)
	toolbar_container.add_child(config_btn)


func _create_toolbar_button(label_text: String, color_val: Color) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 28)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.12, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = color_val * 0.7
	style.corner_radius_top_left = 2
	style.corner_radius_bottom_right = 2

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", color_val)
	btn.add_theme_font_size_override("font_size", 11)
	return btn


func _is_ability_available(ability_res: Resource, cat: CatCharacter) -> bool:
	if not is_instance_valid(ability_res) or not is_instance_valid(cat):
		return true

	var char_class_name: String = ""
	var char_race_name: String = ""
	var char_level: int = 1

	if "level" in cat:
		char_level = int(cat.get("level"))

	if "profession" in cat and cat.profession:
		char_class_name = str(cat.profession.get("profession_name")) if "profession_name" in cat.profession else ""
	elif "character_class" in cat and cat.character_class:
		char_class_name = str(cat.character_class.get("class_name")) if "class_name" in cat.character_class else ""

	if "breed" in cat and cat.breed:
		char_race_name = str(cat.breed.get("breed_name")) if "breed_name" in cat.breed else ""
	elif "character_race" in cat and cat.character_race:
		char_race_name = str(cat.character_race.get("race_name")) if "race_name" in cat.character_race else ""

	if ability_res is SpellData:
		var spell := ability_res as SpellData
		var is_class_ok: bool = spell.is_class_allowed(char_class_name) if spell.has_method("is_class_allowed") else true
		var req_level: int = int(spell.get("requirement")) if "requirement" in spell else 1
		var meets_level: bool = char_level >= req_level
		return is_class_ok and meets_level

	elif ability_res is SkillData:
		var skill := ability_res as SkillData
		var is_class_ok: bool = skill.is_class_allowed(char_class_name) if skill.has_method("is_class_allowed") else true
		var is_race_ok: bool = skill.is_race_allowed(char_race_name) if skill.has_method("is_race_allowed") else true
		var req_level: int = int(skill.get("requirement")) if "requirement" in skill else 1
		var meets_level: bool = char_level >= req_level
		return is_class_ok and is_race_ok and meets_level

	return true


func _is_field_usable(ability_res: Resource) -> bool:
	if not is_instance_valid(ability_res):
		return false

	if ability_res is SpellData:
		var spell := ability_res as SpellData
		return spell.effect_type in [SpellData.EffectType.HEAL, SpellData.EffectType.BUFF, SpellData.EffectType.UTILITY]
	elif ability_res is SkillData:
		var skill := ability_res as SkillData
		return skill.skill_type != SkillData.SkillType.COMBAT

	return false


func _render_list() -> void:
	if not list_container:
		return

	for child in list_container.get_children():
		child.queue_free()

	if not is_instance_valid(current_cat):
		_add_empty_message("NO CHARACTER SELECTED")
		return

	if current_mode == Mode.SKILLS:
		var skills: Array = _get_cat_skills(current_cat)
		if skills.is_empty():
			_add_empty_message("NO KNOWN SKILLS")
		else:
			for item in skills:
				if item is SkillData:
					var is_avail: bool = _is_ability_available(item, current_cat)
					var is_field: bool = _is_field_usable(item)
					var sub_info: String = "Accuracy: %d%% | Cost: %d EN" % [item.accuracy, item.energy_cost]
					_create_entry(item.skill_name, sub_info, item.icon if "icon" in item else null, item, is_avail, is_field)
	else:
		var spells: Array = _get_cat_spells(current_cat)
		if spells.is_empty():
			_add_empty_message("NO KNOWN SPELLS")
		else:
			for item in spells:
				if item is SpellData:
					var is_avail: bool = _is_ability_available(item, current_cat)
					var is_field: bool = _is_field_usable(item)
					var sub_info: String = "Cost: %d EN | %s" % [item.energy_cost, item.description]
					_create_entry(item.spell_name, sub_info, item.icon if "icon" in item else null, item, is_avail, is_field)


func _get_cat_skills(cat: CatCharacter) -> Array:
	if "known_skills" in cat and cat.known_skills is Array:
		return cat.known_skills
	elif "skills" in cat and cat.skills is Array:
		return cat.skills
	return []


func _get_cat_spells(cat: CatCharacter) -> Array:
	if "known_spells" in cat and cat.known_spells is Array:
		return cat.known_spells
	elif "spells" in cat and cat.spells is Array:
		return cat.spells
	return []


func _create_entry(
	title_text: String,
	desc_text: String,
	icon_tex: Texture2D,
	data_resource: Resource,
	is_available: bool = true,
	is_field_usable: bool = false
) -> void:
	if not entry_scene:
		return

	var entry_node: Control = entry_scene.instantiate() as Control
	entry_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := entry_node.get_node_or_null("%NameLabel") as Label
	if not name_label:
		name_label = entry_node.get_node_or_null("MarginContainer/HBox/VBox/Name") as Label

	var desc_label := entry_node.get_node_or_null("%DetailsLabel") as Label
	if not desc_label:
		desc_label = entry_node.get_node_or_null("MarginContainer/HBox/VBox/Desc") as Label

	var icon_rect := entry_node.get_node_or_null("%IconRect") as TextureRect
	if not icon_rect:
		icon_rect = entry_node.get_node_or_null("MarginContainer/HBox/Icon") as TextureRect

	var title_color: Color = Color(0.0, 1.0, 0.8) if is_field_usable else Color.WHITE
	var desc_color: Color = Color(0.0, 0.85, 0.75, 0.8) if is_field_usable else Color(0.8, 0.8, 0.8, 0.8)

	if name_label:
		name_label.text = (title_text.to_upper() + " [RESTRICTED]") if not is_available else title_text.to_upper()
		name_label.add_theme_color_override("font_color", title_color)

	if desc_label:
		desc_label.text = desc_text
		desc_label.add_theme_color_override("font_color", desc_color)

	if icon_rect and icon_tex:
		icon_rect.texture = icon_tex

	# Apply greyed-out visual modulation for unavailable abilities
	if not is_available:
		entry_node.modulate = Color(0.5, 0.5, 0.5, 0.6)

	if entry_node is Button:
		entry_node.pressed.connect(
			func() -> void:
				if is_instance_valid(AudioManager):
					AudioManager.play_button_press()
				if get_tree().root.has_node("SignalBus"):
					var bus: Node = get_tree().root.get_node("SignalBus")
					bus.popup_requested.emit(
						&"ABILITY_INFO",
						{
							"resource": data_resource,
							"character": current_cat,
						},
					),
		)

	list_container.add_child(entry_node)


func _add_empty_message(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6, 0.7))
	lbl.add_theme_font_size_override("font_size", 12)
	list_container.add_child(lbl)
