# res://Scripts/Progression/AbilityRules.gd
class_name AbilityRules
extends RefCounted
## Who can learn which spell / skill, and what a new character starts with. Static and side-effect free
## (except grant_* helpers, which only touch the CatCharacter passed in). Tests: tests/progression/test_ability_rules.gd
##
## SPELLS — a character can learn a spell when ALL of these hold:
##   * the spell's spellbook is one of the class's books (ProfessionData.spellbook_type, e.g. "Soulwright, Archanist")
##   * the class's spellbook is open: level >= "Spells Unlock At Level" (Data/Class_Progression.csv, 0 = never)
##   * spell tier <= max_spell_tier(): tier 1 when the book opens, +1 tier every LEVELS_PER_TIER levels
##   * level >= the spell's `requirement`
##   * class_locked spells only for the class that owns that spellbook (a Wizard can't learn Archanist-locked ones)
## SKILLS — learnable when the class is in assigned_classes OR the breed is in assigned_races
##   (a skill with neither list is open to everyone).
## STARTERS — STARTER_SPELLS cheapest tier-1 spells (if the book is open), the first class COMBAT skill,
##   and every race skill. A class whose book opens later gets its starter spells on that level-up.
## Everything else is learned from Spell Books / Skill Crystals (ItemData.effects "LearnSpell" / "LearnSkill").

const LEVELS_PER_TIER: int = 3
const MAX_TIER: int = 7
const STARTER_SPELLS: int = 2
const STARTER_CLASS_SKILLS: int = 1

## Spellbook names used in ProfessionData.spellbook_type / Spells.csv -> SpellData.SpellbookType.
const BOOK_NAMES: Dictionary = {
	"ARCHANIST": SpellData.SpellbookType.ARCHANIST,
	"SOULWRIGHT": SpellData.SpellbookType.SOULWRIGHT,
	"MAESTER": SpellData.SpellbookType.MAESTER,
	"PSYNIC": SpellData.SpellbookType.PSYNIC,
}


# ------------------------------------------------------------------------------
# Character facts
# ------------------------------------------------------------------------------
static func class_name_of(cat: CatCharacter) -> String:
	if is_instance_valid(cat.profession) and "profession_name" in cat.profession:
		return str(cat.profession.get("profession_name"))
	return ""


static func race_name_of(cat: CatCharacter) -> String:
	if is_instance_valid(cat.breed) and "breed_name" in cat.breed:
		return str(cat.breed.get("breed_name"))
	return ""


## SpellbookType values this character's class can study (empty = no magic).
static func spellbooks_of(cat: CatCharacter) -> Array[int]:
	var books: Array[int] = []
	if not is_instance_valid(cat.profession) or not "spellbook_type" in cat.profession:
		return books
	return parse_spellbooks(str(cat.profession.get("spellbook_type")))


## "Soulwright, Archanist" / "Psynic|Maester" -> [SOULWRIGHT, ARCHANIST]
static func parse_spellbooks(text: String) -> Array[int]:
	var books: Array[int] = []
	for part: String in text.replace("|", ",").split(",", false):
		var key: String = part.strip_edges().to_upper()
		if BOOK_NAMES.has(key) and not books.has(int(BOOK_NAMES[key])):
			books.append(int(BOOK_NAMES[key]))
	return books


static func spell_unlock_level(cat: CatCharacter) -> int:
	if spellbooks_of(cat).is_empty():
		return 0
	return int(cat.get_class_progression()["spells_unlock_at_level"])


## Highest spell tier this character may learn now (0 = none yet).
static func max_spell_tier(cat: CatCharacter) -> int:
	return max_tier_for(cat.level, spell_unlock_level(cat))


static func max_tier_for(level: int, unlock_level: int) -> int:
	if unlock_level <= 0 or level < unlock_level:
		return 0
	return mini(MAX_TIER, 1 + (level - unlock_level) / LEVELS_PER_TIER)


## Level at which `tier` becomes learnable (0 when the class never gets spells).
static func level_for_tier(tier: int, unlock_level: int) -> int:
	if unlock_level <= 0:
		return 0
	return unlock_level + (maxi(1, tier) - 1) * LEVELS_PER_TIER


# ------------------------------------------------------------------------------
# Eligibility
# ------------------------------------------------------------------------------
## Could this class ever learn the spell (ignores level and what's already known)?
static func spell_fits_class(cat: CatCharacter, spell: SpellData) -> bool:
	if not spellbooks_of(cat).has(int(spell.spellbook)):
		return false
	return spell.is_class_allowed(class_name_of(cat))


static func can_learn_spell(cat: CatCharacter, spell: SpellData) -> bool:
	return spell_block_reason(cat, spell).is_empty()


## "" when learnable, otherwise a short player-facing reason ("Needs level 7", "Already known"...).
static func spell_block_reason(cat: CatCharacter, spell: SpellData) -> String:
	if knows(cat, spell):
		return "Already known"
	if not spell_fits_class(cat, spell):
		return "Wrong spellbook"
	var unlock: int = spell_unlock_level(cat)
	if cat.level < unlock:
		return "Spellbook opens at level %d" % unlock
	var need: int = maxi(level_for_tier(spell.tier, unlock), spell.requirement)
	if cat.level < need:
		return "Needs level %d" % need
	return ""


static func skill_fits_character(cat: CatCharacter, skill: SkillData) -> bool:
	var by_class: bool = not skill.assigned_classes.is_empty() and _list_has(skill.assigned_classes, class_name_of(cat))
	var by_race: bool = not skill.assigned_races.is_empty() and _list_has(skill.assigned_races, race_name_of(cat))
	if skill.assigned_classes.is_empty() and skill.assigned_races.is_empty():
		return true
	return by_class or by_race


static func can_learn_skill(cat: CatCharacter, skill: SkillData) -> bool:
	return skill_block_reason(cat, skill).is_empty()


static func skill_block_reason(cat: CatCharacter, skill: SkillData) -> String:
	if knows(cat, skill):
		return "Already known"
	if not skill_fits_character(cat, skill):
		return "Not for this class / breed"
	return ""


static func knows(cat: CatCharacter, ability: Resource) -> bool:
	var id: String = AbilityInfo.id(ability)
	for list: Array[Resource] in [cat.known_spells, cat.known_skills]:
		for known: Resource in list:
			if known == ability or (is_instance_valid(known) and AbilityInfo.id(known) == id):
				return true
	return false


# ------------------------------------------------------------------------------
# Lists
# ------------------------------------------------------------------------------
## Spells this character could learn from a Spell Book right now.
static func learnable_spells(cat: CatCharacter, pool: Array[SpellData]) -> Array[SpellData]:
	var result: Array[SpellData] = []
	for s: SpellData in pool:
		if can_learn_spell(cat, s):
			result.append(s)
	return result


static func learnable_skills(cat: CatCharacter, pool: Array[SkillData]) -> Array[SkillData]:
	var result: Array[SkillData] = []
	for s: SkillData in pool:
		if can_learn_skill(cat, s):
			result.append(s)
	return result


## Class spells the character can't learn YET (shown greyed out with the reason).
static func upcoming_spells(cat: CatCharacter, pool: Array[SpellData]) -> Array[SpellData]:
	var result: Array[SpellData] = []
	for s: SpellData in pool:
		if spell_fits_class(cat, s) and not knows(cat, s) and not can_learn_spell(cat, s):
			result.append(s)
	return result


static func starter_spells(cat: CatCharacter, pool: Array[SpellData]) -> Array[SpellData]:
	var result: Array[SpellData] = []
	if max_spell_tier(cat) < 1:
		return result
	for s: SpellData in pool: # pool is sorted tier -> cost
		if result.size() >= STARTER_SPELLS:
			break
		if s.tier == 1 and spell_fits_class(cat, s) and cat.level >= s.requirement:
			result.append(s)
	return result


static func starter_skills(cat: CatCharacter, pool: Array[SkillData]) -> Array[SkillData]:
	var result: Array[SkillData] = []
	var class_name_str: String = class_name_of(cat)
	var race: String = race_name_of(cat)
	var class_combat: int = 0
	for s: SkillData in pool:
		var is_race_skill: bool = not s.assigned_races.is_empty() and _list_has(s.assigned_races, race)
		var is_class_combat: bool = s.skill_type == SkillData.SkillType.COMBAT \
			and not s.assigned_classes.is_empty() and _list_has(s.assigned_classes, class_name_str)
		if is_race_skill:
			result.append(s)
		elif is_class_combat and class_combat < STARTER_CLASS_SKILLS:
			result.append(s)
			class_combat += 1
	return result


# ------------------------------------------------------------------------------
# Granting
# ------------------------------------------------------------------------------
## Adds an ability to the right known list. Returns false if it was already known.
static func teach(cat: CatCharacter, ability: Resource) -> bool:
	if not is_instance_valid(ability) or knows(cat, ability):
		return false
	if ability is SpellData:
		cat.known_spells.append(ability)
	else:
		cat.known_skills.append(ability)
	return true


## Gives a NEW character its starting set (no-op once abilities_initialized is set).
## Older saves (everyone knew everything) are trimmed to the starter set, keeping anything the
## player already ranked up with level-up points.
static func initialize_abilities(cat: CatCharacter) -> void:
	if cat.abilities_initialized:
		return
	var keep_spells: Array[Resource] = []
	var keep_skills: Array[Resource] = []
	for s: Resource in cat.known_spells:
		if is_instance_valid(s) and cat.get_ability_rank(AbilityInfo.id(s)) > 1:
			keep_spells.append(s)
	for s: Resource in cat.known_skills:
		if is_instance_valid(s) and cat.get_ability_rank(AbilityInfo.id(s)) > 1:
			keep_skills.append(s)
	cat.known_spells = keep_spells
	cat.known_skills = keep_skills
	for s: SpellData in starter_spells(cat, AbilityLibrary.all_spells()):
		teach(cat, s)
	for s: SkillData in starter_skills(cat, AbilityLibrary.all_skills()):
		teach(cat, s)
	cat.abilities_initialized = true


## On level-up: the level the class's spellbook opens, it gets its starter spells for free.
## Returns the spells granted.
static func grant_spellbook_opening(cat: CatCharacter) -> Array[SpellData]:
	var granted: Array[SpellData] = []
	if spell_unlock_level(cat) != cat.level or not cat.known_spells.is_empty():
		return granted
	for s: SpellData in starter_spells(cat, AbilityLibrary.all_spells()):
		if teach(cat, s):
			granted.append(s)
	return granted


static func _list_has(list: Array[String], value: String) -> bool:
	var v: String = value.strip_edges().to_upper()
	if v.is_empty():
		return false
	for item: String in list:
		if item.strip_edges().to_upper() == v:
			return true
	return false
