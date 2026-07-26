# res://Scripts/Utilities/DataCompiler.gd
@tool
extends EditorScript

const CSV_PATH: String = "res://Character_Races_Professions.csv"
const OUTPUT_DIR: String = "res://Data/Classes/"

func _run() -> void:
	compile_professions()

func compile_professions() -> void:
	if not FileAccess.file_exists(CSV_PATH):
		printerr("Data Compiler Error: Cannot find CSV file at ", CSV_PATH)
		return
		
	# Ensure the output directory exists
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_absolute(OUTPUT_DIR)
		
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	
	# Skip the header row
	var header: PackedStringArray = file.get_csv_line()
	
	var count: int = 0
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		# Skip empty/corrupted lines
		if line.size() < 10 or line[0].strip_edges() == "":
			continue
			
		var prof_id: String = line[0].strip_edges()
		var prof_name: String = line[1].strip_edges()
		var based_on: String = line[2].strip_edges()
		
		# Instantiate a clean instance of your script data class
		var prof_res := ProfessionData.new()
		prof_res.profession_name = prof_name
		prof_res.classic_counterpart = based_on
		
		# Map the attribute gate limits directly from the CSV spreadsheet
		prof_res.req_strength = int(line[3])
		prof_res.req_intelligence = int(line[4])
		prof_res.req_piety = int(line[5])
		prof_res.req_vitality = int(line[6])
		prof_res.req_dexterity = int(line[7])
		prof_res.req_speed = int(line[8])
		prof_res.req_personality = int(line[9])
		
		prof_res.spellbook_type = line[10].strip_edges()
		# Handle unlock tier mapping logic safely
		prof_res.level_spells_unlock = 1 if line[11].contains("Lvl 1") else (3 if line[11].contains("Lvl 3") else 5)
		
		# Sanitize string naming conventions for system storage paths
		var safe_name: String = prof_name.to_pascal_case()
		var save_path: String = OUTPUT_DIR + safe_name + ".tres"
		
		var error := ResourceSaver.save(prof_res, save_path)
		if error == OK:
			count += 1
		else:
			printerr("Failed to save resource for: ", prof_name, " Code: ", error)
			
	print("Data Compiler Success: Compiled ", count, " Profession files into ", OUTPUT_DIR)
