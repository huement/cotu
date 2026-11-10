# res://Scripts/Progression/CharacterCreation.gd
class_name CharacterCreation
extends RefCounted
## Rules for making a new character (Wizardry style). Static and side-effect free; the Character Creator
## screens (Scripts/UI/CharacterCreator/) only call into this. Tests: tests/progression/test_character_creation.gd
##
##   1. Pick a race (CatBreed, Data/Races) and a class (ProfessionData, Data/Classes).
##      Every combination can be picked, but a class whose minimum stats the race can't reach even with
##      the best possible roll is greyed out (is_class_reachable).
##   2. Roll BONUS_DICE d6 for a bonus pool (re-roll as often as you like) and spend it on stats.
##      No stat above STAT_CAP; the class minimums must be met and the pool spent to continue.
##      Pick starting spells / class skills from what the class can learn at level 1; race skills are free.
##   3. Name it -> build_character() -> CharacterRoster.save().

const RACES_DIR: String = "res://Data/Races/"
const CLASSES_DIR: String = "res://Data/Classes/"
const FUR_DIR: String = "res://Data/Furs/"
const PORTRAIT_DIR: String = "res://Data/Portraits/"
const FALLBACK_PORTRAIT: String = "res://ui/LOGOS/arcanum_crest_100.png"
const CLASS_TEXT_CSV: String = "res://Data/Character_Classes.csv"

const STATS: Array[String] = ["strength", "intelligence", "piety", "vitality", "dexterity", "speed", "personality"]
const STAT_SHORT: Dictionary = {
	"strength": "STR", "intelligence": "INT", "piety": "PIE", "vitality": "VIT",
	"dexterity": "DEX", "speed": "SPD", "personality": "PER",
}
const STAT_LONG: Dictionary = {
	"strength": "Strength", "intelligence": "Intelligence", "piety": "Piety", "vitality": "Vitality",
	"dexterity": "Dexterity", "speed": "Speed", "personality": "Personality",
}

## Bonus pool = the sum of this many d6 (3..18).
const BONUS_DICE: int = 3
## No stat can go above this at creation.
const STAT_CAP: int = 18
const NAME_MAX_LENGTH: int = 16

static var _class_text: Dictionary = {}


# ------------------------------------------------------------------------------
# Data
# ------------------------------------------------------------------------------
## Every race, alphabetical.
static func all_races() -> Array[CatBreed]:
	var result: Array[CatBreed] = []
	for res: Resource in AbilityLibrary.load_all(RACES_DIR):
		if res is CatBreed:
			result.append(res as CatBreed)
	result.sort_custom(func(a: CatBreed, b: CatBreed) -> bool: return a.breed_name < b.breed_name)
	return result


## Every class, easiest -> hardest (Data/Class_Progression.csv order, unknown classes last).
static func all_classes() -> Array[ProfessionData]:
	var result: Array[ProfessionData] = []
	for res: Resource in AbilityLibrary.load_all(CLASSES_DIR):
		if res is ProfessionData:
			result.append(res as ProfessionData)
	result.sort_custom(func(a: ProfessionData, b: ProfessionData) -> bool:
		var oa: int = class_order(a)
		var ob: int = class_order(b)
		return oa < ob if oa != ob else a.profession_name < b.profession_name)
	return result


static func class_order(prof: ProfessionData) -> int:
	var row: Dictionary = ClassProgression.for_class(prof.profession_name)
	return int(row.get("order", 999))


static func max_bonus() -> int:
	return BONUS_DICE * 6


static func min_bonus() -> int:
	return BONUS_DICE


# ------------------------------------------------------------------------------
# Stats
# ------------------------------------------------------------------------------
## { "strength": 12, ... } straight from the race.
static func base_stats(breed: CatBreed) -> Dictionary:
	var out: Dictionary = {}
	for stat: String in STATS:
		out[stat] = int(breed.get("base_" + stat)) if breed != null else 8
	return out


## { "strength": 12, ... } class minimums (0 = no minimum).
static func class_requirements(prof: ProfessionData) -> Dictionary:
	var out: Dictionary = {}
	for stat: String in STATS:
		out[stat] = int(prof.get("req_" + stat)) if prof != null else 0
	return out


## Bonus points needed just to reach the class minimums from the race's base stats.
static func points_needed(breed: CatBreed, prof: ProfessionData) -> int:
	var base: Dictionary = base_stats(breed)
	var req: Dictionary = class_requirements(prof)
	var total: int = 0
	for stat: String in STATS:
		total += maxi(0, int(req[stat]) - int(base[stat]))
	return total


## False when even the best roll (max_bonus) can't meet the class minimums - greyed out on step 1.
static func is_class_reachable(breed: CatBreed, prof: ProfessionData) -> bool:
	for stat: String in STATS:
		if int(class_requirements(prof)[stat]) > STAT_CAP:
			return false
	return points_needed(breed, prof) <= max_bonus()


## Chance (0..1) that a single roll of the bonus pool is enough for this class.
static func roll_success_chance(breed: CatBreed, prof: ProfessionData) -> float:
	var need: int = points_needed(breed, prof)
	if need <= min_bonus():
		return 1.0
	if not is_class_reachable(breed, prof):
		return 0.0
	var hits: int = 0
	var total: int = 0
	for a: int in range(1, 7):
		for b: int in range(1, 7):
			for c: int in range(1, 7):
				total += 1
				if a + b + c >= need:
					hits += 1
	return float(hits) / float(total)


## Rolls the bonus dice: [d6, d6, d6].
## --- Roll limits (anti re-roll farming) ---
## Each new character gets its first roll plus this many re-rolls.
const REROLLS_PER_CHARACTER: int = 2
## Across ALL characters: at most this many rolls (first rolls included) per window.
## Counting first rolls stops the "back out and make a new character" loophole.
const GLOBAL_ROLL_LIMIT: int = 3
const GLOBAL_ROLL_WINDOW_SEC: float = 30.0
const ROLL_LIMIT_FILE: String = "user://roll_limit.cfg"

static var _roll_times: Array[float] = []
static var _roll_times_loaded: bool = false


static func _load_roll_times() -> void:
	if _roll_times_loaded:
		return
	_roll_times_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(ROLL_LIMIT_FILE) == OK:
		for t: Variant in cfg.get_value("rolls", "times", []):
			_roll_times.append(float(t))


static func _prune_roll_times() -> void:
	_load_roll_times()
	var now: float = Time.get_unix_time_from_system()
	var kept: Array = _roll_times.filter(func(t: float) -> bool:
		return now - t < GLOBAL_ROLL_WINDOW_SEC and t <= now + 1.0)
	_roll_times.assign(kept)


## Seconds until another roll is allowed (0 = roll now).
static func roll_wait_seconds() -> float:
	_prune_roll_times()
	if _roll_times.size() < GLOBAL_ROLL_LIMIT:
		return 0.0
	var oldest: float = _roll_times.min()
	return maxf(0.0, GLOBAL_ROLL_WINDOW_SEC - (Time.get_unix_time_from_system() - oldest))


static func register_roll() -> void:
	_prune_roll_times()
	_roll_times.append(Time.get_unix_time_from_system())
	var cfg := ConfigFile.new()
	cfg.set_value("rolls", "times", _roll_times)
	cfg.save(ROLL_LIMIT_FILE)


static func roll_bonus_dice(rng: RandomNumberGenerator = null) -> Array[int]:
	var dice: Array[int] = []
	for i: int in BONUS_DICE:
		dice.append(rng.randi_range(1, 6) if rng != null else randi_range(1, 6))
	return dice


static func sum_dice(dice: Array[int]) -> int:
	var total: int = 0
	for d: int in dice:
		total += d
	return total


## Stats after adding `allocation` ({ "strength": 2 }) to the race base.
static func apply_allocation(breed: CatBreed, allocation: Dictionary) -> Dictionary:
	var out: Dictionary = base_stats(breed)
	for stat: String in STATS:
		out[stat] = int(out[stat]) + int(allocation.get(stat, 0))
	return out


static func points_spent(allocation: Dictionary) -> int:
	var total: int = 0
	for stat: String in STATS:
		total += maxi(0, int(allocation.get(stat, 0)))
	return total


static func can_raise(breed: CatBreed, allocation: Dictionary, stat: String, pool: int) -> bool:
	if points_spent(allocation) >= pool:
		return false
	return int(apply_allocation(breed, allocation)[stat]) < STAT_CAP


static func can_lower(allocation: Dictionary, stat: String) -> bool:
	return int(allocation.get(stat, 0)) > 0


## Short labels of the class minimums not met yet: ["INT 15", "PIE 15"].
static func unmet_requirements(stats: Dictionary, prof: ProfessionData) -> Array[String]:
	var out: Array[String] = []
	var req: Dictionary = class_requirements(prof)
	for stat: String in STATS:
		if int(stats.get(stat, 0)) < int(req[stat]):
			out.append("%s %d" % [STAT_SHORT[stat], int(req[stat])])
	return out


static func meets_requirements(stats: Dictionary, prof: ProfessionData) -> bool:
	return unmet_requirements(stats, prof).is_empty()


## Puts bonus points on the stats the class still needs (used by "AUTO" and when a roll first lands).
## Returns a new allocation; points left over stay unspent.
static func auto_allocate(breed: CatBreed, prof: ProfessionData, pool: int) -> Dictionary:
	var alloc: Dictionary = {}
	var base: Dictionary = base_stats(breed)
	var req: Dictionary = class_requirements(prof)
	var left: int = pool
	for stat: String in STATS:
		var need: int = mini(maxi(0, int(req[stat]) - int(base[stat])), STAT_CAP - int(base[stat]))
		var give: int = mini(need, left)
		if give > 0:
			alloc[stat] = give
			left -= give
	return alloc


## True when step 2 is complete: class minimums met, pool fully spent (unless every stat is capped).
static func is_allocation_valid(breed: CatBreed, prof: ProfessionData, allocation: Dictionary, pool: int) -> bool:
	if points_spent(allocation) > pool:
		return false
	var stats: Dictionary = apply_allocation(breed, allocation)
	for stat: String in STATS:
		if int(stats[stat]) > STAT_CAP:
			return false
	if not meets_requirements(stats, prof):
		return false
	return points_spent(allocation) == pool or _all_capped(stats)


static func _all_capped(stats: Dictionary) -> bool:
	for stat: String in STATS:
		if int(stats[stat]) < STAT_CAP:
			return false
	return true


# ------------------------------------------------------------------------------
# Starting abilities
# ------------------------------------------------------------------------------
## A level-1 character of this race / class with no abilities yet (for the ability rules).
static func preview_character(breed: CatBreed, prof: ProfessionData, stats: Dictionary = {}) -> CatCharacter:
	var cat := CatCharacter.new()
	cat.breed = breed
	cat.profession = prof
	cat.level = 1
	var s: Dictionary = stats if not stats.is_empty() else base_stats(breed)
	for stat: String in STATS:
		cat.set(stat, int(s.get(stat, 8)))
	cat.abilities_initialized = true
	cat.known_spells = []
	cat.known_skills = []
	cat._calculate_vitals()
	return cat


## Tier-1 spells this class can start with (empty when the spellbook opens later / no magic).
static func spell_choices(breed: CatBreed, prof: ProfessionData) -> Array[SpellData]:
	return AbilityRules.learnable_spells(preview_character(breed, prof), AbilityLibrary.all_spells())


## Class skills this class can start with (race skills are free, see race_skills()).
static func skill_choices(breed: CatBreed, prof: ProfessionData) -> Array[SkillData]:
	var result: Array[SkillData] = []
	var cname: String = prof.profession_name.to_upper() if prof != null else ""
	for s: SkillData in AbilityLibrary.all_skills():
		for c: String in s.assigned_classes:
			if c.strip_edges().to_upper() == cname:
				result.append(s)
				break
	return result


## Skills every member of the race knows from the start.
static func race_skills(breed: CatBreed) -> Array[SkillData]:
	var result: Array[SkillData] = []
	var race: String = breed.breed_name.to_upper() if breed != null else ""
	for s: SkillData in AbilityLibrary.all_skills():
		for r: String in s.assigned_races:
			if r.strip_edges().to_upper() == race:
				result.append(s)
				break
	return result


static func spell_pick_count(breed: CatBreed, prof: ProfessionData) -> int:
	return mini(AbilityRules.STARTER_SPELLS, spell_choices(breed, prof).size())


## Free class-skill picks (a class skill the race already gets for free doesn't count).
static func skill_pick_count(breed: CatBreed, prof: ProfessionData) -> int:
	var free: Array[SkillData] = race_skills(breed)
	var open: int = 0
	for s: SkillData in skill_choices(breed, prof):
		if not free.has(s):
			open += 1
	return mini(AbilityRules.STARTER_CLASS_SKILLS, open)


## Default picks: the first N choices (what the old automatic starter set gave).
static func default_spell_picks(breed: CatBreed, prof: ProfessionData) -> Array[SpellData]:
	var picks: Array[SpellData] = []
	for s: SpellData in spell_choices(breed, prof):
		if picks.size() >= spell_pick_count(breed, prof):
			break
		picks.append(s)
	return picks


static func default_skill_picks(breed: CatBreed, prof: ProfessionData) -> Array[SkillData]:
	var picks: Array[SkillData] = []
	var free: Array[SkillData] = race_skills(breed)
	var choices: Array[SkillData] = skill_choices(breed, prof)
	# Prefer a COMBAT skill (usable in the first fight), then anything else.
	choices.sort_custom(func(a: SkillData, b: SkillData) -> bool:
		return int(a.skill_type == SkillData.SkillType.COMBAT) > int(b.skill_type == SkillData.SkillType.COMBAT))
	for s: SkillData in choices:
		if picks.size() >= skill_pick_count(breed, prof):
			break
		if not free.has(s):
			picks.append(s)
	return picks


# ------------------------------------------------------------------------------
# Building
# ------------------------------------------------------------------------------
## Problems that block CREATE (empty = ok).
static func validate_draft(draft: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var breed: CatBreed = draft.get("breed") as CatBreed
	var prof: ProfessionData = draft.get("profession") as ProfessionData
	if breed == null:
		problems.append("Choose a race.")
	if prof == null:
		problems.append("Choose a class.")
	if breed == null or prof == null:
		return problems
	var pool: int = int(draft.get("bonus_pool", 0))
	var alloc: Dictionary = draft.get("allocation", {}) as Dictionary
	if not meets_requirements(apply_allocation(breed, alloc), prof):
		problems.append("%s needs %s." % [prof.profession_name, ", ".join(unmet_requirements(apply_allocation(breed, alloc), prof))])
	elif not is_allocation_valid(breed, prof, alloc, pool):
		problems.append("Spend all bonus points.")
	var spells: Array = draft.get("spells", []) as Array
	var skills: Array = draft.get("skills", []) as Array
	if spells.size() != spell_pick_count(breed, prof):
		problems.append("Choose %d starting spell(s)." % spell_pick_count(breed, prof))
	if skills.size() != skill_pick_count(breed, prof):
		problems.append("Choose %d starting skill(s)." % skill_pick_count(breed, prof))
	if clean_name(str(draft.get("name", ""))).is_empty():
		problems.append("Give your character a name.")
	return problems


static func clean_name(raw: String) -> String:
	var n: String = raw.strip_edges().replace("\n", " ")
	return n.left(NAME_MAX_LENGTH)


## Makes (or, with `into`, rebuilds an unlocked roster character in place) a level-1 character.
## draft: { name, breed, profession, bonus_dice: Array[int], bonus_pool, allocation, spells, skills }
static func build_character(draft: Dictionary, into: CatCharacter = null) -> CatCharacter:
	var breed: CatBreed = draft.get("breed") as CatBreed
	var prof: ProfessionData = draft.get("profession") as ProfessionData
	var cat: CatCharacter = into if into != null else CatCharacter.new()
	cat.name = clean_name(str(draft.get("name", "")))
	cat.breed = breed
	cat.profession = prof
	cat.portrait_path = resolved_portrait_path(prof)
	cat.portrait = null
	cat.level = 1
	cat.current_xp = 0
	cat.max_xp = ClassProgression.xp_to_next_level(cat.get_class_progression(), 1)
	cat.unspent_stat_points = 0
	cat.unspent_skill_points = 0
	cat.unspent_spell_points = 0
	cat.pending_level_rolls = 0
	cat.bonus_max_hp_percent = 0.0
	cat.ability_ranks = {}
	var dice: Array[int] = []
	dice.assign(draft.get("bonus_dice", []) as Array)
	cat.creation_dice = dice
	cat.creation_allocation = (draft.get("allocation", {}) as Dictionary).duplicate()
	var stats: Dictionary = apply_allocation(breed, cat.creation_allocation)
	for stat: String in STATS:
		cat.set(stat, int(stats[stat]))

	var spells: Array[Resource] = []
	for s: Variant in draft.get("spells", []):
		if s is SpellData and not spells.has(s):
			spells.append(s)
	var skills: Array[Resource] = []
	for s: SkillData in race_skills(breed):
		skills.append(s)
	for s: Variant in draft.get("skills", []):
		if s is SkillData and not skills.has(s):
			skills.append(s)
	cat.known_spells = spells
	cat.known_skills = skills
	cat.abilities_initialized = true
	cat.is_front_row = true
	cat._calculate_vitals()
	cat.stats.health = cat.stats.max_health
	cat.current_hp = cat.stats.max_health
	cat.current_energy = cat.max_energy
	return cat


## The draft that recreates `cat` (for editing an unlocked roster character).
static func draft_from_character(cat: CatCharacter) -> Dictionary:
	var spells: Array = []
	for s: Resource in cat.known_spells:
		spells.append(s)
	var skills: Array = []
	var free: Array[SkillData] = race_skills(cat.breed as CatBreed)
	for s: Resource in cat.known_skills:
		if not free.has(s):
			skills.append(s)
	var alloc: Dictionary = cat.creation_allocation.duplicate()
	var dice: Array[int] = []
	dice.assign(cat.creation_dice)
	return {
		"name": cat.name,
		"breed": cat.breed,
		"profession": cat.profession,
		"bonus_dice": dice,
		"bonus_pool": sum_dice(dice),
		"allocation": alloc,
		"spells": spells,
		"skills": skills,
	}


# ------------------------------------------------------------------------------
# Art + text
# ------------------------------------------------------------------------------
static func fur_path_for(breed: CatBreed) -> String:
	if breed == null:
		return ""
	var path: String = FUR_DIR + breed.breed_name.to_lower() + ".png"
	return path if ResourceLoader.exists(path) else ""


## Data/Portraits/<Class>.png, or "" when that class has no portrait yet. The file name is matched
## without caring about case ("GhostBlade.png" for Ghostblade) and also by the class's name in
## Class_Progression.csv (e.g. a portrait named after an alias). Case-insensitive matching matters for
## exports: the .pck is case-sensitive even when the Mac editor isn't.
static func portrait_path_for(prof: ProfessionData) -> String:
	if prof == null:
		return ""
	var files: Dictionary = _portrait_files()
	var names: Array[String] = [prof.profession_name, str(ClassProgression.for_class(prof.profession_name).get("name", ""))]
	for n: String in names:
		var key: String = n.strip_edges().to_lower()
		if not key.is_empty() and files.has(key):
			return str(files[key])
	return ""


static var _portraits: Dictionary = {}


## lower-case base name -> res:// path for every PNG in PORTRAIT_DIR (export-safe listing).
static func _portrait_files() -> Dictionary:
	if not _portraits.is_empty():
		return _portraits
	var raw: PackedStringArray = ResourceLoader.list_directory(PORTRAIT_DIR)
	if raw.is_empty():
		var da: DirAccess = DirAccess.open(PORTRAIT_DIR)
		if da != null:
			raw = da.get_files()
	for f: String in raw:
		var clean: String = f.trim_suffix(".remap").trim_suffix(".import")
		if clean.get_extension().to_lower() == "png":
			_portraits[clean.get_basename().to_lower()] = PORTRAIT_DIR + clean
	return _portraits


## The class portrait path, or the Arcanum crest while that class has no portrait yet.
static func resolved_portrait_path(prof: ProfessionData) -> String:
	var path: String = portrait_path_for(prof)
	return path if not path.is_empty() else FALLBACK_PORTRAIT


static func fur_texture(breed: CatBreed) -> Texture2D:
	var path: String = fur_path_for(breed)
	return load(path) as Texture2D if not path.is_empty() else null


## The class portrait, or the Arcanum crest while the portrait isn't drawn yet.
static func portrait_texture(prof: ProfessionData) -> Texture2D:
	var path: String = portrait_path_for(prof)
	if path.is_empty():
		path = FALLBACK_PORTRAIT
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Descriptive columns of Data/Character_Classes.csv for a class:
## { based_on, weaponry, physical, academia, features, spell_level } (empty strings when missing).
static func class_text(class_name_str: String) -> Dictionary:
	if _class_text.is_empty():
		_load_class_text()
	return _class_text.get(class_name_str.strip_edges().to_lower(), {}) as Dictionary


static func _load_class_text() -> void:
	var f: FileAccess = FileAccess.open(CLASS_TEXT_CSV, FileAccess.READ)
	if f == null:
		return
	var rows: Array[PackedStringArray] = ClassProgression._split_csv(f.get_as_text())
	if rows.is_empty():
		return
	var cols: Dictionary = {}
	for i: int in rows[0].size():
		cols[rows[0][i].strip_edges().to_lower()] = i
	var keys: Dictionary = {
		"based_on": "based on", "weaponry": "weaponry", "physical": "physical", "academia": "academia",
		"features": "primary features & mechanics", "spell_level": "spell level", "spellbook": "spellbook type",
		"weapon_bonus": "weapon bonus",
	}
	for r: int in range(1, rows.size()):
		var line: PackedStringArray = rows[r]
		var cname: String = ClassProgression._cell(line, cols, "name")
		if cname.is_empty():
			continue
		var entry: Dictionary = {}
		for k: String in keys.keys():
			entry[k] = ClassProgression._cell(line, cols, str(keys[k]))
		_class_text[cname.to_lower()] = entry
