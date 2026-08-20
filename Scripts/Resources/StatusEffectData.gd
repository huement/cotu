extends Resource
class_name StatusEffectData

enum EffectType { POSITIVE, NEGATIVE }
enum EffectElement { NONE, NATURE, ARCANE, BIO, FIRE, WATER }
enum ModifierStat { NONE, DEF, ATK, ACC, DEX, MAG, SPD, HP }
enum ModifierType {
	MULTIPLIER,
	PERCENT_MAX_HP_HEAL,
	PERCENT_SHIELD,
	PERCENT_MAGIC_SHIELD,
	PERCENT_MAX_HP_TICK,
	CC_SKIP_TURN,
	CC_LOCK_MAGIC
}

@export var effect_id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var level: int = 1
@export var type: EffectType = EffectType.POSITIVE
@export var element: EffectElement = EffectElement.NONE
@export var duration: int = 1
@export var modifier_stat: ModifierStat = ModifierStat.NONE
@export var modifier_type: ModifierType = ModifierType.MULTIPLIER
@export var modifier_value: float = 0.0
@export var max_stacks: int = 1
@export var cured_by: String = ""
@export var is_cleansable: bool = false
@export var is_dispellable: bool = false
@export var icon_path: String = ""