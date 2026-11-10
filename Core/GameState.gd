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
## Extra items every new game starts with in the pack (one entry = one item).
const STARTER_BONUS_ITEMS: Array[String] = [
	"res://Data/Items/Equipment/WeapKatIronBroadsword.tres",
	"res://Data/Items/Equipment/WeapKatIronBroadsword.tres",
]

var current_mode: Mode = Mode.EXPLORING:
	set(value):
		if current_mode != value:
			current_mode = value
			core_state_changed.emit(current_mode)

@export var current_party: DungeonParty
@export var inventory: Inventory = Inventory.new()
@export var current_floor_id: int = 1
@export var party_gold: int = 0
## Maps map_id -> (object_id -> state_dictionary)
@export var environment_states: Dictionary = {}
@export var current_time_period: String = "MORNING":
	set(value):
		if current_time_period != value:
			current_time_period = value
			SignalBus.emit_signal("time_period_changed", current_time_period)
			
## Shared day/night clock (0..1, 0.25 = morning). Every map's DayNightCycle reads and advances it,
## so time no longer resets when you change maps. Saved with the game.
var world_time: float = 0.25
## Seconds played (only counts while the game isn't paused).
var play_time_seconds: float = 0.0
## Where the last loaded save left the party: { map_scene_path, player_cell, player_facing, location_name }.
## MapManager consumes it once when the world starts (consume_pending_location()).
var pending_location: Dictionary = {}
## Extra loot for the battle about to start, set by boss scripts right before they emit combat_started
## (register_boss_rewards). CombatManager pays it out on victory and clears it after any battle.
var pending_boss_rewards: Dictionary = {}
## Last place we knew the party was standing - used when saving from somewhere without a live map.
var _last_location: Dictionary = {}

var active_character_index: int = 0
var post_combat_immunity_timer: float = 0.0
var encounter_lock_timer: float = 0.0

## Seconds after ANY battle ends before another can start (also covers fleeing and defeat).
const POST_BATTLE_COOLDOWN: float = 5.0
## Extra immunity once the victory screen is closed (enemies may have walked up meanwhile).
const POST_VICTORY_SCREEN_COOLDOWN: float = 3.0
## Failsafe: never block encounters longer than this waiting for the victory screen.
const VICTORY_SCREEN_MAX_WAIT: float = 120.0

## True between a won battle and the player closing the victory screen. No new fights meanwhile.
var awaiting_victory_screen: bool = false
var _victory_screen_wait: float = 0.0


func _process(delta: float) -> void:
	play_time_seconds += delta
	if post_combat_immunity_timer > 0.0:
		post_combat_immunity_timer -= delta
	if encounter_lock_timer > 0.0:
		encounter_lock_timer -= delta
	if awaiting_victory_screen:
		_victory_screen_wait += delta
		if _victory_screen_wait >= VICTORY_SCREEN_MAX_WAIT:
			push_warning("GameState: victory screen never closed - unblocking encounters.")
			awaiting_victory_screen = false


func _on_combat_started(_enemy_data_or_group: Variant, _player_party: Array, _enemy_facing: String) -> void:
	awaiting_victory_screen = false
	current_mode = Mode.BATTLE


func _on_combat_ended(victory: bool) -> void:
	start_post_combat_immunity(POST_BATTLE_COOLDOWN)
	if victory:
		awaiting_victory_screen = true
		_victory_screen_wait = 0.0
	else:
		current_mode = Mode.EXPLORING


## True while a battle is running or its victory screen is still open: enemies hold still.
func is_battle_in_progress() -> bool:
	if awaiting_victory_screen:
		return true
	var cm: Node = get_tree().root.get_node_or_null("CombatManager")
	return is_instance_valid(cm) and (bool(cm.get("is_combat_active")) or bool(cm.get("is_transitioning_out")))


func _on_popup_confirmed(action_type: StringName, extra_data: Dictionary) -> void:
	if action_type == &"BATTLE_VICTORY":
		_award_victory_xp(extra_data)
		# Now that the player has dismissed the victory screen, return to the
		# normal exploration state and start a brief post-combat immunity period
		# to prevent instant re-engagement from lurking enemies.
		awaiting_victory_screen = false
		var cm: Node = get_tree().root.get_node_or_null("CombatManager")
		var fighting: bool = is_instance_valid(cm) and bool(cm.get("is_combat_active"))
		if not fighting: # never drop out of BATTLE mode (hides the battle HUD) mid-fight
			current_mode = Mode.EXPLORING
			start_post_combat_immunity(POST_VICTORY_SCREEN_COOLDOWN)
	elif action_type == &"REST":
		_process_party_rest(extra_data)


func start_post_combat_immunity(duration: float) -> void:
	post_combat_immunity_timer = max(post_combat_immunity_timer, duration)
	print("[GameState] 🛡️ Post-combat immunity initiated for %.1f seconds." % post_combat_immunity_timer)


func lock_encounters(duration: float) -> void:
	encounter_lock_timer = max(encounter_lock_timer, duration)


func clear_encounter_lock() -> void:
	encounter_lock_timer = 0.0


func can_begin_encounter() -> bool:
	if encounter_lock_timer > 0.0 or post_combat_immunity_timer > 0.0 or awaiting_victory_screen:
		return false
	var cm: Node = get_tree().root.get_node_or_null("CombatManager")
	if is_instance_valid(cm):
		if bool(cm.get("is_combat_active")) or bool(cm.get("is_transitioning_out")):
			return false
	return true


func get_active_cat() -> Resource:
	if current_party != null:
		var party_slots: Array = current_party.get("slots") as Array
		if party_slots != null and active_character_index >= 0 and active_character_index < party_slots.size():
			return party_slots[active_character_index] as Resource
	return null


## Highest level among living party members. Used for StoneGate / zone unlock checks.
## Dead or empty slots are ignored; returns 0 if nobody is alive.
func get_party_level() -> int:
	if current_party == null:
		return 0
	var highest: int = 0
	var party_slots: Array = current_party.slots
	for slot: Variant in party_slots:
		var cat: CatCharacter = slot as CatCharacter
		if not is_instance_valid(cat):
			continue
		if cat.current_hp <= 0:
			continue
		highest = maxi(highest, cat.level)
	return highest


func _ready() -> void:
	_initialize_active_session()

	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb and sb.has_signal("popup_confirmed"):
		sb.popup_confirmed.connect(_on_popup_confirmed)
	if sb and sb.has_signal("combat_started"):
		sb.combat_started.connect(_on_combat_started)
		sb.combat_ended.connect(_on_combat_ended)


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


## equip_starters = false when the caller swaps in its own party right after (roster New Game).
func _load_default_save(equip_starters: bool = true) -> void:
	if ResourceLoader.exists(DEFAULT_SAVE_PATH):
		var default_save := load(DEFAULT_SAVE_PATH) as SaveGame
		if default_save != null and default_save.party != null:
			current_party = default_save.party.duplicate(true) as DungeonParty
			# Starter characters are external .tres files (Data/StarterParty/) - duplicate(true) doesn't
			# copy those, so copy each one or the game would edit the cached starter resources.
			for i: int in current_party.slots.size():
				var starter: Resource = current_party.slots[i]
				if starter != null:
					current_party.slots[i] = starter.duplicate(true)
			inventory = default_save.inventory.duplicate(true) as Inventory if default_save.inventory != null else Inventory.new()
			for path: String in STARTER_BONUS_ITEMS:
				var bonus: ItemData = load(path) as ItemData
				if bonus != null:
					inventory.add_item(bonus.duplicate(true), 1)
			inventory.normalize_stacks()
			if equip_starters:
				# Class starter gear (Data/basic_items.csv); spares go in the pack.
				StarterKit.equip_party(current_party, inventory)
			current_floor_id = default_save.current_floor_id
			party_gold = default_save.party_gold
			# Fresh world: no opened chests / solved puzzles / beaten bosses, morning, start map.
			environment_states = {}
			world_time = 0.25
			current_time_period = "MORNING"
			play_time_seconds = 0.0
			pending_location = {}
			_last_location = {}
			_sync_party_references()
			save_game(false) # the old world may still be loaded - don't record its map
			print("GameState: Starter party successfully initialized from default_save.tres")
			return

	printerr("GameState ERROR: Failed to load default_save.tres from ", DEFAULT_SAVE_PATH)


## include_location = false skips live capture (world may be unloading / not ready).
## It still writes `_last_location` when set — needed so a brand-new game keeps
## GreenGrove + SpawnPointNewGame across Continue before the party has moved.
func save_game(include_location: bool = true) -> bool:
	var save := SaveGame.new()
	save.party = current_party
	save.inventory = inventory
	save.current_floor_id = current_floor_id
	save.save_version = SaveGame.CURRENT_VERSION
	save.party_gold = party_gold
	save.environment_states = environment_states.duplicate(true)
	save.world_time = world_time
	save.time_period = current_time_period
	save.play_time_seconds = play_time_seconds
	var loc: Dictionary = capture_location() if include_location else _last_location
	save.map_scene_path = str(loc.get("map_scene_path", ""))
	save.location_name = str(loc.get("location_name", ""))
	save.player_cell = loc.get("player_cell", Vector2i.ZERO) as Vector2i
	save.player_facing = str(loc.get("player_facing", "NORTH"))
	save.spawn_marker = str(loc.get("spawn_marker", ""))
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
	# CACHE_MODE_IGNORE: read fresh copies, otherwise the cached (live, unsaved) party comes back.
	var save := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
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
	inventory.normalize_stacks() # Older saves stored one entry per potion
	current_floor_id = save.current_floor_id
	party_gold = save.party_gold
	environment_states = save.environment_states.duplicate(true)
	world_time = save.world_time
	play_time_seconds = save.play_time_seconds
	if not save.time_period.is_empty():
		current_time_period = save.time_period
	pending_location = {}
	_last_location = {}
	if not save.map_scene_path.is_empty():
		pending_location = {
			"map_scene_path": save.map_scene_path,
			"location_name": save.location_name,
			"player_cell": save.player_cell,
			"player_facing": save.player_facing,
			"spawn_marker": save.spawn_marker,
		}
		_last_location = pending_location.duplicate()

	_sync_party_references()
	print("GameState: Successfully loaded saved session with %d cats from %s" % [valid_cat_count, SAVE_PATH])
	return true


## Where the party is right now: map path, cell, facing (falls back to the last known place).
## A live capture clears spawn_marker — once they've been placed in the world, Continue
## should restore the cell, not the new-game intro marker.
func capture_location() -> Dictionary:
	var map_mgr: MapManager = get_tree().root.find_child("MapManager", true, false) as MapManager
	var player: DungeonPlayer = get_tree().get_first_node_in_group(&"player") as DungeonPlayer
	if is_instance_valid(map_mgr) and is_instance_valid(map_mgr.active_map_instance) and is_instance_valid(player):
		var path: String = map_mgr.active_map_instance.scene_file_path
		if not path.is_empty():
			_last_location = {
				"map_scene_path": path,
				"location_name": str(map_mgr.active_map_instance.name),
				"player_cell": player.current_grid_pos,
				"player_facing": player.get_facing_name(),
				"spawn_marker": "",
			}
	return _last_location


## Key for environment_states: the active map's name ("FeroShaw", "WindmillCave1"...), so objects
## with the same object_id on different maps (e.g. the BossChamber prefab's chest) don't share state.
func get_current_map_id() -> String:
	var map_mgr: MapManager = get_tree().root.find_child("MapManager", true, false) as MapManager
	if is_instance_valid(map_mgr) and is_instance_valid(map_mgr.active_map_instance):
		return str(map_mgr.active_map_instance.name)
	var scene: Node = get_tree().current_scene
	return str(scene.name) if is_instance_valid(scene) else "default_map"


## Bosses call this just before starting their fight: on victory the party also gets these items.
func register_boss_rewards(spell_books: int, skill_crystals: int) -> void:
	pending_boss_rewards = { "spell_books": maxi(0, spell_books), "skill_crystals": maxi(0, skill_crystals) }


## The pending boss rewards (and clears them). Empty when the battle wasn't a boss fight.
func take_boss_rewards() -> Dictionary:
	var r: Dictionary = pending_boss_rewards
	pending_boss_rewards = {}
	return r


## Returns the saved location once (then clears it). Empty when there's nothing to restore.
func consume_pending_location() -> Dictionary:
	var loc: Dictionary = pending_location
	pending_location = {}
	return loc


## Where a brand-new game (created characters) begins: this map, at this marker.
const NEW_GAME_MAP: String = "res://Scenes/GreenGrove.tscn"
const NEW_GAME_MARKER: String = "SpawnPointNewGame"


## New game with a party built from the roster (CharacterRoster.build_party). Everyone gets their
## class's starter kit (StarterKit). Starts with the test save's supplies (potions, gold) but none of
## its characters, on NEW_GAME_MAP at NEW_GAME_MARKER.
func start_new_game_with_party(party: DungeonParty) -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_load_default_save(false)
	current_party = party
	# Class starter gear from Data/basic_items.csv; anything that doesn't fit a slot goes in the pack.
	StarterKit.equip_party(current_party, inventory)
	_sync_party_references()
	# Persist map + intro marker so Continue (before any travel/fight) still opens
	# SpawnPointNewGame, not GreenGrove's default SpawnPoint.
	pending_location = {
		"map_scene_path": NEW_GAME_MAP,
		"location_name": "GreenGrove",
		"spawn_marker": NEW_GAME_MARKER,
	}
	_last_location = pending_location.duplicate()
	save_game(false)
	print("GameState: New game with %d created characters." % party.get_viable_combatants().size())


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

	var party_slots: Array = current_party.slots
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")

	for i in range(party_slots.size()):
		var cat: CatCharacter = party_slots[i] as CatCharacter
		if is_instance_valid(cat) and cat.current_hp > 0:

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


## -------------------- ENVIRONMENT STUFF --------------------
## Returns the saved state dictionary for a specific object in a map
func get_object_state(map_id: String, object_id: String) -> Dictionary:
	if environment_states.has(map_id) and environment_states[map_id].has(object_id):
		return environment_states[map_id][object_id] as Dictionary
	return {}


## Updates or sets a state flag for an environment object
func set_object_state_flag(map_id: String, object_id: String, flag_name: String, value: Variant) -> void:
	if not environment_states.has(map_id):
		environment_states[map_id] = {}
	if not environment_states[map_id].has(object_id):
		environment_states[map_id][object_id] = {}

	var obj_dict: Dictionary = environment_states[map_id][object_id] as Dictionary
	obj_dict[flag_name] = value
	environment_states[map_id][object_id] = obj_dict
