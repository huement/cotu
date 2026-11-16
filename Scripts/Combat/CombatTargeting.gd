# res://Scripts/Combat/CombatTargeting.gd
class_name CombatTargeting
extends RefCounted
## Who an action hits. Static and scene-free: every function takes the battle's combatant list.
## Only pick_opponent (enemy attacking the party) and the SINGLE_ENEMY fallback use randomness.
## Tests: res://tests/combat/test_combat_targeting.gd

## SpellData / SkillData `target_type` values (same order in both enums and the CSVs).
enum TargetType { SINGLE_ENEMY = 0, ALL_ENEMY = 1, SINGLE_ALLY = 2, ALL_ALLY = 3, SELF = 4, NONE = 5 }


static func find_by_id(combatants: Array[Combatant], id: String) -> Combatant:
	for c: Combatant in combatants:
		if c.id == id:
			return c
	return null


static func find_by_slot(combatants: Array[Combatant], slot_idx: int, is_player: bool) -> Combatant:
	for c: Combatant in combatants:
		if c.is_player == is_player and c.slot_index == slot_idx:
			return c
	return null


## Living members of one side.
static func living(combatants: Array[Combatant], of_players: bool) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for c: Combatant in combatants:
		if c.is_player == of_players and c.current_hp > 0:
			result.append(c)
	return result


## A living opponent of `attacker`.
## Party: enemy "enemy_<target_index>" if alive, else the first living enemy.
## Enemies: a random living party member. null when the other side is wiped out.
static func pick_opponent(combatants: Array[Combatant], attacker: Combatant, target_index: int) -> Combatant:
	if attacker.is_player:
		var chosen: Combatant = find_by_id(combatants, "enemy_%d" % target_index)
		if chosen != null and chosen.current_hp > 0:
			return chosen
		for c: Combatant in combatants:
			if not c.is_player and c.current_hp > 0:
				return c
		return null
	var alive_party: Array[Combatant] = living(combatants, true)
	return alive_party.pick_random() if not alive_party.is_empty() else null


## Everyone an ability hits, from its `target_type` (default SINGLE_ENEMY).
## - ALL_ENEMY / ALL_ALLY: the whole living side (allies include the dead when allow_dead_ally, for revives).
## - SELF / NONE: the caster.
## - SINGLE_ALLY: party casters use slot `target_index`; enemy casters pick their lowest-HP ally.
##   Falls back to the caster if that ally isn't valid.
## - SINGLE_ENEMY: pick_opponent.
static func resolve_ability_targets(combatants: Array[Combatant], caster: Combatant, ability: Resource, target_index: int, allow_dead_ally: bool) -> Array[Combatant]:
	var target_type: int = int(ability.get("target_type")) if "target_type" in ability else TargetType.SINGLE_ENEMY
	var foes: Array[Combatant] = []
	var allies: Array[Combatant] = []
	for c: Combatant in combatants:
		if c.is_player == caster.is_player:
			if c.current_hp > 0 or allow_dead_ally:
				allies.append(c)
		elif c.current_hp > 0:
			foes.append(c)

	var result: Array[Combatant] = []
	match target_type:
		TargetType.ALL_ENEMY:
			result = foes
		TargetType.ALL_ALLY:
			result = allies
		TargetType.SELF, TargetType.NONE:
			result.append(caster)
		TargetType.SINGLE_ALLY:
			var ally: Combatant = null
			if caster.is_player:
				ally = find_by_slot(combatants, target_index, true)
			else:
				for c: Combatant in allies:
					if ally == null or c.current_hp < ally.current_hp:
						ally = c
			if ally == null or not allies.has(ally):
				ally = caster
			result.append(ally)
		_:
			var foe: Combatant = pick_opponent(combatants, caster, target_index)
			if foe != null:
				result.append(foe)
	return result
