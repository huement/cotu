# res://Scripts/UI/SkillsSpellsPopup.gd
extends VBoxContainer
class_name SkillsSpellsPopup

signal closed

@onready var skills_button: Button = %SkillsButton as Button
@onready var spells_button: Button = %SpellsButton as Button
@onready var list_container: VBoxContainer = %ListContainer as VBoxContainer
@onready var title_label: Label = %TitleLabel as Label
@onready var class_name_label: Label = %ClassNameLabel as Label
@onready var close_button: Button = %CloseButton as Button

@export var entry_scene: PackedScene = preload("res://Scenes/UI/SkillSpellPopupEntry.tscn")

enum Mode {
	SKILLS,
	SPELLS,
}
var current_mode: Mode = Mode.SPELLS
var current_cat: CatCharacter = null


func _ready() -> void:
	if skills_button and not skills_button.pressed.is_connected(_on_skills_tab_pressed):
		skills_button.pressed.connect(_on_skills_tab_pressed)
	if spells_button and not spells_button.pressed.is_connected(_on_spells_tab_pressed):
		spells_button.pressed.connect(_on_spells_tab_pressed)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

	_update_tab_ui()


## PUBLIC API: Pass character resource and initial tab mode
func display_character_abilities(cat: CatCharacter, initial_mode: Mode = Mode.SPELLS) -> void:
	current_cat = cat
	current_mode = initial_mode
	_update_tab_ui()
	_render_list()


func _on_close_pressed() -> void:
	closed.emit()


func _on_skills_tab_pressed() -> void:
	current_mode = Mode.SKILLS
	_update_tab_ui()
	_render_list()


func _on_spells_tab_pressed() -> void:
	current_mode = Mode.SPELLS
	_update_tab_ui()
	_render_list()


func _update_header_badge() -> void:
	if title_label:
		title_label.text = "SKILLBOOK" if current_mode == Mode.SKILLS else "SPELLBOOK"

	if class_name_label:
		if is_instance_valid(current_cat):
			if "profession" in current_cat and current_cat.profession:
				class_name_label.text = current_cat.profession.profession_name.to_upper()
			elif "character_class" in current_cat and current_cat.character_class:
				class_name_label.text = current_cat.character_class.class_name.to_upper()
			else:
				class_name_label.text = "UNASSIGNED"


func _update_tab_ui() -> void:
	if skills_button:
		skills_button.text = "[ SKILLS ]" if current_mode == Mode.SKILLS else "  SKILLS  "
		skills_button.modulate = Color(0.0, 1.0, 0.8, 1.0) if current_mode == Mode.SKILLS else Color(0.5, 0.6, 0.7, 0.5)

	if spells_button:
		spells_button.text = "[ SPELLS ]" if current_mode == Mode.SPELLS else "  SPELLS  "
		spells_button.modulate = Color(0.0, 1.0, 0.8, 1.0) if current_mode == Mode.SPELLS else Color(0.5, 0.6, 0.7, 0.5)

	_update_header_badge()


func _render_list() -> void:
	if not list_container:
		return

	for child in list_container.get_children():
		child.queue_free()

	if not is_instance_valid(current_cat):
		_add_empty_message("NO CHARACTER SELECTED")
		return

	var char_class_name: String = ""
	if "profession" in current_cat and current_cat.profession:
		char_class_name = current_cat.profession.profession_name
	elif "character_class" in current_cat and current_cat.character_class:
		char_class_name = current_cat.character_class.class_name

	var char_race_name: String = ""
	if "breed" in current_cat and current_cat.breed:
		char_race_name = current_cat.breed.breed_name
	elif "character_race" in current_cat and current_cat.character_race:
		char_race_name = current_cat.character_race.race_name

	if current_mode == Mode.SKILLS:
		var skills: Array = _get_cat_skills(current_cat)
		if skills.is_empty():
			_add_empty_message("NO KNOWN SKILLS")
		else:
			for item in skills:
				if item is SkillData:
					_render_skill_row(item, char_class_name, char_race_name)
	else:
		var spells: Array = _get_cat_spells(current_cat)
		if spells.is_empty():
			_add_empty_message("NO KNOWN SPELLS")
		else:
			for item in spells:
				if item is SpellData:
					_render_spell_row(item, char_class_name)


func _render_spell_row(spell: SpellData, char_class_name: String) -> void:
	var entry_node: Control = entry_scene.instantiate() as Control

	var icon_rect := entry_node.get_node_or_null("%IconRect") as TextureRect
	var name_label := entry_node.get_node_or_null("%NameLabel") as Label
	var cost_label := entry_node.get_node_or_null("%CostLabel") as Label
	var prereq_label := entry_node.get_node_or_null("%PrereqLabel") as Label
	var elem_label := entry_node.get_node_or_null("%ElemLabel") as Label
	var details_label := entry_node.get_node_or_null("%DetailsLabel") as Label

	if icon_rect and spell.icon:
		icon_rect.texture = spell.icon
	if name_label:
		name_label.text = spell.spell_name
	if cost_label:
		cost_label.text = str(spell.energy_cost)
	if prereq_label:
		prereq_label.text = "LVL %d" % spell.requirement
	if elem_label:
		var element_key: String = ItemData.ElementalBase.keys()[spell.element]
		elem_label.text = element_key.capitalize()
	if details_label:
		details_label.text = spell.description

	var is_allowed: bool = spell.is_class_allowed(char_class_name)
	if not is_allowed:
		entry_node.modulate = Color(0.5, 0.5, 0.5, 0.4)
		if name_label:
			name_label.text += " [LOCKED]"

	_connect_entry_click(entry_node, spell)
	list_container.add_child(entry_node)


func _render_skill_row(skill: SkillData, char_class_name: String, char_race_name: String) -> void:
	var entry_node: Control = entry_scene.instantiate() as Control

	var icon_rect := entry_node.get_node_or_null("%IconRect") as TextureRect
	var name_label := entry_node.get_node_or_null("%NameLabel") as Label
	var cost_label := entry_node.get_node_or_null("%CostLabel") as Label
	var prereq_label := entry_node.get_node_or_null("%PrereqLabel") as Label
	var elem_label := entry_node.get_node_or_null("%ElemLabel") as Label
	var details_label := entry_node.get_node_or_null("%DetailsLabel") as Label

	if icon_rect and skill.icon:
		icon_rect.texture = skill.icon
	if name_label:
		name_label.text = skill.skill_name
	if cost_label:
		cost_label.text = str(skill.energy_cost)
	if prereq_label:
		prereq_label.text = "%d%% ACC" % skill.accuracy
	if elem_label:
		elem_label.text = ItemData.EffectElement.keys()[skill.element] if "element" in skill else "NONE"
	if details_label:
		details_label.text = skill.description

	var class_ok: bool = skill.is_class_allowed(char_class_name)
	var race_ok: bool = skill.is_race_allowed(char_race_name)

	if not (class_ok and race_ok):
		entry_node.modulate = Color(0.5, 0.5, 0.5, 0.4)
		if name_label:
			name_label.text += " [RESTRICTED]"

	_connect_entry_click(entry_node, skill)
	list_container.add_child(entry_node)


func _connect_entry_click(entry_node: Control, data_resource: Resource) -> void:
	if entry_node is Button:
		entry_node.pressed.connect(
			func() -> void:
				if get_tree().root.has_node("SignalBus"):
					var bus: Node = get_tree().root.get_node("SignalBus")
					bus.popup_requested.emit(
						&"ABILITY_INFO",
						{
							"resource": data_resource,
							"character": current_cat, # <--- Included character reference
						},
					),
		)


func _get_cat_skills(cat: CatCharacter) -> Array:
	if "known_skills" in cat and cat.known_skills is Array:
		return cat.known_skills
	if "skills" in cat and cat.skills is Array:
		return cat.skills
	return []


func _get_cat_spells(cat: CatCharacter) -> Array:
	if "known_spells" in cat and cat.known_spells is Array:
		return cat.known_spells
	if "spells" in cat and cat.spells is Array:
		return cat.spells
	return []


func _add_empty_message(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6, 0.7))
	lbl.add_theme_font_size_override("font_size", 12)
	list_container.add_child(lbl)
