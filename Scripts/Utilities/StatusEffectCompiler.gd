@tool
extends EditorScript
class_name StatusEffectCompiler

const CSV_PATH: String = "res://Data/status_effects.csv"
const OUTPUT_DIR: String = "res://Data/StatusEffects/"

func _run() -> void:
	compile_csv()

func compile_csv() -> void:
	if not FileAccess.file_exists(CSV_PATH):
		push_error("StatusEffectCompiler: CSV file not found at %s" % CSV_PATH)
		return

	var dir := DirAccess.open("res://Data/")
	if dir and not dir.dir_exists("StatusEffects"):
		dir.make_dir("StatusEffects")

	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if not file:
		push_error("StatusEffectCompiler: Failed to open CSV file.")
		return

	# Skip CSV Header
	var _header := file.get_line()
	var count: int = 0

	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 15 or line[0].strip_edges().is_empty():
			continue

		var resource := StatusEffectData.new()
		resource.effect_id = line[0].strip_edges()
		resource.name = line[1].strip_edges()
		resource.description = line[2].strip_edges()
		resource.level = line[3].to_int()
		resource.type = _parse_effect_type(line[4].strip_edges())
		resource.element = _parse_element(line[5].strip_edges())
		resource.duration = line[6].to_int()
		resource.modifier_stat = _parse_stat(line[7].strip_edges())
		resource.modifier_type = _parse_mod_type(line[8].strip_edges())
		resource.modifier_value = line[9].to_float()
		resource.max_stacks = line[10].to_int()
		resource.cured_by = line[11].strip_edges()
		resource.is_cleansable = line[12].strip_edges().to_lower() == "true"
		resource.is_dispellable = line[13].strip_edges().to_lower() == "true"
		resource.icon_path = line[14].strip_edges()

		var save_path: String = OUTPUT_DIR + resource.effect_id + ".tres"
		var err := ResourceSaver.save(resource, save_path)
		if err == OK:
			count += 1
		else:
			push_error("Failed to save status effect: %s (Error %d)" % [save_path, err])

	print("StatusEffectCompiler: Successfully compiled %d status effect resources into %s" % [count, OUTPUT_DIR])

func _parse_effect_type(val: String) -> StatusEffectData.EffectType:
	match val.to_upper():
		"NEGATIVE": return StatusEffectData.EffectType.NEGATIVE
		_: return StatusEffectData.EffectType.POSITIVE

func _parse_element(val: String) -> StatusEffectData.EffectElement:
	match val.to_upper():
		"NATURE": return StatusEffectData.EffectElement.NATURE
		"ARCANE": return StatusEffectData.EffectElement.ARCANE
		"BIO": return StatusEffectData.EffectElement.BIO
		"FIRE": return StatusEffectData.EffectElement.FIRE
		"WATER": return StatusEffectData.EffectElement.WATER
		_: return StatusEffectData.EffectElement.NONE

func _parse_stat(val: String) -> StatusEffectData.ModifierStat:
	match val.to_upper():
		"DEF": return StatusEffectData.ModifierStat.DEF
		"ATK": return StatusEffectData.ModifierStat.ATK
		"ACC": return StatusEffectData.ModifierStat.ACC
		"DEX": return StatusEffectData.ModifierStat.DEX
		"MAG": return StatusEffectData.ModifierStat.MAG
		"SPD": return StatusEffectData.ModifierStat.SPD
		"HP": return StatusEffectData.ModifierStat.HP
		_: return StatusEffectData.ModifierStat.NONE

func _parse_mod_type(val: String) -> StatusEffectData.ModifierType:
	match val.to_upper():
		"PERCENT_MAX_HP_HEAL": return StatusEffectData.ModifierType.PERCENT_MAX_HP_HEAL
		"PERCENT_SHIELD": return StatusEffectData.ModifierType.PERCENT_SHIELD
		"PERCENT_MAGIC_SHIELD": return StatusEffectData.ModifierType.PERCENT_MAGIC_SHIELD
		"PERCENT_MAX_HP_TICK": return StatusEffectData.ModifierType.PERCENT_MAX_HP_TICK
		"CC_SKIP_TURN": return StatusEffectData.ModifierType.CC_SKIP_TURN
		"CC_LOCK_MAGIC": return StatusEffectData.ModifierType.CC_LOCK_MAGIC
		_: return StatusEffectData.ModifierType.MULTIPLIER
