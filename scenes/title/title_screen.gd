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

# Target the Party Builder button from your scene tree layout
@onready var party_builder_button: Button = $Center/Panel/Margin/VBox/AddCharacter

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

# Active Roster Construction State
var current_party: Array[CatCharacter] = []

func _ready() -> void:
	center_menu.show()
	cat_builder.hide()
	selection_popup.hide()
	
	# Connect your party builder button programmatically to avoid scene corruption
	if party_builder_button:
		party_builder_button.pressed.connect(_on_party_builder_pressed)
		
	_load_resources_from_disk()

## Scans your filesystem for compiled .tres spreadsheet data files
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

# =============================================================================
# ⚔️ PARTY BUILDER ROSTER SELECTION LOOP
# =============================================================================

func _on_party_builder_pressed() -> void:
	# Load every legitimate cat saved inside user:// persistently
	var saved_pool: Array[CatCharacter] = RosterSaveSystem.load_all_characters_from_pool()
	
	if saved_pool.size() == 0:
		# Fallback indicator if the user clicks party builder with zero generated cats
		popup_title.text = "ERROR: POOL EMPTY"
		_clear_options_container()
		var warning_label := Label.new()
		warning_label.text = "Create characters at the Cat Builder first!"
		warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		choices_grid.add_child(warning_label)
		selection_popup.show()
		return
		
	# Present selection screen overlay
	render_party_builder_screen(saved_pool)

## Draws selectable toggle buttons for all characters existing in your user database
func render_party_builder_screen(saved_pool: Array[CatCharacter]) -> void:
	_clear_options_container()
	
	# Dynamic title configuration tracking squad limits (Up to 6)
	popup_title.text = "ASSEMBLE PARTY (" + str(current_party.size()) + "/6)"
	
	for cat in saved_pool:
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Validate active state configuration presence to display text selection decorators
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
			
		# Connect selection event toggle logic programmatically via inline lambdas
		btn.pressed.connect(func(): _toggle_party_member(cat, saved_pool))
		choices_grid.add_child(btn)
		
	# Dynamically append a continuous full-width confirm button beneath the 2-column grid layout
	var confirm_btn := Button.new()
	confirm_btn.text = "CONFIRM ACTIVE ROSTER"
	confirm_btn.name = "DynamicConfirmButton"
	confirm_btn.disabled = current_party.size() == 0
	confirm_btn.pressed.connect(func(): _finalize_party_selection())
	choices_grid.get_parent().add_child(confirm_btn)
	
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
		
	# Redraw the system rows immediately to show real-time dynamic UI checkbox state updates
	render_party_builder_screen(saved_pool)

func _finalize_party_selection() -> void:
	selection_popup.hide()
	_clear_options_container()
	
	print("--- ACTIVE ADVENTURING PARTY LOCKED IN ---")
	for i in range(current_party.size()):
		# Classic row allocation reporting logic (Front vs Back distribution metrics)
		var row_side: String = "FRONT ROW" if i < 3 else "BACK ROW"
		print("Slot ", i, " [", row_side, "]: ", current_party[i].name, " (", current_party[i].profession.profession_name, ")")
		
	# Next architectural phase: Pass current_party into GameState.gd array pool and switch scenes!

# =============================================================================
# 🧬 CHARACTER GENERATION WIZARD PIPELINE
# =============================================================================

func start_character_generation() -> void:
	current_building_cat = CatCharacter.new()
	show_breed_selection()

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
	
	gender_race_label.text = "Space Cat - " + selected_breed.breed_name
	class_label.text = selected_class.profession_name.to_upper()
	level_label.text = "LVL - 1"
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
			
		# Clean up any lingering dynamic confirmation buttons inside the parent VBox Container
		var parent_vbox = choices_grid.get_parent()
		if parent_vbox:
			var dynamic_btn = parent_vbox.get_node_or_null("DynamicConfirmButton")
			if dynamic_btn:
				dynamic_btn.queue_free()
