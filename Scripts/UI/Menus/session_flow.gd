# res://Scripts/UI/Menus/session_flow.gd
class_name SessionFlow
extends RefCounted
## Moving between the main menu and the game world (new game, load, quit to menu).
## One place for the "clean up the running session" rules so both menus agree.

const GAME_SCENE: String = "res://Scenes/world.tscn"
const MAIN_MENU_SCENE: String = "res://Scenes/GameMenus/MainMenu.tscn"
## Opening cinematic shown once when a new game starts; it opens GAME_SCENE when it ends / is skipped.
const INTRO_SCENE: String = "res://Scenes/GameMenus/IntroVideo.tscn"


## True when the session's own save slot has a save (in-game Load / Game Over screen).
static func has_save() -> bool:
	return ResourceLoader.exists(GameState.get_save_path())


## True when any save slot is used (main menu Load Game).
static func has_any_save() -> bool:
	for slot: int in range(1, GameState.SAVE_SLOT_COUNT + 1):
		if GameState.slot_has_save(slot):
			return true
	return false


## The slot saved most recently, or 0 when there are no saves.
static func latest_slot() -> int:
	var best: int = 0
	var best_time: int = -1
	for slot: int in range(1, GameState.SAVE_SLOT_COUNT + 1):
		if GameState.slot_has_save(slot):
			var modified: int = int(FileAccess.get_modified_time(GameState.slot_path(slot)))
			if modified > best_time:
				best_time = modified
				best = slot
	return best


## Two lines for the save-slot list: "SLOT 2  ·  Whiskers Lv 4 +3" / "FeroShaw  ·  2026-11-11 14:03  ·  2h 05m".
## `save` = GameState.read_slot(slot) (null = empty slot).
static func describe_save(slot: int, save: SaveGame) -> String:
	if save == null:
		return "SLOT %d\nEmpty" % slot
	var leader: String = ""
	var others: int = 0
	if save.party != null and save.party.slots != null:
		for member: Variant in save.party.slots:
			var cat: CatCharacter = member as CatCharacter
			if cat == null:
				continue
			if leader.is_empty():
				leader = "%s Lv %d" % [cat.name, cat.level]
			else:
				others += 1
	var top: String = "SLOT %d" % slot
	if not leader.is_empty():
		top += "  ·  " + leader + ("  +%d" % others if others > 0 else "")
	var parts: PackedStringArray = []
	if not save.location_name.is_empty():
		parts.append(save.location_name)
	if not save.save_timestamp.is_empty():
		parts.append(save.save_timestamp.replace("T", " ").left(16))
	var minutes: int = int(save.play_time_seconds / 60.0)
	parts.append("%dh %02dm" % [minutes / 60, minutes % 60])
	return top + "\n" + "  ·  ".join(parts)


## "2026-11-06 14:03 · FeroShaw" style label of the save (time + where), or "" when unknown.
static func get_save_timestamp() -> String:
	if not has_save():
		return ""
	# CACHE_MODE_IGNORE: read a fresh copy without touching the live party objects.
	var save: SaveGame = ResourceLoader.load(GameState.get_save_path(), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	if save == null or save.save_timestamp.is_empty():
		return ""
	var label: String = save.save_timestamp.replace("T", " ").left(16)
	if not save.location_name.is_empty():
		label += "  ·  " + save.location_name
	return label


## Wipes the session's save slot, rebuilds the TEST party (Data/default_save.tres) and opens the game world.
## Players start through the roster instead (start_new_game_with_roster); this is the debug Quick Start.
static func start_new_game(tree: SceneTree) -> void:
	_clear_running_session(tree)
	GameState.reset_to_starter_party()
	MenuKit.change_scene(GAME_SCENE)


## Wipes the session's save slot (GameState.save_slot - the main menu picks it before opening the
## roster) and starts a new game with characters from the roster (Character Creator).
## `slot_ids`: 6 roster ids, "" for an empty slot (0-2 front row, 3-5 back row). The game plays with
## copies; the roster characters are locked (no more edits) once the game starts.
## Plays the intro video (INTRO_SCENE) before the world opens.
static func start_new_game_with_roster(tree: SceneTree, slot_ids: Array) -> bool:
	var party: DungeonParty = CharacterRoster.build_party(slot_ids)
	if party.get_viable_combatants().is_empty():
		return false
	_clear_running_session(tree)
	GameState.start_new_game_with_party(party)
	CharacterRoster.lock(slot_ids.filter(func(id: Variant) -> bool: return not str(id).is_empty()))
	# The new-game save (GreenGrove @ SpawnPointNewGame) is already written; play the intro, then the world.
	MenuKit.change_scene(INTRO_SCENE)
	return true


## Loads save slot `slot` and opens the game world; that slot becomes the session's slot.
## Returns false (and keeps the old slot) if the save is unusable.
static func load_slot(tree: SceneTree, slot: int) -> bool:
	var previous: int = GameState.save_slot
	GameState.dev_session = false
	GameState.set_save_slot(slot)
	if load_saved_game(tree):
		return true
	GameState.set_save_slot(previous)
	return false


## Loads the session's save slot and (re)opens the game world. Returns false if the save is unusable.
static func load_saved_game(tree: SceneTree) -> bool:
	if not GameState.load_game():
		return false
	GameState.session_active = true
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
	# Back at the title screen: no session, and the menu shows the player save again (not the dev one).
	GameState.session_active = false
	GameState.dev_session = false
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
