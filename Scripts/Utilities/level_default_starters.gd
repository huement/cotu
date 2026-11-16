# res://Scripts/Utilities/level_default_starters.gd
# One-shot: godot --path . --headless -s Scripts/Utilities/level_default_starters.gd
## Points Data/default_save.tres at the characters in Data/StarterParty (in creation order, first
## three = front row) and keeps its supplies (pack, gold, floor) as they are.
##
## The game itself no longer depends on this file's party list: the test party (dev start, debug
## Quick Start) is always built from Data/StarterParty by GameState._load_default_save(), which also
## adds the test loadout (GameState.TEST_PARTY_WEAPON_PATH on everyone who can use it, plus
## TEST_PARTY_REVIVE_POTIONS Revive Potions). Run this after adding / removing a starter so
## default_save.tres reads the same as what the game loads.
extends SceneTree

const SAVE_PATH: String = "res://Data/default_save.tres"
const STARTER_PARTY_DIR: String = "res://Data/StarterParty/"
const PARTY_SIZE: int = 6


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var save: SaveGame = load(SAVE_PATH) as SaveGame if ResourceLoader.exists(SAVE_PATH) else null
	if save == null:
		push_error("level_default_starters: can't load %s" % SAVE_PATH)
		quit(1)
		return

	var paths: Array[String] = _starter_paths()
	if paths.is_empty():
		push_error("level_default_starters: no characters in %s" % STARTER_PARTY_DIR)
		quit(1)
		return

	# Loaded (not copied) so default_save.tres keeps referencing the starter files.
	var party := DungeonParty.new()
	for i: int in paths.size():
		var cat: CatCharacter = load(paths[i]) as CatCharacter
		if cat == null:
			push_error("level_default_starters: %s is not a character" % paths[i])
			quit(1)
			return
		party.slots[i] = cat
		print("  slot %d (%s row): %s - %s" % [i, "front" if i < 3 else "back", cat.name, paths[i].get_file()])
	save.party = party

	var err: Error = ResourceSaver.save(save, SAVE_PATH)
	if err != OK:
		push_error("level_default_starters: couldn't write %s (%s)" % [SAVE_PATH, error_string(err)])
		quit(1)
		return
	print("level_default_starters: %s now lists %d starters from %s" % [SAVE_PATH, paths.size(), STARTER_PARTY_DIR])
	quit(0)


## Same order as CharacterRoster.starter_party_paths(): by the creation time in the roster id
## (name_<unix time>_<rand>), so the first three made are the front row.
func _starter_paths() -> Array[String]:
	var ids: Array[String] = []
	for file: String in DirAccess.get_files_at(STARTER_PARTY_DIR):
		if file.ends_with(".tres"):
			ids.append(file.get_basename())
	ids.sort_custom(func(a: String, b: String) -> bool:
		return _created_at(a) < _created_at(b) if _created_at(a) != _created_at(b) else a < b)
	var paths: Array[String] = []
	for id: String in ids.slice(0, PARTY_SIZE):
		paths.append(STARTER_PARTY_DIR + id + ".tres")
	return paths


func _created_at(roster_id: String) -> int:
	var parts: PackedStringArray = roster_id.split("_")
	return int(parts[parts.size() - 2]) if parts.size() >= 3 else 0
