# res://Scripts/UI/SkillsSpellsPanel.gd
extends VBoxContainer
class_name SkillsSpellsPanel

## Touch layout only: the selected row changed (null = nothing selected any more).
signal ability_selected(ability: Resource)

## Touch layout: how much bigger the rows are than on desktop.
const TOUCH_ROW_SCALE: float = 1.5

@onready var skills_button: Button = %SkillsButton as Button
@onready var spells_button: Button = %SpellsButton as Button
@onready var toolbar_container: HBoxContainer = %ToolbarContainer as HBoxContainer
@onready var list_container: VBoxContainer = %ListContainer as VBoxContainer


enum Mode {
	SKILLS,
	SPELLS,
}
var current_mode: Mode = Mode.SKILLS
var current_cat: CatCharacter = null

## Touch layout (phones, see CharacterSheetMobile): bigger rows, tapping a row SELECTS it
## (ability_selected) instead of opening the detail popup, and the toolbar gets a
## "show field-usable only" filter. Switch with set_touch_layout().
var touch_layout: bool = false
## Touch layout filter: list only abilities that can be used outside battle.
var field_only: bool = false
var selected_ability: Resource = null
var _row_group: ButtonGroup = null


func _ready() -> void:
	if skills_button and not skills_button.pressed.is_connected(_on_skills_tab_pressed):
		skills_button.pressed.connect(_on_skills_tab_pressed)
	if spells_button and not spells_button.pressed.is_connected(_on_spells_tab_pressed):
		spells_button.pressed.connect(_on_spells_tab_pressed)

	_update_tab_ui()


func display_character_abilities(cat: CatCharacter) -> void:
	current_cat = cat
	_render_list()


func set_touch_layout(on: bool) -> void:
	if touch_layout == on:
		return
	touch_layout = on
	if not on:
		field_only = false
		selected_ability = null
	_update_toolbar()
	_render_list()


## "" when `cat` can use `ability` from the menu (outside battle), else the reason in capitals.
func field_use_blocker(ability: Resource, cat: CatCharacter) -> String:
	if not _is_ability_available(ability, cat):
		return "CLASS, BREED OR LEVEL RESTRICTED"
	if not _is_field_usable(ability):
		return "COMBAT ONLY"
	return ""


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

	if touch_layout:
		var filter_btn := _create_toolbar_button("SHOW: FIELD ONLY" if field_only else "SHOW: ALL", Color(1.0, 0.8, 0.18, 1.0))
		filter_btn.pressed.connect(
			func() -> void:
				if is_instance_valid(AudioManager):
					AudioManager.play_button_press()
				field_only = not field_only
				_update_toolbar()
				_render_list(),
		)
		toolbar_container.add_child(filter_btn)

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
	btn.custom_minimum_size = Vector2(0, 42 if touch_layout else 28)
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
	btn.add_theme_font_size_override("font_size", 16 if touch_layout else 11)
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

	_row_group = ButtonGroup.new()
	var selection_listed: bool = false

	if not is_instance_valid(current_cat):
		_add_empty_message("NO CHARACTER SELECTED")
	else:
		var is_skills: bool = current_mode == Mode.SKILLS
		var known: Array = _get_cat_skills(current_cat) if is_skills else _get_cat_spells(current_cat)
		var kind: String = "SKILLS" if is_skills else "SPELLS"
		var hidden_by_filter: int = 0
		if known.is_empty():
			_add_empty_message("NO KNOWN %s" % kind)
		for item in known:
			if not (item is SkillData if is_skills else item is SpellData):
				continue
			if field_only and not _is_field_usable(item):
				hidden_by_filter += 1
				continue
			_add_row(item)
			selection_listed = selection_listed or item == selected_ability
		if hidden_by_filter > 0 and hidden_by_filter == known.size():
			_add_empty_message("NO %s USABLE OUTSIDE BATTLE" % kind)

	# The selected ability is no longer in the list (other tab, filter, other character).
	if selected_ability != null and not selection_listed:
		selected_ability = null
		ability_selected.emit(null)


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


## One ability as the shared AbilityRow (same look as the battle HUD and every other ability list).
## Abilities usable outside battle keep the teal title; battle-only ones are white.
func _add_row(ability: Resource) -> void:
	var options: Dictionary = { "context": AbilityRow.Context.MENU }
	if not _is_field_usable(ability):
		options["title_color"] = Color.WHITE
	if touch_layout:
		options["toggle"] = true
		options["button_group"] = _row_group
	var row: AbilityRow = AbilityRow.create(ability, options)
	if not _is_ability_available(ability, current_cat):
		row.set_unavailable("Restricted - class, breed or level requirement not met")
	if touch_layout:
		row.set_ui_scale(TOUCH_ROW_SCALE)
		row.set_selected(ability == selected_ability)
	row.pressed.connect(
		func() -> void:
			if is_instance_valid(AudioManager):
				AudioManager.play_button_press()
			if touch_layout:
				# Details + casting are on the sheet itself (CharacterSheetMobile), no popup.
				selected_ability = ability
				ability_selected.emit(ability)
				return
			if get_tree().root.has_node("SignalBus"):
				var bus: Node = get_tree().root.get_node("SignalBus")
				bus.popup_requested.emit(&"ABILITY_INFO", { "resource": ability, "character": current_cat }),
	)
	list_container.add_child(row)


func _add_empty_message(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6, 0.7))
	lbl.add_theme_font_size_override("font_size", 18 if touch_layout else 12)
	list_container.add_child(lbl)
