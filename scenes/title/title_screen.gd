extends Control

# Screen Component Groupings
@onready var center_menu: CenterContainer = $Center
@onready var cat_builder: Control = $CatBuilder

# UI Scene Unique Node Links
@onready var selection_popup: PanelContainer = %SelectionPopup
@onready var popup_title: Label = %PopupTitle
@onready var choices_grid: GridContainer = %ChoicesGrid

# Left & Right Character Sheet View Nodes
@onready var given_name_edit: LineEdit = %GivenNameEdit
@onready var hp_value: Label = %HPValue
@onready var exp_value: Label = %EXPValue
@onready var gender_race_label: Label = %GenderRaceLabel
@onready var class_label: Label = %ClassLabel
@onready var level_label: Label = %LevelLabel
@onready var stats_container: VBoxContainer = %StatsContainer

# Configuration Paths
const CLASSES_DIR: String = "res://Data/Classes/"
const BREEDS_DIR: String = "res://Data/Races/"

# In-Memory Storage Arrays
var available_classes: Array[ProfessionData] = []
var available_breeds: Array[CatBreed] = []

# Character Builder Temporary Allocation State
var current_building_cat: CatCharacter = null
var selected_breed: CatBreed = null
var selected_class: ProfessionData = null

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

func _ready() -> void:
	center_menu.show()
	cat_builder.hide()
	selection_popup.hide()
	_load_resources_from_disk()

## Scans your filesystem for compiled .tres files
func _load_resources_from_disk() -> void:
	available_classes.clear()
	available_breeds.clear()

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

func _on_create_character_pressed() -> void:
	center_menu.hide()
	cat_builder.show()
	start_character_generation()

## Phase 1: Begins the creation wizard sequence
func start_character_generation() -> void:
	current_building_cat = CatCharacter.new()
	show_breed_selection()

## Phase 2: Populates the popup container with Breed data
func show_breed_selection() -> void:
	popup_title.text = "SELECT CAT BREED"
	_clear_options_container()

	for breed in available_breeds:
		var btn := Button.new()
		btn.text = breed.breed_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func(): _on_breed_chosen(breed))
		choices_grid.add_child(btn)

	selection_popup.show()

func _on_breed_chosen(breed: CatBreed) -> void:
	selected_breed = breed
	current_building_cat.breed = breed
	show_profession_selection()

## Phase 3: Populates the popup container with your Class data
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

func _on_profession_chosen(prof: ProfessionData) -> void:
	selected_class = prof
	current_building_cat.profession = prof
	selection_popup.hide()
	
	# Proceed directly to Point Allocation & Naming instead of exiting!
	setup_stat_allocation_phase()

## Phase 4: Calculate entry requirements and prepare allocation screen rows
func setup_stat_allocation_phase() -> void:
	# Reset old manual adjustments
	for key in allocated_stats.keys():
		allocated_stats[key] = 0
		
	# Calculate structural gate cost completely programmatically
	var entry_cost: int = 0
	entry_cost += max(0, selected_class.req_strength - selected_breed.base_strength)
	entry_cost += max(0, selected_class.req_intelligence - selected_breed.base_intelligence)
	entry_cost += max(0, selected_class.req_piety - selected_breed.base_piety)
	entry_cost += max(0, selected_class.req_vitality - selected_breed.base_vitality)
	entry_cost += max(0, selected_class.req_dexterity - selected_breed.base_dexterity)
	entry_cost += max(0, selected_class.req_speed - selected_breed.base_speed)
	entry_cost += max(0, selected_class.req_personality - selected_breed.base_personality)
	
	# Roll a random pool of bonus points (e.g. 10 to 25 points).
	# Guarantee players always have at least a handful of spare leftover points to spend!
	var base_roll: int = randi_range(12, 24)
	bonus_pool = max(base_roll - entry_cost, randi_range(6, 12))
	
	# Populate Left UI Panels
	gender_race_label.text = "Space Cat - " + selected_breed.breed_name
	class_label.text = selected_class.profession_name.to_upper()
	level_label.text = "LVL - 1"
	exp_value.text = "00/400"
	given_name_edit.text = ""
	
	_update_dynamic_hp_label()
	render_stat_allocation_screen()

## Renders stat lines with spendable '+' and '-' buttons directly in your container
func render_stat_allocation_screen() -> void:
	for child in stats_container.get_children():
		child.queue_free()
		
	# Unspent points header display row
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
		
		# Minus Button component
		var btn_minus := Button.new()
		btn_minus.text = " - "
		btn_minus.disabled = allocated_stats[stat] == 0
		btn_minus.pressed.connect(func(): _modify_allocated_stat(stat, -1))
		hbox.add_child(btn_minus)
		
		# Calculated current attribute total value display
		var value_label := Label.new()
		var display_val: int = _get_base_stat_requirement(stat) + allocated_stats[stat]
		value_label.text = " " + str(display_val) + " "
		value_label.custom_minimum_size = Vector2(30, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(value_label)
		
		# Plus Button component
		var btn_plus := Button.new()
		btn_plus.text = " + "
		btn_plus.disabled = bonus_pool == 0
		btn_plus.pressed.connect(func(): _modify_allocated_stat(stat, 1))
		hbox.add_child(btn_plus)
		
		stats_container.add_child(hbox)
		
	# Finalize Button hook placement at the bottom of the column layout
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
	if selected_class.profession_name in ["Spartan", "Crusader", "Amazon"]:
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

## Phase 5: Gathers custom naming text strings and saves data back to state managers
func _on_finalize_registration_pressed() -> void:
	var entered_name: String = given_name_edit.text.strip_edges()
	if entered_name == "":
		entered_name = "Meowmer the Brave" # Fallback security value
		
	current_building_cat.name = entered_name
	current_building_cat.breed = selected_breed
	current_building_cat.profession = selected_class
	
	var finalized_stats := {
		"strength": _get_base_stat_requirement("strength") + allocated_stats["strength"],
		"intelligence": _get_base_stat_requirement("intelligence") + allocated_stats["intelligence"],
		"piety": _get_base_stat_requirement( "piety") + allocated_stats["piety"],
		"vitality": _get_base_stat_requirement("vitality") + allocated_stats["vitality"],
		"dexterity": _get_base_stat_requirement("dexterity") + allocated_stats["dexterity"],
		"speed": _get_base_stat_requirement("speed") + allocated_stats["speed"],
		"personality": _get_base_stat_requirement("personality") + allocated_stats["personality"]
	}
	
	current_building_cat.assemble_character(finalized_stats)
	
	print("SUCCESS: Fully Registered '", current_building_cat.name, "' (HP: ", current_building_cat.max_hp, ")")
	
	# Clear layout panel views and slide back to the home screen menu loop
	for child in stats_container.get_children():
		child.queue_free()
	cat_builder.hide()
	center_menu.show()

func _clear_options_container() -> void:
	if choices_grid:
		for child in choices_grid.get_children():
			child.queue_free()
