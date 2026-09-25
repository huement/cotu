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

# SceneUniqueNodes for XP Display
@onready var exp_label: Label = %ExpLabel as Label
@onready var xp_progress_bar: ProgressBar = %XPProgressBar as ProgressBar

@onready var hp_val_label: Label = %HPValLabel as Label
@onready var energy_val_label: Label = %EnergyValLabel as Label
@onready var close_button: Button = %CloseButton as Button
@onready var portrait_texture: TextureRect = %PortraitTexture as TextureRect

# SceneUniqueNodes for Attack Type and Row Toggle
@onready var attack_val_label: Label = %AttackValLabel as Label
@onready var row_toggle_button: Button = %RowToggleButton as Button

# SceneUniqueNodes for Paginator
@onready var prev_character_button: TextureButton = %PrevCharacterButton as TextureButton
@onready var next_character_button: TextureButton = %NextCharacterButton as TextureButton
@onready var index_label: Label = %IndexLabel as Label

# Default path for incapacitated state
const DOWNED_PORTRAIT_PATH: String = "res://ui/portrait-down.png"

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
		if bus.has_signal("character_health_changed"):
			bus.character_health_changed.connect(_on_character_stats_changed)
		if bus.has_signal("character_mana_changed"):
			bus.character_mana_changed.connect(_on_character_stats_changed)

	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

	if prev_character_button:
		prev_character_button.pressed.connect(_on_prev_character_pressed)
	if next_character_button:
		next_character_button.pressed.connect(_on_next_character_pressed)

	if row_toggle_button:
		row_toggle_button.toggle_mode = true
		row_toggle_button.toggled.connect(_on_row_toggle_toggled)
		row_toggle_button.add_theme_color_override("font_color", Color.BLACK)
		row_toggle_button.add_theme_color_override("font_hover_color", Color.BLACK)
		row_toggle_button.add_theme_color_override("font_pressed_color", Color.BLACK)
		row_toggle_button.add_theme_color_override("font_focus_color", Color.BLACK)


func _on_portrait_clicked(slot_index: int) -> void:
	GameState.current_mode = GameState.Mode.MANAGEMENT
	_current_slot_index = slot_index
	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound("button-press")

	if "active_character_index" in GameState:
		GameState.active_character_index = slot_index

	if not GameState.current_party or slot_index >= GameState.current_party.slots.size():
		return

	var character: CatCharacter = GameState.current_party.slots[slot_index] as CatCharacter
	if not is_instance_valid(character):
		return

	_render_character_sheet(character)
	overlay_panel.visible = true


func _render_character_sheet(character: CatCharacter) -> void:
	if not is_instance_valid(character):
		return

	_current_character = character
	if GameState.current_party:
		_current_slot_index = GameState.current_party.slots.find(character)
		if _current_slot_index != -1 and "active_character_index" in GameState:
			GameState.active_character_index = _current_slot_index

	var is_downed: bool = character.current_hp <= 0

	# 1. Load Portrait Texture (Downed Override vs Normal Portrait)
	if portrait_texture:
		if is_downed and ResourceLoader.exists(DOWNED_PORTRAIT_PATH):
			portrait_texture.texture = load(DOWNED_PORTRAIT_PATH) as Texture2D
		else:
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
		var breed_str: String = character.breed.breed_name.to_upper() if character.breed else "UNKNOWN"
		breed_label.text = "INCAPACITATED" if is_downed else breed_str
	if hp_val_label:
		hp_val_label.text = "%d / %d" % [character.current_hp, character.max_hp]
	if energy_val_label:
		energy_val_label.text = "%d / %d" % [character.current_energy, character.max_energy]

	# 3. Apply Downed Grayscale & Tint Modifications
	_apply_downed_visual_effects(is_downed)

	# 4. Update Level & XP Progression
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

	# 5. Update Attack Type Label
	if attack_val_label:
		var attack_type: String = character.get_attack_type_string() if character.has_method("get_attack_type_string") else "UNARMED"
		attack_val_label.text = attack_type.to_upper()

	# 6. Update Row Position Toggle Button UI
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

	# 7. Update Paginator Index Label & Buttons
	_update_paginator()

	# 8. Delegate Sub-Panel Displays
	if stats_panel:
		stats_panel.display_character_stats(character)
	if loadout_panel:
		loadout_panel.display_loadout(character)
	if inventory_grid and "inventory" in GameState:
		inventory_grid.display_inventory(GameState.inventory)
	if skills_spells_panel:
		skills_spells_panel.display_character_abilities(character)
	
	_update_status_effects_display(character)


## Tints and desaturates UI elements when character is downed
func _apply_downed_visual_effects(is_downed: bool) -> void:
	var main_hbox: Control = $OverlayPanel/MarginContainer/MainHBox as Control
	if is_instance_valid(main_hbox):
		main_hbox.modulate = Color(0.4, 0.4, 0.4, 1.0) if is_downed else Color.WHITE

	if hp_val_label:
		if is_downed:
			hp_val_label.add_theme_color_override("font_color", Color.WHITE)
		else:
			hp_val_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.4, 1.0))

	if breed_label:
		if is_downed:
			breed_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1.0))
		else:
			breed_label.remove_theme_color_override("font_color")


## Refreshes status effect badges inside %CurrentStatusEffects
func _update_status_effects_display(cat_character: Resource) -> void:
	var container: Control = %CurrentStatusEffects
	if not is_instance_valid(container):
		return
		
	# Clear previous badge instances
	for child in container.get_children():
		if child is StatusEffectBadge:
			child.queue_free()
			
	if not is_instance_valid(cat_character):
		return

	var equipped_items: Array[Resource] = []
	
	# 1. Collect equipment across all storage patterns
	if cat_character.has_method("get_all_equipped_items"):
		var res: Variant = cat_character.call("get_all_equipped_items")
		if res is Array:
			for item in (res as Array):
				if item is Resource:
					equipped_items.append(item as Resource)
	elif "equipment" in cat_character and cat_character.get("equipment") is Dictionary:
		var eq_dict: Dictionary = cat_character.get("equipment") as Dictionary
		for item in eq_dict.values():
			if is_instance_valid(item) and item is Resource:
				equipped_items.append(item as Resource)
	elif cat_character.has_method("get_equipped_item"):
		var slots: Array[String] = ["RIGHT_HAND", "LEFT_HAND", "HEAD", "BODY", "ARMS", "LEGS", "FEET", "ACCESSORY_1", "ACCESSORY_2"]
		for slot in slots:
			var item: Resource = cat_character.call("get_equipped_item", slot) as Resource
			if is_instance_valid(item):
				equipped_items.append(item)

	# 2. Extract unique granted_status_effects IDs
	var effect_ids: Array[String] = []
	for item in equipped_items:
		if is_instance_valid(item) and "granted_status_effects" in item:
			var effects: Array = item.get("granted_status_effects") as Array
			for eff_id in effects:
				if eff_id is String and not effect_ids.has(eff_id):
					effect_ids.append(eff_id)

	# 3. Instantiate badge scenes for each granted equipment status effect
	var badge_scene: PackedScene = load("res://Scenes/UI/StatusEffectBadge.tscn")
	for eff_id in effect_ids:
		var info: Dictionary = StatusEffectDatabase.get_effect_info(eff_id)
		if not info.is_empty():
			var badge_inst := badge_scene.instantiate() as StatusEffectBadge
			container.add_child(badge_inst)
			# Pass 0 so equipment status effects are recognized as permanent (no "2t" label)
			badge_inst.setup(info, 0)


# ==============================================================================
# UI FUNCTIONS AND HELPERS
# ==============================================================================
func _on_prev_character_pressed() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound("button-press")
	_navigate_character(-1)


func _on_next_character_pressed() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound("button-press")	
	_navigate_character(1)


func _navigate_character(direction: int) -> void:
	if not GameState.current_party or GameState.current_party.slots.is_empty():
		return

	var valid_characters: Array = GameState.current_party.slots.filter(
		func(c):
			return is_instance_valid(c),
	)

	if valid_characters.is_empty():
		return

	var current_idx: int = valid_characters.find(_current_character)
	if current_idx == -1:
		current_idx = 0

	var next_idx: int = (current_idx + direction + valid_characters.size()) % valid_characters.size()
	var target_character: CatCharacter = valid_characters[next_idx] as CatCharacter

	_current_slot_index = GameState.current_party.slots.find(target_character)
	if "active_character_index" in GameState:
		GameState.active_character_index = _current_slot_index

	_render_character_sheet(target_character)


func _update_paginator() -> void:
	if not GameState.current_party:
		return

	var valid_characters: Array = GameState.current_party.slots.filter(
		func(c):
			return is_instance_valid(c),
	)

	var total_count: int = valid_characters.size()
	var current_pos: int = valid_characters.find(_current_character) + 1 if _current_character in valid_characters else 0

	if index_label:
		index_label.text = "%d | %d" % [current_pos, total_count]

	var can_cycle: bool = total_count > 1
	if prev_character_button:
		prev_character_button.disabled = not can_cycle
	if next_character_button:
		next_character_button.disabled = not can_cycle


func _on_row_toggle_toggled(button_pressed: bool) -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound("button-press")	
	if not is_instance_valid(_current_character) or not GameState.current_party:
		return

	var target_front: bool = not button_pressed

	if not target_front:
		var front_count: int = GameState.current_party.get_front_row_count()
		if front_count <= 1 and _current_character.is_front_row:
			row_toggle_button.set_block_signals(true)
			row_toggle_button.button_pressed = false
			_update_row_button_text(true)
			row_toggle_button.set_block_signals(false)
			var sb: Node = get_tree().root.get_node_or_null("SignalBus")
			if sb and sb.has_signal("show_toast"):
				sb.show_toast.emit("Cannot move: At least 1 party member must be in Front Row!", true)
			return

	GameState.current_party.set_character_row(_current_character, target_front)

	_current_slot_index = GameState.current_party.slots.find(_current_character)
	if "active_character_index" in GameState:
		GameState.active_character_index = _current_slot_index

	_update_row_button_text(target_front)
	_update_paginator()

	if GameState.has_method("save_game"):
		GameState.call("save_game")


func _update_row_button_text(is_front: bool) -> void:
	if not row_toggle_button:
		return

	var bg_color: Color
	if is_front:
		row_toggle_button.text = "⚔️ FRONT ROW"
		bg_color = Color("#00ffc8")
	else:
		row_toggle_button.text = "🛡️ BACK ROW"
		bg_color = Color("#fd6644")

	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = bg_color
	style_box.set_corner_radius_all(4)

	row_toggle_button.add_theme_stylebox_override("normal", style_box)
	row_toggle_button.add_theme_stylebox_override("hover", style_box)
	row_toggle_button.add_theme_stylebox_override("pressed", style_box)


func _on_character_xp_changed(_slot_index: int, _current_xp: int, _max_xp: int) -> void:
	if overlay_panel and overlay_panel.visible:
		var active_cat: CatCharacter = GameState.get_active_cat() as CatCharacter
		if is_instance_valid(active_cat):
			_render_character_sheet(active_cat)


func _on_character_stats_changed(slot_index: int, _current: int, _max: int) -> void:
	if overlay_panel.visible and slot_index == _current_slot_index:
		if is_instance_valid(_current_character):
			_render_character_sheet(_current_character)


func _on_close_button_pressed() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound("button-confirm")
	if overlay_panel:
		overlay_panel.visible = false
	GameState.current_mode = GameState.Mode.EXPLORING
