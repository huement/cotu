# res://Scripts/Combat/AbilityInfo.gd
class_name AbilityInfo
extends RefCounted
## Read-only lookups on an ability Resource (SpellData, SkillData, or anything shaped like them).
## Static, no side effects. Tests: res://tests/combat/test_ability_info.gd


## "DAMAGE" / "HEAL" / "BUFF" / "DEBUFF" / "UTILITY" from the resource's effect_type enum.
## SkillData only has DAMAGE / HEAL / everything else = UTILITY. Unknown shapes read effect_type as text.
static func category(ability: Resource) -> String:
	if ability is SpellData:
		match (ability as SpellData).effect_type:
			SpellData.EffectType.HEAL:
				return "HEAL"
			SpellData.EffectType.BUFF:
				return "BUFF"
			SpellData.EffectType.DEBUFF:
				return "DEBUFF"
			SpellData.EffectType.UTILITY:
				return "UTILITY"
			_:
				return "DAMAGE"
	if ability is SkillData:
		match (ability as SkillData).effect_type:
			SkillData.EffectType.DAMAGE:
				return "DAMAGE"
			SkillData.EffectType.HEAL:
				return "HEAL"
			_:
				return "UTILITY"
	var raw: String = str(ability.get("effect_type")).to_upper() if "effect_type" in ability else "DAMAGE"
	for cat_name: String in ["HEAL", "BUFF", "DEBUFF", "UTILITY"]:
		if cat_name in raw:
			return cat_name
	return "DAMAGE"


## First non-empty of spell_name / skill_name / name, else "Ability".
static func display_name(ability: Resource) -> String:
	for key: String in ["spell_name", "skill_name", "name"]:
		if key in ability and not str(ability.get(key)).is_empty():
			return str(ability.get(key))
	return "Ability"


## First non-empty of spell_id / skill_id / id, else display_name in snake_case.
static func id(ability: Resource) -> String:
	for key: String in ["spell_id", "skill_id", "id"]:
		if key in ability and not str(ability.get(key)).is_empty():
			return str(ability.get(key))
	return display_name(ability).to_snake_case()


## The ability's `status_effect` id, or "" when empty / "NONE".
static func status_id(ability: Resource) -> String:
	var status: String = str(ability.get("status_effect")).strip_edges() if "status_effect" in ability else ""
	if status.is_empty() or status.to_upper() == "NONE":
		return ""
	return status


## Log verb for a hit kind: RANGED "SHOT", BLADE "SLASHED", BASH "BASHED", SPELL "BLASTED", else "hit".
static func hit_verb(hit_kind: String) -> String:
	match hit_kind:
		"RANGED":
			return "SHOT"
		"BLADE":
			return "SLASHED"
		"BASH":
			return "BASHED"
		"SPELL":
			return "BLASTED"
		_:
			return "hit"
