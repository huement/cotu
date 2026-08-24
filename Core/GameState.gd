# res://Core/GameState.gd
extends Node
class_name CoreGameState

enum Mode {
	EXPLORING,
	BATTLE,
	MANAGEMENT,
}

signal core_state_changed(new_mode: Mode)

const SAVE_PATH: String = "user://save_game.tres"
const DEFAULT_SAVE_PATH: String = "res://Data/default_save.tres"

var current_mode: Mode = Mode.EXPLORING:
	set(value):
		if current_mode != value:
			current_mode = value
			core_state_changed.emit(current_mode)

@export var current_party: DungeonParty
@export var inventory: Inventory = Inventory.new()
@export var current_floor_id: int = 1
@export var party_gold: int = 0

var active_character_index: int = 0


func _on_popup_confirmed(action_type: StringName, extra_data: Dictionary) -> void:
	if action_type == &"BATTLE_VICTORY":
		_award_victory_xp(extra_data)
	elif action_type == &"REST":
		_process_party_rest(extra_data)


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
	print("GameState: Initializing active session...")

	if ResourceLoader.exists(SAVE_PATH):
		if not load_game():
			print("GameState: Existing save file in user:// invalid. Loading default_save.tres...")
			_load_default_save()
	else:
		print("GameState: No save file found in user://. Loading default_save.tres...")
		_load_default_save()


func _load_default_save() -> void:
	if ResourceLoader.exists(DEFAULT_SAVE_PATH):
		var default_save := load(DEFAULT_SAVE_PATH) as SaveGame
		if default_save != null and default_save.party != null:
			current_party = default_save.party.duplicate(true) as DungeonParty
			inventory = default_save.inventory.duplicate(true) as Inventory if default_save.inventory != null else Inventory.new()
			current_floor_id = default_save.current_floor_id
			if "party_gold" in default_save:
				party_gold = default_save.party_gold
			_sync_party_references()
			save_game()
			print("GameState: Starter party successfully initialized from default_save.tres")
			return

	printerr("GameState ERROR: Failed to load default_save.tres from ", DEFAULT_SAVE_PATH)


func save_game() -> bool:
	var save := SaveGame.new()
	save.party = current_party
	save.inventory = inventory
	save.current_floor_id = current_floor_id
	if "party_gold" in save:
		save.party_gold = party_gold
	save.save_timestamp = Time.get_datetime_string_from_system()

	var err := ResourceSaver.save(save, SAVE_PATH)
	if err == OK:
		print("GameState: Session successfully saved to ", SAVE_PATH)
		return true
	else:
		printerr("GameState ERROR: Failed to save session! Error code: ", err)
		return false


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
		return false

	current_party = save.party
	inventory = save.inventory if save.inventory != null else Inventory.new()
	current_floor_id = save.current_floor_id
	if "party_gold" in save:
		party_gold = save.party_gold

	_sync_party_references()
	print("GameState: Successfully loaded saved session with %d cats from %s" % [valid_cat_count, SAVE_PATH])
	return true


func reset_to_starter_party() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_load_default_save()


func _sync_party_references() -> void:
	var party_slots: Array = current_party.get("slots") as Array if current_party else []
	for slot in party_slots:
		if is_instance_valid(slot):
			if "inventory" in slot:
				slot.inventory = inventory
			if slot.has_method("populate_starting_skills"):
				slot.populate_starting_skills()
			if slot.has_method("populate_starting_spells"):
				slot.populate_starting_spells()
			if slot.get("stats") == null and slot.has_method("initialize_stats"):
				slot.initialize_stats()

	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb and sb.has_signal("party_roster_updated"):
		sb.party_roster_updated.emit(party_slots)


## Adds gold to the party wallet and emits a signal
func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	party_gold += amount
	GameLogger.combat("Party gained %d coins! Total Gold: %d" % [amount, party_gold])
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb and sb.has_signal("party_gold_changed"):
		sb.party_gold_changed.emit(party_gold, amount)


## Attempts to spend gold from the party wallet. Returns true if successful.
func spend_gold(amount: int) -> bool:
	if amount <= 0 or party_gold < amount:
		return false
	party_gold -= amount
	GameLogger.combat("Party spent %d coins. Remaining Gold: %d" % [amount, party_gold])
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb and sb.has_signal("party_gold_changed"):
		sb.party_gold_changed.emit(party_gold, -amount)
	return true


func _process_party_rest(rest_data: Dictionary) -> void:
	var hours: int = int(rest_data.get("hours", 4))
	if hours <= 0 or current_party == null:
		return

	print("[GameState] 🏕️ Party resting for %d hours..." % hours)

	var total_hp_recovered: int = 0
	var total_energy_recovered: int = 0
	var party_slots: Array = current_party.slots
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")

	for i in range(party_slots.size()):
		var cat: CatCharacter = party_slots[i] as CatCharacter
		if is_instance_valid(cat) and cat.current_hp > 0:
			var recovery: Dictionary = cat.rest(hours)
			total_hp_recovered += int(recovery.get("hp_restored", 0))
			total_energy_recovered += int(recovery.get("energy_restored", 0))

			# Broadcast live HUD updates
			if sb:
				if sb.has_signal("character_health_changed"):
					sb.character_health_changed.emit(i, cat.current_hp)
				if sb.has_signal("character_mana_changed"):
					sb.character_mana_changed.emit(i, cat.current_mana)

	# Broadcast Toast Notification
	if sb and sb.has_signal("show_toast"):
		var toast_msg: String = "Rested for %d hours. Party recovered!" % hours
		sb.show_toast.emit(toast_msg, false)

	save_game()
