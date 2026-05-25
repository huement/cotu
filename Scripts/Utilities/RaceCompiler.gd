@tool
extends EditorScript

const CSV_PATH: String = "res://Character_Races_Races.csv"
const OUT_DIR: String = "res://Data/Races/"

func _run() -> void:
	if not FileAccess.file_exists(CSV_PATH):
		printerr("Race Compiler Error: Missing source CSV file at: ", CSV_PATH)
		return

	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_absolute(OUT_DIR)

	var file := FileAccess.open(CSV_PATH, FileAccess.READ)

	# Skip the header row ( #, Race Name, Based On, Description... )
	var _header: PackedStringArray = file.get_csv_line()

	var count: int = 0
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()

		# Safely filter out short engine data rows or trailing empty spreadsheet lines
		if row.size() < 11 or row[1].strip_edges() == "":
			continue

		var breed := CatBreed.new()
		breed.breed_name = row[1].strip_edges()
		breed.description = row[3].strip_edges()

		# Map the classic Wizardry 7 attributes directly from row indices 4 through 10
		breed.base_strength = int(row[4])
		breed.base_intelligence = int(row[5])
		breed.base_piety = int(row[6])
		breed.base_vitality = int(row[7])
		breed.base_dexterity = int(row[8])
		breed.base_speed = int(row[9])
		breed.base_personality = int(row[10])

		# Build a safe pascal-cased naming convention for files (e.g., ScottishFold.tres)
		var safe_name: String = breed.breed_name.to_pascal_case()
		var save_path: String = OUT_DIR + safe_name + ".tres"

		var error := ResourceSaver.save(breed, save_path)
		if error == OK:
			count += 1
		else:
			printerr("Failed to save breed asset file for: ", breed.breed_name, " Error Code: ", error)

	print("Data Compiler Success: Generated ", count, " Cat Breed files into ", OUT_DIR)
