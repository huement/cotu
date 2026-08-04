# res://Scripts/Resources/SkillData.gd
class_name SkillData
extends Resource

enum SkillType { COMBAT, ENVIRONMENT, INVENTORY }
enum TargetType { SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_PARTY, SELF, NONE }
enum EffectType { DAMAGE, HEAL, LOCKPICK, STEALTH_SEARCH, REST_BOOST, CRAFT_AMMO, CRAFT_THROWABLE, CRAFT_POTION, ENCHANT_EQUIPMENT }

@export_group("Identity")
@export var skill_id: String = ""
@export var skill_name: String = ""
@export var skill_type: SkillType = SkillType.COMBAT
@export_multiline var description: String = ""
@export var icon_path: String = ""
@export var icon: Texture2D

@export_group("Cost & Targeting")
@export var energy_cost: int = 0
@export var target_type: TargetType = TargetType.SINGLE_ENEMY

@export_group("Effect Mechanics & Accuracy")
@export var effect_type: EffectType = EffectType.DAMAGE
@export var effect_amount: int = 0
@export var element: ItemData.EffectElement = ItemData.EffectElement.NONE
## Base success / hit chance (0% to 100%)
@export var accuracy: int = 90

@export_group("Class & Race Assignments")
@export var assigned_classes: Array[String] = []
@export var assigned_races: Array[String] = []


func can_character_use(energy_available: int) -> bool:
	return energy_available >= energy_cost

## Evaluates whether the skill lands successfully based on its accuracy rating
func roll_success_check() -> bool:
	return randi_range(1, 100) <= accuracy
