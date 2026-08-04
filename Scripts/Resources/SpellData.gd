# res://Scripts/Resources/SpellData.gd
class_name SpellData
extends Resource

enum SpellbookType { ARCHANIST, SOULWRIGHT, MAESTER, PSYNIC }
enum TargetType { SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_PARTY, SELF }
enum EffectType { DAMAGE, HEAL, BUFF, DEBUFF, UTILITY }
enum StatusEffect { NONE, STUN, POISON, SLOW, HASTE, SHIELD, DEFENSE_DOWN }

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
@export var element: ItemData.EffectElement = ItemData.EffectElement.MAGIC

@export_group("Potency & Scaling")
@export var effect_type: EffectType = EffectType.DAMAGE
@export var base_amount: int = 15
@export var var_multiplier: float = 0.5
@export var stat_scaling: String = "INT"
@export var status_effect: StatusEffect = StatusEffect.NONE


## Calculates spell potency using Base + Random Variance + Caster Stat Bonus
func calculate_potency(caster_stat_value: int) -> int:
	var max_var: int = int(float(base_amount) * var_multiplier)
	var random_bonus: int = randi_range(0, max_var) if max_var > 0 else 0
	var stat_bonus: int = int(float(caster_stat_value) * 0.5)
	
	return base_amount + random_bonus + stat_bonus


func can_cast(current_energy: int) -> bool:
	return current_energy >= energy_cost
