# res://Core/GameState.gd
extends Node
class_name CoreGameState

enum Mode { EXPLORING, BATTLE, MANAGEMENT }

signal core_state_changed(new_mode: Mode)

const SAVE_PATH: String = "user://save_game.tres"

var current_mode: Mode = Mode.EXPLORING:
	set(value):
		if current_mode != value:
			current_mode = value
			core_state_changed.emit(current_mode)

@export var current_party: DungeonParty
@export var inventory: Inventory = Inventory.new()
@export var current_floor_id: int = 1
var active_character_index: int = 0


## Returns the currently selected Space Cat resource from the active 6-slot party
func get_active_cat() -> Resource:
	if current_party != null:
		var party_slots: Array = current_party.get("slots") as Array
		if party_slots != null and active_character_index >= 0 and active_character_index < party_slots.size():
			return party_slots[active_character_index] as Resource
	return null


func _ready() -> void:
	_initialize_active_session()


func _initialize_active_session() -> void:
	print("GameState: Assembling tactical data structures...")
	
	if ResourceLoader.exists(SAVE_PATH):
		if not load_game():
			print("GameState: Save file invalid. Rebuilding default starter party...")
			_build_default_starter_party()
			save_game()
	else:
		print("GameState: No save file found. Building default starter party...")
		_build_default_starter_party()
		save_game()


## Programmatically builds default starter party with multi-path item resolution
func _build_default_starter_party() -> void:
	current_party = DungeonParty.new()
	if current_party.has_method("setup_starter_party"):
		current_party.setup_starter_party()
		
	inventory = Inventory.new()
	var slots: Array = current_party.slots

	# 1. Commander Whiskers (Slot 0 - Spartan)
	if slots.size() > 0 and slots[0] != null:
		var whiskers: CatCharacter = slots[0] as CatCharacter
		_safe_equip(whiskers, "HEAD", ["ArmorSpartanRegularHead", "Equipment/PowerSuit"])
		_safe_equip(whiskers, "BODY", ["ArmorSpartanRegularBody", "Equipment/PowerSuit"])
		_safe_equip(whiskers, "ARMS", ["ArmorSpartanRegularArms"])
		_safe_equip(whiskers, "LEGS", ["ArmorSpartanRegularLegs"])
		_safe_equip(whiskers, "FEET", ["ArmorSpartanRegularFeet"])
		_safe_equip(whiskers, "RIGHT_HAND", ["WeapSpartanRegularPrimary", "Equipment/Broadsword", "Equipment/LaserClaw"])

	# 2. Baron Von Hiss (Slot 1 - Warden)
	if slots.size() > 1 and slots[1] != null:
		var baron: CatCharacter = slots[1] as CatCharacter
		_safe_equip(baron, "HEAD", ["ArmorWardenRegularHead"])
		_safe_equip(baron, "BODY", ["ArmorWardenRegularBody"])
		_safe_equip(baron, "ARMS", ["ArmorWardenRegularArms"])
		_safe_equip(baron, "LEGS", ["ArmorWardenRegularLegs"])
		_safe_equip(baron, "FEET", ["ArmorWardenRegularFeet"])
		_safe_equip(baron, "RIGHT_HAND", ["WeapWardenRegularPrimary", "Equipment/Crossbow", "Equipment/LaserClaw"])
		_safe_equip(baron, "LEFT_HAND", ["WeapWardenRegularAmmo", "Equipment/IronArrows"])

	# 3. Sage Psych-Meow (Slot 3 - Wizard)
	if slots.size() > 3 and slots[3] != null:
		var sage: CatCharacter = slots[3] as CatCharacter
		_safe_equip(sage, "HEAD", ["ArmorWizardRegularHead"])
		_safe_equip(sage, "BODY", ["ArmorWizardRegularBody"])
		_safe_equip(sage, "ARMS", ["ArmorWizardRegularArms"])
		_safe_equip(sage, "LEGS", ["ArmorWizardRegularLegs"])
		_safe_equip(sage, "FEET", ["ArmorWizardRegularFeet"])
		_safe_equip(sage, "RIGHT_HAND", ["WeapWizardRegularPrimary", "Equipment/ElderStaff"])

	# 4. Shared Inventory Potions
	_safe_add_consumable(["PotHp50", "HealthPotion(+50)", "HealthPotion50", "Consumables/CatnipPotion"], 5)
	_safe_add_consumable(["PotMana25", "ManaPotion(+25)", "ManaPotion25", "Consumables/CatnipPotion"], 3)
	_safe_add_consumable(["PotCatnip", "Consumables/CatnipPotion"], 3)

	_sync_party_references()


func _safe_equip(cat: CatCharacter, slot: String, item_candidates: Array) -> void:
	var item: ItemData = _load_item_from_candidates(item_candidates)
	if is_instance_valid(item):
		cat.equip_item(slot, item)


func _safe_add_consumable(item_candidates: Array, count: int) -> void:
	var item: ItemData = _load_item_from_candidates(item_candidates)
	if is_instance_valid(item):
		for i in range(count):
			inventory.add_item(item)


func _load_item_from_candidates(candidates: Array) -> ItemData:
	for name_key in candidates:
		var paths: Array[String] = [
			"res://Data/Items/Equipment/" + name_key + ".tres",
			"res://Data/Items/Consumables/" + name_key + ".tres",
			"res://Data/Items/Misc/" + name_key + ".tres",
			"res://Data/Items/" + name_key + ".tres"
		]
		for path in paths:
			if ResourceLoader.exists(path):
				return load(path) as ItemData
	return null


## Saves active party, character equipment, vitals, and inventory to user://save_game.tres
func save_game() -> bool:
	var save := SaveGame.new()
	save.party = current_party
	save.inventory = inventory
	save.current_floor_id = current_floor_id
	save.save_timestamp = Time.get_datetime_string_from_system()

	var err := ResourceSaver.save(save, SAVE_PATH)
	if err == OK:
		print("GameState: Session successfully saved to ", SAVE_PATH)
		return true
	else:
		printerr("GameState ERROR: Failed to save session! Error code: ", err)
		return false


## Loads active party, character equipment, vitals, and inventory from user://save_game.tres
func load_game() -> bool:
	if not ResourceLoader.exists(SAVE_PATH):
		return false

	var save := ResourceLoader.load(SAVE_PATH) as SaveGame
	if save == null or save.party == null or save.party.slots == null:
		return false

	var valid_cat_count: int = 0
	for slot in save.party.slots:
		if is_instance_valid(slot):
			valid_cat_count += 1

	if valid_cat_count == 0:
		print("GameState WARNING: Loaded save file contains 0 cats! Discarding empty save...")
		return false

	current_party = save.party
	inventory = save.inventory if save.inventory != null else Inventory.new()
	current_floor_id = save.current_floor_id
	
	_sync_party_references()
	print("GameState: Successfully loaded saved session with %d cats from %s" % [valid_cat_count, SAVE_PATH])
	return true


## Debug Helper: Deletes save file and resets to default starter party
func reset_to_starter_party() -> void:
	print("GameState: Resetting session to default starter party...")
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_build_default_starter_party()
	save_game()


func _sync_party_references() -> void:
	var party_slots: Array = current_party.get("slots") as Array if current_party else []
	for slot in party_slots:
		if is_instance_valid(slot):
			if "inventory" in slot:
				slot.inventory = inventory
			if slot.get("stats") == null and slot.has_method("initialize_stats"):
				slot.initialize_stats()

	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb and sb.has_signal("party_roster_updated"):
		sb.party_roster_updated.emit(party_slots)
