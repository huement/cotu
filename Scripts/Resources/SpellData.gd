# res://Scripts/Resources/SpellData.gd
extends Resource
class_name SpellData

enum SpellType { OFFENSIVE, DEFENSIVE, HEALING, UTILITY }
enum Element { NONE, FIRE, WATER, EARTH, AIR, HOLY, DARK }
enum TargetType { SELF, SINGLE_ALLY, SINGLE_ENEMY, ALL_ALLIES, ALL_ENEMIES }
enum ScalingStat { STRENGTH, INTELLIGENCE, PIETY, DEXTERITY }

@export var spell_id: StringName
@export var spell_name: String
@export var spell_title: String
@export var description: String
@export var icon: Texture2D
@export var spell_level: int = 1
@export var energy_cost: int = 1
@export var spell_type: SpellType = SpellType.OFFENSIVE
@export var element: Element = Element.NONE
@export var target_type: TargetType = TargetType.SINGLE_ENEMY

@export_group("Effect Calculation")
@export var dice_count: int = 1
@export var dice_sides: int = 4
@export var base_bonus: int = 0
@export var scaling_stat: ScalingStat = ScalingStat.INTELLIGENCE
@export var stat_multiplier: float = 1.0

## Calculates the final effect value based on caster stats and a power level.
## Typed as `Resource` to prevent circular class dependencies with CatCharacter
func calculate_effect_value(caster: Resource, power_level: int = 1) -> int:
	var final_value: int = 0
	for _i in range(dice_count):
		final_value += randi_range(1, dice_sides)
	
	final_value += base_bonus
	
	var scaling_bonus: int = 0
	if is_instance_valid(caster):
		var caster_stat_value: int = 0
		match scaling_stat:
			ScalingStat.STRENGTH:
				caster_stat_value = caster.get("strength") if "strength" in caster else 0
			ScalingStat.INTELLIGENCE:
				caster_stat_value = caster.get("intelligence") if "intelligence" in caster else 0
			ScalingStat.PIETY:
				caster_stat_value = caster.get("piety") if "piety" in caster else 0
			ScalingStat.DEXTERITY:
				caster_stat_value = caster.get("dexterity") if "dexterity" in caster else 0
		
		scaling_bonus = int(caster_stat_value * stat_multiplier)

	final_value += scaling_bonus
	final_value += power_level # Add bonus from power level
	
	return final_value
