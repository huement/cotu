# res://Scripts/UI/character_sheet_menu.gd
extends CanvasLayer
class_name CharacterSheetMenu

@onready var overlay_panel: Control = %OverlayPanel as Control
@onready var stats_panel: CharacterStatsPanel = %CharacterStatsPanel as CharacterStatsPanel
@onready var loadout_panel: CharacterLoadoutPanel = %CharacterLoadoutPanel as CharacterLoadoutPanel
@onready var inventory_grid: CharacterInventoryGrid = %CharacterInventoryGrid as CharacterInventoryGrid
@onready var char_name_label: Label = %CharNameLabel as Label
@onready var breed_label: Label = %BreedLabel as Label
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
		
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

func _on_portrait_clicked(slot_index: int) -> void:
	GameState.current_mode = GameState.Mode.MANAGEMENT
	
	if not GameState.current_party or slot_index >= GameState.current_party.slots.size():
		return
		
	var character: CatCharacter = GameState.current_party.slots[slot_index]
	if not is_instance_valid(character):
		return
	
	# 🖼️ LOAD PORTRAIT FROM EXISTING portrait_path
	if portrait_texture:
		var tex: Texture2D = null
		
		# 1. Primary: Load texture string from CatCharacter.portrait_path
		if "portrait_path" in character and not str(character.portrait_path).is_empty():
			if ResourceLoader.exists(character.portrait_path):
				tex = load(character.portrait_path) as Texture2D
		# 2. Fallback: Direct Texture2D reference if used
		elif "portrait" in character and character.portrait is Texture2D:
			tex = character.portrait
		# 3. Fallback: CatBreed portrait path
		elif character.breed and "portrait_path" in character.breed and not str(character.breed.portrait_path).is_empty():
			if ResourceLoader.exists(character.breed.portrait_path):
				tex = load(character.breed.portrait_path) as Texture2D

		portrait_texture.texture = tex
			
	# Update Left Identity Column
	if char_name_label: char_name_label.text = character.name.to_upper()
	if breed_label: breed_label.text = character.breed.breed_name.to_upper() if character.breed else "UNKNOWN BREED"
	if hp_val_label: hp_val_label.text = "%d / %d" % [character.current_hp, character.max_hp]
	if energy_val_label: energy_val_label.text = "%d / %d" % [character.current_energy, character.max_energy]
	
	# Delegate Sub-Panel Displays
	if stats_panel:
		stats_panel.display_character_stats(character)
		
	if loadout_panel:
		loadout_panel.display_loadout(character)
		
	if inventory_grid:
		# The inventory is shared across the party, so we always source it from the global GameState.
		if "inventory" in get_tree().root.get_node("GameState"):
			var global_inventory: Inventory = get_tree().root.get_node("GameState").inventory
			inventory_grid.display_inventory(global_inventory)
		
	overlay_panel.visible = true

func _on_close_button_pressed() -> void:
	if overlay_panel:
		overlay_panel.visible = false
	GameState.current_mode = GameState.Mode.EXPLORING
