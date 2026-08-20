# res://Scripts/Utilities/SpellCompiler.gd
@tool
extends EditorScript

const CSV_PATHS: Array[String] = ["res://Data/Spells.csv", "res://Data/Spells/Spells.csv"]
const OUTPUT_DIR: String = "res://Data/Spells/"


func _run() -> void:
	compile_spells()


func compile_spells() -> void:
	var csv_path: String = _find_valid_csv_path()
	if csv_path.is_empty():
		printerr("Spell Compiler Error: Cannot find 'Spells.csv'!")
		return

	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		printerr("Spell Compiler Error: Failed to open CSV file at ", csv_path)
		return

	var _header: PackedStringArray = file.get_csv_line()
	var count: int = 0

	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() < 17 or line[0].strip_edges().is_empty():
			continue

		var spell := SpellData.new()
		spell.spell_id = line[0].strip_edges()
		spell.spell_name = line[1].strip_edges()
		spell.spellbook = _parse_spellbook(line[2].strip_edges())
		spell.tier = int(line[3])
		spell.energy_cost = int(line[4])
		spell.element = _parse_element(line[5].strip_edges())
		spell.target_type = _parse_target_type(line[6].strip_edges())
		spell.effect_type = _parse_effect_type(line[7].strip_edges())
		spell.base_amount = int(line[8])
		spell.var_multiplier = float(line[9])
		spell.stat_scaling = line[10].strip_edges()
		spell.status_effect = _parse_status_effect(line[11].strip_edges(), spell.tier)
		spell.duration = int(line[12])
		spell.requirement = int(line[13])
		var class_locked_str: String = line[14].strip_edges().to_upper()
		spell.class_locked = (class_locked_str == "TRUE" or class_locked_str == "1")
		spell.description = line[15].strip_edges()
		spell.icon_path = line[16].strip_edges()

		if not spell.icon_path.is_empty() and ResourceLoader.exists(spell.icon_path):
			spell.icon = load(spell.icon_path) as Texture2D

		var save_path: String = OUTPUT_DIR + spell.spell_id.to_pascal_case() + ".tres"

		var err := ResourceSaver.save(spell, save_path)
		if err == OK:
			count += 1
		else:
			printerr("Failed to save Spell resource for: ", spell.spell_name, " Error: ", err)

	print("Spell Compiler Success: Generated ", count, " Spell .tres files into ", OUTPUT_DIR)


func _find_valid_csv_path() -> String:
	for path in CSV_PATHS:
		if FileAccess.file_exists(path):
			return path
	return ""


func _parse_spellbook(s: String) -> SpellData.SpellbookType:
	match s.to_upper():
		"SOULWRIGHT":
			return SpellData.SpellbookType.SOULWRIGHT
		"MAESTER":
			return SpellData.SpellbookType.MAESTER
		"PSYNIC":
			return SpellData.SpellbookType.PSYNIC
		_:
			return SpellData.SpellbookType.ARCHANIST


func _parse_element(s: String) -> ItemData.EffectElement:
	match s.to_upper():
		"FIRE":
			return ItemData.EffectElement.MAGIC
		"LIFE", "HOLY":
			return ItemData.EffectElement.LIFE
		"BASH", "ACID":
			return ItemData.EffectElement.BASH
		"BLADE":
			return ItemData.EffectElement.BLADE
		_:
			return ItemData.EffectElement.MAGIC


func _parse_target_type(s: String) -> SpellData.TargetType:
	match s.to_upper():
		"ALL_ENEMY", "ALL_ENEMIES":
			return SpellData.TargetType.ALL_ENEMY
		"SINGLE_ALLY":
			return SpellData.TargetType.SINGLE_ALLY
		"ALL_ALLY", "ALL_ALLIES", "ALL_PARTY":
			return SpellData.TargetType.ALL_ALLY
		"SELF":
			return SpellData.TargetType.SELF
		_:
			return SpellData.TargetType.SINGLE_ENEMY


func _parse_effect_type(s: String) -> SpellData.EffectType:
	match s.to_upper():
		"HEAL":
			return SpellData.EffectType.HEAL
		"BUFF":
			return SpellData.EffectType.BUFF
		"DEBUFF":
			return SpellData.EffectType.DEBUFF
		"UTILITY":
			return SpellData.EffectType.UTILITY
		_:
			return SpellData.EffectType.DAMAGE


func _parse_status_effect(s: String, tier: int = 1) -> String:
	var clean_s: String = s.strip_edges()
	if clean_s.is_empty() or clean_s.to_upper() == "NONE":
		return "NONE"

	# Pass through explicit ID references (e.g. "eff_defense_down_1")
	if clean_s.begins_with("eff_"):
		return clean_s

	# Map short CSV keywords to status_effects.csv IDs using the spell's tier level
	var clamped_tier: int = clampi(tier, 1, 3)
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
