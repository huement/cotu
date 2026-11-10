# res://Scripts/UI/Menus/session_flow.gd
class_name SessionFlow
extends RefCounted
## Moving between the main menu and the game world (new game, load, quit to menu).
## One place for the "clean up the running session" rules so both menus agree.

const GAME_SCENE: String = "res://Scenes/world.tscn"
const MAIN_MENU_SCENE: String = "res://Scenes/GameMenus/MainMenu.tscn"


## True when a save file exists in user://.
static func has_save() -> bool:
	return ResourceLoader.exists(GameState.SAVE_PATH)


## "2026-11-06 14:03 · FeroShaw" style label of the save (time + where), or "" when unknown.
static func get_save_timestamp() -> String:
	if not has_save():
		return ""
	# CACHE_MODE_IGNORE: read a fresh copy without touching the live party objects.
	var save: SaveGame = ResourceLoader.load(GameState.SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	if save == null or save.save_timestamp.is_empty():
		return ""
	var label: String = save.save_timestamp.replace("T", " ").left(16)
	if not save.location_name.is_empty():
		label += "  ·  " + save.location_name
	return label


## Wipes the save, rebuilds the TEST party (Data/default_save.tres) and opens the game world.
## Players start through the roster instead (start_new_game_with_roster); this is the debug Quick Start.
static func start_new_game(tree: SceneTree) -> void:
	_clear_running_session(tree)
	GameState.reset_to_starter_party()
	MenuKit.change_scene(GAME_SCENE)


## Wipes the save and starts a new game with characters from the roster (Character Creator).
## `slot_ids`: 6 roster ids, "" for an empty slot (0-2 front row, 3-5 back row). The game plays with
## copies; the roster characters are locked (no more edits) once the game starts.
static func start_new_game_with_roster(tree: SceneTree, slot_ids: Array) -> bool:
	var party: DungeonParty = CharacterRoster.build_party(slot_ids)
	if party.get_viable_combatants().is_empty():
		return false
	_clear_running_session(tree)
	GameState.start_new_game_with_party(party)
	CharacterRoster.lock(slot_ids.filter(func(id: Variant) -> bool: return not str(id).is_empty()))
	MenuKit.change_scene(GAME_SCENE)
	return true


## Loads the save and (re)opens the game world. Returns false if the save is unusable.
static func load_saved_game(tree: SceneTree) -> bool:
	if not GameState.load_game():
		return false
	_clear_running_session(tree)
	MenuKit.change_scene(GAME_SCENE)
	return true


## Leaves the game for the title screen (does NOT save; call GameState.save_game() first if wanted).
static func quit_to_main_menu(tree: SceneTree) -> void:
	_clear_running_session(tree)
	if is_instance_valid(AudioManager):
		AudioManager.stop_bgm()
		AudioManager.stop_level_sound()
		AudioManager.stop_battle_music()
		AudioManager.stop_all_enemy_loops()
	MenuKit.main_menu_scene = MAIN_MENU_SCENE
	MenuKit.change_scene(MAIN_MENU_SCENE)


## True while a battle is running (saving / party changes are blocked then).
static func is_in_battle() -> bool:
	return GameState.current_mode == GameState.Mode.BATTLE or bool(CombatManager.get("is_combat_active"))


static func _clear_running_session(tree: SceneTree) -> void:
	tree.paused = false
	if bool(CombatManager.get("is_combat_active")) and CombatManager.has_method("_reset_battle_state"):
		CombatManager.call("_reset_battle_state")
	GameState.current_mode = GameState.Mode.EXPLORING
	GameState.awaiting_victory_screen = false
