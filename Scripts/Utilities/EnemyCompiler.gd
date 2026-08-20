@tool
extends EditorScript
class_name EnemyCompiler

const CSV_PATHS: Array[String] = ["res://Enemies.csv", "res://Data/Enemies.csv", "res://Data/Enemies/Enemies.csv"]
const OUTPUT_DIR: String = "res://Data/Enemies/"
const MATERIAL_DIR: String = "res://resources/Enemies/Kenny/Materials/"


func _run() -> void:
	compile_enemies()


func compile_enemies() -> void:
	var csv_path: String = _find_valid_csv_path()
	if csv_path.is_empty():
		printerr("EnemyCompiler Error: Cannot find 'Enemies.csv' in project root or Data folder!")
		return

	_ensure_directories_exist()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		printerr("EnemyCompiler Error: Failed to open CSV file at ", csv_path)
		return

	var _header: PackedStringArray = file.get_csv_line()
	var count: int = 0

	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() < 28 or line[0].strip_edges().is_empty():
			continue

		var enemy := EnemyData.new()
		enemy.enemy_id = line[0].strip_edges()
		enemy.enemy_name = line[1].strip_edges()
		enemy.model_path = line[2].strip_edges()
		enemy.texture_path = line[3].strip_edges()
		enemy.base_level = int(line[4])
		enemy.scale_with_player = line[5].strip_edges().to_lower() == "true"
		enemy.max_health = int(line[6])
		enemy.current_health = enemy.max_health
		enemy.attack_damage = int(line[7])
		enemy.defense = int(line[8])
		enemy.speed = float(line[9])
		enemy.initiative_speed = int(line[10])
		enemy.weakness_element = _parse_element(line[11].strip_edges())
		enemy.attack_element = _parse_element(line[12].strip_edges())
		enemy.equipped_weapon_id = line[13].strip_edges()
		enemy.equipped_item_id = line[14].strip_edges()
		enemy.can_cast_spells = line[15].strip_edges().to_lower() == "true"
		enemy.spell_ids = _parse_string_list(line[16].strip_edges())
		enemy.max_mana = int(line[17])
		enemy.occurs_in_groups = line[18].strip_edges().to_lower() == "true"
		enemy.min_group_size = int(line[19])
		enemy.max_group_size = int(line[20])
		enemy.movement_speed = float(line[21])
		enemy.aggro_range_tiles = int(line[22])
		enemy.can_surprise_player = line[23].strip_edges().to_lower() == "true"
		enemy.can_be_surprised = line[24].strip_edges().to_lower() == "true"
		enemy.xp_value = int(line[25])
		enemy.gold_value = int(line[26])
		enemy.drops_loot = line[27].strip_edges().to_lower() == "true"

		# Load 3D GLB mesh
		if not enemy.model_path.is_empty() and ResourceLoader.exists(enemy.model_path):
			enemy.model_scene = load(enemy.model_path) as PackedScene

		# Generate or load unshaded StandardMaterial3D for the texture
		if not enemy.texture_path.is_empty() and ResourceLoader.exists(enemy.texture_path):
			enemy.custom_material = _create_or_load_material(enemy.texture_path, enemy.enemy_id)

		var save_path: String = OUTPUT_DIR + enemy.enemy_id.to_pascal_case() + ".tres"
		var err := ResourceSaver.save(enemy, save_path)
		if err == OK:
			count += 1
		else:
			printerr("Failed to save Enemy resource for: ", enemy.enemy_name, " Error: ", err)

	print("EnemyCompiler Success: Compiled ", count, " Enemy .tres files into ", OUTPUT_DIR)


func _create_or_load_material(tex_path: String, id_str: String) -> StandardMaterial3D:
	var mat_file_name: String = id_str + "_mat.tres"
	var full_mat_path: String = MATERIAL_DIR + mat_file_name

	if ResourceLoader.exists(full_mat_path):
		return load(full_mat_path) as StandardMaterial3D

	var tex := load(tex_path) as Texture2D
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	ResourceSaver.save(mat, full_mat_path)
	return mat


func _ensure_directories_exist() -> void:
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(MATERIAL_DIR):
		DirAccess.make_dir_recursive_absolute(MATERIAL_DIR)


func _find_valid_csv_path() -> String:
	for path in CSV_PATHS:
		if FileAccess.file_exists(path):
			return path
	return ""


func _parse_element(s: String) -> ItemData.EffectElement:
	match s.to_upper():
		"BLADE":
			return ItemData.EffectElement.BLADE
		"BASH":
			return ItemData.EffectElement.BASH
		"RANGED":
			return ItemData.EffectElement.RANGED
		"MAGIC":
			return ItemData.EffectElement.MAGIC
		"LIFE":
			return ItemData.EffectElement.LIFE
		_:
			return ItemData.EffectElement.NONE


func _parse_string_list(s: String) -> Array[String]:
	var result: Array[String] = []
	if s.is_empty() or s.to_upper() == "NONE":
		return result
	for part in s.split("|"):
		var trimmed: String = part.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result
