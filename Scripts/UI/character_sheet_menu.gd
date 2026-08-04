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


func _on_portrait_clicked(slot_index: int) -> void:
	GameState.current_mode = GameState.Mode.MANAGEMENT
	
	if not GameState.current_party or slot_index >= GameState.current_party.slots.size():
		return
		
	var character: CatCharacter = GameState.current_party.slots[slot_index]
	if not is_instance_valid(character):
		return
	
	_render_character_sheet(character)
	overlay_panel.visible = true


func _render_character_sheet(character: CatCharacter) -> void:
	if not is_instance_valid(character): return

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
	if char_name_label: char_name_label.text = character.name.to_upper()
	if breed_label: breed_label.text = character.breed.breed_name.to_upper() if character.breed else "UNKNOWN"
	if hp_val_label: hp_val_label.text = "%d / %d" % [character.current_hp, character.max_hp]
	if energy_val_label: energy_val_label.text = "%d / %d" % [character.current_energy, character.max_energy]
	
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

	if profession_label:
		var prof_title: String = "UNASSIGNED"
		if is_instance_valid(character.profession) and not character.profession.profession_name.is_empty():
			prof_title = character.profession.profession_name
		profession_label.text = prof_title.to_upper()
		
	# 4. Delegate Sub-Panel Displays
	if stats_panel: stats_panel.display_character_stats(character)
	if loadout_panel: loadout_panel.display_loadout(character)
	if inventory_grid and "inventory" in GameState:
		inventory_grid.display_inventory(GameState.inventory)
	if skills_spells_panel: skills_spells_panel.display_character_abilities(character)


func _on_character_xp_changed(_slot_index: int, _current_xp: int, _max_xp: int) -> void:
	if overlay_panel and overlay_panel.visible:
		var active_cat: CatCharacter = GameState.get_active_cat() as CatCharacter
		if is_instance_valid(active_cat):
			_render_character_sheet(active_cat)


func _on_close_button_pressed() -> void:
	if overlay_panel:
		overlay_panel.visible = false
	GameState.current_mode = GameState.Mode.EXPLORING
