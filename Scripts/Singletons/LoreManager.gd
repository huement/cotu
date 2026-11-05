# res://Scripts/Singletons/LoreManager.gd
extends Node
## Autoload "LoreManager". Loads Data/Lore/Bosses.csv (imported as "Keep File") into LoreData rows.
## Columns are read by header name, so they can be reordered and new ones added freely.
## Boss chambers look their row up with get_lore_by_id(boss_id).

const LORE_CSV_PATH: String = "res://Data/Lore/Bosses.csv"
const GROUP_SEPARATOR: String = "|" # between chests
const ITEM_SEPARATOR: String = ";" # between items in one chest

## In-memory cache of all lore entries (CSV order)
var lore_database: Array[LoreData] = []

## Tracks player progression count
var unlocked_count: int = 0

var _by_id: Dictionary[int, LoreData] = {}


func _ready() -> void:
	load_lore_csv()


func load_lore_csv() -> void:
	lore_database.clear()
	_by_id.clear()

	if not FileAccess.file_exists(LORE_CSV_PATH):
		push_error("LoreManager: Could not find CSV at ", LORE_CSV_PATH)
		return

	var file := FileAccess.open(LORE_CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("LoreManager: Failed to open CSV file.")
		return

	var header: PackedStringArray = file.get_csv_line()
	var columns: Dictionary[String, int] = {}
	for i: int in range(header.size()):
		columns[header[i].strip_edges().to_lower()] = i

	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.is_empty() or line[0].strip_edges().is_empty() or line[0].begins_with("#"):
			continue
		var row: Dictionary[String, String] = {}
		for key: String in columns:
			var idx: int = columns[key]
			row[key] = line[idx].strip_edges() if idx < line.size() else ""
		var lore: LoreData = _parse_row(row)
		lore_database.append(lore)
		_by_id[lore.id] = lore


func _parse_row(row: Dictionary[String, String]) -> LoreData:
	var lore := LoreData.new()
	lore.id = _cell(row, "id", "0").to_int()
	lore.title = _cell(row, "title", "")
	lore.description = _cell(row, "description", "")

	var ascii_path: String = _cell(row, "ascii_file_path", "")
	if not ascii_path.is_empty() and FileAccess.file_exists(ascii_path):
		lore.ascii_art = FileAccess.get_file_as_string(ascii_path)
	lore.loot_item = _load_item(_cell(row, "loot_item_path", ""), false)
	lore.sfx_path = _cell(row, "sfx_path", "")
	lore.sound_effect = _load_typed(lore.sfx_path, "AudioStream", false) as AudioStream
	lore.shader_material = _load_typed(_cell(row, "shader_path", ""), "ShaderMaterial", false) as ShaderMaterial

	# Boss
	lore.boss_scene_path = _cell(row, "boss_scene", "")
	lore.enemy_data = _load_typed(_cell(row, "enemy_data_path", ""), "EnemyData") as EnemyData
	lore.boss_name = _cell(row, "boss_name", "")
	lore.boss_level = _cell(row, "boss_level", "0").to_int()
	lore.boss_scale = _cell(row, "boss_scale", "0").to_float()
	var minions: String = _cell(row, "has_minions", "").to_lower()
	if not minions.is_empty():
		lore.has_minions = 1 if minions in ["true", "yes", "1"] else 0

	# Reward side
	var side: String = _cell(row, "reward_side", "").to_lower()
	if side in [LoreData.SIDE_EAST, LoreData.SIDE_WEST, LoreData.SIDE_NONE]:
		lore.reward_side = side
	elif not side.is_empty():
		push_warning("LoreManager: row %d has reward_side '%s' (use east, west or none)." % [lore.id, side])
	lore.side_open_sfx = _cell(row, "side_open_sfx", "")
	var gold_text: String = _cell(row, "chest_gold", "")
	if not gold_text.is_empty():
		for part: String in gold_text.split(GROUP_SEPARATOR):
			lore.chest_gold.append(part.strip_edges().to_int())
	var items_text: String = _cell(row, "chest_items", "")
	if not items_text.is_empty():
		for group: String in items_text.split(GROUP_SEPARATOR):
			var items: Array[ItemData] = []
			for path: String in group.split(ITEM_SEPARATOR, false):
				var item: ItemData = _load_item(path.strip_edges())
				if item != null:
					items.append(item)
			lore.chest_items.append(items)

	# Lore object in the reward room
	lore.aura_type = _cell(row, "aura_type", "").to_lower()
	var xp_text: String = _cell(row, "xp_reward", "")
	if not xp_text.is_empty():
		lore.xp_reward = xp_text.to_int()
	lore.scare_flash_texture = _load_typed(_cell(row, "scare_flash_texture", ""), "Texture2D") as Texture2D
	var shake_text: String = _cell(row, "scare_shake", "")
	if not shake_text.is_empty():
		lore.scare_shake = shake_text.to_float()
	var hold_text: String = _cell(row, "scare_hold", "")
	if not hold_text.is_empty():
		lore.scare_hold = hold_text.to_float()

	# North gate
	lore.exit_scene = _cell(row, "exit_scene", "")
	var arrival: String = _cell(row, "exit_arrival", "")
	if not arrival.is_empty():
		lore.exit_arrival = arrival
	lore.exit_prompt = _cell(row, "exit_prompt", "")
	lore.exit_requires_boss = not (_cell(row, "exit_requires_boss", "true").to_lower() in ["false", "no", "0"])
	return lore


func _cell(row: Dictionary[String, String], key: String, fallback: String = "") -> String:
	var value: String = row.get(key, "")
	return fallback if value.is_empty() else value


func _load_item(path: String, warn: bool = true) -> ItemData:
	return _load_typed(path, "ItemData", warn) as ItemData


## Loads a resource if the path is set and exists. Lore assets that aren't made yet are skipped
## quietly (warn = false); anything a boss chamber needs warns when it's missing.
func _load_typed(path: String, type_name: String, warn: bool = true) -> Resource:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		if warn:
			push_warning("LoreManager: %s not found: %s" % [type_name, path])
		return null
	return load(path)


## The row with this id (the CSV "id" column), or null.
func get_lore_by_id(lore_id: int) -> LoreData:
	return _by_id.get(lore_id, null) as LoreData


## Unlocks and returns the next sequential lore entry regardless of which statue is touched
func advance_and_get_lore() -> LoreData:
	if unlocked_count >= lore_database.size():
		return null # All lore entries have been discovered

	var next_lore: LoreData = lore_database[unlocked_count]
	unlocked_count += 1
	return next_lore


## Peek or re-read an already collected lore entry by 0-based index
func get_lore_by_index(index: int) -> LoreData:
	if index >= 0 and index < lore_database.size():
		return lore_database[index]
	return null
