class_name SpellData
extends Resource

enum SpellbookType {
	ARCHANIST,
	SOULWRIGHT,
	MAESTER,
	PSYNIC,
}
enum TargetType {
	SINGLE_ENEMY,
	ALL_ENEMY,
	SINGLE_ALLY,
	ALL_ALLY,
	SELF,
}
enum EffectType {
	DAMAGE,
	HEAL,
	BUFF,
	DEBUFF,
	UTILITY,
}

@export_group("Identity & Grouping")
@export var spell_id: String = ""
@export var spell_name: String = ""
@export var spellbook: SpellbookType = SpellbookType.ARCHANIST
@export var tier: int = 1
@export_multiline var description: String = ""
@export var icon_path: String = ""
@export var icon: Texture2D

@export_group("Cost & Targeting")
@export var energy_cost: int = 4
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var element: ItemData.ElementalBase = ItemData.ElementalBase.NONE
@export var requirement: int = 0
@export var class_locked: bool = false

@export_group("Potency & Scaling")
@export var effect_type: EffectType = EffectType.DAMAGE
@export var base_amount: int = 15
@export var var_multiplier: float = 0.5
@export var stat_scaling: String = "INT"
@export var status_effect: String = "NONE" # Replaced enum with String ID
@export var duration: int = 1
@export var animation: String = "NONE"

## Calculates spell potency using Base + Random Variance + Caster Stat Bonus
func calculate_potency(caster_stat_value: int) -> int:
	var max_var: int = int(float(base_amount) * var_multiplier)
	var random_bonus: int = randi_range(0, max_var) if max_var > 0 else 0
	var stat_bonus: int = int(float(caster_stat_value) * 0.5)

	return base_amount + random_bonus + stat_bonus


## Checks whether a given character class string is authorized to cast this spell.
func is_class_allowed(character_class_name: String) -> bool:
	# Off-class characters can cast unlocked spells freely
	if not class_locked:
		return true

	if character_class_name.is_empty():
		return false

	# Convert enum key to string (e.g. SpellbookType.MAESTER -> "MAESTER")
	var required_class_name: String = SpellbookType.keys()[spellbook]
	return character_class_name.strip_edges().to_upper() == required_class_name


## Evaluates whether the caster meets both resource (energy) and class locking rules.
func can_cast(current_energy: int, character_class_name: String = "") -> bool:
	if current_energy < energy_cost:
		return false

	if class_locked and not is_class_allowed(character_class_name):
		return false

	return true


## Convenience method to fetch the compiled StatusEffectData resource directly
func get_status_effect_data() -> StatusEffectData:
	if status_effect.is_empty() or status_effect.to_upper() == "NONE":
		return null
	return StatusEffectDatabase.get_effect(status_effect)
