extends Control

# Preload your breed row template scene
const BREED_ITEM_SCENE = preload("res://scenes/title/BreedItem.tscn")
const PROFESSION_ITEM_SCENE = preload("res://scenes/title/ProfessionItem.tscn")

# Info boxes
@onready var breed_popup: PanelContainer = %BreedInfoPopup
@onready var list_container: VBoxContainer = %BreedListContainer
@onready var profession_popup: PanelContainer = %ProfessionInfoPopup
@onready var profession_list_container: VBoxContainer = %ProfessionListContainer

# Screen Component Groupings
@onready var center_menu: CenterContainer = $Center
@onready var cat_builder: Control = $CatBuilder
@onready var builder_sheet: MarginContainer = $CatBuilder/MarginContainer

# UI Scene Unique Node Links
@onready var selection_popup: PanelContainer = %SelectionPopup
@onready var popup_title: Label = %PopupTitle
@onready var choices_grid: GridContainer = %ChoicesGrid
@export var breed_button_scene: PackedScene
@export var profession_button_scene: PackedScene

# Left & Right Character Sheet View Nodes
@onready var portrait_frame: TextureRect = $CatBuilder/MarginContainer/HBoxContainer/LeftColumn_Identity/PortraitMetaHBox/PortraitVBox/PortraitFrame
@onready var prev_portrait_btn: Button = $CatBuilder/MarginContainer/HBoxContainer/LeftColumn_Identity/PortraitMetaHBox/PortraitVBox/PortraitNavHBox/PrevPortrait
@onready var next_portrait_btn: Button = $CatBuilder/MarginContainer/HBoxContainer/LeftColumn_Identity/PortraitMetaHBox/PortraitVBox/PortraitNavHBox/NextPortrait
@onready var builder_back_button: Button = $CatBuilder/BuilderBackButton
@onready var breed_info_button: Button = $CatBuilder/BuilderBreedInfoButton
@onready var profession_info_button: Button = $CatBuilder/ProfessionInfoButton

@onready var given_name_edit: LineEdit = %GivenNameEdit
@onready var hp_value: Label = %HPValue
@onready var exp_value: Label = %EXPValue
@onready var gender_race_label: Label = %GenderRaceLabel
@onready var class_label: Label = %ClassLabel
@onready var level_label: Label = %LevelLabel
@onready var stats_container: VBoxContainer = %StatsContainer
@onready var hint_label: Label = $Center/Panel/Margin/VBox/Hint

# Target the Party Builder button from your scene tree layout
@onready var party_builder_button: Button = $Center/Panel/Margin/VBox/AddCharacter

# LFG
@onready var start_button: Button = $Center/Panel/Margin/VBox/StartButton

# Configuration Paths
const CLASSES_DIR: String = "res://Data/Classes/"
const BREEDS_DIR: String = "res://Data/Races/"
const PORTRAITS_DIR: String = "res://Data/Portraits/"

# In-Memory Storage Arrays
var available_classes: Array[ProfessionData] = []
var available_breeds: Array[CatBreed] = []
var available_portraits: Array[String] = []

# Character Builder Temporary Allocation State
var current_building_cat: CatCharacter = null
var selected_breed: CatBreed = null
var selected_class: ProfessionData = null
var current_portrait_index: int = 0

var bonus_pool: int = 0
var allocated_stats: Dictionary = {
	"strength": 0,
	"intelligence": 0,
	"piety": 0,
	"vitality": 0,
	"dexterity": 0,
	"speed": 0,
	"personality": 0
}

# Active Roster Construction State
var current_party: Array[CatCharacter] = []

func _ready() -> void:
	center_menu.show()
	cat_builder.hide()
	selection_popup.hide()
	
	if party_builder_button:
		party_builder_button.pressed.connect(_on_party_builder_pressed)
		
	if prev_portrait_btn:
		prev_portrait_btn.pressed.connect(_on_prev_portrait_pressed)
	if next_portrait_btn:
		next_portrait_btn.pressed.connect(_on_next_portrait_pressed)
		
	if builder_back_button:
		builder_back_button.pressed.connect(_on_builder_back_pressed)
		
	if breed_info_button:
		breed_info_button.pressed.connect(_on_builder_breed_info_pressed)
		
	if profession_info_button:
		profession_info_button.pressed.connect(_on_builder_profession_info_pressed)
	
	if start_button:
		start_button.pressed.connect(_on_start_game_pressed)
		
	_load_resources_from_disk()

## Scans your filesystem for compiled .tres spreadsheet data files and portrait PNGs
func _load_resources_from_disk() -> void:
	available_classes.clear()
	available_breeds.clear()
	available_portraits.clear()

	# Load Professions
	if DirAccess.dir_exists_absolute(CLASSES_DIR):
		var dir := DirAccess.open(CLASSES_DIR)
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res := ResourceLoader.load(CLASSES_DIR + file_name) as ProfessionData
				if res: available_classes.append(res)
			file_name = dir.get_next()

	# Load Breeds
	if DirAccess.dir_exists_absolute(BREEDS_DIR):
		var dir := DirAccess.open(BREEDS_DIR)
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res := ResourceLoader.load(BREEDS_DIR + file_name) as CatBreed
				if res: available_breeds.append(res)
			file_name = dir.get_next()

	# Load Portraits (Supports both local assets and production builds)
	if DirAccess.dir_exists_absolute(PORTRAITS_DIR):
		var dir := DirAccess.open(PORTRAITS_DIR)
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".png") or file_name.ends_with(".png.remap")):
				var base_file: String = file_name.replace(".remap", "")
				var full_path: String = PORTRAITS_DIR + base_file
				if not available_portraits.has(full_path):
					available_portraits.append(full_path)
			file_name = dir.get_next()
			
	print("Asset Loading Complete: Found ", available_breeds.size(), " Breeds, ", available_classes.size(), " Classes, and ", available_portraits.size(), " Custom Portraits.")

func _on_create_character_pressed() -> void:
	center_menu.hide()
	cat_builder.show()
	builder_sheet.show()
	
	# Forcefully restore visibility to all builder side-controls 
	# so they are never accidentally left invisible by the error checker!
	if builder_back_button: builder_back_button.show()
	if breed_info_button: breed_info_button.show()
	if profession_info_button: profession_info_button.show()
	
	start_character_generation()

# =============================================================================
# 🖼️ PORTRAIT VIEWER CYCLE NAVIGATION
# =============================================================================

func _on_prev_portrait_pressed() -> void:
	if available_portraits.size() == 0: return
	current_portrait_index = (current_portrait_index - 1 + available_portraits.size()) % available_portraits.size()
	_update_portrait_display()

func _on_next_portrait_pressed() -> void:
	if available_portraits.size() == 0: return
	current_portrait_index = (current_portrait_index + 1) % available_portraits.size()
	_update_portrait_display()

func _update_portrait_display() -> void:
	if available_portraits.size() > 0 and current_portrait_index < available_portraits.size():
		var texture_resource = load(available_portraits[current_portrait_index])
		if texture_resource:
			portrait_frame.texture = texture_resource

# =============================================================================
# ⚔️ PARTY BUILDER ROSTER SELECTION LOOP
# =============================================================================

func _on_party_builder_pressed() -> void:
	var saved_pool: Array[CatCharacter] = RosterSaveSystem.load_all_characters_from_pool()
	
	center_menu.hide()
	cat_builder.show()
	builder_sheet.hide()
	builder_back_button.hide() # Hide floating cancel button while building party
	
	if saved_pool.size() == 0:
		popup_title.text = "ERROR: POOL EMPTY"
		_clear_options_container()
		var warning_label := Label.new()
		warning_label.text = "Create characters at the Cat Builder first!"
		warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		choices_grid.add_child(warning_label)
		selection_popup.show()
		return
		
	render_party_builder_screen(saved_pool)

func render_party_builder_screen(saved_pool: Array[CatCharacter]) -> void:
	_clear_options_container()
	popup_title.text = "ASSEMBLE PARTY (" + str(current_party.size()) + "/6)"
	
	for cat in saved_pool:
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var is_selected: bool = false
		for member in current_party:
			if member.name == cat.name:
				is_selected = true
				break
				
		var prof_name: String = cat.profession.profession_name if cat.profession else "No Class"
		if is_selected:
			btn.text = " [X] " + cat.name + " (" + prof_name + ")"
			btn.add_theme_color_override("font_color", Color.GREEN)
		else:
			btn.text = " [ ] " + cat.name + " (" + prof_name + ")"
			
		btn.pressed.connect(func(): _toggle_party_member(cat, saved_pool))
		choices_grid.add_child(btn)
		
	var parent_vbox = choices_grid.get_parent()
	
	# Since names are scrubbed above, this will reliably build a fresh button every frame
	var confirm_btn = Button.new()
	confirm_btn.text = "CONFIRM ACTIVE ROSTER"
	confirm_btn.name = "DynamicConfirmButton"
	confirm_btn.pressed.connect(func(): _finalize_party_selection())
	parent_vbox.add_child(confirm_btn)
		
	# FIXED LOGIC: Button stays visible, but is grayed out until at least 1 cat is ready
	confirm_btn.disabled = (current_party.size() == 0)
	
	var back_btn = Button.new()
	back_btn.text = "BACK TO MAIN MENU"
	back_btn.name = "DynamicBackButton"
	back_btn.add_theme_color_override("font_color", Color(0.87, 0.13, 0.32))
	back_btn.pressed.connect(func(): _on_party_builder_back_pressed())
	parent_vbox.add_child(back_btn)
	
	selection_popup.show()

func _toggle_party_member(cat: CatCharacter, saved_pool: Array[CatCharacter]) -> void:
	var index_to_remove: int = -1
	for i in range(current_party.size()):
		if current_party[i].name == cat.name:
			index_to_remove = i
			break
			
	if index_to_remove != -1:
		current_party.remove_at(index_to_remove)
	elif current_party.size() < 6:
		current_party.append(cat)
		
	render_party_builder_screen(saved_pool)

func _on_party_builder_back_pressed() -> void:
	selection_popup.hide()
	cat_builder.hide()
	
	var parent_vbox = choices_grid.get_parent()
	if parent_vbox:
		var confirm_btn = parent_vbox.get_node_or_null("DynamicConfirmButton")
		if confirm_btn: confirm_btn.queue_free()
		var back_btn = parent_vbox.get_node_or_null("DynamicBackButton")
		if back_btn: back_btn.queue_free()
			
	_clear_options_container()
	center_menu.show()

func _finalize_party_selection() -> void:
	selection_popup.hide()
	cat_builder.hide()
	
	var parent_vbox = choices_grid.get_parent()
	if parent_vbox:
		var confirm_btn = parent_vbox.get_node_or_null("DynamicConfirmButton")
		if confirm_btn: confirm_btn.queue_free()
		var back_btn = parent_vbox.get_node_or_null("DynamicBackButton")
		if back_btn: back_btn.queue_free()
			
	_clear_options_container()
	center_menu.show()
	
	# --- FIXED: DYNAMIC HINT TEXT UPDATER ---
	if hint_label:
		if current_party.size() > 0:
			# Format the string with the current array size
			hint_label.text = "Party Active | %d / 6 Cats Ready" % current_party.size()
			
			# Change color to matching UI neon teal/cyan to show success state
			hint_label.add_theme_color_override("font_color", Color(0.215, 1.0, 0.811, 1))
		else:
			# Fallback default if they remove all members from their party roster
			hint_label.text = "You must add at least 1 member to begin.\nAlso try not to die."
			
			# Revert color back to the initial warn yellow
			hint_label.add_theme_color_override("font_color", Color(0.992, 0.988, 0, 1))
	
	print("--- ACTIVE ADVENTURING PARTY LOCKED IN ---")
	for i in range(current_party.size()):
		var row_side: String = "FRONT ROW" if i < 3 else "BACK ROW"
		print("Slot ", i, " [", row_side, "]: ", current_party[i].name, " (", current_party[i].profession.profession_name, ")")
		
# =============================================================================
# ⚔️ START GAME / LOAD GAME
# =============================================================================
# Triggered when players click the "Start Game" button
func _on_start_game_pressed() -> void:
	# Check if the party array contains zero members
	if current_party.is_empty():
		# 1. Canvas Visibility Setup
		center_menu.hide()
		cat_builder.show()
		builder_sheet.hide() 
		
		# 2. FIXED: Explicitly hide the loose side buttons so they don't leak onto the screen
		if builder_back_button: builder_back_button.hide()
		if breed_info_button: breed_info_button.hide()
		if profession_info_button: profession_info_button.hide()
		
		popup_title.text = "ROSTER UNASSEMBLED"
		_clear_options_container()
		
		# Get the parent VBox container of the popup layout
		var parent_vbox = choices_grid.get_parent()
		
		# 3. FIXED: Add the label directly to the VBox instead of the 2-column ChoicesGrid
		var error_label := Label.new()
		error_label.name = "DynamicErrorLabel" # Named so we can clean it up safely later
		error_label.text = "Your party is empty! You must deploy at least 1 Space Cat Wizard using the Party Builder before launching your campaign."
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		error_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Insert it right into the main vertical layout stack
		parent_vbox.add_child(error_label)
		
		# 4. Inject a temporary Dismiss button into the popup structure
		var dismiss_btn: Button = parent_vbox.get_node_or_null("DynamicDismissButton") as Button
		if not dismiss_btn:
			dismiss_btn = Button.new()
			dismiss_btn.text = "UNDERSTOOD"
			dismiss_btn.name = "DynamicDismissButton"
			
			# Clean up visibility states and remove dynamic elements when returning to the main menu
			dismiss_btn.pressed.connect(func():
				selection_popup.hide()
				cat_builder.hide()  
				center_menu.show()  
				_clear_options_container()
				
				# Garbage collection: delete the dynamic error label and button from memory
				if parent_vbox.has_node("DynamicErrorLabel"):
					parent_vbox.get_node("DynamicErrorLabel").queue_free()
				if parent_vbox.has_node("DynamicDismissButton"):
					parent_vbox.get_node("DynamicDismissButton").queue_free()
			)
			parent_vbox.add_child(dismiss_btn)
			
		selection_popup.show()
		print("Launch aborted: Player attempted to deploy with an empty party.")
		
	else:
		# Success branch: Transition to your primary gameplay canvas
		print("Launch successful! Transitioning with a deployment of ", current_party.size(), " cats.")
		
		# 1. Map chosen cats directly into the global persistent 6-slot party setup
		for i in range(6):
			if i < current_party.size():
				var character: CatCharacter = current_party[i]
				# Initialize resource statistics (HP/MP calculations from breed) if not done yet
				if character.has_method("initialize_stats"):
					character.initialize_stats()
				
				GameState.set_party_slot(i, character)
			else:
				# Ensure remaining slots are explicitly cleared out if running a partial party
				GameState.set_party_slot(i, null)
		
		# 2. Perform a type-safe scene change transition with strict string conversion
		var scene_path: String = "res://scenes/main_gameplay.tscn"
		
		# Verify file existence before even trying to load it
		if not FileAccess.file_exists(scene_path):
			print("❌ CRITICAL: The file path '" + scene_path + "' does not exist! Check your folder capitalization (e.g., 'Scenes' vs 'scenes').")
			return
			
		var change_err: Error = get_tree().change_scene_to_file(scene_path)
		
		if change_err != OK:
			print("❌ SCENE TRANSITION FAILED: ", error_string(change_err))
			push_error("Critical Core Engine failure: Could not load gameplay scene. Error Code: %d" % change_err)
		
# =============================================================================
# 🧬 CHARACTER GENERATION WIZARD PIPELINE
# =============================================================================

func start_character_generation() -> void:
	current_building_cat = CatCharacter.new()
	current_portrait_index = 0
	_update_portrait_display()
	show_breed_selection()

func _on_builder_profession_info_pressed() -> void:
	# 1. Clear any old entries out of the container so they don't stack up
	if profession_list_container:
		for child in profession_list_container.get_children():
			child.queue_free()
	else:
		print("❌ Error: profession_list_container is null!")
		return

	# 2. Open the CSV file and read data
	var file = FileAccess.open("res://Character_Races_Professions.csv", FileAccess.READ)
	if not file:
		print("⚠️ Error: Could not find or open 'res://Character_Races_Professions.csv'")
		return

	# Skip the CSV header row
	if not file.eof_reached():
		file.get_csv_line()

	# Define the scene path for your Profession items
	var profession_item_scene_path = "res://scenes/title/ProfessionItem.tscn"
	
	if not ResourceLoader.exists(profession_item_scene_path):
		print("❌ Error: Cannot find ProfessionItem.tscn at path: ", profession_item_scene_path)
		if profession_popup: profession_popup.show()
		return

	var row_scene = load(profession_item_scene_path)

	# 3. Loop through rows and parse data
	while not file.eof_reached():
		var line = file.get_csv_line()
		# Make sure row is complete (The professions file contains 16 total metadata columns)
		if line.size() < 16:
			continue 

		# Correct Column Mappings based on your CSV structure
		var prof_name = line[1]
		var based_on = line[2]
		
		# Stats map to indices 3 through 9
		var stats_string = "REQ -> STR: %s | INT: %s | PIE: %s | VIT: %s | DEX: %s | SPD: %s | PER: %s" % [
			line[3], line[4], line[5], line[6], line[7], line[8], line[9]
		]
		
		# Build an informative multi-line block using the mechanics and combat columns
		var description_text = "FEATURES: %s\n\nWEAPONRY: %s" % [line[15], line[12]]
		
		# If the class features custom magic systems, include them at the bottom
		if line[10] != "None":
			description_text += "\n\nMAGIC TYPE: %s (%s)" % [line[10], line[11]]

		# Instantiate a new card row into the CORRECT container
		var item = row_scene.instantiate()
		profession_list_container.add_child(item)
		
		# Populate text labels matching your ProfessionItem structure
		item.get_node("HBoxContainer/VBoxContainer/ProfessionName").text = prof_name + " (Class Archetype: " + based_on + ")"
		item.get_node("HBoxContainer/VBoxContainer/Description").text = description_text
		item.get_node("HBoxContainer/VBoxContainer/Stats").text = stats_string
		
		# Layout Adjustment: Force expansion so formatting doesn't squeeze up
		item.get_node("HBoxContainer/VBoxContainer").size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Asset / Image Location resolution
		var img_path = "res://ui/" + prof_name.to_lower().replace(" ", "_") + ".png"
		var texture_rect = item.get_node("HBoxContainer/BreedImage")
		
		if texture_rect:
			texture_rect.custom_minimum_size = Vector2(96, 96)
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			if ResourceLoader.exists(img_path):
				texture_rect.texture = load(img_path)
			else:
				texture_rect.texture = load("res://ui/portrait.png") # Standard placeholder fallback

	# 4. Finally, reveal the popup view
	if profession_popup:
		profession_popup.show()
		
# Triggered when the BREED INFO button is pressed
func _on_builder_breed_info_pressed() -> void:
	# 1. Clear any old entries out of the container so they don't stack up
	if list_container:
		for child in list_container.get_children():
			child.queue_free()
	else:
		print("Error: list_container is null!")
		return

	# 2. Open the CSV file and read data
	var file = FileAccess.open("res://Character_Races_Races.csv", FileAccess.READ)
	if not file:
		print("Error: Could not open Character_Races_Races.csv")
		return

	# Skip the CSV header row
	if not file.eof_reached():
		file.get_csv_line()

	# Loop through the rows
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 11:
			continue # Skip empty or malformed rows

		var race_name = line[1]
		var based_on = line[2]
		var description = line[3]
		var stats_string = "STR: %s | INT: %s | PIE: %s | VIT: %s | DEX: %s | SPD: %s | PER: %s" % [
			line[4], line[5], line[6], line[7], line[8], line[9], line[10]
		]

		# Only build rows if you have created BreedItem.tscn
		if ResourceLoader.exists("res://scenes/title/BreedItem.tscn"):
			var row_scene = load("res://scenes/title/BreedItem.tscn")
			var item = row_scene.instantiate()
			list_container.add_child(item)
			
			# Populate text nodes (Make sure these paths match BreedItem.tscn layout)
			item.get_node("HBoxContainer/VBoxContainer/RaceName").text = race_name + " (Based on: " + based_on + ")"
			item.get_node("HBoxContainer/VBoxContainer/Description").text = description
			item.get_node("HBoxContainer/VBoxContainer/Stats").text = stats_string
			
			# Image Fallback handling
			var img_path = "res://ui/" + race_name.to_lower().replace(" ", "_") + ".png"
			var texture_rect = item.get_node("HBoxContainer/BreedImage")
			if ResourceLoader.exists(img_path):
				texture_rect.texture = load(img_path)
			else:
				texture_rect.texture = load("res://ui/portrait.png") # Fallback to your default cat frame

	# 3. Finally, show the popup window overlay
	if breed_popup:
		breed_popup.show()

# Triggered when the CLOSE LORE BOOK button is pressed
func _on_breed_info_close_button_pressed() -> void:
	if breed_popup:
		breed_popup.hide()

func _on_builder_back_pressed() -> void:
	selection_popup.hide()
	cat_builder.hide()
	_clear_options_container()
	
	for child in stats_container.get_children():
		child.queue_free()
		
	current_building_cat = null
	center_menu.show()
	print("Character creation cancelled by player.")

func show_breed_selection() -> void:
	popup_title.text = "SELECT CAT BREED"
	_clear_options_container()

	for breed in available_breeds:
		var btn = breed_button_scene.instantiate() as Button
		btn.text = breed.breed_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func(): _on_breed_chosen(breed))
		choices_grid.add_child(btn)

	selection_popup.show()

func _on_breed_chosen(breed: CatBreed) -> void:
	selected_breed = breed
	current_building_cat.breed = breed
	show_profession_selection()

func show_profession_selection() -> void:
	popup_title.text = "SELECT CLASS PROFESSION"
	_clear_options_container()

	for prof in available_classes:
		var btn := Button.new()
		btn.text = prof.profession_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func(): _on_profession_chosen(prof))
		choices_grid.add_child(btn)

	selection_popup.show()

func _on_profession_info_close_button_pressed() -> void:
	if profession_popup:
		profession_popup.hide()
		
func _on_profession_chosen(prof: ProfessionData) -> void:
	selected_class = prof
	current_building_cat.profession = prof
	selection_popup.hide()
	setup_stat_allocation_phase()

func setup_stat_allocation_phase() -> void:
	for key in allocated_stats.keys():
		allocated_stats[key] = 0
		
	var entry_cost: int = 0
	entry_cost += max(0, selected_class.req_strength - selected_breed.base_strength)
	entry_cost += max(0, selected_class.req_intelligence - selected_breed.base_intelligence)
	entry_cost += max(0, selected_class.req_piety - selected_breed.base_piety)
	entry_cost += max(0, selected_class.req_vitality - selected_breed.base_vitality)
	entry_cost += max(0, selected_class.req_dexterity - selected_breed.base_dexterity)
	entry_cost += max(0, selected_class.req_speed - selected_breed.base_speed)
	entry_cost += max(0, selected_class.req_personality - selected_breed.base_personality)
	
	var base_roll: int = randi_range(12, 24)
	bonus_pool = max(base_roll - entry_cost, randi_range(6, 12))
	
	gender_race_label.text = "M - " + selected_breed.breed_name
	class_label.text = selected_class.profession_name.to_upper()
	level_label.text = "LEVEL | 1"
	exp_value.text = "00/400"
	given_name_edit.text = ""
	
	_update_dynamic_hp_label()
	render_stat_allocation_screen()

func render_stat_allocation_screen() -> void:
	for child in stats_container.get_children():
		child.queue_free()
		
	var pool_label := Label.new()
	pool_label.text = "UNALLOCATED BONUS POINTS: " + str(bonus_pool)
	pool_label.add_theme_color_override("font_color", Color.YELLOW if bonus_pool > 0 else Color.DARK_GRAY)
	stats_container.add_child(pool_label)
	
	var stat_keys = ["strength", "intelligence", "piety", "vitality", "dexterity", "speed", "personality"]
	for stat in stat_keys:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		
		var name_label := Label.new()
		name_label.text = stat.to_upper().rpad(12)
		name_label.custom_minimum_size = Vector2(130, 0)
		hbox.add_child(name_label)
		
		var btn_minus := Button.new()
		btn_minus.text = " - "
		btn_minus.disabled = allocated_stats[stat] == 0
		btn_minus.pressed.connect(func(): _modify_allocated_stat(stat, -1))
		hbox.add_child(btn_minus)
		
		var value_label := Label.new()
		var display_val: int = _get_base_stat_requirement(stat) + allocated_stats[stat]
		value_label.text = " " + str(display_val) + " "
		value_label.custom_minimum_size = Vector2(30, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(value_label)
		
		var btn_plus := Button.new()
		btn_plus.text = " + "
		btn_plus.disabled = bonus_pool == 0
		btn_plus.pressed.connect(func(): _modify_allocated_stat(stat, 1))
		hbox.add_child(btn_plus)
		
		stats_container.add_child(hbox)
		
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	stats_container.add_child(spacer)
	
	var btn_save := Button.new()
	btn_save.text = "REGISTER COMPLETED CHARACTER"
	btn_save.pressed.connect(func(): _on_finalize_registration_pressed())
	stats_container.add_child(btn_save)

func _modify_allocated_stat(stat_name: String, amount: int) -> void:
	allocated_stats[stat_name] += amount
	bonus_pool -= amount
	_update_dynamic_hp_label()
	render_stat_allocation_screen()

func _update_dynamic_hp_label() -> void:
	var current_vit: int = _get_base_stat_requirement("vitality") + allocated_stats["vitality"]
	var calc_hp: int = 0
	if selected_class and selected_class.profession_name in ["Spartan", "Crusader", "Amazon"]:
		calc_hp = current_vit * 3
	else:
		calc_hp = current_vit * 2
	hp_value.text = str(calc_hp) + "/" + str(calc_hp)

func _get_base_stat_requirement(stat_name: String) -> int:
	var breed_val: int = 0
	var req_val: int = 0
	match stat_name:
		"strength": breed_val = selected_breed.base_strength; req_val = selected_class.req_strength
		"intelligence": breed_val = selected_breed.base_intelligence; req_val = selected_class.req_intelligence
		"piety": breed_val = selected_breed.base_piety; req_val = selected_class.req_piety
		"vitality": breed_val = selected_breed.base_vitality; req_val = selected_class.req_vitality
		"dexterity": breed_val = selected_breed.base_dexterity; req_val = selected_class.req_dexterity
		"speed": breed_val = selected_breed.base_speed; req_val = selected_class.req_speed
		"personality": breed_val = selected_breed.base_personality; req_val = selected_class.req_personality
	return max(breed_val, req_val)

func _on_finalize_registration_pressed() -> void:
	if given_name_edit.has_focus():
		given_name_edit.release_focus()
		
	var entered_name: String = given_name_edit.text.strip_edges()
	if entered_name == "":
		entered_name = "Space Cat Rec" + str(randi_range(100, 999))
		
	current_building_cat.name = entered_name
	current_building_cat.breed = selected_breed
	current_building_cat.profession = selected_class
	
	if available_portraits.size() > 0:
		current_building_cat.portrait_path = available_portraits[current_portrait_index]
	
	var finalized_stats := {
		"strength": _get_base_stat_requirement("strength") + allocated_stats["strength"],
		"intelligence": _get_base_stat_requirement("intelligence") + allocated_stats["intelligence"],
		"piety": _get_base_stat_requirement("piety") + allocated_stats["piety"],
		"vitality": _get_base_stat_requirement("vitality") + allocated_stats["vitality"],
		"dexterity": _get_base_stat_requirement("dexterity") + allocated_stats["dexterity"],
		"speed": _get_base_stat_requirement("speed") + allocated_stats["speed"],
		"personality": _get_base_stat_requirement("personality") + allocated_stats["personality"]
	}
	
	current_building_cat.assemble_character(finalized_stats)
	RosterSaveSystem.save_character_to_pool(current_building_cat)
	
	for child in stats_container.get_children():
		child.queue_free()
	cat_builder.hide()
	center_menu.show()

# =============================================================================
# 🧹 UI CLEANUP CLEANERS
# =============================================================================

func _clear_options_container() -> void:
	if choices_grid:
		for child in choices_grid.get_children():
			child.queue_free()
			
		var parent_vbox = choices_grid.get_parent()
		if parent_vbox:
			# Change names to prevent 'get_node' from seeing them while they die
			var dynamic_btn = parent_vbox.get_node_or_null("DynamicConfirmButton")
			if dynamic_btn:
				dynamic_btn.name = "DELETING_CONFIRM"
				dynamic_btn.queue_free()
				
			var dynamic_back = parent_vbox.get_node_or_null("DynamicBackButton")
			if dynamic_back:
				dynamic_back.name = "DELETING_BACK"
				dynamic_back.queue_free()
