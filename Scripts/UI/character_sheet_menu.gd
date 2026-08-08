# res://Scripts/UI/character_sheet_menu.gd
extends CanvasLayer
class_name CharacterSheetMenu

@onready var overlay_panel: Control = %OverlayPanel as Control
@onready var stats_panel: CharacterStatsPanel = %CharacterStatsPanel as CharacterStatsPanel
@onready var loadout_panel: CharacterLoadoutPanel = %CharacterLoadoutPanel as CharacterLoadoutPanel
@onready var inventory_grid: CharacterInventoryGrid = %CharacterInventoryGrid as CharacterInventoryGrid
@onready var skills_spells_panel: SkillsSpellsPanel = %SkillsSpellsPanel as SkillsSpellsPanel
@onready var char_name_label: Label = %CharNameLabel as Label
@onready var breed_label: Label = %BreedLabel as Label
@onready var profession_label: Label = %ProfessionLabel as Label
@onready var level_val_label: Label = %LevelValLabel as Label

# 🎯 SceneUniqueNodes for XP Display
@onready var exp_label: Label = %ExpLabel as Label
@onready var xp_progress_bar: ProgressBar = %XPProgressBar as ProgressBar

@onready var hp_val_label: Label = %HPValLabel as Label
@onready var energy_val_label: Label = %EnergyValLabel as Label
@onready var close_button: Button = %CloseButton as Button
@onready var portrait_texture: TextureRect = %PortraitTexture as TextureRect

# 🎯 SceneUniqueNodes for Attack Type and Row Toggle
@onready var attack_val_label: Label = %AttackValLabel as Label
@onready var row_toggle_button: Button = %RowToggleButton as Button

var _current_character: CatCharacter = null
var _current_slot_index: int = -1


func _ready() -> void:
	if overlay_panel:
		overlay_panel.visible = false

	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		bus.portrait_clicked.connect(_on_portrait_clicked)
		if bus.has_signal("character_xp_changed"):
			bus.character_xp_changed.connect(_on_character_xp_changed)

	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

	if row_toggle_button:
		row_toggle_button.toggled.connect(_on_row_toggle_toggled)
		# 1. Force the font color to remain Black (for normal, hover, and pressed states)
		row_toggle_button.add_theme_color_override("font_color", Color.BLACK)
		row_toggle_button.add_theme_color_override("font_hover_color", Color.BLACK)
		row_toggle_button.add_theme_color_override("font_pressed_color", Color.BLACK)
		row_toggle_button.add_theme_color_override("font_focus_color", Color.BLACK)


func _on_portrait_clicked(slot_index: int) -> void:
	GameState.current_mode = GameState.Mode.MANAGEMENT
	_current_slot_index = slot_index

	if not GameState.current_party or slot_index >= GameState.current_party.slots.size():
		return

	var character: CatCharacter = GameState.current_party.slots[slot_index]
	if not is_instance_valid(character):
		return

	_render_character_sheet(character)
	overlay_panel.visible = true


func _render_character_sheet(character: CatCharacter) -> void:
	if not is_instance_valid(character):
		return

	# 1. Load Portrait Texture
	if portrait_texture:
		var tex: Texture2D = null
		if "portrait_path" in character and not str(character.portrait_path).is_empty():
			if ResourceLoader.exists(character.portrait_path):
				tex = load(character.portrait_path) as Texture2D
		elif "portrait" in character and character.portrait is Texture2D:
			tex = character.portrait
		elif character.breed and "portrait_path" in character.breed and not str(character.breed.portrait_path).is_empty():
			if ResourceLoader.exists(character.breed.portrait_path):
				tex = load(character.breed.portrait_path) as Texture2D

		portrait_texture.texture = tex

	# 2. Update Left Identity Column
	if char_name_label:
		char_name_label.text = character.name.to_upper()
	if breed_label:
		breed_label.text = character.breed.breed_name.to_upper() if character.breed else "UNKNOWN"
	if hp_val_label:
		hp_val_label.text = "%d / %d" % [character.current_hp, character.max_hp]
	if energy_val_label:
		energy_val_label.text = "%d / %d" % [character.current_energy, character.max_energy]

	# 3. Update Level & XP Progression
	if character.max_xp <= 0 and character.has_method("get_required_xp_for_level"):
		character.max_xp = character.get_required_xp_for_level(character.level)

	if level_val_label:
		level_val_label.text = str(character.level)

	if exp_label:
		exp_label.text = "%d / %d" % [character.current_xp, character.max_xp]

	if xp_progress_bar:
		xp_progress_bar.min_value = 0
		xp_progress_bar.max_value = character.max_xp
		xp_progress_bar.value = character.current_xp

	# 4. ⚔️ Update Attack Type Label
	if attack_val_label:
		var attack_type: String = character.get_attack_type_string() if character.has_method("get_attack_type_string") else "UNARMED"
		attack_val_label.text = attack_type.to_upper()

	# 5. 🛡️ Update Row Position Toggle Button UI
	if row_toggle_button:
		row_toggle_button.set_block_signals(true)
		var is_front: bool = character.is_front_row if "is_front_row" in character else true
		row_toggle_button.button_pressed = not is_front
		_update_row_button_text(is_front)
		row_toggle_button.set_block_signals(false)

	if profession_label:
		var prof_title: String = "UNASSIGNED"
		if is_instance_valid(character.profession) and not character.profession.profession_name.is_empty():
			prof_title = character.profession.profession_name
		profession_label.text = prof_title.to_upper()

	# 4. Delegate Sub-Panel Displays
	if stats_panel:
		stats_panel.display_character_stats(character)
	if loadout_panel:
		loadout_panel.display_loadout(character)
	if inventory_grid and "inventory" in GameState:
		inventory_grid.display_inventory(GameState.inventory)
	if skills_spells_panel:
		skills_spells_panel.display_character_abilities(character)


func _on_row_toggle_toggled(button_pressed: bool) -> void:
	if not is_instance_valid(_current_character) or not GameState.current_party:
		return

	var target_front: bool = not button_pressed

	if not target_front:
		var front_count: int = GameState.current_party.get_front_row_count()
		if front_count <= 1 and _current_character.is_front_row:
			# Reject change! At least 1 character must remain in the Front Row
			row_toggle_button.set_block_signals(true)
			row_toggle_button.button_pressed = false
			_update_row_button_text(true)
			row_toggle_button.set_block_signals(false)
			print("CharacterSheetMenu: Cannot move to Back Row: At least 1 party member must be in the Front Row!")
			return

	GameState.current_party.set_character_row(_current_character, target_front)
	_update_row_button_text(target_front)
	GameState.save_game()


func _update_row_button_text(is_front: bool) -> void:
	if not row_toggle_button:
		return

	var bg_color: Color

	if is_front:
		row_toggle_button.text = "⚔️ FRONT ROW"
		# High contrast dark text on the cyan button background
		bg_color = Color("#00ffc8") # Cyberpunk Cyan
	else:
		row_toggle_button.text = "🛡️ BACK ROW"
		bg_color = Color("#fd6644") # Cyberpunk Orange

	# 3. Create a StyleBox for the background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = bg_color

	# Optional: Add subtle rounded corners to match standard UI
	style_box.set_corner_radius_all(4)

	# 4. Apply the stylebox to the button states
	row_toggle_button.add_theme_stylebox_override("normal", style_box)
	row_toggle_button.add_theme_stylebox_override("hover", style_box)
	row_toggle_button.add_theme_stylebox_override("pressed", style_box)


func _on_character_xp_changed(_slot_index: int, _current_xp: int, _max_xp: int) -> void:
	if overlay_panel and overlay_panel.visible:
		var active_cat: CatCharacter = GameState.get_active_cat() as CatCharacter
		if is_instance_valid(active_cat):
			_render_character_sheet(active_cat)


func _on_close_button_pressed() -> void:
	if overlay_panel:
		overlay_panel.visible = false
	GameState.current_mode = GameState.Mode.EXPLORING
