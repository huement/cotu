# res://Scripts/Progression/AbilityLibrary.gd
class_name AbilityLibrary
extends RefCounted
## Every SpellData / SkillData in the game, loaded once. Export-safe: uses ResourceLoader.list_directory,
## which lists the original *.tres names inside exported builds too (raw DirAccess only sees *.remap
## files there, which is why spells/skills/status effects used to vanish from exports).
##
##   AbilityLibrary.all_spells()        # Array[SpellData], sorted tier -> cost -> name
##   AbilityLibrary.spell_by_id("sp_plasma_dart")
##   AbilityLibrary.load_all("res://Data/StatusEffects/")   # any resource folder

const SPELLS_DIR: String = "res://Data/Spells/"
const SKILLS_DIR: String = "res://Data/Skills/"

static var _spells: Array[SpellData] = []
static var _skills: Array[SkillData] = []
static var _loaded: bool = false


static func all_spells() -> Array[SpellData]:
	_ensure_loaded()
	return _spells


static func all_skills() -> Array[SkillData]:
	_ensure_loaded()
	return _skills


static func spell_by_id(spell_id: String) -> SpellData:
	for s: SpellData in all_spells():
		if s.spell_id == spell_id:
			return s
	return null


static func skill_by_id(skill_id: String) -> SkillData:
	for s: SkillData in all_skills():
		if s.skill_id == skill_id:
			return s
	return null


## Loads every resource in `dir` (non-recursive). Works in the editor and in exported builds.
static func load_all(dir: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var folder: String = dir if dir.ends_with("/") else dir + "/"
	for file_name: String in list_resource_files(folder):
		var res: Resource = load(folder + file_name)
		if res != null:
			result.append(res)
	return result


## Resource file names in `dir` (".tres" / ".res"), with export ".remap" suffixes stripped.
static func list_resource_files(dir: String) -> PackedStringArray:
	var names: PackedStringArray = []
	var raw: PackedStringArray = ResourceLoader.list_directory(dir)
	if raw.is_empty():
		var da: DirAccess = DirAccess.open(dir)
		if da != null:
			raw = da.get_files()
	for f: String in raw:
		var clean: String = f.trim_suffix(".remap")
		if (clean.ends_with(".tres") or clean.ends_with(".res")) and not names.has(clean):
			names.append(clean)
	names.sort()
	return names


## Forces a reload (e.g. after recompiling Spells.csv while the game runs).
static func reload() -> void:
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_spells.clear()
	_skills.clear()
	for res: Resource in load_all(SPELLS_DIR):
		if res is SpellData:
			_spells.append(res as SpellData)
	for res: Resource in load_all(SKILLS_DIR):
		if res is SkillData:
			_skills.append(res as SkillData)
	_spells.sort_custom(func(a: SpellData, b: SpellData) -> bool:
		if a.tier != b.tier:
			return a.tier < b.tier
		if a.energy_cost != b.energy_cost:
			return a.energy_cost < b.energy_cost
		return a.spell_name < b.spell_name)
	_skills.sort_custom(func(a: SkillData, b: SkillData) -> bool:
		if a.energy_cost != b.energy_cost:
			return a.energy_cost < b.energy_cost
		return a.skill_name < b.skill_name)
