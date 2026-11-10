# res://Scripts/Combat/CombatMath.gd
class_name CombatMath
extends RefCounted
## Pure combat formulas. Static, no randomness of their own (SpellData.calculate_potency may roll), no logging, no SignalBus, no scene tree.
## CombatManager owns state (guards, tuning exports) and passes it in; it also does the logging.
## Tests: res://tests/combat/test_combat_math.gd

## Multiplier for back-row targets, back-row melee attackers and guarding party members.
const ROW_GUARD_MULT: float = 0.5
## Attack types that count as melee (halved from the back row).
const MELEE_TYPES: Array[String] = ["BLADE", "BASH", "UNARMED"]
const FLEE_MIN: float = 0.15
const FLEE_MAX: float = 0.95
## Flee chance gained per point of speed over the enemies' average.
const FLEE_PER_SPEED: float = 0.05

## Throwing (ItemData.is_throwable). Tuning lives here; tests: test_combat_math.gd "throw".
## Hit chance = THROW_BASE_HIT + (thrower DEX - target speed) x THROW_HIT_PER_POINT, clamped.
const THROW_BASE_HIT: float = 0.80
const THROW_HIT_PER_POINT: float = 0.025
const THROW_MIN_HIT: float = 0.40
const THROW_MAX_HIT: float = 0.98
## Damage = (power x THROW_POWER_MULT + DEX) x (1 + DEX x THROW_DEX_SCALE) - defence x THROW_DEFENSE_FACTOR
## (thrown items ignore half of the target's armour, and don't care about rows).
const THROW_POWER_MULT: float = 2.0
const THROW_DEX_SCALE: float = 0.05
const THROW_DEFENSE_FACTOR: float = 0.5
## Crit chance = DEX x THROW_CRIT_PER_DEX (max THROW_MAX_CRIT); crits do THROW_CRIT_MULT damage.
const THROW_CRIT_PER_DEX: float = 0.01
const THROW_MAX_CRIT: float = 0.35
const THROW_CRIT_MULT: float = 1.5


# ------------------------------------------------------------------------------
# Elements / attack types
# ------------------------------------------------------------------------------
## ItemData.EffectElement -> "BLADE" / "RANGED" / "MAGIC" / "BASH" (everything else is BASH).
static func attack_type_from_element(element: int) -> String:
	match element:
		ItemData.EffectElement.BLADE:
			return "BLADE"
		ItemData.EffectElement.RANGED:
			return "RANGED"
		ItemData.EffectElement.MAGIC:
			return "MAGIC"
		_:
			return "BASH"


## "BLADE" / "RANGED" / "MAGIC" -> that element; "BASH" and "UNARMED" -> BASH.
static func element_for_attack_type(attack_type: String) -> int:
	match attack_type:
		"BLADE":
			return ItemData.EffectElement.BLADE
		"RANGED":
			return ItemData.EffectElement.RANGED
		"MAGIC":
			return ItemData.EffectElement.MAGIC
		_:
			return ItemData.EffectElement.BASH


## True when an equipped item is consumable ammo (arrows, bolts, alchemy flasks, etc.).
## Flasks are their own launcher: each throw uses one, and the last one leaves the hand empty.
static func is_ammo_item(item: ItemData) -> bool:
	if not is_instance_valid(item):
		return false
	if item.quantity > 1:
		return true
	var name_upper: String = item.item_name.to_upper()
	var id_upper: String = item.item_id.to_upper()
	for word: String in ["ARROW", "BOLT", "AMMO", "QUIVER", "DART", "FLASK"]:
		if word in name_upper or word in id_upper:
			return true
	return false


## True when the character has usable ammo equipped in either hand.
static func character_has_ranged_ammo(character: Resource) -> bool:
	if not is_instance_valid(character) or not character.has_method("get_equipped_item"):
		return false
	var right_item: ItemData = character.call("get_equipped_item", "RIGHT_HAND") as ItemData
	var left_item: ItemData = character.call("get_equipped_item", "LEFT_HAND") as ItemData
	var ammo: ItemData = null
	if is_ammo_item(left_item):
		ammo = left_item
	elif is_ammo_item(right_item):
		ammo = right_item
	return is_instance_valid(ammo) and ammo.quantity > 0


## Attack type the character will actually use this turn (RANGED with no ammo → BASH fists).
static func effective_attack_type_for_character(character: Resource) -> String:
	var attack_type: String = "UNARMED"
	if is_instance_valid(character) and character.has_method("get_attack_type_string"):
		attack_type = str(character.call("get_attack_type_string")).to_upper()
	if attack_type == "RANGED" and not character_has_ranged_ammo(character):
		return "BASH"
	if attack_type == "UNARMED" or attack_type.is_empty():
		return "BASH"
	return attack_type


## True when `element` is the defender's weakness (NONE never counts).
static func is_weak_to(defender: Combatant, element: int) -> bool:
	return defender.weakness != ItemData.EffectElement.NONE and defender.weakness == element


## effect_amount values <= 1 are fractions (0.2 = 20%), larger values are percents (50 = 50%). Clamped 0..1.
static func as_fraction(amount: float) -> float:
	if amount > 1.0:
		return clampf(amount / 100.0, 0.0, 1.0)
	return clampf(amount, 0.0, 1.0)


# ------------------------------------------------------------------------------
# Physical damage
# ------------------------------------------------------------------------------
## (ATK - DEF*(1-pierce)), min 1, x back-row melee attacker 0.5 x back-row defender 0.5
## x guarding 0.5 x weakness x (1 - resist). Result min 1. UNARMED drops weapon attack and pierce.
static func physical_damage(attacker: Combatant, defender: Combatant, attack_type: String, defender_guarding: bool, weakness_multiplier: float) -> int:
	if attacker == null or defender == null:
		return 1

	var is_unarmed: bool = attack_type == "UNARMED"
	var atk: float = float(attacker.get_effective_attack(is_unarmed))
	var pierce: float = 0.0 if is_unarmed else attacker.pierce
	var def: float = float(defender.get_effective_defense()) * (1.0 - pierce)
	var dmg: float = maxf(1.0, atk - def)

	if not attacker.is_front_row and attack_type in MELEE_TYPES:
		dmg *= ROW_GUARD_MULT
	if not defender.is_front_row:
		dmg *= ROW_GUARD_MULT
	if defender_guarding:
		dmg *= ROW_GUARD_MULT

	var element: int = element_for_attack_type(attack_type)
	if is_weak_to(defender, element):
		dmg *= weakness_multiplier
	dmg *= 1.0 - defender.get_resist(element)

	return maxi(1, roundi(dmg))


# ------------------------------------------------------------------------------
# Abilities (spells / skills)
# ------------------------------------------------------------------------------
## Potency before the target's defenses.
## Resources with calculate_potency(stat): players scale off their `stat_scaling` attribute (default INT),
## enemies off magic_power; spells are then x magic buffs x spell_amplify.
## Otherwise effect_amount, then base_amount, then 10.
static func ability_power(caster: Combatant, ability: Resource, kind: StringName) -> float:
	if ability.has_method("calculate_potency"):
		var caster_stat: int = caster.magic_power
		if caster.is_player and is_instance_valid(caster.ref):
			var stat_key: String = str(ability.get("stat_scaling")).to_lower() if "stat_scaling" in ability else "int"
			caster_stat = cat_attribute(caster.ref, StringName(stat_key), 10)
		var potency: float = float(ability.call("calculate_potency", caster_stat))
		if kind == &"SPELL":
			potency *= caster.get_stat_multiplier(&"magic") * caster.spell_amplify
		return potency
	if "effect_amount" in ability:
		return float(ability.get("effect_amount"))
	if "base_amount" in ability:
		return float(ability.get("base_amount"))
	return 10.0


## True when a spell hits the target's weakness: MAGIC, or LIFE for life-element spells.
static func spell_hits_weakness(target: Combatant, ability: Resource) -> bool:
	var is_life: bool = ability is SpellData and (ability as SpellData).element == ItemData.ElementalBase.LIFE
	return target.weakness == ItemData.EffectElement.MAGIC or (is_life and target.weakness == ItemData.EffectElement.LIFE)


## Element a physical skill hits with: its own `element`, or the caster's attack type when NONE.
static func skill_element(caster: Combatant, ability: Resource) -> int:
	var element: int = int(ability.get("element")) if "element" in ability else 0
	if element == ItemData.EffectElement.NONE:
		element = element_for_attack_type(caster.attack_type)
	return element


## Damage an ability deals to one target from `power` (see ability_power).
## SPELL: x weakness (spell_hits_weakness) x (1 - MAGIC resist). Defense and rows do NOT apply.
## Skills: x back-row 0.5 x guarding 0.5 x weakness x (1 - element resist). Defense does NOT apply.
## Result min 1.
static func ability_damage(caster: Combatant, target: Combatant, ability: Resource, kind: StringName, power: float, target_guarding: bool, weakness_multiplier: float) -> int:
	var dmg: float = power
	if kind == &"SPELL":
		if spell_hits_weakness(target, ability):
			dmg *= weakness_multiplier
		dmg *= 1.0 - target.get_resist(ItemData.EffectElement.MAGIC)
	else:
		var element: int = skill_element(caster, ability)
		if not target.is_front_row:
			dmg *= ROW_GUARD_MULT
		if target_guarding:
			dmg *= ROW_GUARD_MULT
		if is_weak_to(target, element):
			dmg *= weakness_multiplier
		dmg *= 1.0 - target.get_resist(element)
	return maxi(1, roundi(dmg))


## Generic buff/HoT duration: ability `duration` (default 1) x spell `tier` for spells. Min 1.
## (Status effects use their own StatusEffectData duration.)
static func ability_duration(ability: Resource, kind: StringName) -> int:
	var base_duration: int = int(ability.get("duration")) if "duration" in ability else 1
	if kind == &"SPELL" and "tier" in ability:
		base_duration *= maxi(1, int(ability.get("tier")))
	return maxi(1, base_duration)


# ------------------------------------------------------------------------------
# Turn meters / fleeing
# ------------------------------------------------------------------------------
## Meter after one tick: + effective speed x tick_rate x delta, capped at max_meter.
static func next_meter(meter: float, effective_speed: float, tick_rate: float, delta: float, max_meter: float) -> float:
	return minf(meter + effective_speed * tick_rate * delta, max_meter)


## base + (party speed - enemy average speed) x 0.05, clamped 0.15..0.95.
static func flee_chance(base_chance: float, caster_speed: int, enemy_avg_speed: int) -> float:
	return clampf(base_chance + float(caster_speed - enemy_avg_speed) * FLEE_PER_SPEED, FLEE_MIN, FLEE_MAX)


## Average effective speed of the living members of one side (int, 0 when nobody is alive).
static func average_speed(combatants: Array[Combatant], of_players: bool) -> int:
	var total: float = 0.0
	var count: int = 0
	for c: Combatant in combatants:
		if c.is_player == of_players and c.current_hp > 0:
			total += c.get_effective_speed()
			count += 1
	return int(total / maxf(1.0, float(count)))


# ------------------------------------------------------------------------------
# Character sheet reads
# ------------------------------------------------------------------------------
## Reads a core attribute the way the character sheet does (includes "+stat" equipment).
static func cat_attribute(cat: Resource, stat: StringName, fallback: int) -> int:
	if cat.has_method("get_effective_stat"):
		return int(cat.call("get_effective_stat", stat))
	if str(stat) in cat:
		return int(cat.get(str(stat)))
	return fallback


## StatusEffectData.ModifierStat -> Combatant stat key (&"" when unknown).
static func modifier_stat_name(stat: int) -> StringName:
	match stat:
		StatusEffectData.ModifierStat.DEF:
			return &"defense"
		StatusEffectData.ModifierStat.ATK:
			return &"strength"
		StatusEffectData.ModifierStat.ACC:
			return &"accuracy"
		StatusEffectData.ModifierStat.DEX:
			return &"dexterity"
		StatusEffectData.ModifierStat.MAG:
			return &"magic"
		StatusEffectData.ModifierStat.SPD:
			return &"speed"
		_:
			return &""


# ------------------------------------------------------------------------------
# Throwing (ItemData.is_throwable)
# ------------------------------------------------------------------------------
## Chance (0..1) that a throw from someone with `dexterity` hits a target with `target_speed`.
static func throw_hit_chance(dexterity: int, target_speed: float) -> float:
	var chance: float = THROW_BASE_HIT + (float(dexterity) - target_speed) * THROW_HIT_PER_POINT
	return clampf(chance, THROW_MIN_HIT, THROW_MAX_HIT)


static func throw_crit_chance(dexterity: int) -> float:
	return clampf(float(dexterity) * THROW_CRIT_PER_DEX, 0.0, THROW_MAX_CRIT)


## Damage of a throw that hit (before the crit roll). Min 1.
static func throw_damage(power: int, dexterity: int, defender: Combatant, weakness_multiplier: float, element: int = -1) -> int:
	var raw: float = (float(power) * THROW_POWER_MULT + float(dexterity)) * (1.0 + float(dexterity) * THROW_DEX_SCALE)
	var def: float = float(defender.get_effective_defense()) * THROW_DEFENSE_FACTOR if defender != null else 0.0
	var dmg: float = maxf(1.0, raw - def)
	if defender != null and element >= 0:
		if is_weak_to(defender, element):
			dmg *= weakness_multiplier
		dmg *= 1.0 - defender.get_resist(element)
	return maxi(1, roundi(dmg))
