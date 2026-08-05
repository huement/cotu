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


func get_active_cat() -> Resource:
	if current_party != null:
		var party_slots: Array = current_party.get("slots") as Array
		if party_slots != null and active_character_index >= 0 and active_character_index < party_slots.size():
			return party_slots[active_character_index] as Resource
	return null


func _ready() -> void:
	_initialize_active_session()
	
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb and sb.has_signal("popup_confirmed"):
		sb.popup_confirmed.connect(_on_popup_confirmed)


func _on_popup_confirmed(action_type: StringName, extra_data: Dictionary) -> void:
	if action_type == &"BATTLE_VICTORY":
		_award_victory_xp(extra_data)


func _award_victory_xp(victory_data: Dictionary) -> void:
	var total_xp: int = int(victory_data.get("total_xp", 0))
	var living_members: int = int(victory_data.get("living_members", 1))
	if total_xp <= 0 or living_members <= 0 or current_party == null:
		return

	var xp_per_member: int = int(float(total_xp) / float(living_members))
	print("[GameState] 🏆 Battle victory confirmed! Awarding %d XP to %d living party members..." % [xp_per_member, living_members])

	var party_slots: Array = current_party.slots
	for i in range(party_slots.size()):
		var cat: CatCharacter = party_slots[i] as CatCharacter
		if is_instance_valid(cat) and cat.current_hp > 0:
			var leveled_up: bool = cat.add_xp(xp_per_member)
			
			var sb: Node = get_tree().root.get_node_or_null("SignalBus")
			if sb:
				if sb.has_signal("character_xp_changed"):
					sb.character_xp_changed.emit(i, cat.current_xp, cat.max_xp)
				if leveled_up and sb.has_signal("character_leveled_up"):
					sb.character_leveled_up.emit(i, cat.level)

	save_game()


func _initialize_active_session() -> void:
	print("GameState: Assembling tactical data structures...")
	
	if ResourceLoader.exists(SAVE_PATH):
		if not load_game():
			print("GameState: Existing save file invalid. Rebuilding default starter party...")
			_build_default_starter_party()
			save_game()
	else:
		print("GameState: No save file found. Building default starter party...")
		_build_default_starter_party()
		save_game()


func _build_default_starter_party() -> void:
	current_party = DungeonParty.new()
	if current_party.has_method("setup_starter_party"):
		current_party.setup_starter_party()
		
	inventory = Inventory.new()
	var slots: Array = current_party.slots

	# 1. Commander Whiskers (Slot 0 - Spartan / Maine Coon)
	if slots.size() > 0 and slots[0] != null:
		var whiskers: CatCharacter = slots[0] as CatCharacter
		_safe_equip(whiskers, "HEAD", ["ArmorSpartanRegularHead", "Equipment/IronHeadArmor", "Equipment/PowerSuit"])
		_safe_equip(whiskers, "BODY", ["ArmorSpartanRegularBody", "Equipment/IronBodyArmor", "Equipment/PowerSuit"])
		_safe_equip(whiskers, "ARMS", ["ArmorSpartanRegularArms", "Equipment/IronArmsArmor"])
		_safe_equip(whiskers, "LEGS", ["ArmorSpartanRegularLegs", "Equipment/IronLegsArmor"])
		_safe_equip(whiskers, "FEET", ["ArmorSpartanRegularFeet", "Equipment/IronFeetArmor"])
		_safe_equip(whiskers, "RIGHT_HAND", ["WeapSpartanRegularPrimary", "Equipment/Broadsword", "Equipment/LaserClaw"])
		_safe_add_skill(whiskers, ["OverdriveStrike", "KineticSlam", "GrenadeWorkshop", "LaserClawProficiency"])

	# 2. Baron Von Hiss (Slot 1 - Warden / Siamese)
	if slots.size() > 1 and slots[1] != null:
		var baron: CatCharacter = slots[1] as CatCharacter
		_safe_equip(baron, "HEAD", ["ArmorWardenRegularHead", "Equipment/HunterHeadArmor"])
		_safe_equip(baron, "BODY", ["ArmorWardenRegularBody", "Equipment/HunterBodyArmor"])
		_safe_equip(baron, "ARMS", ["ArmorWardenRegularArms", "Equipment/HunterArmsArmor"])
		_safe_equip(baron, "LEGS", ["ArmorWardenRegularLegs", "Equipment/HunterLegsArmor"])
		_safe_equip(baron, "FEET", ["ArmorWardenRegularFeet", "Equipment/HunterFeetArmor"])
		_safe_equip(baron, "RIGHT_HAND", ["WeapWardenRegularPrimary", "Equipment/Crossbow", "Equipment/LaserClaw"])
		
		var ammo: ItemData = _load_item_from_candidates(["WeapWardenRegularAmmo", "Equipment/IronArrows"])
		if is_instance_valid(ammo):
			var ammo_stack: ItemData = ammo.duplicate(true) as ItemData
			ammo_stack.quantity = 20
			baron.equip_item("LEFT_HAND", ammo_stack)

		_safe_add_skill(baron, ["TargetingLock", "MunitionsAssembly", "CyberLockpicking", "PurrgatoryCamp"])
		_safe_add_spell(baron, ["CorrosiveSpray", "StimulantMist", "NeurotoxinGas"])

	# 3. Sage Psych-Meow (Slot 3 - Wizard / Sphynx)
	if slots.size() > 3 and slots[3] != null:
		var sage: CatCharacter = slots[3] as CatCharacter
		_safe_equip(sage, "HEAD", ["ArmorWizardRegularHead", "Equipment/MysticHeadGarb"])
		_safe_equip(sage, "BODY", ["ArmorWizardRegularBody", "Equipment/MysticBodyGarb"])
		_safe_equip(sage, "ARMS", ["ArmorWizardRegularArms", "Equipment/MysticArmsGarb"])
		_safe_equip(sage, "LEGS", ["ArmorWizardRegularLegs", "Equipment/MysticLegsGarb"])
		_safe_equip(sage, "FEET", ["ArmorWizardRegularFeet", "Equipment/MysticFeetGarb"])
		_safe_equip(sage, "RIGHT_HAND", ["WeapWizardRegularPrimary", "Equipment/ElderStaff"])

		_safe_add_skill(sage, ["PurrHealing", "ArcaneSynthesis", "RuneImbuement"])
		_safe_add_spell(sage, ["PlasmaDart", "StaticNova", "OverclockShield", "NanoRepair", "AdrenalineSurge", "AegisGrid"])

	# 4. Shared Inventory Potions
	_safe_add_consumable(["PotHp50", "HealthPotion(+50)", "HealthPotion50", "Consumables/CatnipPotion"], 5)
	_safe_add_consumable(["PotMana25", "ManaPotion(+25)", "ManaPotion25", "Consumables/CatnipPotion"], 3)
	_safe_add_consumable(["PotCatnip", "Consumables/CatnipPotion"], 3)

	_sync_party_references()


func _safe_equip(cat: CatCharacter, slot: String, item_candidates: Array) -> void:
	var item: ItemData = _load_item_from_candidates(item_candidates)
	if is_instance_valid(item): cat.equip_item(slot, item)

func _safe_add_consumable(item_candidates: Array, count: int) -> void:
	var item: ItemData = _load_item_from_candidates(item_candidates)
	if is_instance_valid(item):
		for i in range(count): inventory.add_item(item)

func _safe_add_skill(cat: CatCharacter, skill_candidates: Array) -> void:
	for name_key in skill_candidates:
		var res: Resource = _load_ability_from_candidates("Skills/", name_key)
		if is_instance_valid(res) and not cat.known_skills.has(res): cat.known_skills.append(res)

func _safe_add_spell(cat: CatCharacter, spell_candidates: Array) -> void:
	for name_key in spell_candidates:
		var res: Resource = _load_ability_from_candidates("Spells/", name_key)
		if is_instance_valid(res) and not cat.known_spells.has(res): cat.known_spells.append(res)

func _load_item_from_candidates(candidates: Array) -> ItemData:
	for name_key in candidates:
		var paths: Array[String] = [
			"res://Data/Items/Equipment/" + name_key + ".tres",
			"res://Data/Items/Consumables/" + name_key + ".tres",
			"res://Data/Items/Misc/" + name_key + ".tres",
			"res://Data/Items/" + name_key + ".tres"
		]
		for path in paths:
			if ResourceLoader.exists(path): return load(path) as ItemData
	return null

func _load_ability_from_candidates(sub_folder: String, name_key: String) -> Resource:
	var paths: Array[String] = [
		"res://Data/" + sub_folder + name_key + ".tres",
		"res://Data/" + sub_folder + name_key.to_pascal_case() + ".tres"
	]
	for path in paths:
		if ResourceLoader.exists(path): return load(path)
	return null

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

func load_game() -> bool:
	if not ResourceLoader.exists(SAVE_PATH): return false
	var save := ResourceLoader.load(SAVE_PATH) as SaveGame
	if save == null or save.party == null or save.party.slots == null: return false

	var valid_cat_count: int = 0
	for slot in save.party.slots:
		if is_instance_valid(slot): valid_cat_count += 1

	if valid_cat_count == 0: return false

	current_party = save.party
	inventory = save.inventory if save.inventory != null else Inventory.new()
	current_floor_id = save.current_floor_id
	
	_sync_party_references()
	print("GameState: Successfully loaded saved session with %d cats from %s" % [valid_cat_count, SAVE_PATH])
	return true

func reset_to_starter_party() -> void:
	if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(SAVE_PATH)
	_build_default_starter_party()
	save_game()

func _sync_party_references() -> void:
	var party_slots: Array = current_party.get("slots") as Array if current_party else []
	for slot in party_slots:
		if is_instance_valid(slot):
			if "inventory" in slot: slot.inventory = inventory
			if slot.has_method("populate_starting_skills"): slot.populate_starting_skills()
			if slot.has_method("populate_starting_spells"): slot.populate_starting_spells()
			if slot.get("stats") == null and slot.has_method("initialize_stats"): slot.initialize_stats()

	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb and sb.has_signal("party_roster_updated"): sb.party_roster_updated.emit(party_slots)
