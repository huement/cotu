# res://Scripts/Utilities/SkillCompiler.gd
@tool
extends EditorScript

const CSV_PATHS: Array[String] = ["res://Data/Skills.csv", "res://Data/Skills/Skills.csv"]
const OUTPUT_DIR: String = "res://Data/Skills/"


func _run() -> void:
	compile_skills()


func compile_skills() -> void:
	var csv_path: String = _find_valid_csv_path()
	if csv_path.is_empty():
		printerr("Skill Compiler Error: Cannot find 'Skills.csv' in project root or Data folder!")
		return

	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		printerr("Skill Compiler Error: Failed to open CSV file at ", csv_path)
		return

	var _header: PackedStringArray = file.get_csv_line()
	var count: int = 0

	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() < 14 or line[0].strip_edges().is_empty():
			continue

		var skill := SkillData.new()
		skill.skill_id = line[0].strip_edges()
		skill.skill_name = line[1].strip_edges()
		skill.skill_type = _parse_skill_type(line[2].strip_edges())
		skill.energy_cost = int(line[3])
		skill.target_type = _parse_target_type(line[4].strip_edges())
		skill.effect_type = _parse_effect_type(line[5].strip_edges())
		skill.effect_amount = int(line[6])
		skill.element = _parse_element(line[7].strip_edges())

		var classes_str: String = line[8].strip_edges()
		var class_list: Array[String] = []
		if not classes_str.is_empty():
			for c in classes_str.split("|"):
				var trimmed: String = c.strip_edges()
				if not trimmed.is_empty():
					class_list.append(trimmed)
		skill.assigned_classes = class_list

		var races_str: String = line[9].strip_edges()
		var race_list: Array[String] = []
		if not races_str.is_empty():
			for r in races_str.split("|"):
				var trimmed: String = r.strip_edges()
				if not trimmed.is_empty():
					race_list.append(trimmed)
		skill.assigned_races = race_list

		skill.description = line[10].strip_edges()
		skill.icon_path = line[11].strip_edges()
		if not skill.icon_path.is_empty() and ResourceLoader.exists(skill.icon_path):
			skill.icon = load(skill.icon_path) as Texture2D
		skill.accuracy = int(line[12])
		skill.duration = int(line[13])

		# Column 14: status_effect
		if line.size() >= 15:
			skill.status_effect = _parse_status_effect(line[14].strip_edges(), skill.duration)
		else:
			skill.status_effect = "NONE"

		var save_path: String = OUTPUT_DIR + save_path_filename(skill.skill_id)

		var err := ResourceSaver.save(skill, save_path)
		if err == OK:
			count += 1
		else:
			printerr("Failed to save Skill resource for: ", skill.skill_name, " Error: ", err)

	print("Skill Compiler Success: Generated ", count, " Skill .tres files into ", OUTPUT_DIR)


func save_path_filename(id_str: String) -> String:
	return id_str.to_pascal_case() + ".tres"


func _find_valid_csv_path() -> String:
	for path in CSV_PATHS:
		if FileAccess.file_exists(path):
			return path
	return ""


func _parse_skill_type(s: String) -> SkillData.SkillType:
	match s.to_upper():
		"ENVIRONMENT":
			return SkillData.SkillType.ENVIRONMENT
		"INVENTORY":
			return SkillData.SkillType.INVENTORY
		_:
			return SkillData.SkillType.COMBAT


func _parse_target_type(s: String) -> SkillData.TargetType:
	match s.to_upper():
		"ALL_ENEMY", "ALL_ENEMIES":
			return SkillData.TargetType.ALL_ENEMY
		"SINGLE_ALLY":
			return SkillData.TargetType.SINGLE_ALLY
		"ALL_ALLY", "ALL_ALLIES", "ALL_PARTY":
			return SkillData.TargetType.ALL_ALLY
		"SELF":
			return SkillData.TargetType.SELF
		"NONE":
			return SkillData.TargetType.NONE
		_:
			return SkillData.TargetType.SINGLE_ENEMY


func _parse_effect_type(s: String) -> SkillData.EffectType:
	match s.to_upper():
		"HEAL":
			return SkillData.EffectType.HEAL
		"LOCKPICK":
			return SkillData.EffectType.LOCKPICK
		"STEALTH_SEARCH":
			return SkillData.EffectType.STEALTH_SEARCH
		"REST_BOOST":
			return SkillData.EffectType.REST_BOOST
		"CRAFT_AMMO":
			return SkillData.EffectType.CRAFT_AMMO
		"CRAFT_THROWABLE":
			return SkillData.EffectType.CRAFT_THROWABLE
		"CRAFT_POTION":
			return SkillData.EffectType.CRAFT_POTION
		"ENCHANT_EQUIPMENT":
			return SkillData.EffectType.ENCHANT_EQUIPMENT
		_:
			return SkillData.EffectType.DAMAGE


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


func _parse_status_effect(s: String, duration: int = 1) -> String:
	var clean_s: String = s.strip_edges()
	if clean_s.is_empty() or clean_s.to_upper() == "NONE":
		return "NONE"

	if clean_s.begins_with("eff_"):
		return clean_s

	var clamped_tier: int = clampi(duration, 1, 3)
	match clean_s.to_upper():
		"DEFENSE_DOWN":
			return "eff_defense_down_%d" % clamped_tier
		"ATTACK_DOWN":
			return "eff_attack_down_%d" % clamped_tier
		"SPEED_DOWN", "SLOW":
			return "eff_speed_down_%d" % clamped_tier
		"ACCURACY_DOWN":
			return "eff_accuracy_down_%d" % clamped_tier
		"DEXTERITY_DOWN":
			return "eff_dexterity_down_%d" % clamped_tier
		"MAGIC_DOWN":
			return "eff_magic_down_%d" % clamped_tier
		"DEFENSE_UP":
			return "eff_defense_up_%d" % clamped_tier
		"ATTACK_UP":
			return "eff_attack_up_%d" % clamped_tier
		"SPEED_UP", "HASTE":
			return "eff_speed_up_%d" % clamped_tier
		"ACCURACY_UP":
			return "eff_accuracy_up_%d" % clamped_tier
		"STUN":
			return "eff_stun_%d" % clamped_tier
		"POISON":
			return "eff_poison_%d" % clamped_tier
		"FREEZE":
			return "eff_freeze_%d" % clamped_tier
		"SILENCE":
			return "eff_silence_%d" % clamped_tier
		"SHIELD":
			return "eff_shield_%d" % clamped_tier
		"MAGIC_SHIELD":
			return "eff_magic_shield_%d" % clamped_tier
		"HEAL", "CONTINUOUS_HEAL":
			return "eff_continuous_heal_%d" % clamped_tier
		"HP_BURN", "BURN":
			return "eff_hp_burn_%d" % clamped_tier
		_:
			return clean_s
