# res://Scripts/Combat/Combatant.gd
class_name Combatant
extends RefCounted
## One party member or enemy in a battle. Stats are snapshotted at battle start by CombatManager;
## `ref` points back at the CatCharacter / EnemyData. Pure data + stat math, no scene access.

var id: String
var name: String
## Base speed including equipment (before buffs)
var speed: float
var meter: float = 0.0
var is_player: bool
var slot_index: int
var current_hp: int
var max_hp: int
var current_mp: int
var max_mp: int
## Attack power before buffs. Players: effective STR + all equipment attack_bonus. Enemies: attack_damage.
var strength: int
## Defense before buffs. Players: base defense + all equipment defense_bonus. Enemies: defense.
var defense: int
var is_front_row: bool = true
var ref: Resource
var active_effects: Array[ActiveEffect] = []

## Attack bonus that comes from hand-held weapons (removed for UNARMED attacks, e.g. out of ammo)
var weapon_attack: int = 0
## ItemData.EffectElement -> fraction of that damage ignored (0.0 - 0.9). MAGIC = magic defense.
var element_resists: Dictionary = {}
## ItemData.EffectElement this combatant takes extra damage from (enemies)
var weakness: int = 0
## Multiplier on outgoing spell damage (equipment "Amplify")
var spell_amplify: float = 1.0
## Fraction of the target's defense ignored by weapon attacks (equipment "Pierce")
var pierce: float = 0.0
## [{ "id": status_id, "chance": 0..1 }] rolled on every weapon hit (equipment "Burn"/"Freeze"/"Stun")
var on_hit_statuses: Array[Dictionary] = []
## Enemy spellcasting
var can_cast_spells: bool = false
var spells: Array[Resource] = []
var magic_power: int = 0
## Physical attack type string: BLADE / BASH / RANGED / MAGIC / UNARMED
var attack_type: String = "UNARMED"


func _init(
	p_id: String,
	p_name: String,
	p_speed: float,
	p_is_player: bool,
	p_slot: int,
	p_hp: int,
	p_max_hp: int,
	p_mp: int,
	p_max_mp: int,
	p_str: int,
	p_def: int,
	p_ref: Resource,
	p_is_front: bool = true,
) -> void:
	id = p_id
	name = p_name
	speed = maxf(1.0, p_speed)
	is_player = p_is_player
	slot_index = p_slot
	current_hp = p_hp
	max_hp = max(1, p_max_hp)
	current_mp = p_mp
	max_mp = max(0, p_max_mp)
	strength = p_str
	defense = p_def
	ref = p_ref
	is_front_row = p_is_front


func add_effect(effect: ActiveEffect) -> void:
	for existing: ActiveEffect in active_effects:
		if existing.id == effect.id:
			existing.duration = max(existing.duration, effect.duration)
			existing.value = effect.value
			return
	active_effects.append(effect)


func has_effect_type(effect_type: StringName) -> bool:
	for eff: ActiveEffect in active_effects:
		# Permanent gear buffs use duration < 0; timed effects need remaining turns.
		if eff.effect_type == effect_type and (eff.duration > 0 or eff.duration < 0):
			return true
	return false


## Display names of currently active negative status effects (poison, stun, etc.).
func get_negative_status_names() -> Array[String]:
	var names: Array[String] = []
	var seen: Dictionary = {}
	for eff: ActiveEffect in active_effects:
		if eff.duration == 0:
			continue
		if not _is_negative_effect(eff):
			continue
		var label: String = eff.name if not eff.name.is_empty() else eff.id
		if label.is_empty() or seen.has(label):
			continue
		seen[label] = true
		names.append(label)
	return names


func _is_negative_effect(eff: ActiveEffect) -> bool:
	if not is_instance_valid(eff):
		return false
	# Runtime types that are always harmful
	if eff.effect_type == &"DOT" or eff.effect_type == &"SKIP_TURN" or eff.effect_type == &"LOCK_MAGIC":
		return true
	if (eff.effect_type == &"STAT_BUFF" or eff.effect_type == &"STAT_PCT") and eff.value < 0.0:
		return true
	# Prefer authored StatusEffectData when available (strip @slot unique suffix from gear)
	if not eff.id.is_empty():
		var lookup_id: String = eff.id.split("@")[0]
		var data: StatusEffectData = StatusEffectDatabase.get_effect(lookup_id)
		if is_instance_valid(data):
			return data.type == StatusEffectData.EffectType.NEGATIVE
	return false


## Applies flat (STAT_BUFF) then percent (STAT_PCT) modifiers for one stat.
func get_effective_stat(stat_name: StringName, base_val: int) -> int:
	var flat: float = 0.0
	var pct: float = 0.0
	for eff: ActiveEffect in active_effects:
		if eff.stat_target != stat_name:
			continue
		if eff.effect_type == &"STAT_BUFF":
			flat += eff.value
		elif eff.effect_type == &"STAT_PCT":
			pct += eff.value
	var result: float = (float(base_val) + flat) * maxf(0.0, 1.0 + pct / 100.0)
	return maxi(0, roundi(result))


## Percent-only multiplier for stats that have no base number (magic power, accuracy)
func get_stat_multiplier(stat_name: StringName) -> float:
	var pct: float = 0.0
	for eff: ActiveEffect in active_effects:
		if eff.stat_target == stat_name and eff.effect_type == &"STAT_PCT":
			pct += eff.value
	return maxf(0.0, 1.0 + pct / 100.0)


## Attack power used by physical attacks. Unarmed attacks drop the weapon's attack bonus.
func get_effective_attack(is_unarmed: bool = false) -> int:
	var base_atk: int = strength - (weapon_attack if is_unarmed else 0)
	return maxi(1, get_effective_stat(&"strength", base_atk))


func get_effective_strength() -> int:
	return get_effective_attack(false)


func get_effective_defense() -> int:
	return get_effective_stat(&"defense", defense)


func get_effective_speed() -> float:
	return maxf(1.0, float(get_effective_stat(&"speed", roundi(speed))))


func get_resist(element: int) -> float:
	return clampf(float(element_resists.get(element, 0.0)), 0.0, 0.9)


## Shields soak damage before HP. Returns the damage left over.
func absorb_with_shields(amount: int, is_magic: bool) -> int:
	var remaining: int = amount
	for eff: ActiveEffect in active_effects:
		if remaining <= 0:
			break
		var soaks: bool = eff.effect_type == &"SHIELD" or (is_magic and eff.effect_type == &"MAGIC_SHIELD")
		if not soaks or eff.value <= 0.0:
			continue
		var used: int = mini(remaining, int(eff.value))
		eff.value -= float(used)
		remaining -= used

	var kept: Array[ActiveEffect] = []
	for eff: ActiveEffect in active_effects:
		var is_shield: bool = eff.effect_type == &"SHIELD" or eff.effect_type == &"MAGIC_SHIELD"
		if is_shield and eff.value <= 0.0:
			continue
		kept.append(eff)
	active_effects = kept
	return remaining
