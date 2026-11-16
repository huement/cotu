# res://Scripts/Progression/ClassBuildGuide.gd
class_name ClassBuildGuide
extends RefCounted
## Recommended stat priorities per class, plus the "auto spend" used by the Debug Menu's LEVEL UP.
## The same table feeds the "?" help popup on the Level Up screen, so the advice players see and
## what the auto-leveler does always match. Tune a class by editing its weights in BUILDS.
##
## STATS  - every auto level-up puts 1 point into SPD first (any class), then spreads the rest by
##          weight. Each point goes to the stat with the highest  weight / current value,  so over
##          many levels the stats drift toward the weight ratio instead of dumping everything in one.
## SKILLS / SPELLS - points go to the lowest-rank known ability first (ties: list order), so every
##          skill and spell keeps pace with the character's level.

const STAT_ORDER: Array[String] = [
	"strength", "intelligence", "piety", "vitality", "dexterity", "speed", "personality"
]
const STAT_SHORT: Dictionary = {
	"strength": "STR", "intelligence": "INT", "piety": "PIE", "vitality": "VIT",
	"dexterity": "DEX", "speed": "SPD", "personality": "PER",
}
const STAT_HINTS: Dictionary = {
	"strength": "Weapon damage",
	"intelligence": "Arcane casting, bigger MP pool",
	"piety": "Divine casting, MP pool and MP regen",
	"vitality": "Max HP",
	"dexterity": "Accuracy and evasion",
	"speed": "Act sooner in battle",
	"personality": "Voice and support abilities",
}

## Always put this many points into SPD on an auto level-up (when there are points to spend).
const SPEED_POINTS_PER_LEVEL: int = 1

## Class name (as in Data/Class_Progression.csv) -> weights (higher = more important) + a tip.
const BUILDS: Dictionary = {
	"Spartan": {
		"weights": { "strength": 5, "vitality": 4, "dexterity": 2 },
		"tip": "Front-line tank. Hit hard and soak hits: STR first, VIT close behind.",
	},
	"Shade": {
		"weights": { "dexterity": 5, "speed": 3, "vitality": 2, "strength": 1 },
		"tip": "Evasive striker and trap expert. DEX above all, then SPD to strike first.",
	},
	"Soulwright": {
		"weights": { "piety": 5, "vitality": 3, "personality": 2 },
		"tip": "Main healer. PIE powers every heal; VIT keeps the healer alive.",
	},
	"Archanist": {
		"weights": { "intelligence": 6, "vitality": 2, "dexterity": 2 },
		"tip": "Glass cannon. Pour points into INT; a little VIT so one hit doesn't drop you.",
	},
	"Warden": {
		"weights": { "dexterity": 5, "vitality": 3, "strength": 2, "intelligence": 1 },
		"tip": "Archer. DEX for accuracy, VIT for staying power, some INT for Maester spells.",
	},
	"Echo": {
		"weights": { "personality": 5, "dexterity": 3, "intelligence": 2, "vitality": 1 },
		"tip": "Support bard. PER drives your voice skills; DEX and INT round you out.",
	},
	"Maester": {
		"weights": { "intelligence": 5, "dexterity": 4, "vitality": 2 },
		"tip": "Fast caster. INT for spells, DEX to keep casts quick and accurate.",
	},
	"Psynic": {
		"weights": { "intelligence": 5, "vitality": 3, "personality": 2, "strength": 1 },
		"tip": "Mind mage with a sturdy frame. INT first, VIT second.",
	},
	"Amazon": {
		"weights": { "strength": 4, "vitality": 3, "piety": 2, "dexterity": 2, "speed": 1 },
		"tip": "Elite lancer. STR and VIT for the front row; PIE for Soulwright spells later.",
	},
	"Wizard": {
		"weights": { "intelligence": 4, "piety": 4, "vitality": 2 },
		"tip": "Two spellbooks. Keep INT and PIE even so both books stay strong.",
	},
	"Crusader": {
		"weights": { "strength": 4, "vitality": 4, "piety": 3, "personality": 1 },
		"tip": "Holy tank. STR and VIT to hold the line, PIE for backup healing.",
	},
	"Ronin": {
		"weights": { "strength": 4, "speed": 3, "dexterity": 3, "vitality": 2, "intelligence": 1 },
		"tip": "Fast killer. STR for damage, SPD and DEX to strike first and land crits.",
	},
	"Voidhand": {
		"weights": { "strength": 4, "speed": 3, "dexterity": 3, "piety": 2, "vitality": 1 },
		"tip": "Unarmed master. STR for blows, SPD and DEX for evasion and extra hits.",
	},
	"Ghostblade": {
		"weights": { "dexterity": 4, "strength": 3, "speed": 3, "vitality": 2 },
		"tip": "Assassin. DEX for crits and stealth, STR and SPD to finish fights fast.",
	},
}

const DEFAULT_BUILD: Dictionary = {
	"weights": { "strength": 3, "vitality": 3, "dexterity": 2, "intelligence": 1, "piety": 1 },
	"tip": "Balanced build: STR and VIT first, then DEX.",
}


# ------------------------------------------------------------------------------
# Lookups
# ------------------------------------------------------------------------------
## Build for a class name or alias ("Spartan" or "Fighter"). Unknown classes get DEFAULT_BUILD.
static func build_for_class(class_name_or_alias: String) -> Dictionary:
	if BUILDS.has(class_name_or_alias):
		return BUILDS[class_name_or_alias]
	var canonical: String = str(ClassProgression.for_class(class_name_or_alias).get("name", ""))
	return BUILDS.get(canonical, DEFAULT_BUILD) as Dictionary


static func build_for(cat: CatCharacter) -> Dictionary:
	if not is_instance_valid(cat):
		return DEFAULT_BUILD
	return build_for_class(AbilityRules.class_name_of(cat))


## Stats in priority order for the help popup: [{ "stat": "strength", "weight": 5 }, ...].
static func priorities(cat: CatCharacter) -> Array[Dictionary]:
	var weights: Dictionary = build_for(cat)["weights"]
	var result: Array[Dictionary] = []
	for stat: String in STAT_ORDER:
		if int(weights.get(stat, 0)) > 0:
			result.append({ "stat": stat, "weight": int(weights[stat]) })
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["weight"]) != int(b["weight"]):
			return int(a["weight"]) > int(b["weight"])
		return STAT_ORDER.find(str(a["stat"])) < STAT_ORDER.find(str(b["stat"])))
	return result


# ------------------------------------------------------------------------------
# Planning (no side effects)
# ------------------------------------------------------------------------------
## How `points` stat points should be spent: { "speed": 1, "strength": 2, ... }.
static func plan_stat_points(cat: CatCharacter, points: int) -> Dictionary:
	var deltas: Dictionary = {}
	if not is_instance_valid(cat) or points <= 0:
		return deltas
	var to_speed: int = mini(points, SPEED_POINTS_PER_LEVEL)
	if to_speed > 0:
		deltas["speed"] = to_speed
		points -= to_speed
	var weights: Dictionary = build_for(cat)["weights"]
	for _i: int in range(points):
		var best: String = ""
		var best_score: float = -1.0
		for stat: String in STAT_ORDER:
			var w: float = float(weights.get(stat, 0))
			if w <= 0.0:
				continue
			var current: float = float(int(cat.get(stat)) + int(deltas.get(stat, 0)))
			var score: float = w / maxf(1.0, current)
			if score > best_score:
				best_score = score
				best = stat
		if best.is_empty():
			best = "speed"
		deltas[best] = int(deltas.get(best, 0)) + 1
	return deltas


## Ability ids to rank up, lowest current rank first. An id may repeat if there are more points
## than abilities.
static func plan_ability_ranks(cat: CatCharacter, points: int, abilities: Array, is_skill: bool) -> Array[String]:
	var picks: Array[String] = []
	if not is_instance_valid(cat) or points <= 0:
		return picks
	var ids: Array[String] = []
	for ability: Variant in abilities:
		var id: String = ability_id_of(ability as Resource, is_skill)
		if not id.is_empty() and not ids.has(id):
			ids.append(id)
	if ids.is_empty():
		return picks
	var ranks: Dictionary = {}
	for id: String in ids:
		ranks[id] = cat.get_ability_rank(id)
	for _i: int in range(points):
		var best: String = ids[0]
		for id: String in ids:
			if int(ranks[id]) < int(ranks[best]):
				best = id
		picks.append(best)
		ranks[best] = int(ranks[best]) + 1
	return picks


## Up to `points` DIFFERENT ability ids, lowest rank first (ties: list order). Used by the Level Up
## screen's RECOMMENDED button, which allows one rank per ability per level-up.
static func pick_lowest_ranks(cat: CatCharacter, points: int, abilities: Array, is_skill: bool) -> Array[String]:
	var ids: Array[String] = []
	if not is_instance_valid(cat) or points <= 0:
		return ids
	for ability: Variant in abilities:
		var id: String = ability_id_of(ability as Resource, is_skill)
		if not id.is_empty() and not ids.has(id):
			ids.append(id)
	var order: Dictionary = {}
	for i: int in ids.size():
		order[ids[i]] = cat.get_ability_rank(ids[i]) * 1000 + i
	ids.sort_custom(func(a: String, b: String) -> bool: return int(order[a]) < int(order[b]))
	return ids.slice(0, mini(points, ids.size()))


## Same id rules as the Level Up screen (skill_id / spell_id, falling back to the snake_case name).
static func ability_id_of(ability: Resource, is_skill: bool) -> String:
	if not is_instance_valid(ability):
		return ""
	var id_key: String = "skill_id" if is_skill else "spell_id"
	var name_key: String = "skill_name" if is_skill else "spell_name"
	var id: String = str(ability.get(id_key)) if id_key in ability else ""
	if id.is_empty() and name_key in ability:
		id = str(ability.get(name_key)).to_snake_case()
	return id


# ------------------------------------------------------------------------------
# Apply
# ------------------------------------------------------------------------------
## Spends every unspent stat / skill / spell point on `cat` using the class build.
## Returns { "stats": { stat: amount }, "skills": int, "spells": int }.
static func auto_spend(cat: CatCharacter) -> Dictionary:
	var summary: Dictionary = { "stats": {}, "skills": 0, "spells": 0 }
	if not is_instance_valid(cat) or not cat.has_unspent_points():
		return summary
	var deltas: Dictionary = plan_stat_points(cat, cat.unspent_stat_points)
	var skill_ups: Array[String] = plan_ability_ranks(cat, cat.unspent_skill_points, cat.known_skills, true)
	var spell_ups: Array[String] = plan_ability_ranks(cat, cat.unspent_spell_points, cat.known_spells, false)
	cat.apply_level_up_allocation(deltas, skill_ups, spell_ups)
	summary["stats"] = deltas
	summary["skills"] = skill_ups.size()
	summary["spells"] = spell_ups.size()
	return summary


## "SPD+1 STR+2 VIT+1, 3 skill ranks, 1 spell rank"
static func describe(summary: Dictionary) -> String:
	var parts: PackedStringArray = []
	var deltas: Dictionary = summary.get("stats", {})
	for stat: String in STAT_ORDER:
		if int(deltas.get(stat, 0)) > 0:
			parts.append("%s+%d" % [STAT_SHORT[stat], int(deltas[stat])])
	var text: String = " ".join(parts)
	var skills: int = int(summary.get("skills", 0))
	var spells: int = int(summary.get("spells", 0))
	if skills > 0:
		text += ", %d skill rank%s" % [skills, "" if skills == 1 else "s"]
	if spells > 0:
		text += ", %d spell rank%s" % [spells, "" if spells == 1 else "s"]
	return text.trim_prefix(", ")
