# res://Scripts/Resources/SkillData.gd
class_name SkillData
extends Resource

enum SkillType {
	COMBAT,
	ENVIRONMENT,
	INVENTORY,
}
enum TargetType {
	SINGLE_ENEMY,
	ALL_ENEMY,
	SINGLE_ALLY,
	ALL_ALLY,
	SELF,
	NONE,
}
enum EffectType {
	DAMAGE,
	HEAL,
	LOCKPICK,
	STEALTH_SEARCH,
	REST_BOOST,
	CRAFT_AMMO,
	CRAFT_THROWABLE,
	CRAFT_POTION,
	ENCHANT_EQUIPMENT,
}

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
@export var duration: int = 1

@export_group("Class & Race Assignments")
@export var assigned_classes: Array[String] = []
@export var assigned_races: Array[String] = []


## Checks if a character's class is permitted to use this skill.
## An empty assigned_classes array means ALL classes can use it.
func is_class_allowed(character_class_name: String) -> bool:
	if assigned_classes.is_empty():
		return true
	if character_class_name.is_empty():
		return false

	var clean_target: String = character_class_name.strip_edges().to_upper()
	for allowed in assigned_classes:
		if allowed.strip_edges().to_upper() == clean_target:
			return true
	return false


## Checks if a character's race/breed is permitted to use this skill.
## An empty assigned_races array means ALL races can use it.
func is_race_allowed(character_race_name: String) -> bool:
	if assigned_races.is_empty():
		return true
	if character_race_name.is_empty():
		return false

	var clean_target: String = character_race_name.strip_edges().to_upper()
	for allowed in assigned_races:
		if allowed.strip_edges().to_upper() == clean_target:
			return true
	return false


## Evaluates full availability (energy cost, class alignment, and race alignment)
func can_use(current_energy: int, character_class_name: String = "", character_race_name: String = "") -> bool:
	if current_energy < energy_cost:
		return false
	if not is_class_allowed(character_class_name):
		return false
	if not is_race_allowed(character_race_name):
		return false
	return true


## Evaluates whether the skill lands successfully based on its accuracy rating
func roll_success_check() -> bool:
	return randi_range(1, 100) <= accuracy
