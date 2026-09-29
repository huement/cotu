# res://Scripts/Utilities/ClassCompiler.gd
@tool
extends EditorScript

const CSV_PATH: String = "res://Data/Character_Classes.csv"
const OUTPUT_DIR: String = "res://Data/Classes/"

func _run() -> void:
	compile_professions()

func compile_professions() -> void:
	if not FileAccess.file_exists(CSV_PATH):
		printerr("Class Compiler Error: Cannot find CSV file at ", CSV_PATH)
		return
		
	# Ensure the output directory exists
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_absolute(OUTPUT_DIR)
		
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		printerr("Class Compiler Error: Failed to open ", CSV_PATH)
		return

	# Parse header row to dynamically locate column indices
	var header: PackedStringArray = file.get_csv_line()
	var col_map: Dictionary = _map_header_columns(header)
	
	var count: int = 0
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		# Skip empty or malformed lines
		if line.size() < 4 or line[0].strip_edges().is_empty():
			continue
			
		var prof_name: String = _get_col_val(line, col_map, "name", "1")
		if prof_name.is_empty():
			continue

		var based_on: String = _get_col_val(line, col_map, "based_on", "2")
		
		# Instantiate a clean ProfessionData resource
		var prof_res := ProfessionData.new()
		prof_res.profession_name = prof_name
		prof_res.classic_counterpart = based_on
		
		# Map attribute gate requirements from CSV
		prof_res.req_strength = int(_get_col_val(line, col_map, "str", "3"))
		prof_res.req_intelligence = int(_get_col_val(line, col_map, "int", "4"))
		prof_res.req_piety = int(_get_col_val(line, col_map, "pie", "5"))
		prof_res.req_vitality = int(_get_col_val(line, col_map, "vit", "6"))
		prof_res.req_dexterity = int(_get_col_val(line, col_map, "dex", "7"))
		prof_res.req_speed = int(_get_col_val(line, col_map, "spd", "8"))
		prof_res.req_personality = int(_get_col_val(line, col_map, "per", "9"))
		
		# Spellbook configuration
		prof_res.spellbook_type = _get_col_val(line, col_map, "spellbook", "10")
		var spell_lvl_str: String = _get_col_val(line, col_map, "spell_level", "11")
		prof_res.level_spells_unlock = 1 if "Lvl 1" in spell_lvl_str else (3 if "Lvl 3" in spell_lvl_str else 5)
		
		# Progression & Point Allocation per level
		prof_res.stat_points_per_level = int(_get_col_val_default(line, col_map, "stat_points", "5"))
		prof_res.skill_points_per_level = int(_get_col_val_default(line, col_map, "skill_points", "2"))
		prof_res.spell_points_per_level = int(_get_col_val_default(line, col_map, "spell_points", "1"))
		
		# Sanitize string naming conventions for system storage paths
		var safe_name: String = prof_name.to_pascal_case()
		var save_path: String = OUTPUT_DIR + safe_name + ".tres"
		
		var error := ResourceSaver.save(prof_res, save_path)
		if error == OK:
			count += 1
		else:
			printerr("Failed to save resource for: ", prof_name, " Code: ", error)
			
	print("Class Compiler Success: Compiled ", count, " Class files from ", CSV_PATH, " into ", OUTPUT_DIR)


func _map_header_columns(header: PackedStringArray) -> Dictionary:
	var map: Dictionary = {}
	for i in range(header.size()):
		var col_name: String = header[i].strip_edges().to_lower()
		map[col_name] = i
		if "name" in col_name and not map.has("name"): map["name"] = i
		elif "based" in col_name: map["based_on"] = i
		elif col_name == "str": map["str"] = i
		elif col_name == "int": map["int"] = i
		elif col_name == "pie": map["pie"] = i
		elif col_name == "vit": map["vit"] = i
		elif col_name == "dex": map["dex"] = i
		elif col_name == "spd": map["spd"] = i
		elif col_name == "per": map["per"] = i
		elif "spellbook" in col_name: map["spellbook"] = i
		elif "spell level" in col_name or "spell_level" in col_name: map["spell_level"] = i
		elif "stat point" in col_name or "stat_point" in col_name or "stat pts" in col_name: map["stat_points"] = i
		elif "skill point" in col_name or "skill_point" in col_name or "skill pts" in col_name: map["skill_points"] = i
		elif "spell point" in col_name or "spell_point" in col_name or "spell pts" in col_name: map["spell_points"] = i
	return map


func _get_col_val(line: PackedStringArray, col_map: Dictionary, key: String, fallback_idx_str: String) -> String:
	if col_map.has(key):
		var idx: int = col_map[key]
		if idx < line.size():
			return line[idx].strip_edges()
	var fallback_idx: int = int(fallback_idx_str)
	if fallback_idx < line.size():
		return line[fallback_idx].strip_edges()
	return ""


func _get_col_val_default(line: PackedStringArray, col_map: Dictionary, key: String, default_val: String) -> String:
	if col_map.has(key):
		var idx: int = col_map[key]
		if idx < line.size() and not line[idx].strip_edges().is_empty():
			return line[idx].strip_edges()
	return default_val
