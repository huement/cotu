# res://Scripts/UI/SkillsSpellsPanel.gd
extends VBoxContainer
class_name SkillsSpellsPanel

@onready var skills_button: Button = %SkillsButton as Button
@onready var spells_button: Button = %SpellsButton as Button
@onready var toolbar_container: HBoxContainer = %ToolbarContainer as HBoxContainer
@onready var list_container: VBoxContainer = %ListContainer as VBoxContainer

@export var entry_scene: PackedScene = preload("res://Scenes/UI/SkillSpellEntry.tscn")

enum Mode { SKILLS, SPELLS }
var current_mode: Mode = Mode.SKILLS
var current_cat: CatCharacter = null

func _ready() -> void:
	if skills_button and not skills_button.pressed.is_connected(_on_skills_tab_pressed):
		skills_button.pressed.connect(_on_skills_tab_pressed)
	if spells_button and not spells_button.pressed.is_connected(_on_spells_tab_pressed):
		spells_button.pressed.connect(_on_spells_tab_pressed)
		
	_update_tab_ui()

## PUBLIC API: Pass the active CatCharacter resource to display abilities
func display_character_abilities(cat: CatCharacter) -> void:
	current_cat = cat
	_render_list()

func _on_skills_tab_pressed() -> void:
	current_mode = Mode.SKILLS
	_update_tab_ui()
	_render_list()

func _on_spells_tab_pressed() -> void:
	current_mode = Mode.SPELLS
	_update_tab_ui()
	_render_list()

func _update_tab_ui() -> void:
	# Active tab visual feedback
	if skills_button:
		skills_button.text = "[ SKILLS ]" if current_mode == Mode.SKILLS else "  SKILLS  "
		skills_button.modulate = Color(0.0, 1.0, 0.8, 1.0) if current_mode == Mode.SKILLS else Color(0.5, 0.6, 0.7, 0.5)
		
	if spells_button:
		spells_button.text = "[ SPELLS ]" if current_mode == Mode.SPELLS else "  SPELLS  "
		spells_button.modulate = Color(0.0, 1.0, 0.8, 1.0) if current_mode == Mode.SPELLS else Color(0.5, 0.6, 0.7, 0.5)

	_update_toolbar()

## 🛠️ DYNAMIC TOOLBAR BUILDER
func _update_toolbar() -> void:
	if not toolbar_container:
		return

	# Wipe previous toolbar buttons
	for child in toolbar_container.get_children():
		child.queue_free()

	if current_mode == Mode.SKILLS:
		# --- SKILLS TOOLBAR BUTTONS ---
		var config_skills_btn := _create_toolbar_button("[ ALL SKILLS ]", Color(0.0, 0.9, 0.8, 1.0))
		config_skills_btn.pressed.connect(func() -> void:
			if get_tree().root.has_node("SignalBus"):
				var bus: Node = get_tree().root.get_node("SignalBus")
				bus.popup_requested.emit(&"ALL_SKILLS", {"character": current_cat})
		)
		toolbar_container.add_child(config_skills_btn)
	else:
		# --- SPELLS TOOLBAR BUTTONS ---
		var config_spells_btn := _create_toolbar_button("[ ALL SPELLS ]", Color(0.0, 0.9, 0.8, 1.0))
		config_spells_btn.pressed.connect(func() -> void:
			if get_tree().root.has_node("SignalBus"):
				var bus: Node = get_tree().root.get_node("SignalBus")
				bus.popup_requested.emit(&"ALL_SPELLS", {"character": current_cat})
		)
		toolbar_container.add_child(config_spells_btn)

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
					var icon_tex: Texture2D = item.icon if "icon" in item else null
					var sub_info: String = "Accuracy: %d%% | Cost: %d EN" % [item.accuracy, item.energy_cost]
					_create_entry(item.skill_name, sub_info, icon_tex, item)
	else:
		var spells: Array = _get_cat_spells(current_cat)
		if spells.is_empty():
			_add_empty_message("NO KNOWN SPELLS")
		else:
			for item in spells:
				if item is SpellData:
					var title: String = item.spell_title if "spell_title" in item else "Spell"
					var cost: int = item.energy_cost if "energy_cost" in item else 0
					var desc: String = item.description if "description" in item else ""
					var icon_tex: Texture2D = item.icon if "icon" in item else null
					var sub_info: String = "%s | Cost: %d EN | %s" % [title, cost, desc]
					_create_entry(item.spell_name, sub_info, icon_tex, item)

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

func _create_entry(title_text: String, desc_text: String, icon_tex: Texture2D, data_resource: Resource) -> void:
	if not entry_scene:
		return

	var entry_node: Control = entry_scene.instantiate() as Control
	entry_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := entry_node.get_node_or_null("MarginContainer/HBox/VBox/Name") as Label
	if not name_label:
		name_label = entry_node.get_node_or_null("HBox/VBox/Name") as Label

	var desc_label := entry_node.get_node_or_null("MarginContainer/HBox/VBox/Desc") as Label
	if not desc_label:
		desc_label = entry_node.get_node_or_null("HBox/VBox/Desc") as Label

	var icon_rect := entry_node.get_node_or_null("MarginContainer/HBox/Icon") as TextureRect
	if not icon_rect:
		icon_rect = entry_node.get_node_or_null("HBox/Icon") as TextureRect

	if name_label: name_label.text = title_text.to_upper()
	if desc_label: desc_label.text = desc_text
	if icon_rect and icon_tex: icon_rect.texture = icon_tex

	if entry_node is Button:
		entry_node.pressed.connect(func() -> void:
			if get_tree().root.has_node("SignalBus"):
				var bus: Node = get_tree().root.get_node("SignalBus")
				bus.popup_requested.emit(&"ABILITY_INFO", {"resource": data_resource})
		)

	list_container.add_child(entry_node)

func _add_empty_message(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6, 0.7))
	lbl.add_theme_font_size_override("font_size", 12)
	list_container.add_child(lbl)
