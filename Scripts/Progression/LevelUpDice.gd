# res://Scripts/Progression/LevelUpDice.gd
class_name LevelUpDice
extends RefCounted
## Level-up bonus from one D6 roll. Pure / static: no scene, no randomness (the roll is passed in).
## Tests: res://tests/progression/test_level_up_dice.gd
##
##   1-3 : +roll stat points
##   4   : +3 stat points, +1 skill/spell point
##   5   : +3 stat points, +2 skill/spell points
##   6   : +3 stat points, +2 skill/spell points, +3% max HP (permanent)

const HP_BONUS_PERCENT_ON_SIX: float = 3.0


## { "stat": int, "ability": int, "hp_percent": float } for a D6 result (clamped to 1..6).
static func bonus_for_roll(roll: int) -> Dictionary:
	var r: int = clampi(roll, 1, 6)
	if r <= 3:
		return { "stat": r, "ability": 0, "hp_percent": 0.0 }
	if r == 4:
		return { "stat": 3, "ability": 1, "hp_percent": 0.0 }
	if r == 5:
		return { "stat": 3, "ability": 2, "hp_percent": 0.0 }
	return { "stat": 3, "ability": 2, "hp_percent": HP_BONUS_PERCENT_ON_SIX }


## Splits bonus skill/spell points between the two pools: Vector2i(skill_points, spell_points).
## Only-skills or only-spells characters get them all in that pool; characters with both alternate,
## starting with whichever list is longer (skills on a tie). Characters with neither get skill points.
static func split_ability_points(points: int, known_skills: int, known_spells: int) -> Vector2i:
	if points <= 0:
		return Vector2i.ZERO
	if known_spells > 0 and known_skills <= 0:
		return Vector2i(0, points)
	if known_spells <= 0:
		return Vector2i(points, 0)
	var spells_first: bool = known_spells > known_skills
	var first: int = ceili(float(points) / 2.0)
	var second: int = points - first
	return Vector2i(second, first) if spells_first else Vector2i(first, second)


## One line for the UI, e.g. "+3 STAT  •  +2 SKILL/SPELL  •  +3% MAX HP".
static func describe(bonus: Dictionary) -> String:
	var parts: PackedStringArray = []
	var stat: int = int(bonus.get("stat", 0))
	var ability: int = int(bonus.get("ability", 0))
	var hp: float = float(bonus.get("hp_percent", 0.0))
	if stat > 0:
		parts.append("+%d STAT" % stat)
	if ability > 0:
		parts.append("+%d SKILL/SPELL" % ability)
	if hp > 0.0:
		parts.append("+%d%% MAX HP" % roundi(hp))
	return "  •  ".join(parts)
