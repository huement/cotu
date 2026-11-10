# res://Scripts/Combat/ActiveEffect.gd
class_name ActiveEffect
extends RefCounted
## One buff / debuff / DoT / HoT / shield / crowd-control on a Combatant.
## Durations count the AFFECTED combatant's turns.

var id: String
var name: String
var duration: int # Remaining turns of the AFFECTED combatant
## &"STAT_BUFF" (flat), &"STAT_PCT" (percent), &"DOT", &"HOT",
## &"SHIELD", &"MAGIC_SHIELD", &"SKIP_TURN", &"LOCK_MAGIC"
var effect_type: StringName
## &"strength", &"defense", &"speed", &"magic", &"accuracy", &"dexterity"
var stat_target: StringName
var value: float
var caster_id: String


func _init(p_id: String, p_name: String, p_duration: int, p_type: StringName, p_stat: StringName = &"", p_val: float = 0.0, p_caster: String = "") -> void:
	id = p_id
	name = p_name
	duration = p_duration
	effect_type = p_type
	stat_target = p_stat
	value = p_val
	caster_id = p_caster
