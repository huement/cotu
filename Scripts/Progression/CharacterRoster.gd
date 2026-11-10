# res://Scripts/Progression/CharacterRoster.gd
class_name CharacterRoster
extends RefCounted
## Every character the player has created, kept outside any save game (user://character_pool/).
## One .tres per character, named by its roster_id. A roster character can be edited / deleted until it
## is taken into a game (roster_locked); the game itself always plays with COPIES (copies_for_game), so
## the roster keeps the character exactly as it was created.
##
##   CharacterRoster.save(cat)                 # assigns roster_id on first save
##   CharacterRoster.list()                    # Array[CatCharacter], oldest first
##   CharacterRoster.remove(cat)               # refused when locked
##   var party: DungeonParty = CharacterRoster.build_party(["id_a", "", "id_b", ...])   # 6 slots, "" = empty
##
## Tests: tests/progression/test_character_creation.gd (uses a temporary pool_dir).

const DEFAULT_DIR: String = "user://character_pool/"
const PARTY_SIZE: int = 6

## Where the roster lives. Tests point this at a scratch folder.
static var pool_dir: String = DEFAULT_DIR


static func path_for(roster_id: String) -> String:
	return pool_dir + roster_id + ".tres"


static func new_roster_id(char_name: String) -> String:
	var base: String = char_name.to_lower().validate_filename().replace(" ", "_")
	if base.is_empty():
		base = "cat"
	return "%s_%d_%04d" % [base.left(12), int(Time.get_unix_time_from_system()), randi() % 10000]


## Writes the character. Locked characters can't be saved over. Returns OK / an Error.
static func save(cat: CatCharacter) -> Error:
	if cat == null:
		return ERR_INVALID_PARAMETER
	if cat.roster_id.is_empty():
		cat.roster_id = new_roster_id(cat.name)
	elif cat.roster_locked and FileAccess.file_exists(path_for(cat.roster_id)):
		var on_disk: CatCharacter = load_character(cat.roster_id)
		if on_disk != null and on_disk.roster_locked:
			return ERR_LOCKED
	_ensure_dir()
	var err: Error = ResourceSaver.save(cat, path_for(cat.roster_id))
	if err != OK:
		push_error("CharacterRoster: couldn't save '%s' (error %d)." % [cat.name, err])
	return err


## Fresh copy from disk (never the cached instance), or null.
static func load_character(roster_id: String) -> CatCharacter:
	var path: String = path_for(roster_id)
	if roster_id.is_empty() or not FileAccess.file_exists(path):
		return null
	var cat: CatCharacter = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CatCharacter
	if cat == null:
		return null
	if cat.roster_id.is_empty():
		cat.roster_id = roster_id
	# Pick up class portraits drawn after the character was made.
	if cat.portrait_path.is_empty() or cat.portrait_path == CharacterCreation.FALLBACK_PORTRAIT:
		cat.portrait_path = CharacterCreation.resolved_portrait_path(cat.profession as ProfessionData)
	cat._calculate_vitals()
	if cat.current_hp <= 0 or cat.current_hp > cat.max_hp:
		cat.current_hp = cat.max_hp
	cat.stats.health = cat.current_hp
	return cat


## Every roster character, in creation order (roster ids carry the creation time).
static func list() -> Array[CatCharacter]:
	var result: Array[CatCharacter] = []
	if not DirAccess.dir_exists_absolute(pool_dir):
		return result
	var files: PackedStringArray = DirAccess.get_files_at(pool_dir)
	var entries: Array[Dictionary] = []
	for f: String in files:
		if not f.ends_with(".tres"):
			continue
		var cat: CatCharacter = load_character(f.get_basename())
		if cat != null:
			entries.append({ "cat": cat, "t": FileAccess.get_modified_time(pool_dir + f), "id": f.get_basename() })
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _created_at(str(a["id"])) < _created_at(str(b["id"])) if _created_at(str(a["id"])) != _created_at(str(b["id"])) else str(a["id"]) < str(b["id"]))
	for e: Dictionary in entries:
		result.append(e["cat"] as CatCharacter)
	return result


static func count() -> int:
	return list().size()


## Deletes an unlocked character. Returns false when locked / missing.
static func remove(cat: CatCharacter) -> bool:
	if cat == null or cat.roster_id.is_empty():
		return false
	var on_disk: CatCharacter = load_character(cat.roster_id)
	if on_disk == null or on_disk.roster_locked:
		return false
	return DirAccess.remove_absolute(path_for(cat.roster_id)) == OK


static func is_locked(roster_id: String) -> bool:
	var cat: CatCharacter = load_character(roster_id)
	return cat != null and cat.roster_locked


## Marks roster characters as used in a game (no more edits). Returns how many were locked.
static func lock(roster_ids: Array) -> int:
	var n: int = 0
	for id: Variant in roster_ids:
		var cat: CatCharacter = load_character(str(id))
		if cat == null:
			continue
		if not cat.roster_locked:
			cat.roster_locked = true
			if ResourceSaver.save(cat, path_for(cat.roster_id)) == OK:
				n += 1
		else:
			n += 1
	return n


## A 6-slot party of fresh copies. `slot_ids[i]` is the roster id for slot i ("" = empty).
## Slots 0-2 are the front row, 3-5 the back row. The copies are full HP/MP with no inventory set yet.
static func build_party(slot_ids: Array) -> DungeonParty:
	var party := DungeonParty.new()
	for i: int in PARTY_SIZE:
		var id: String = str(slot_ids[i]) if i < slot_ids.size() else ""
		var cat: CatCharacter = load_character(id) if not id.is_empty() else null
		if cat == null:
			continue
		cat.roster_locked = true
		cat.is_front_row = i < 3
		cat.current_hp = cat.max_hp
		cat.stats.health = cat.max_hp
		cat.current_energy = cat.max_energy
		party.slots[i] = cat
	return party


static func _created_at(roster_id: String) -> int:
	var parts: PackedStringArray = roster_id.split("_")
	return int(parts[parts.size() - 2]) if parts.size() >= 3 else 0


static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(pool_dir):
		DirAccess.make_dir_recursive_absolute(pool_dir)
