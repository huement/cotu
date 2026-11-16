# res://Scripts/Progression/ClassProgression.gd
class_name ClassProgression
extends RefCounted
## Per-class leveling rules read from res://Data/Class_Progression.csv (edit the sheet, no compile step).
## Rows are ordered easiest -> hardest: harder classes need more XP but gain more per level.
## Tests: res://tests/progression/test_class_progression.gd
##
## Columns (header names, case-insensitive):
##   Name, Aliases (comma list), Difficulty, Difficulty Label,
##   Base XP, XP Growth          -> XP to go from level L to L+1 = Base XP * L ^ XP Growth
##   Max Level,
##   HP Per VIT, HP Per Level    -> max HP = VIT * HP Per VIT + (level - 1) * HP Per Level
##   MP Per Level                -> max MP = INT + PIE + (level - 1) * MP Per Level
##   Stat / Skill / Spell Points Per Level, Spells Unlock At Level (0 = never),
##   Auto Stat Gains ("STR+1,VIT+1", applied every level),
##   Milestone Every, Milestone Stat Points (extra stat points every N levels)

const CSV_PATH: String = "res://Data/Class_Progression.csv"

## Used for unknown classes and empty cells (matches the old hard-coded behaviour).
const DEFAULTS: Dictionary = {
	"name": "", "difficulty": 1, "difficulty_label": "Normal",
	"base_xp": 450, "xp_growth": 1.5, "max_level": 50,
	"hp_per_vit": 2, "hp_per_level": 0, "mp_per_level": 0,
	"stat_points_per_level": 5, "skill_points_per_level": 2, "spell_points_per_level": 1,
	"spells_unlock_at_level": 1, "auto_stat_gains": { "strength": 1, "vitality": 1 },
	"milestone_every": 0, "milestone_stat_points": 0,
}

const STAT_KEYS: Dictionary = {
	"STR": "strength", "INT": "intelligence", "PIE": "piety", "VIT": "vitality",
	"DEX": "dexterity", "SPD": "speed", "PER": "personality",
}

static var _table: Dictionary = {} # lower-case name / alias -> row
static var _loaded: bool = false


## The row for a class name (or alias). Unknown names get DEFAULTS.
static func for_class(class_name_or_alias: String) -> Dictionary:
	_ensure_loaded()
	var key: String = class_name_or_alias.strip_edges().to_lower()
	return _table.get(key, DEFAULTS) as Dictionary


## All rows in sheet order (easiest first).
static func all_classes() -> Array[Dictionary]:
	_ensure_loaded()
	var seen: Dictionary = {}
	var result: Array[Dictionary] = []
	for row: Dictionary in _table.values():
		if not seen.has(row["name"]):
			seen[row["name"]] = true
			result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
	return result


## XP needed to go from `level` to `level + 1`.
static func xp_to_next_level(row: Dictionary, level: int) -> int:
	return int(float(row["base_xp"]) * pow(float(maxi(1, level)), float(row["xp_growth"])))


## Points granted when reaching `new_level`: Vector3i(stat, skill, spell).
## Spell points only start once the class's spellbook is unlocked; milestones add stat points.
static func points_for_level(row: Dictionary, new_level: int) -> Vector3i:
	var stat: int = int(row["stat_points_per_level"])
	var every: int = int(row["milestone_every"])
	if every > 0 and new_level % every == 0:
		stat += int(row["milestone_stat_points"])
	var unlock: int = int(row["spells_unlock_at_level"])
	var spell: int = int(row["spell_points_per_level"]) if unlock > 0 and new_level >= unlock else 0
	return Vector3i(stat, int(row["skill_points_per_level"]), spell)


static func max_hp(row: Dictionary, vitality: int, level: int) -> int:
	return vitality * int(row["hp_per_vit"]) + maxi(0, level - 1) * int(row["hp_per_level"])


static func max_mp(row: Dictionary, intelligence: int, piety: int, level: int) -> int:
	return intelligence + piety + maxi(0, level - 1) * int(row["mp_per_level"])


## "STR+1,VIT+1" -> { "strength": 1, "vitality": 1 }
static func parse_stat_gains(text: String) -> Dictionary:
	var gains: Dictionary = {}
	for part: String in text.split(",", false):
		var p: String = part.strip_edges().to_upper()
		var sign_at: int = maxi(p.find("+"), p.find("-"))
		if sign_at <= 0:
			continue
		var stat: String = STAT_KEYS.get(p.substr(0, sign_at).strip_edges(), "")
		if stat.is_empty():
			continue
		gains[stat] = int(gains.get(stat, 0)) + int(p.substr(sign_at))
	return gains


## Parses the whole sheet. Returns { lower-case name or alias: row }.
static func parse_csv_text(text: String) -> Dictionary:
	var rows: Array[PackedStringArray] = _split_csv(text)
	var table: Dictionary = {}
	if rows.is_empty():
		return table
	var cols: Dictionary = {}
	var header: PackedStringArray = rows[0]
	for i: int in header.size():
		cols[header[i].strip_edges().to_lower()] = i
	for r: int in range(1, rows.size()):
		var line: PackedStringArray = rows[r]
		var name: String = _cell(line, cols, "name")
		if name.is_empty():
			continue
		var row: Dictionary = DEFAULTS.duplicate(true)
		row["order"] = r
		row["name"] = name
		row["difficulty"] = _int_cell(line, cols, "difficulty", int(DEFAULTS["difficulty"]))
		row["difficulty_label"] = _cell(line, cols, "difficulty label", str(DEFAULTS["difficulty_label"]))
		row["base_xp"] = _int_cell(line, cols, "base xp", int(DEFAULTS["base_xp"]))
		row["xp_growth"] = _float_cell(line, cols, "xp growth", float(DEFAULTS["xp_growth"]))
		row["max_level"] = _int_cell(line, cols, "max level", int(DEFAULTS["max_level"]))
		row["hp_per_vit"] = _int_cell(line, cols, "hp per vit", int(DEFAULTS["hp_per_vit"]))
		row["hp_per_level"] = _int_cell(line, cols, "hp per level", 0)
		row["mp_per_level"] = _int_cell(line, cols, "mp per level", 0)
		row["stat_points_per_level"] = _int_cell(line, cols, "stat points per level", 5)
		row["skill_points_per_level"] = _int_cell(line, cols, "skill points per level", 2)
		row["spell_points_per_level"] = _int_cell(line, cols, "spell points per level", 1)
		row["spells_unlock_at_level"] = _int_cell(line, cols, "spells unlock at level", 1)
		var gains_text: String = _cell(line, cols, "auto stat gains", "")
		row["auto_stat_gains"] = parse_stat_gains(gains_text) if not gains_text.is_empty() else {}
		row["milestone_every"] = _int_cell(line, cols, "milestone every", 0)
		row["milestone_stat_points"] = _int_cell(line, cols, "milestone stat points", 0)
		row["notes"] = _cell(line, cols, "notes", "")
		table[name.to_lower()] = row
		for alias: String in _cell(line, cols, "aliases", "").split(",", false):
			if not alias.strip_edges().is_empty():
				table[alias.strip_edges().to_lower()] = row
	return table


## Forces a re-read (e.g. after editing the sheet while the game runs).
static func reload() -> void:
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_warning("ClassProgression: can't read %s - using defaults." % CSV_PATH)
		_table = {}
		return
	_table = parse_csv_text(file.get_as_text())


# ------------------------------------------------------------------------------
# CSV helpers (quoted cells may contain commas)
# ------------------------------------------------------------------------------
static func _split_csv(text: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	for raw: String in text.replace("\r", "").split("\n", false):
		if raw.strip_edges().is_empty():
			continue
		var cells: PackedStringArray = []
		var cur: String = ""
		var quoted: bool = false
		var i: int = 0
		while i < raw.length():
			var ch: String = raw[i]
			if ch == "\"":
				if quoted and i + 1 < raw.length() and raw[i + 1] == "\"":
					cur += "\""
					i += 1
				else:
					quoted = not quoted
			elif ch == "," and not quoted:
				cells.append(cur)
				cur = ""
			else:
				cur += ch
			i += 1
		cells.append(cur)
		rows.append(cells)
	return rows


static func _cell(line: PackedStringArray, cols: Dictionary, col: String, fallback: String = "") -> String:
	if not cols.has(col):
		return fallback
	var idx: int = int(cols[col])
	if idx >= line.size():
		return fallback
	var v: String = line[idx].strip_edges()
	return fallback if v.is_empty() else v


static func _int_cell(line: PackedStringArray, cols: Dictionary, col: String, fallback: int) -> int:
	var v: String = _cell(line, cols, col, "")
	return int(v) if v.is_valid_int() else (int(float(v)) if v.is_valid_float() else fallback)


static func _float_cell(line: PackedStringArray, cols: Dictionary, col: String, fallback: float) -> float:
	var v: String = _cell(line, cols, col, "")
	return float(v) if v.is_valid_float() else fallback
