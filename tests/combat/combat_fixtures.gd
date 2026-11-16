# res://tests/combat/combat_fixtures.gd
class_name CombatFixtures
extends RefCounted
## Tiny builders for combat unit tests. No scene tree, no autoloads.


## Party member in slot `slot` (front row for 0-2). atk/def are base strength/defense.
static func party(slot: int, atk: int = 20, def: int = 5, hp: int = 50, spd: float = 10.0) -> Combatant:
	var c := Combatant.new("player_%d" % slot, "Cat%d" % slot, spd, true, slot, hp, hp, 10, 10, atk, def, null, slot < 3)
	c.attack_type = "BLADE"
	return c


## Enemy "enemy_<idx>". weakness = ItemData.EffectElement value.
static func enemy(idx: int, atk: int = 12, def: int = 4, hp: int = 40, weakness: int = ItemData.EffectElement.NONE, spd: float = 8.0) -> Combatant:
	var c := Combatant.new("enemy_%d" % idx, "Foe%d" % idx, spd, false, idx, hp, hp, 0, 0, atk, def, null, true)
	c.weakness = weakness
	c.attack_type = "BASH"
	return c


## Spell with fixed potency (no random variance). target_type = SpellData.TargetType.
static func spell(base: int = 20, target_type: int = 0, element: int = ItemData.ElementalBase.FIRE) -> SpellData:
	var s := SpellData.new()
	s.spell_id = "spl_test"
	s.spell_name = "Test Bolt"
	s.base_amount = base
	s.var_multiplier = 0.0
	s.target_type = target_type
	s.element = element
	return s


static func skill(amount: int = 15, element: int = ItemData.EffectElement.NONE, target_type: int = 0) -> SkillData:
	var s := SkillData.new()
	s.skill_id = "skl_test"
	s.skill_name = "Test Strike"
	s.effect_amount = amount
	s.element = element
	s.target_type = target_type
	return s
