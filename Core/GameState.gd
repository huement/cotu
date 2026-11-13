# res://Core/GameState.gd
extends Node
class_name CoreGameState

enum Mode {
	EXPLORING,
	BATTLE,
	MANAGEMENT,
}

signal core_state_changed(new_mode: Mode)

## The old single save file. Moved into slot 1 the first time the game runs with save slots.
const LEGACY_SAVE_PATH: String = "user://save_game.tres"
## Save slots: user://saves/slot_1.tres ... slot_N.tres. `save_slot` is the one this session uses.
const SAVE_DIR: String = "user://saves"
const SAVE_SLOT_COUNT: int = 5
## Remembers the last used slot between runs.
const SAVE_META_PATH: String = "user://saves/slots.cfg"
const DEFAULT_SAVE_PATH: String = "res://Data/default_save.tres"
## Dev-start sessions (MapManager.dev_start_override) save here, so they never touch the player save.
const DEV_SAVE_PATH: String = "user://save_game_dev.tres"
## Test party loadout (dev start / debug Quick Start / boot fallback only - real new games skip it).
## Weapon equipped on every starter who can wield it; it grants Attack Up I (eff_attack_up_1).
const TEST_PARTY_WEAPON_PATH: String = "res://Data/Items/Equipment/Broadsword.tres"
const TEST_PARTY_REVIVE_PATH: String = "res://Data/Items/Consumables/PotRevive.tres"
## Revive Potions added to the pack on top of default_save.tres's supplies.
const TEST_PARTY_REVIVE_POTIONS: int = 5
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
			
## Arcanum Shards collected so far: shard_id -> { "level", "map_id" }. Read / write through ShardLedger.
var collected_shards: Dictionary = {}
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

## True once a session was started on purpose: main menu (new game / load) or a dev start.
## The world scene opened without one sends the player to the main menu (see MapManager).
var session_active: bool = false
## True while playing a dev-start session (test party from default_save.tres, own save file).
var dev_session: bool = false
## The save slot (1..SAVE_SLOT_COUNT) this session saves to and loads from. Every save_game()
## call in the game writes here. Change it with set_save_slot() (main menu: new game / load).
var save_slot: int = 1

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
	GameLogger.combat("[GameState] 🛡️ Post-combat immunity initiated for %.1f seconds." % post_combat_immunity_timer)


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
	GameLogger.combat("[GameState] 🏆 Battle victory confirmed! Awarding %d XP to %d living party members..." % [xp_per_member, living_members])

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
	GameLogger.info("GameState: Initializing active session...")
	_setup_save_slots()

	if ResourceLoader.exists(get_save_path()):
		if not load_game():
			GameLogger.info("GameState: Existing save file in user:// invalid. Loading default_save.tres...")
			_load_default_save(true, false)
	else:
		GameLogger.info("GameState: No save file found in user://. Loading default_save.tres...")
		_load_default_save(true, false)


## Fresh world with the starting supplies from default_save.tres (pack, gold, floor).
## equip_starters = true: the TEST party - always the characters in Data/StarterParty (never
## default_save's own party list), with class starter gear plus the test loadout (TEST_PARTY_*).
## equip_starters = false when the caller swaps in its own party right after (roster New Game).
## persist = false keeps it in memory only (game boot: opening the game must not create a save).
func _load_default_save(equip_starters: bool = true, persist: bool = true) -> void:
	if ResourceLoader.exists(DEFAULT_SAVE_PATH):
		var default_save := load(DEFAULT_SAVE_PATH) as SaveGame
		if default_save != null:
			current_party = CharacterRoster.starter_party()
			if current_party.get_viable_combatants().is_empty():
				printerr("GameState ERROR: no characters in %s - the test party is empty." % CharacterRoster.STARTER_PARTY_DIR)
			inventory = default_save.inventory.duplicate(true) as Inventory if default_save.inventory != null else Inventory.new()
			for path: String in STARTER_BONUS_ITEMS:
				var bonus: ItemData = load(path) as ItemData
				if bonus != null:
					inventory.add_item(bonus.duplicate(true), 1)
			inventory.normalize_stacks()
			if equip_starters:
				# Class starter gear (Data/basic_items.csv); spares go in the pack.
				StarterKit.equip_party(current_party, inventory)
				_apply_test_party_loadout()
			current_floor_id = default_save.current_floor_id
			party_gold = default_save.party_gold
			# Fresh world: no opened chests / solved puzzles / beaten bosses, morning, start map.
			environment_states = {}
			collected_shards = {}
			world_time = 0.25
			current_time_period = "MORNING"
			play_time_seconds = 0.0
			pending_location = {}
			_last_location = {}
			_sync_party_references()
			if persist:
				save_game(false) # the old world may still be loaded - don't record its map
			GameLogger.info("GameState: Starter party (%d from %s) initialized with default_save.tres supplies" % [current_party.get_viable_combatants().size(), CharacterRoster.STARTER_PARTY_DIR])
			return

	printerr("GameState ERROR: Failed to load default_save.tres from ", DEFAULT_SAVE_PATH)


## Test party extras: the TEST_PARTY_WEAPON in the main hand of everyone whose class can use it
## (the class weapon it replaces goes to the pack) and TEST_PARTY_REVIVE_POTIONS Revive Potions.
func _apply_test_party_loadout() -> void:
	var weapon: ItemData = load(TEST_PARTY_WEAPON_PATH) as ItemData
	if weapon == null:
		push_warning("GameState: test party weapon missing at %s" % TEST_PARTY_WEAPON_PATH)
	else:
		var slot: String = weapon.get_slot_string()
		for member: Variant in current_party.slots:
			var cat: CatCharacter = member as CatCharacter
			if cat == null or not cat.can_equip_item(weapon):
				continue
			var replaced: ItemData = cat.get_equipped_item(slot) as ItemData
			if cat.equip_item(slot, weapon.duplicate(true)):
				if replaced != null:
					inventory.add_item(replaced, 1)
				cat.equipment_changed.emit()
	var revive: ItemData = load(TEST_PARTY_REVIVE_PATH) as ItemData
	if revive != null and TEST_PARTY_REVIVE_POTIONS > 0:
		inventory.add_item(revive.duplicate(true), TEST_PARTY_REVIVE_POTIONS)
	inventory.normalize_stacks()


## The save file of the running session (dev starts use their own, see DEV_SAVE_PATH).
func get_save_path() -> String:
	return DEV_SAVE_PATH if dev_session else slot_path(save_slot)


# ==============================================================================
# Save slots
# ==============================================================================
static func slot_path(slot: int) -> String:
	return "%s/slot_%d.tres" % [SAVE_DIR, slot]


func slot_has_save(slot: int) -> bool:
	return slot >= 1 and slot <= SAVE_SLOT_COUNT and FileAccess.file_exists(slot_path(slot))


## Makes `slot` the session's save slot and remembers it for the next run.
func set_save_slot(slot: int) -> void:
	save_slot = clampi(slot, 1, SAVE_SLOT_COUNT)
	var cfg := ConfigFile.new()
	cfg.set_value("saves", "last_slot", save_slot)
	cfg.save(SAVE_META_PATH)


## Lowest-numbered slot with no save in it, or 0 when every slot is used.
func first_empty_slot() -> int:
	for slot: int in range(1, SAVE_SLOT_COUNT + 1):
		if not slot_has_save(slot):
			return slot
	return 0


func delete_slot(slot: int) -> void:
	if slot_has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))


## The slot's save file read fresh from disk (never the live party), or null.
func read_slot(slot: int) -> SaveGame:
	if not slot_has_save(slot):
		return null
	return ResourceLoader.load(slot_path(slot), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame


## Creates the saves folder, moves a pre-slots save into slot 1 and restores the last used slot.
func _setup_save_slots() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if FileAccess.file_exists(LEGACY_SAVE_PATH) and not FileAccess.file_exists(slot_path(1)):
		var err: Error = DirAccess.rename_absolute(LEGACY_SAVE_PATH, slot_path(1))
		if err == OK:
			GameLogger.info("GameState: Moved the old save into slot 1.")
		else:
			printerr("GameState ERROR: Could not move the old save into slot 1 (error %d)." % err)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_META_PATH) == OK:
		save_slot = clampi(int(cfg.get_value("saves", "last_slot", 1)), 1, SAVE_SLOT_COUNT)


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
	save.collected_shards = collected_shards.duplicate(true)
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

	var err := ResourceSaver.save(save, get_save_path())
	if err == OK:
		GameLogger.info(str("GameState: Session successfully saved to ", get_save_path()))
		return true
	else:
		printerr("GameState ERROR: Failed to save session! Error code: ", err)
		return false


func load_game() -> bool:
	if not ResourceLoader.exists(get_save_path()):
		return false
	# CACHE_MODE_IGNORE: read fresh copies, otherwise the cached (live, unsaved) party comes back.
	var save := ResourceLoader.load(get_save_path(), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
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
	collected_shards = save.collected_shards.duplicate(true)
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
	GameLogger.info("GameState: Successfully loaded saved session with %d cats from %s" % [valid_cat_count, get_save_path()])
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
	dev_session = false
	session_active = true
	delete_slot(save_slot) # the caller picked the slot (set_save_slot) before starting
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
	GameLogger.info("GameState: New game with %d created characters." % party.get_viable_combatants().size())


func reset_to_starter_party() -> void:
	dev_session = false
	session_active = true
	delete_slot(save_slot) # the caller picked the slot (set_save_slot) before starting
	_load_default_save()


## Dev start (MapManager.dev_start_override, editor only): fresh test party from default_save.tres,
## saved to DEV_SAVE_PATH so the real player save is left alone.
func begin_dev_session() -> void:
	dev_session = true
	session_active = true
	_load_default_save()
	GameLogger.info(str("GameState: DEV START - test party loaded, saving to ", DEV_SAVE_PATH))


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

	GameLogger.info("[GameState] 🏕️ Party resting for %d hours..." % hours)

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
