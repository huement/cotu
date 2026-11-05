# res://Scripts/Managers/CombatManager.gd
extends Node

## Turn-meter (ATB style) combat. See res://Scripts/Managers/COMBAT_README.md for the full flow.


# ==============================================================================
# ACTIVE EFFECTS (buffs, debuffs, DoT/HoT, shields, crowd control)
# ==============================================================================
class ActiveEffect:
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


# ==============================================================================
# COMBATANT (one per party member / enemy, stats are snapshotted at battle start)
# ==============================================================================
class Combatant:
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
			if eff.effect_type == effect_type and eff.duration > 0:
				return true
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


# ==============================================================================
# CONFIGURATION
# ==============================================================================
const MAX_TURN_METER: float = 100.0

@export var is_combat_active: bool = false
@export var is_paused_for_input: bool = false
@export var base_flee_chance: float = 0.60

@export_group("Pacing")
## Meter fill per second = effective speed * base_tick_rate. At 25, speed 10 fills in 0.4 s.
@export var base_tick_rate: float = 25.0
## Seconds between the weapon swing starting and the hit landing.
@export var player_attack_windup: float = 0.25
## Seconds between an enemy's attack animation starting and the hit landing.
@export var enemy_attack_windup: float = 0.45
## Seconds between a spell/skill VFX starting and the effect landing.
@export var spell_windup: float = 0.35
## Meters stay frozen this long after every action so animations can finish.
@export var action_recovery: float = 0.55
## Seconds to hold the battle scene after the last enemy dies (death animations).
@export var victory_linger: float = 1.0

@export_group("Damage Tuning")
## Defense every party member has before armor.
@export var player_base_defense: int = 2
## Damage multiplier when an attack matches the target's weakness_element.
@export var weakness_multiplier: float = 1.5
## Chance (0-1) that an enemy with can_cast_spells uses a spell instead of a physical attack.
@export_range(0.0, 1.0, 0.05) var enemy_spell_chance: float = 0.5

var is_transitioning_out: bool = false
var combatants: Array[Combatant] = []
var turn_queue: Array[Combatant] = []
var active_combatant: Combatant = null
var guarding_characters: Array[int] = [] # Party slot indices currently guarding

## True while an action (attack/spell/item...) is playing out. Meters are frozen.
var _is_resolving_action: bool = false
## Incremented every battle so coroutines from an old battle never touch a new one.
var _battle_serial: int = 0
var _is_water_battle: bool = false
## spell_id -> SpellData, built once from res://Data/Spells/
var _spell_index: Dictionary = {}


func _ready() -> void:
	var sb: Node = SignalBus
	if is_instance_valid(sb):
		if not sb.combat_started.is_connected(_on_combat_started):
			sb.combat_started.connect(_on_combat_started)
		if not sb.combat_ended.is_connected(_on_combat_ended):
			sb.combat_ended.connect(_on_combat_ended)
		if not sb.player_action_selected.is_connected(_on_player_action_selected):
			sb.player_action_selected.connect(_on_player_action_selected)


func _process(delta: float) -> void:
	_run_hud_watchdog(delta)
	if not _can_advance():
		return
	_tick_turn_meters(delta)


# ==============================================================================
# HUD WATCHDOG - a running battle must always have its HUD on screen
# ==============================================================================
## How often (seconds) the watchdog checks, and how long the HUD may be missing before it acts.
const HUD_WATCHDOG_INTERVAL: float = 0.5
const HUD_WATCHDOG_GRACE: float = 1.0

var _watchdog_timer: float = 0.0
var _hud_missing_time: float = 0.0
var _battle_payload: Variant = null
var _battle_party: Array = []
var _battle_hud_node: Control = null


func _run_hud_watchdog(delta: float) -> void:
	if not is_combat_active or is_transitioning_out:
		_hud_missing_time = 0.0
		return
	_watchdog_timer += delta
	if _watchdog_timer < HUD_WATCHDOG_INTERVAL:
		return
	_watchdog_timer = 0.0

	if not is_instance_valid(_battle_hud_node):
		_battle_hud_node = get_tree().root.find_child("BattleHUD", true, false) as Control
	if not is_instance_valid(_battle_hud_node):
		return
	if _battle_hud_node.is_visible_in_tree():
		_hud_missing_time = 0.0
		return

	_hud_missing_time += HUD_WATCHDOG_INTERVAL
	if _hud_missing_time < HUD_WATCHDOG_GRACE:
		return
	_hud_missing_time = 0.0
	push_warning("CombatManager: battle is running but the battle HUD is hidden - restoring it.")
	GameLogger.combat("⚠️ Watchdog: battle HUD was hidden during combat - restoring it.")
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(gs) and "current_mode" in gs:
		gs.set("current_mode", 1) # Mode.BATTLE
	SignalBus.battle_hud_recovery_requested.emit(_battle_payload, _battle_party)
	# Re-announce a player turn that was waiting, so the action bar comes back.
	if is_paused_for_input and active_combatant != null and active_combatant.is_player:
		SignalBus.combatant_turn_ready.emit(active_combatant.id, active_combatant.slot_index)


func _can_advance() -> bool:
	return is_combat_active and not is_transitioning_out and not is_paused_for_input and not _is_resolving_action


func _is_same_battle(serial: int) -> bool:
	return serial == _battle_serial and is_combat_active and not is_transitioning_out


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout


# ==============================================================================
# BATTLE START
# ==============================================================================
func _on_combat_started(enemy_data_or_group: Variant, player_party: Array, _enemy_facing: String) -> void:
	if is_combat_active:
		return

	_battle_serial += 1
	_reset_battle_state()
	_battle_payload = enemy_data_or_group
	_battle_party = player_party
	_hud_missing_time = 0.0

	for i in range(player_party.size()):
		var cat: Resource = player_party[i] as Resource
		if is_instance_valid(cat):
			combatants.append(_build_player_combatant(cat, i))

	var enemy_resources: Array[Resource] = _resolve_enemy_resources(enemy_data_or_group)
	for e_idx in range(enemy_resources.size()):
		var raw_e_data: Resource = enemy_resources[e_idx]
		if is_instance_valid(raw_e_data):
			combatants.append(_build_enemy_combatant(raw_e_data, e_idx, enemy_resources.size()))

	_is_water_battle = _detect_water_battle()
	is_combat_active = true

	if _check_battle_state():
		return

	for c: Combatant in combatants:
		c.meter = minf(MAX_TURN_METER, c.get_effective_speed() * 5.0)
		SignalBus.turn_meter_updated.emit(c.id, c.meter / MAX_TURN_METER)
		GameLogger.combat("%s ready: ATK %d  DEF %d  SPD %.0f  HP %d/%d  MRES %.0f%%" % [
			c.name, c.get_effective_attack(), c.get_effective_defense(), c.get_effective_speed(),
			c.current_hp, c.max_hp, c.get_resist(ItemData.EffectElement.MAGIC) * 100.0])


func _reset_battle_state() -> void:
	combatants.clear()
	turn_queue.clear()
	active_combatant = null
	guarding_characters.clear()
	is_combat_active = false
	is_paused_for_input = false
	is_transitioning_out = false
	_is_resolving_action = false
	_is_water_battle = false


func _build_player_combatant(cat: Resource, slot: int) -> Combatant:
	var c_name: String = str(cat.get("name")) if cat.get("name") != null else "Space Cat %d" % (slot + 1)
	var c_hp: int = int(cat.get("current_hp")) if "current_hp" in cat else 20
	var c_max_hp: int = int(cat.get("max_hp")) if "max_hp" in cat else 20

	var c_mp: int = 10
	if "current_energy" in cat:
		c_mp = int(cat.get("current_energy"))
	elif "current_mp" in cat:
		c_mp = int(cat.get("current_mp"))
	elif "current_mana" in cat:
		c_mp = int(cat.get("current_mana"))

	var c_max_mp: int = maxi(c_mp, 10)
	if "max_energy" in cat:
		c_max_mp = int(cat.get("max_energy"))
	elif "max_mp" in cat:
		c_max_mp = int(cat.get("max_mp"))
	elif "max_mana" in cat:
		c_max_mp = int(cat.get("max_mana"))

	# Core attributes INCLUDING "+stat" equipment (same numbers the character sheet shows)
	var base_str: int = _get_cat_attribute(cat, &"strength", 10)
	var base_spd: int = _get_cat_attribute(cat, &"speed", 8)

	var equip_atk: int = 0
	var equip_def: int = 0
	var equip_spd: int = 0
	var weapon_atk: int = 0
	var resists: Dictionary = {}
	var amplify: float = 1.0
	var pierce: float = 0.0
	var on_hit: Array[Dictionary] = []

	for entry: Dictionary in _get_equipped_items(cat):
		var item: Resource = entry["item"]
		var slot_name: String = entry["slot"]
		var atk_b: int = int(item.get("attack_bonus")) if "attack_bonus" in item else 0
		equip_atk += atk_b
		equip_def += int(item.get("defense_bonus")) if "defense_bonus" in item else 0
		equip_spd += int(item.get("speed_bonus")) if "speed_bonus" in item else 0
		if _is_hand_weapon(item, slot_name):
			weapon_atk += atk_b

		# Special equipment effects (ItemData.effects / effect_amount / effect_element)
		var fx: String = str(item.get("effects")).strip_edges().to_upper() if "effects" in item else ""
		if fx.is_empty():
			continue
		var amount: float = float(item.get("effect_amount")) if "effect_amount" in item else 0.0
		var element: int = int(item.get("effect_element")) if "effect_element" in item else 0
		match fx:
			"RESIST":
				resists[element] = float(resists.get(element, 0.0)) + _as_fraction(amount)
			"AMPLIFY":
				if amount > 0.0:
					amplify *= amount
			"PIERCE":
				pierce += _as_fraction(amount)
			"BURN":
				on_hit.append({ "id": "eff_hp_burn_1", "chance": _as_fraction(amount) })
			"FREEZE":
				on_hit.append({ "id": "eff_freeze_1", "chance": _as_fraction(amount) })
			"STUN":
				on_hit.append({ "id": "eff_stun_1", "chance": _as_fraction(amount) })

	var c_is_front: bool = bool(cat.get("is_front_row")) if "is_front_row" in cat else (slot <= 2)

	var c: Combatant = Combatant.new(
		"party_slot_%d" % slot, c_name, float(base_spd + equip_spd), true, slot,
		c_hp, c_max_hp, c_mp, c_max_mp,
		base_str + equip_atk, player_base_defense + equip_def, cat, c_is_front)
	c.weapon_attack = weapon_atk
	c.element_resists = resists
	c.spell_amplify = amplify
	c.pierce = clampf(pierce, 0.0, 1.0)
	c.on_hit_statuses = on_hit
	c.attack_type = str(cat.call("get_attack_type_string")) if cat.has_method("get_attack_type_string") else "UNARMED"
	return c


func _build_enemy_combatant(raw_e_data: Resource, e_idx: int, pack_size: int) -> Combatant:
	# Duplicate so combat mutations never touch the source .tres
	var e_data: Resource = raw_e_data.duplicate(true)

	var e_speed: float = float(e_data.get("speed")) if "speed" in e_data else 10.0
	var e_max_hp: int = int(e_data.get("max_health")) if "max_health" in e_data else (int(e_data.get("max_hp")) if "max_hp" in e_data else 90)
	var e_hp: int = e_max_hp
	if "current_health" in e_data and int(e_data.get("current_health")) > 0:
		e_hp = mini(int(e_data.get("current_health")), e_max_hp)
	if "current_health" in e_data:
		e_data.set("current_health", e_hp)

	# EnemyData's attack stat is attack_damage (there is no "strength" on enemies)
	var e_atk: int = 16
	if "attack_damage" in e_data:
		e_atk = int(e_data.get("attack_damage"))
	elif "strength" in e_data:
		e_atk = int(e_data.get("strength"))
	var e_def: int = int(e_data.get("defense")) if "defense" in e_data else 8

	var e_name: String = str(e_data.get("enemy_name")) if e_data.get("enemy_name") != null else "Enemy"
	if pack_size > 1:
		e_name = "%s %c" % [e_name, 65 + e_idx]
	var e_is_front: bool = bool(e_data.get("is_front_row")) if "is_front_row" in e_data else true

	var c: Combatant = Combatant.new("enemy_%d" % e_idx, e_name, e_speed, false, e_idx, e_hp, e_max_hp, 0, 0, e_atk, e_def, e_data, e_is_front)
	c.weakness = int(e_data.get("weakness_element")) if "weakness_element" in e_data else 0
	if "magic_resist" in e_data:
		c.element_resists[ItemData.EffectElement.MAGIC] = float(e_data.get("magic_resist"))
	c.magic_power = int(e_data.get("magic_power")) if "magic_power" in e_data else 0
	c.can_cast_spells = bool(e_data.get("can_cast_spells")) if "can_cast_spells" in e_data else false
	if c.can_cast_spells:
		c.spells = _resolve_enemy_spells(e_data)
	c.attack_type = _attack_type_from_element(int(e_data.get("attack_element")) if "attack_element" in e_data else ItemData.EffectElement.BASH)
	return c


## Reads a core attribute the way the character sheet does (includes "+stat" equipment).
func _get_cat_attribute(cat: Resource, stat: StringName, fallback: int) -> int:
	if cat.has_method("get_effective_stat"):
		return int(cat.call("get_effective_stat", stat))
	if str(stat) in cat:
		return int(cat.get(str(stat)))
	return fallback


## Every equipped item, including ARMS / FEET / BOTH_HANDS, de-duplicated.
func _get_equipped_items(cat: Resource) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	var slot_map: Dictionary = {}

	if "equipment" in cat and cat.get("equipment") is Dictionary:
		slot_map = cat.get("equipment") as Dictionary
	elif cat.has_method("get_equipped_item"):
		for slot_name: String in ["HEAD", "BODY", "ARMS", "LEGS", "FEET", "LEFT_HAND", "RIGHT_HAND", "BOTH_HANDS", "ACCESSORY_1", "ACCESSORY_2"]:
			slot_map[slot_name] = cat.call("get_equipped_item", slot_name)

	for slot_name in slot_map.keys():
		var item: Resource = slot_map[slot_name] as Resource
		if not is_instance_valid(item):
			continue
		var key: int = item.get_instance_id()
		if seen.has(key):
			continue
		seen[key] = true
		result.append({ "slot": str(slot_name), "item": item })
	return result


func _is_hand_weapon(item: Resource, slot_name: String) -> bool:
	if not slot_name in ["LEFT_HAND", "RIGHT_HAND", "BOTH_HANDS"]:
		return false
	if "weapon_type" in item and int(item.get("weapon_type")) != ItemData.WeaponType.NONE:
		return true
	return "item_type" in item and int(item.get("item_type")) == ItemData.ItemType.WEAPON


## effect_amount values <= 1 are fractions (0.2 = 20%), larger values are percents (50 = 50%).
func _as_fraction(amount: float) -> float:
	if amount > 1.0:
		return clampf(amount / 100.0, 0.0, 1.0)
	return clampf(amount, 0.0, 1.0)


func _attack_type_from_element(element: int) -> String:
	match element:
		ItemData.EffectElement.BLADE:
			return "BLADE"
		ItemData.EffectElement.RANGED:
			return "RANGED"
		ItemData.EffectElement.MAGIC:
			return "MAGIC"
		_:
			return "BASH"


func _element_for_attack_type(attack_type: String) -> int:
	match attack_type:
		"BLADE":
			return ItemData.EffectElement.BLADE
		"RANGED":
			return ItemData.EffectElement.RANGED
		"MAGIC":
			return ItemData.EffectElement.MAGIC
		_:
			return ItemData.EffectElement.BASH # BASH and UNARMED


# ==============================================================================
# TURN METERS & TURN QUEUE
# ==============================================================================
func _tick_turn_meters(delta: float) -> void:
	for c: Combatant in combatants:
		if c.current_hp <= 0 or c.meter >= MAX_TURN_METER:
			continue
		c.meter = minf(c.meter + c.get_effective_speed() * base_tick_rate * delta, MAX_TURN_METER)
		SignalBus.turn_meter_updated.emit(c.id, c.meter / MAX_TURN_METER)
		if c.meter >= MAX_TURN_METER and not turn_queue.has(c) and active_combatant != c:
			turn_queue.append(c)

	if not turn_queue.is_empty():
		_process_turn_queue()


## Starts the next ready combatant's turn. Players pause for input; enemies act on their own.
func _process_turn_queue() -> void:
	while _can_advance() and not turn_queue.is_empty():
		var c: Combatant = turn_queue.pop_front()
		if c == null or c.current_hp <= 0:
			continue

		if c.is_player:
			guarding_characters.erase(c.slot_index) # Guard lasts until this character's next turn

		var skip_turn: bool = _tick_effects_at_turn_start(c)
		if _check_battle_state():
			return
		if c.current_hp <= 0:
			_reset_combatant_meter(c)
			continue
		if skip_turn:
			GameLogger.combat("%s is unable to act!" % c.name)
			_toast("%s is unable to act!" % c.name, not c.is_player)
			_reset_combatant_meter(c)
			continue

		active_combatant = c
		if c.is_player:
			is_paused_for_input = true
			SignalBus.combatant_turn_ready.emit(c.id, c.slot_index)
		else:
			_run_enemy_turn(c, _battle_serial)
		return


## Ticks DoT/HoT and durations. Returns true if a stun/freeze makes this combatant skip its turn.
func _tick_effects_at_turn_start(c: Combatant) -> bool:
	var skip_turn: bool = c.has_effect_type(&"SKIP_TURN")
	var expired: Array[ActiveEffect] = []

	for eff: ActiveEffect in c.active_effects:
		if eff.effect_type == &"DOT":
			GameLogger.combat("%s took %d damage from %s!" % [c.name, int(eff.value), eff.name])
			_apply_damage_to_combatant(c, int(eff.value), null, null, false, "DOT")
		elif eff.effect_type == &"HOT":
			_heal_combatant(c, int(eff.value), eff.name)

		eff.duration -= 1
		if eff.duration <= 0:
			expired.append(eff)

	for eff: ActiveEffect in expired:
		c.active_effects.erase(eff)
		GameLogger.combat("%s wore off %s" % [eff.name, c.name])

	return skip_turn


## Every action ends here: reset the meter, check for victory/defeat, give animations time, continue.
func _end_action(actor: Combatant, serial: int) -> void:
	if serial != _battle_serial:
		return
	_reset_combatant_meter(actor)
	if _check_battle_state():
		return

	await _wait(action_recovery)
	if not _is_same_battle(serial):
		return

	active_combatant = null
	_is_resolving_action = false
	_process_turn_queue()


# ==============================================================================
# PLAYER ACTIONS
# ==============================================================================
func _on_player_action_selected(slot_index: int, action_type: StringName, target_index: int) -> void:
	if not is_combat_active or is_transitioning_out or _is_resolving_action:
		return
	if active_combatant == null or not active_combatant.is_player or active_combatant.slot_index != slot_index:
		return

	var actor: Combatant = active_combatant
	var serial: int = _battle_serial
	is_paused_for_input = false
	_is_resolving_action = true

	match action_type:
		&"DEFEND", &"GUARD":
			execute_guard_action(actor.slot_index)
		&"RUN", &"FLEE", &"FLEED":
			execute_run_action(int(actor.get_effective_speed()), _get_average_enemy_speed())
		&"ITEM":
			_execute_item_use_in_combat(actor, target_index)
		&"SPELL", &"SKILL":
			var target_mgr: Node = get_tree().root.get_node_or_null("TargetSelectionManager")
			var ability: Resource = target_mgr.call("get_pending_ability") if is_instance_valid(target_mgr) and target_mgr.has_method("get_pending_ability") else null
			if is_instance_valid(target_mgr) and target_mgr.has_method("clear_pending_ability"):
				target_mgr.call("clear_pending_ability")
			await _execute_ability(actor, ability, action_type, target_index, serial)
		_:
			await _execute_physical_attack(actor, target_index, serial)

	if not _is_same_battle(serial):
		return
	_end_action(actor, serial)


func _execute_physical_attack(attacker: Combatant, target_index: int, serial: int) -> void:
	var attack_type: String = attacker.attack_type
	if attacker.is_player and attack_type == "RANGED" and not _consume_ranged_ammo(attacker):
		GameLogger.combat("%s has no ammo! Falling back to an unarmed attack." % attacker.name)
		attack_type = "UNARMED"

	var target: Combatant = _pick_opponent(attacker, target_index)
	if target == null:
		return

	# 1. Start the swing / attack animation
	if attacker.is_player:
		_emit_weapon_swing(attack_type)
	else:
		SignalBus.enemy_attack_started.emit(attacker.id)
		_play_enemy_type_sound(attacker, "attack")

	# 2. Let it wind up, then land the hit
	await _wait(player_attack_windup if attacker.is_player else enemy_attack_windup)
	if not _is_same_battle(serial):
		return
	if target.current_hp <= 0:
		target = _pick_opponent(attacker, -1)
		if target == null:
			return

	var damage: int = _calculate_physical_damage(attacker, target, attack_type)
	GameLogger.combat("%s attacked %s (%s) for %d damage" % [attacker.name, target.name, attack_type, damage])
	_apply_damage_to_combatant(target, damage, attacker, _get_weapon_resource(attacker, attack_type), false, attack_type)

	# 3. Weapon on-hit effects (Burn / Freeze / Stun)
	if attack_type != "UNARMED" and target.current_hp > 0:
		for proc: Dictionary in attacker.on_hit_statuses:
			if randf() < float(proc.get("chance", 0.0)):
				_apply_status(target, str(proc.get("id", "")), attacker)


## "<enemy_type>_<action>.mp3" (beast_attack, minotaur_attack...) if the enemy type has one.
func _play_enemy_type_sound(enemy: Combatant, action: String) -> void:
	if enemy == null or enemy.is_player or not is_instance_valid(enemy.ref) or not is_instance_valid(AudioManager):
		return
	var e_type: String = str(enemy.ref.get("enemy_type")) if "enemy_type" in enemy.ref else ""
	if AudioManager.has_method("play_enemy_action_sound"):
		AudioManager.play_enemy_action_sound(e_type, action)


func _get_weapon_resource(attacker: Combatant, attack_type: String) -> Resource:
	if attack_type == "UNARMED" or not attacker.is_player or not is_instance_valid(attacker.ref):
		return null
	if attacker.ref.has_method("get_equipped_item"):
		var right: Resource = attacker.ref.call("get_equipped_item", "RIGHT_HAND") as Resource
		if is_instance_valid(right):
			return right
		return attacker.ref.call("get_equipped_item", "LEFT_HAND") as Resource
	return null


## Process a Guard Command
func execute_guard_action(caster_index: int) -> void:
	if not guarding_characters.has(caster_index):
		guarding_characters.append(caster_index)
	SignalBus.character_guarded.emit(caster_index)
	GameLogger.combat("Slot %d raises their defense!" % (caster_index + 1))
	_toast("Slot %d guards!" % (caster_index + 1), false)


## Process a Run / Flee Command
func execute_run_action(caster_speed: int, enemy_avg_speed: int) -> void:
	var speed_diff: int = caster_speed - enemy_avg_speed
	var final_flee_chance: float = clampf(base_flee_chance + (speed_diff * 0.05), 0.15, 0.95)

	if randf() <= final_flee_chance:
		GameLogger.combat("The party successfully fled from battle!")
		SignalBus.party_flee_attempted.emit(true)
		_toast("The party successfully fled from battle!", false)
		_finish_battle(false)
	else:
		GameLogger.combat("Escape failed! The enemies block your retreat!")
		SignalBus.party_flee_attempted.emit(false)
		_toast("Escape failed! The enemies block your retreat!", true)


# ==============================================================================
# ENEMY TURN
# ==============================================================================
func _run_enemy_turn(enemy: Combatant, serial: int) -> void:
	_is_resolving_action = true

	var spell: Resource = _choose_enemy_spell(enemy)
	if is_instance_valid(spell):
		SignalBus.enemy_attack_started.emit(enemy.id)
		await _execute_ability(enemy, spell, &"SPELL", -1, serial)
	else:
		await _execute_physical_attack(enemy, -1, serial)

	if not _is_same_battle(serial):
		return
	_end_action(enemy, serial)


func _choose_enemy_spell(enemy: Combatant) -> Resource:
	if not enemy.can_cast_spells or enemy.spells.is_empty():
		return null
	if enemy.has_effect_type(&"LOCK_MAGIC"):
		return null
	if randf() > enemy_spell_chance:
		return null
	return enemy.spells.pick_random()


## Resolves EnemyData.spell_ids (or other spell properties) into SpellData resources, once per battle.
func _resolve_enemy_spells(enemy_ref: Resource) -> Array[Resource]:
	var found: Array[Resource] = []
	for key: String in ["spell_ids", "spells", "known_spells", "abilities"]:
		if not key in enemy_ref:
			continue
		var val: Variant = enemy_ref.get(key)
		var entries: Array = val if val is Array else [val]
		for entry in entries:
			if entry is Resource:
				found.append(entry as Resource)
			elif entry is String and not str(entry).strip_edges().is_empty():
				var spell: Resource = _load_spell_by_id(str(entry))
				if is_instance_valid(spell):
					found.append(spell)
				else:
					GameLogger.combat("[AI] Unknown spell id '%s' on %s" % [entry, enemy_ref.get("enemy_name")])
	return found


func _load_spell_by_id(spell_id: String) -> Resource:
	if spell_id.begins_with("res://"):
		return load(spell_id) as Resource if ResourceLoader.exists(spell_id) else null

	if _spell_index.is_empty():
		var dir := DirAccess.open("res://Data/Spells/")
		if dir:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")):
					var res: Resource = load("res://Data/Spells/" + file_name.trim_suffix(".remap")) as Resource
					if is_instance_valid(res) and "spell_id" in res:
						_spell_index[str(res.get("spell_id"))] = res
				file_name = dir.get_next()
			dir.list_dir_end()

	return _spell_index.get(spell_id, null) as Resource


# ==============================================================================
# SPELLS & SKILLS (players and enemies)
# ==============================================================================
func _execute_ability(caster: Combatant, ability: Resource, kind: StringName, target_index: int, serial: int) -> void:
	if not is_instance_valid(ability):
		GameLogger.combat("%s tried to use an ability, but none was selected." % caster.name)
		return

	var ability_name: String = _get_ability_name(ability)
	var category: String = _get_ability_category(ability)

	if kind == &"SPELL" and caster.has_effect_type(&"LOCK_MAGIC"):
		_toast("%s is silenced and can't cast %s!" % [caster.name, ability_name], true)
		return

	# Mana is spent ONLY here (the ability popup no longer subtracts it)
	var cost: int = int(ability.get("energy_cost")) if "energy_cost" in ability else 0
	if caster.is_player and cost > 0:
		if caster.current_mp < cost:
			_toast("%s doesn't have enough MANA to cast %s!" % [caster.name, ability_name], true)
			return
		caster.current_mp -= cost
		_sync_mp_to_ref(caster)
		SignalBus.character_mana_changed.emit(caster.slot_index, caster.current_mp, caster.max_mp)

	if kind == &"SKILL":
		if is_instance_valid(AudioManager):
			AudioManager.play_skill_sound(ability_name)
		var accuracy: float = float(ability.get("accuracy")) if "accuracy" in ability else 100.0
		accuracy *= caster.get_stat_multiplier(&"accuracy")
		if randf() * 100.0 > accuracy:
			GameLogger.combat("%s used %s, but it MISSED!" % [caster.name, ability_name])
			_toast("%s's %s missed!" % [caster.name, ability_name], caster.is_player)
			return

	var is_revive: bool = category == "HEAL" and ("revive" in ability_name.to_lower() or "revive" in str(ability.get("spell_id") if "spell_id" in ability else "").to_lower())
	var targets: Array[Combatant] = _resolve_ability_targets(caster, ability, target_index, is_revive)
	if targets.is_empty():
		GameLogger.combat("%s used %s, but there was no valid target." % [caster.name, ability_name])
		return

	# Cast VFX once, then wind up
	var anim_name: String = str(ability.get("animation")) if "animation" in ability else "NONE"
	if anim_name != "NONE" and not anim_name.is_empty():
		var vfx_element: ItemData.ElementalBase = ItemData.ElementalBase.NONE
		if ability is SpellData:
			vfx_element = (ability as SpellData).element
		SignalBus.spell_vfx_requested.emit(anim_name, vfx_element)
		SignalBus.camera_shake_requested.emit(0.6)
	elif kind == &"SKILL" and caster.is_player and category == "DAMAGE":
		_emit_weapon_swing(caster.attack_type)

	await _wait(spell_windup)
	if not _is_same_battle(serial):
		return

	var power: float = _get_ability_power(caster, ability, kind)
	var status_id: String = _get_status_id(ability)
	var duration: int = _get_ability_duration(ability, kind)

	for t: Combatant in targets:
		if t.current_hp <= 0 and not is_revive:
			continue
		match category:
			"DAMAGE":
				var damage: int = _calculate_ability_damage(caster, t, ability, kind, power)
				GameLogger.combat("%s used %s on %s for %d damage" % [caster.name, ability_name, t.name, damage])
				_apply_damage_to_combatant(t, damage, caster, ability, kind == &"SPELL", "SPELL" if kind == &"SPELL" else caster.attack_type)
				if t.current_hp > 0 and not status_id.is_empty():
					_apply_status(t, status_id, caster, duration)
			"HEAL":
				var heal_amt: int = maxi(1, roundi(power))
				_heal_combatant(t, heal_amt, ability_name)
				if not status_id.is_empty():
					_apply_status(t, status_id, caster, duration)
				elif kind == &"SPELL" and duration > 1:
					t.add_effect(ActiveEffect.new(_get_ability_id(ability), ability_name, duration - 1, &"HOT", &"", power, caster.id))
			"BUFF":
				if not status_id.is_empty():
					_apply_status(t, status_id, caster, duration)
				else:
					t.add_effect(ActiveEffect.new(_get_ability_id(ability), ability_name, duration, &"STAT_BUFF", &"defense", power, caster.id))
					GameLogger.combat("%s: %s gains +%.0f defense for %d turns" % [ability_name, t.name, power, duration])
			"DEBUFF":
				if not status_id.is_empty():
					_apply_status(t, status_id, caster, duration)
				else:
					t.add_effect(ActiveEffect.new(_get_ability_id(ability), ability_name, duration, &"STAT_BUFF", &"defense", -power, caster.id))
					GameLogger.combat("%s: %s loses %.0f defense for %d turns" % [ability_name, t.name, power, duration])
			_:
				if not status_id.is_empty():
					_apply_status(t, status_id, caster, duration)
				else:
					GameLogger.combat("%s used %s (no combat effect)" % [caster.name, ability_name])


## "DAMAGE" / "HEAL" / "BUFF" / "DEBUFF" / "UTILITY" from the resource's effect_type enum.
func _get_ability_category(ability: Resource) -> String:
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


## Potency before the target's defenses.
func _get_ability_power(caster: Combatant, ability: Resource, kind: StringName) -> float:
	if ability.has_method("calculate_potency"):
		var caster_stat: int = caster.magic_power
		if caster.is_player and is_instance_valid(caster.ref):
			var stat_key: String = str(ability.get("stat_scaling")).to_lower() if "stat_scaling" in ability else "int"
			caster_stat = _get_cat_attribute(caster.ref, StringName(stat_key), 10)
		var potency: float = float(ability.call("calculate_potency", caster_stat))
		if kind == &"SPELL":
			potency *= caster.get_stat_multiplier(&"magic") * caster.spell_amplify
		return potency
	if "effect_amount" in ability:
		return float(ability.get("effect_amount"))
	if "base_amount" in ability:
		return float(ability.get("base_amount"))
	return 10.0


func _calculate_ability_damage(caster: Combatant, target: Combatant, ability: Resource, kind: StringName, power: float) -> int:
	var dmg: float = power

	if kind == &"SPELL":
		# Magic: weakness MAGIC (or LIFE for life spells), reduced by magic resist (magic defense)
		var is_life: bool = ability is SpellData and (ability as SpellData).element == ItemData.ElementalBase.LIFE
		var weak: bool = target.weakness == ItemData.EffectElement.MAGIC or (is_life and target.weakness == ItemData.EffectElement.LIFE)
		if weak:
			dmg *= weakness_multiplier
			GameLogger.combat("%s is weak to magic!" % target.name)
		dmg *= 1.0 - target.get_resist(ItemData.EffectElement.MAGIC)
	else:
		# Physical skill: row, guard, weakness and element resist apply (defense does not)
		var element: int = int(ability.get("element")) if "element" in ability else 0
		if element == ItemData.EffectElement.NONE:
			element = _element_for_attack_type(caster.attack_type)
		if not target.is_front_row:
			dmg *= 0.5
		if target.is_player and guarding_characters.has(target.slot_index):
			dmg *= 0.5
		if target.weakness != ItemData.EffectElement.NONE and target.weakness == element:
			dmg *= weakness_multiplier
		dmg *= 1.0 - target.get_resist(element)

	return maxi(1, roundi(dmg))


func _resolve_ability_targets(caster: Combatant, ability: Resource, target_index: int, allow_dead_ally: bool) -> Array[Combatant]:
	var target_type: int = int(ability.get("target_type")) if "target_type" in ability else 0
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
		1: # ALL_ENEMY
			result = foes
		3: # ALL_ALLY
			result = allies
		4, 5: # SELF / NONE
			result.append(caster)
		2: # SINGLE_ALLY
			var ally: Combatant = null
			if caster.is_player:
				ally = _find_combatant_by_slot(target_index, true)
			else:
				for c: Combatant in allies:
					if ally == null or c.current_hp < ally.current_hp:
						ally = c
			if ally == null or not allies.has(ally):
				ally = caster
			result.append(ally)
		_: # SINGLE_ENEMY
			var foe: Combatant = _pick_opponent(caster, target_index)
			if foe != null:
				result.append(foe)
	return result


func _get_ability_name(ability: Resource) -> String:
	for key: String in ["spell_name", "skill_name", "name"]:
		if key in ability and not str(ability.get(key)).is_empty():
			return str(ability.get(key))
	return "Ability"


func _get_ability_id(ability: Resource) -> String:
	for key: String in ["spell_id", "skill_id", "id"]:
		if key in ability and not str(ability.get(key)).is_empty():
			return str(ability.get(key))
	return _get_ability_name(ability).to_snake_case()


func _get_status_id(ability: Resource) -> String:
	var status: String = str(ability.get("status_effect")).strip_edges() if "status_effect" in ability else ""
	if status.is_empty() or status.to_upper() == "NONE":
		return ""
	return status


## Generic buff/HoT duration: ability duration x spell tier (status effects use their own duration).
func _get_ability_duration(ability: Resource, kind: StringName) -> int:
	var base_duration: int = int(ability.get("duration")) if "duration" in ability else 1
	if kind == &"SPELL" and "tier" in ability:
		base_duration *= maxi(1, int(ability.get("tier")))
	return maxi(1, base_duration)


# ==============================================================================
# STATUS EFFECTS (data-driven from Data/StatusEffects via StatusEffectDatabase)
# ==============================================================================
func _apply_status(target: Combatant, status_id: String, caster: Combatant = null, duration_override: int = 0) -> void:
	var data: StatusEffectData = StatusEffectDatabase.get_effect(status_id)
	if not is_instance_valid(data):
		GameLogger.combat("Unknown status effect '%s' - nothing applied" % status_id)
		return

	var duration: int = maxi(data.duration, duration_override)
	var caster_id: String = caster.id if caster != null else ""
	var value: float = data.modifier_value
	var effect: ActiveEffect = null

	match data.modifier_type:
		StatusEffectData.ModifierType.MULTIPLIER:
			effect = ActiveEffect.new(data.effect_id, data.name, duration, &"STAT_PCT", _modifier_stat_name(data.modifier_stat), value, caster_id)
		StatusEffectData.ModifierType.PERCENT_MAX_HP_HEAL:
			effect = ActiveEffect.new(data.effect_id, data.name, duration, &"HOT", &"", maxf(1.0, target.max_hp * value / 100.0), caster_id)
		StatusEffectData.ModifierType.PERCENT_MAX_HP_TICK:
			effect = ActiveEffect.new(data.effect_id, data.name, duration, &"DOT", &"", maxf(1.0, target.max_hp * value / 100.0), caster_id)
		StatusEffectData.ModifierType.PERCENT_SHIELD:
			effect = ActiveEffect.new(data.effect_id, data.name, duration, &"SHIELD", &"", maxf(1.0, target.max_hp * value / 100.0), caster_id)
		StatusEffectData.ModifierType.PERCENT_MAGIC_SHIELD:
			effect = ActiveEffect.new(data.effect_id, data.name, duration, &"MAGIC_SHIELD", &"", maxf(1.0, target.max_hp * value / 100.0), caster_id)
		StatusEffectData.ModifierType.CC_SKIP_TURN:
			effect = ActiveEffect.new(data.effect_id, data.name, duration, &"SKIP_TURN", &"", value, caster_id)
			target.meter = 0.0
			SignalBus.turn_meter_updated.emit(target.id, 0.0)
		StatusEffectData.ModifierType.CC_LOCK_MAGIC:
			effect = ActiveEffect.new(data.effect_id, data.name, duration, &"LOCK_MAGIC", &"", value, caster_id)

	if effect == null:
		return
	target.add_effect(effect)
	GameLogger.combat("%s is affected by %s (%d turns)" % [target.name, data.name, duration])
	_toast("%s: %s" % [target.name, data.name], target.is_player and data.type == StatusEffectData.EffectType.NEGATIVE)


func _modifier_stat_name(stat: int) -> StringName:
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


# ==============================================================================
# ITEMS
# ==============================================================================
func _execute_item_use_in_combat(acting_char: Combatant, target_slot_index: int) -> void:
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if not is_instance_valid(gs) or not "inventory" in gs or gs.inventory == null:
		return

	var inv: Inventory = gs.inventory as Inventory
	var target_mgr: Node = get_tree().root.get_node_or_null("TargetSelectionManager")
	var item_slot_idx: int = target_mgr.call("get_pending_slot_index") if is_instance_valid(target_mgr) and target_mgr.has_method("get_pending_slot_index") else -1
	if inv == null or item_slot_idx < 0 or item_slot_idx >= inv.size():
		GameLogger.combat("CombatManager: Invalid item slot index %d requested!" % item_slot_idx)
		return

	var item: ItemData = inv.get_items()[item_slot_idx]
	if not is_instance_valid(item):
		return

	match item.target_type:
		ItemData.TargetType.ALL_PARTY:
			var party_refs: Array = []
			for c: Combatant in combatants:
				if c.is_player and is_instance_valid(c.ref):
					party_refs.append(c.ref)
			if inv.use_item_on_targets(item_slot_idx, party_refs):
				_sync_party_from_refs()
				_toast("%s used %s on the whole party!" % [acting_char.name, item.item_name], false)
			else:
				_toast("%s had no effect." % item.item_name, true)

		ItemData.TargetType.ALL_ENEMIES, ItemData.TargetType.SINGLE_ENEMY:
			_use_offensive_item(acting_char, inv, item_slot_idx, item, target_slot_index)

		_:
			# SINGLE_PARTY_MEMBER / NONE: one party member (falls back to the user)
			var target_cat: Resource = null
			var target_c: Combatant = _find_combatant_by_slot(target_slot_index, true)
			if target_c != null:
				target_cat = target_c.ref
			if not is_instance_valid(target_cat):
				target_cat = acting_char.ref
			if is_instance_valid(target_cat) and inv.use_item(item_slot_idx, target_cat):
				_sync_party_from_refs()
				_toast("%s used %s." % [acting_char.name, item.item_name], false)
			else:
				_toast("The item had no effect.", true)


## Items aimed at enemies: damage = effect_amount (falls back to attack_bonus / heal_amount),
## plus any granted_status_effects. ALL_ENEMIES hits every enemy, SINGLE_ENEMY hits target_index.
func _use_offensive_item(acting_char: Combatant, inv: Inventory, item_slot_idx: int, item: ItemData, target_index: int) -> void:
	var targets: Array[Combatant] = []
	if item.target_type == ItemData.TargetType.ALL_ENEMIES:
		for c: Combatant in combatants:
			if not c.is_player and c.current_hp > 0:
				targets.append(c)
	else:
		var foe: Combatant = _pick_opponent(acting_char, target_index)
		if foe != null:
			targets.append(foe)
	if targets.is_empty():
		_toast("No enemies to target!", true)
		return

	var damage: int = int(item.effect_amount)
	if damage <= 0:
		damage = item.attack_bonus if item.attack_bonus > 0 else item.heal_amount
	var is_magic: bool = item.effect_element == ItemData.EffectElement.MAGIC

	_toast("%s threw %s!" % [acting_char.name, item.item_name], false)
	for t: Combatant in targets:
		if damage > 0:
			var dealt: float = float(damage)
			if is_magic:
				dealt *= 1.0 - t.get_resist(ItemData.EffectElement.MAGIC)
			elif t.weakness != ItemData.EffectElement.NONE and t.weakness == item.effect_element:
				dealt *= weakness_multiplier
			_apply_damage_to_combatant(t, maxi(1, roundi(dealt)), acting_char, item, is_magic, "SPELL" if is_magic else "BASH")
		if t.current_hp > 0:
			for status_id: String in item.granted_status_effects:
				_apply_status(t, status_id, acting_char)

	inv.item_used.emit(item)
	inv.consume_one(item_slot_idx)


## Pulls HP/MP back from the CatCharacter resources after an item changed them.
func _sync_party_from_refs() -> void:
	for c: Combatant in combatants:
		if not c.is_player or not is_instance_valid(c.ref):
			continue
		if "current_hp" in c.ref:
			c.current_hp = clampi(int(c.ref.get("current_hp")), 0, c.max_hp)
		if "current_energy" in c.ref:
			c.current_mp = int(c.ref.get("current_energy"))
		elif "current_mp" in c.ref:
			c.current_mp = int(c.ref.get("current_mp"))
		SignalBus.character_health_changed.emit(c.slot_index, c.current_hp)
		SignalBus.character_mana_changed.emit(c.slot_index, c.current_mp, c.max_mp)


func _consume_ranged_ammo(acting_char: Combatant) -> bool:
	if not is_instance_valid(acting_char.ref):
		return true

	var cat: Resource = acting_char.ref
	var right_item: ItemData = null
	var left_item: ItemData = null
	if cat.has_method("get_equipped_item"):
		right_item = cat.call("get_equipped_item", "RIGHT_HAND") as ItemData
		left_item = cat.call("get_equipped_item", "LEFT_HAND") as ItemData

	var ammo_item: ItemData = null
	var ammo_slot: String = ""
	if _is_ammo_resource(left_item):
		ammo_item = left_item
		ammo_slot = "LEFT_HAND"
	elif _is_ammo_resource(right_item):
		ammo_item = right_item
		ammo_slot = "RIGHT_HAND"

	if not is_instance_valid(ammo_item):
		var launcher_name: String = right_item.item_name if is_instance_valid(right_item) else (left_item.item_name if is_instance_valid(left_item) else "Ranged Weapon")
		_notify_out_of_ammo(acting_char, launcher_name)
		return false

	if ammo_item.quantity <= 0:
		_notify_out_of_ammo(acting_char, ammo_item.item_name)
		return false

	ammo_item.quantity -= 1
	GameLogger.combat("%s fired 1 projectile from %s! (%d remaining)" % [acting_char.name, ammo_item.item_name, ammo_item.quantity])

	if ammo_item.quantity <= 0:
		if cat.has_method("unequip_item"):
			cat.call("unequip_item", ammo_slot)
		_toast("%s ran out of %s!" % [acting_char.name, ammo_item.item_name], true)

	return true


func _is_ammo_resource(item: ItemData) -> bool:
	if not is_instance_valid(item):
		return false
	if item.quantity > 1:
		return true
	var name_upper: String = item.item_name.to_upper()
	var id_upper: String = item.item_id.to_upper()
	for word: String in ["ARROW", "BOLT", "AMMO", "QUIVER", "DART"]:
		if word in name_upper or word in id_upper:
			return true
	return false


func _notify_out_of_ammo(acting_char: Combatant, weapon_or_ammo_name: String) -> void:
	var msg: String = "No ammo! %s has no projectiles for %s!" % [acting_char.name, weapon_or_ammo_name]
	GameLogger.combat(msg)
	_toast(msg, true)


# ==============================================================================
# DAMAGE & HEALING
# ==============================================================================
## Physical damage: (ATK - DEF*(1-pierce)) x row x guard x weakness x (1 - resist), minimum 1.
func _calculate_physical_damage(attacker: Combatant, defender: Combatant, attack_type: String = "UNARMED") -> int:
	if attacker == null or defender == null:
		return 1

	var is_unarmed: bool = attack_type == "UNARMED"
	var atk: float = float(attacker.get_effective_attack(is_unarmed))
	var pierce: float = 0.0 if is_unarmed else attacker.pierce
	var def: float = float(defender.get_effective_defense()) * (1.0 - pierce)
	var dmg: float = maxf(1.0, atk - def)

	# Back-row melee attacker: 50%
	if not attacker.is_front_row and attack_type in ["BLADE", "BASH", "UNARMED"]:
		dmg *= 0.5
	# Back-row defender: 50%
	if not defender.is_front_row:
		dmg *= 0.5
	# Guarding party member: 50%
	if defender.is_player and guarding_characters.has(defender.slot_index):
		dmg *= 0.5
		GameLogger.combat("%s is guarding! (50%% damage)" % defender.name)

	var element: int = _element_for_attack_type(attack_type)
	if defender.weakness != ItemData.EffectElement.NONE and defender.weakness == element:
		dmg *= weakness_multiplier
		GameLogger.combat("%s is weak to %s!" % [defender.name, attack_type])
	dmg *= 1.0 - defender.get_resist(element)

	return maxi(1, roundi(dmg))


## hit_kind: BLADE / BASH / RANGED / MAGIC / UNARMED for weapon hits, "SPELL" for magic, "DOT" for ticks.
func _apply_damage_to_combatant(target: Combatant, damage: int, attacker: Combatant = null, source: Resource = null, is_magic: bool = false, hit_kind: String = "") -> void:
	if target == null or target.current_hp <= 0 or damage <= 0:
		return

	var final_damage: int = damage
	if hit_kind != "DOT":
		final_damage = target.absorb_with_shields(damage, is_magic)
		if final_damage < damage:
			GameLogger.combat("%s's shield absorbed %d damage" % [target.name, damage - final_damage])
	if final_damage <= 0:
		_toast("%s's shield absorbed the hit!" % target.name, false)
		return

	target.current_hp = max(0, target.current_hp - final_damage)
	_sync_hp_to_ref(target)
	_emit_hit_feedback(target, final_damage, source, is_magic, hit_kind)

	var attacker_name: String = attacker.name if attacker != null else ""
	if target.is_player:
		var msg: String = "⚡ %s took %d damage!" % [target.name, final_damage]
		GameLogger.combat(msg)
		_toast(msg, true)
	else:
		var msg: String = "💥 %s took %d damage!" % [target.name, final_damage]
		if not attacker_name.is_empty():
			msg = "💥 %s %s %s for %d damage!" % [attacker_name, _get_attack_verb(hit_kind), target.name, final_damage]
		GameLogger.combat(msg)
		_toast(msg, false)

	if target.current_hp <= 0:
		_on_combatant_defeated(target)


func _heal_combatant(t: Combatant, amount: int, source_name: String) -> void:
	var was_dead: bool = t.current_hp <= 0
	t.current_hp = mini(t.max_hp, t.current_hp + amount)
	_sync_hp_to_ref(t)
	if t.is_player:
		SignalBus.character_health_changed.emit(t.slot_index, t.current_hp)
	else:
		SignalBus.enemy_health_changed.emit(t.id, t.current_hp, t.max_hp)
	var verb: String = "revived" if was_dead else "healed"
	GameLogger.combat("%s %s %d HP from %s (HP %d/%d)" % [t.name, verb, amount, source_name, t.current_hp, t.max_hp])
	_toast("%s %s %d HP!" % [t.name, verb, amount], false)


func _on_combatant_defeated(target: Combatant) -> void:
	target.active_effects.clear()
	turn_queue.erase(target)
	if target.is_player:
		guarding_characters.erase(target.slot_index)
		var death_msg: String = "💀 %s HAS FALLEN IN BATTLE!" % target.name.to_upper()
		GameLogger.combat(death_msg)
		_toast(death_msg, true)
		return

	var death_msg: String = "☠️ %s HAS BEEN DEFEATED!" % target.name.to_upper()
	GameLogger.combat(death_msg)
	_toast(death_msg, false)
	var e_type: String = ""
	if is_instance_valid(target.ref):
		if "enemy_type" in target.ref and not str(target.ref.get("enemy_type")).is_empty():
			e_type = str(target.ref.get("enemy_type"))
		elif "enemy_id" in target.ref:
			e_type = str(target.ref.get("enemy_id"))
	if is_instance_valid(AudioManager):
		AudioManager.play_enemy_death_sound(e_type)


func _get_attack_verb(hit_kind: String) -> String:
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


# ==============================================================================
# VISUAL / AUDIO FEEDBACK
# ==============================================================================
## Weapon animation at the START of a player attack (the hit lands after player_attack_windup).
func _emit_weapon_swing(attack_type: String) -> void:
	match attack_type:
		"BASH", "MAGIC":
			SignalBus.weapon_swing_requested.emit("staff_bash")
		"RANGED":
			SignalBus.weapon_swing_requested.emit("bow_shot")
		"BLADE":
			SignalBus.weapon_swing_requested.emit("sword_swing")


## Impact feedback at the moment damage lands.
func _emit_hit_feedback(target: Combatant, damage: int, source: Resource, is_magic: bool, hit_kind: String) -> void:
	if target.is_player:
		SignalBus.character_health_changed.emit(target.slot_index, target.current_hp)
		SignalBus.chevron_flash_requested.emit(true)
		if hit_kind == "DOT":
			return
		if is_magic:
			SignalBus.camera_shake_requested.emit(0.65)
		else:
			SignalBus.screen_slice_requested.emit()
			SignalBus.camera_shake_requested.emit(0.85)
		return

	SignalBus.enemy_damaged_visual.emit(target.id, damage)
	SignalBus.enemy_health_changed.emit(target.id, target.current_hp, target.max_hp)
	SignalBus.chevron_flash_requested.emit(false)
	if hit_kind == "DOT" or is_magic:
		return

	if is_instance_valid(AudioManager):
		AudioManager.play_attack_sound(hit_kind)
	match hit_kind:
		"BASH", "MAGIC":
			SignalBus.camera_shake_requested.emit(0.50)
		"RANGED":
			SignalBus.camera_shake_requested.emit(0.40)
		"BLADE":
			SignalBus.camera_shake_requested.emit(0.55)
		_:
			SignalBus.camera_shake_requested.emit(0.40)
	if hit_kind == "BLADE" or _is_water_battle:
		SignalBus.screen_slice_requested.emit()

	var vfx_frames: SpriteFrames = null
	if is_instance_valid(source) and "attack_vfx" in source:
		vfx_frames = source.get("attack_vfx") as SpriteFrames
	if is_instance_valid(vfx_frames):
		SignalBus.target_vfx_requested.emit(target.id, vfx_frames, 0.5)


func _detect_water_battle() -> bool:
	for c: Combatant in combatants:
		if c.is_player or not is_instance_valid(c.ref) or not "enemy_id" in c.ref:
			continue
		var e_id: String = str(c.ref.get("enemy_id"))
		if e_id == "en_lake_tentacle" or e_id == "en_lake_monster":
			return true
	return false


func _toast(message: String, is_error: bool) -> void:
	if is_instance_valid(SignalBus) and SignalBus.has_signal(&"show_toast"):
		SignalBus.show_toast.emit(message, is_error)


# ==============================================================================
# BATTLE END
# ==============================================================================
## Returns true (and starts the end-of-battle sequence) if one side is wiped out.
func _check_battle_state() -> bool:
	if not is_combat_active or is_transitioning_out:
		return true

	var any_enemies_alive: bool = false
	var any_party_alive: bool = false
	for c: Combatant in combatants:
		if c.current_hp > 0:
			if c.is_player:
				any_party_alive = true
			else:
				any_enemies_alive = true

	if not any_enemies_alive:
		_finish_battle(true)
		return true
	if not any_party_alive:
		_toast("The party has been defeated...", true)
		_finish_battle(false)
		return true
	return false


## The ONLY place combat_ended is emitted. Victory waits victory_linger for death animations.
func _finish_battle(victory: bool) -> void:
	if not is_combat_active or is_transitioning_out:
		return

	GameLogger.combat("BATTLE ENDED! Victory = %s" % str(victory))
	is_transitioning_out = true # Stops meters, queue and any in-flight action
	is_paused_for_input = true
	turn_queue.clear()
	var serial: int = _battle_serial

	var victory_data: Dictionary = {}
	if victory:
		victory_data = _collect_victory_rewards()
		await _wait(victory_linger)
		if serial != _battle_serial:
			return

	var gs: Node = get_tree().root.get_node_or_null("GameState")
	_reset_battle_state()
	SignalBus.combat_ended.emit(victory)

	if is_instance_valid(gs) and gs.has_method("save_game"):
		gs.save_game()
	if victory:
		SignalBus.popup_requested.emit(&"BATTLE_VICTORY", victory_data)


## Only reached when something OTHER than this manager emits combat_ended (e.g. BattleTest).
## By the time our own emit fires, is_combat_active is already false.
func _on_combat_ended(_victory: bool) -> void:
	if is_combat_active:
		_battle_serial += 1
		_reset_battle_state()


func _collect_victory_rewards() -> Dictionary:
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	var total_xp: int = 0
	var total_gold: int = 0
	var living_party_members: int = 0
	var total_party_members: int = 0
	var enemies_killed: int = 0
	var items_dropped: Array[ItemData] = []

	for c: Combatant in combatants:
		if c.is_player:
			total_party_members += 1
			if c.current_hp > 0:
				living_party_members += 1
			continue
		if c.current_hp > 0:
			continue
		enemies_killed += 1
		var single_xp: int = 50
		var single_gold: int = 25
		if is_instance_valid(c.ref):
			if "xp_value" in c.ref and int(c.ref.get("xp_value")) > 0:
				single_xp = int(c.ref.get("xp_value"))
			if "gold_value" in c.ref and int(c.ref.get("gold_value")) > 0:
				single_gold = int(c.ref.get("gold_value"))
			var drops_loot: bool = bool(c.ref.get("drops_loot")) if "drops_loot" in c.ref else true
			if drops_loot:
				var rolled: Array[ItemData] = _resolve_enemy_loot(c.ref)
				items_dropped.append_array(rolled)
				if is_instance_valid(gs) and "inventory" in gs and gs.inventory != null and gs.inventory.has_method("add_item"):
					for dropped_item: ItemData in rolled:
						gs.inventory.add_item(dropped_item)
		total_xp += single_xp
		total_gold += single_gold

	if enemies_killed == 0:
		enemies_killed = 1
		total_xp = 50
		total_gold = 25

	if is_instance_valid(gs) and gs.has_method("add_gold"):
		gs.add_gold(total_gold)

	return {
		"enemies_killed": enemies_killed,
		"total_xp": total_xp,
		"total_gold": total_gold,
		"items_dropped": items_dropped,
		"living_members": max(1, living_party_members),
		"total_members": max(1, total_party_members),
	}


func _resolve_enemy_loot(enemy_ref: Resource) -> Array[ItemData]:
	if not is_instance_valid(enemy_ref):
		return _generate_fallback_loot()
	if "loot_table" in enemy_ref and is_instance_valid(enemy_ref.get("loot_table")):
		var table: LootTable = enemy_ref.get("loot_table") as LootTable
		return table.roll_table()
	return _generate_fallback_loot()


func _generate_fallback_loot() -> Array[ItemData]:
	var drops: Array[ItemData] = []
	var item_paths: Array[String] = [
		"res://Data/Items/GemDataQuartz.tres",
		"res://Data/Items/ConHealthVial.tres",
		"res://Data/Items/ConCyberRation.tres",
		"res://Data/Items/ConManaStim.tres",
		"res://Data/Items/GemNeonRuby.tres",
		"res://Data/Items/GemGlowOpal.tres",
	]
	var pool: Array[ItemData] = []
	for p: String in item_paths:
		if ResourceLoader.exists(p):
			var item: ItemData = load(p) as ItemData
			if is_instance_valid(item):
				pool.append(item)
	if not pool.is_empty():
		drops.append(pool.pick_random())
	return drops


# ==============================================================================
# HELPERS
# ==============================================================================
## Picks a living opponent of `attacker`. Players use target_index (enemy_N); enemies pick a random party member.
func _pick_opponent(attacker: Combatant, target_index: int) -> Combatant:
	if attacker.is_player:
		var chosen: Combatant = _find_combatant_by_id("enemy_%d" % target_index)
		if chosen != null and chosen.current_hp > 0:
			return chosen
		for c: Combatant in combatants:
			if not c.is_player and c.current_hp > 0:
				return c
		return null

	var alive_party: Array[Combatant] = []
	for c: Combatant in combatants:
		if c.is_player and c.current_hp > 0:
			alive_party.append(c)
	return alive_party.pick_random() if not alive_party.is_empty() else null


func _sync_hp_to_ref(c: Combatant) -> void:
	if not is_instance_valid(c.ref):
		return
	if "current_hp" in c.ref:
		c.ref.set("current_hp", c.current_hp)
	elif "current_health" in c.ref:
		c.ref.set("current_health", c.current_hp)


func _sync_mp_to_ref(c: Combatant) -> void:
	if not is_instance_valid(c.ref):
		return
	if "current_energy" in c.ref:
		c.ref.set("current_energy", c.current_mp)
	elif "current_mp" in c.ref:
		c.ref.set("current_mp", c.current_mp)
	elif "current_mana" in c.ref:
		c.ref.set("current_mana", c.current_mp)


func _reset_combatant_meter(combatant: Combatant) -> void:
	if combatant != null:
		combatant.meter = 0.0
		SignalBus.turn_meter_updated.emit(combatant.id, 0.0)


func _find_combatant_by_id(id: String) -> Combatant:
	for c: Combatant in combatants:
		if c.id == id:
			return c
	return null


func _find_combatant_by_slot(slot_idx: int, is_player_target: bool) -> Combatant:
	for c: Combatant in combatants:
		if c.is_player == is_player_target and c.slot_index == slot_idx:
			return c
	return null


func _get_average_enemy_speed() -> int:
	var total_speed: float = 0.0
	var enemy_count: int = 0
	for c: Combatant in combatants:
		if not c.is_player and c.current_hp > 0:
			total_speed += c.get_effective_speed()
			enemy_count += 1
	return int(total_speed / maxf(1.0, float(enemy_count)))


## Resolves any enemy payload variant (Array, WorldEnemy node, EnemyGroupData, or single Resource) into a typed Array[Resource]
func _resolve_enemy_resources(payload: Variant) -> Array[Resource]:
	var result: Array[Resource] = []

	if payload is Array:
		for item in (payload as Array):
			if item is Resource:
				result.append(item as Resource)
			elif is_instance_valid(item) and "enemy_group" in item:
				var group_array: Variant = item.get("enemy_group")
				if group_array is Array:
					for sub_item in (group_array as Array):
						if sub_item is Resource:
							result.append(sub_item as Resource)

	elif is_instance_valid(payload):
		if "enemy_group" in payload:
			var group_val: Variant = payload.get("enemy_group")
			if group_val is Array and not (group_val as Array).is_empty():
				for item in (group_val as Array):
					if item is Resource:
						result.append(item as Resource)

		if result.is_empty() and "members" in payload:
			var members_val: Variant = payload.get("members")
			if members_val is Array and not (members_val as Array).is_empty():
				for item in (members_val as Array):
					if item is Resource:
						result.append(item as Resource)

		if result.is_empty() and payload is Resource:
			var target_res: Resource = payload as Resource
			var best_node: Node3D = _find_nearest_world_enemy(target_res)

			if is_instance_valid(best_node) and ("enemy_group" in best_node):
				var grp: Variant = best_node.get("enemy_group")
				if grp is Array and not (grp as Array).is_empty():
					for item in (grp as Array):
						if item is Resource:
							result.append(item as Resource)

			if result.is_empty():
				var count: int = 1
				if is_instance_valid(best_node) and "pack_size" in best_node:
					count = max(1, int(best_node.get("pack_size")))
				elif "pack_size" in payload:
					count = max(1, int(payload.get("pack_size")))
				for i in range(count):
					result.append(target_res.duplicate(true) if count > 1 else target_res)

	return result


func _find_nearest_world_enemy(target_res: Resource) -> Node3D:
	var overworld_enemies: Array[Node] = get_tree().get_nodes_in_group(&"world_enemies")
	if overworld_enemies.is_empty():
		overworld_enemies = get_tree().root.find_children("*", "WorldEnemy", true, false)

	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var player_pos: Vector3 = player.global_position if is_instance_valid(player) else Vector3.ZERO
	var player_cell: Vector2i = player.current_grid_pos if is_instance_valid(player) and ("current_grid_pos" in player) else Vector2i(-9999, -9999)

	var best_node: Node3D = null
	var min_dist: float = INF

	for node in overworld_enemies:
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var enemy_node: Node3D = node as Node3D
		if not enemy_node.visible and not ("_is_in_active_combat" in enemy_node and bool(enemy_node.get("_is_in_active_combat"))):
			continue

		var grp: Variant = enemy_node.get("enemy_group") if "enemy_group" in enemy_node else null
		var n_data: Variant = enemy_node.get("data") if "data" in enemy_node else null
		var n_edata: Variant = enemy_node.get("enemy_data") if "enemy_data" in enemy_node else null

		var matches: bool = n_data == target_res or n_edata == target_res
		if not matches and grp is Array:
			matches = (grp as Array).has(target_res)
		if not matches:
			continue

		var dist: float = enemy_node.global_position.distance_to(player_pos)
		if enemy_node.has_method("get_grid_pos") and player_cell != Vector2i(-9999, -9999):
			var n_cell: Vector2i = enemy_node.get_grid_pos()
			dist = float(absi(n_cell.x - player_cell.x) + absi(n_cell.y - player_cell.y))

		if dist < min_dist:
			min_dist = dist
			best_node = enemy_node

	return best_node
