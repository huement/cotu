# res://Scripts/Managers/CombatManager.gd
extends Node

## Turn-meter (ATB style) combat. See res://_documentation/COMBAT_README.md for the full flow.
## State + orchestration only. Pure pieces live in res://Scripts/Combat/ (read those instead of this file
## when you only need a formula):
##   Combatant / ActiveEffect - battle snapshot + stat/buff math
##   CombatMath      - damage, potency, durations, flee, meters, elements
##   CombatTargeting - who an action hits
##   AbilityInfo     - name / id / category / status of a spell or skill


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
## Set when every party member is down, so _finish_battle can tell a wipe from fleeing.
var _party_wiped: bool = false
const BOSS_SPELL_BOOK_PATH: String = "res://Data/Items/Loot/LrnSpellBook.tres"
const BOSS_SKILL_CRYSTAL_PATH: String = "res://Data/Items/Loot/LrnSkillCrystal.tres"


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
		# process_always = false: battle timing freezes while the game menu (or anything else) pauses the tree.
		await get_tree().create_timer(seconds, false).timeout


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
	var base_str: int = CombatMath.cat_attribute(cat, &"strength", 10)
	var base_spd: int = CombatMath.cat_attribute(cat, &"speed", 8)

	var equip_atk: int = 0
	var equip_def: int = 0
	var equip_spd: int = 0
	var weapon_atk: int = 0
	var resists: Dictionary = {}
	var amplify: float = 1.0
	var pierce: float = 0.0
	var on_hit: Array[Dictionary] = []

	var equipped: Array[Dictionary] = _get_equipped_items(cat)
	for entry: Dictionary in equipped:
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
				resists[element] = float(resists.get(element, 0.0)) + CombatMath.as_fraction(amount)
			"AMPLIFY":
				if amount > 0.0:
					amplify *= amount
			"PIERCE":
				pierce += CombatMath.as_fraction(amount)
			"BURN":
				on_hit.append({ "id": "eff_hp_burn_1", "chance": CombatMath.as_fraction(amount) })
			"FREEZE":
				on_hit.append({ "id": "eff_freeze_1", "chance": CombatMath.as_fraction(amount) })
			"STUN":
				on_hit.append({ "id": "eff_stun_1", "chance": CombatMath.as_fraction(amount) })

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
	_apply_equipped_granted_statuses(c, equipped)
	return c


## Permanent stacking STAT_PCT from ItemData.granted_status_effects (unique id per slot so pieces stack).
func _apply_equipped_granted_statuses(c: Combatant, equipped: Array[Dictionary]) -> void:
	for entry: Dictionary in equipped:
		var item: Resource = entry["item"] as Resource
		var slot_name: String = str(entry["slot"])
		if not is_instance_valid(item) or not ("granted_status_effects" in item):
			continue
		var granted: Variant = item.get("granted_status_effects")
		if not (granted is Array):
			continue
		for raw_id: Variant in granted as Array:
			var effect_id: String = str(raw_id).strip_edges()
			if effect_id.is_empty():
				continue
			var data: StatusEffectData = StatusEffectDatabase.get_effect(effect_id)
			if not is_instance_valid(data):
				continue
			if data.modifier_type != StatusEffectData.ModifierType.MULTIPLIER:
				continue
			var unique_id: String = "%s@%s" % [effect_id, slot_name]
			c.add_effect(ActiveEffect.new(
				unique_id,
				data.name,
				-1,
				&"STAT_PCT",
				CombatMath.modifier_stat_name(data.modifier_stat),
				data.modifier_value,
				c.id
			))


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
	var e_level: int = int(e_data.get("base_level")) if "base_level" in e_data else 1
	var level_mult: float = CombatMath.enemy_level_damage_mult(e_level)
	e_atk = maxi(1, roundi(float(e_atk) * level_mult))

	var e_name: String = str(e_data.get("enemy_name")) if e_data.get("enemy_name") != null else "Enemy"
	if pack_size > 1:
		e_name = "%s %c" % [e_name, 65 + e_idx]
	var e_is_front: bool = bool(e_data.get("is_front_row")) if "is_front_row" in e_data else true

	var c: Combatant = Combatant.new("enemy_%d" % e_idx, e_name, e_speed, false, e_idx, e_hp, e_max_hp, 0, 0, e_atk, e_def, e_data, e_is_front)
	c.weakness = int(e_data.get("weakness_element")) if "weakness_element" in e_data else 0
	if "magic_resist" in e_data:
		c.element_resists[ItemData.EffectElement.MAGIC] = float(e_data.get("magic_resist"))
	var e_magic: int = int(e_data.get("magic_power")) if "magic_power" in e_data else 0
	c.magic_power = maxi(0, roundi(float(e_magic) * level_mult))
	c.can_cast_spells = bool(e_data.get("can_cast_spells")) if "can_cast_spells" in e_data else false
	if c.can_cast_spells:
		c.spells = _resolve_enemy_spells(e_data)
	c.attack_type = CombatMath.attack_type_from_element(int(e_data.get("attack_element")) if "attack_element" in e_data else ItemData.EffectElement.BASH)
	return c


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


# ==============================================================================
# TURN METERS & TURN QUEUE
# ==============================================================================
func _tick_turn_meters(delta: float) -> void:
	for c: Combatant in combatants:
		if c.current_hp <= 0 or c.meter >= MAX_TURN_METER:
			continue
		c.meter = CombatMath.next_meter(c.meter, c.get_effective_speed(), base_tick_rate, delta, MAX_TURN_METER)
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

		# duration < 0 = permanent (e.g. equipment-granted STAT_PCT); never tick/expire
		if eff.duration < 0:
			continue
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

	# 1. Start the swing / attack animation (flask throwers are RANGED but get the potion throw)
	if attacker.is_player:
		var swing_type: String = (
			"POTION_THROW" if attack_type == "RANGED" and _throws_flasks(attacker) else attack_type
		)
		_emit_weapon_swing(attacker, swing_type)
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
	var final_flee_chance: float = CombatMath.flee_chance(base_flee_chance, caster_speed, enemy_avg_speed)

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

	return AbilityLibrary.spell_by_id(spell_id)


# ==============================================================================
# SPELLS & SKILLS (players and enemies)
# ==============================================================================
func _execute_ability(caster: Combatant, ability: Resource, kind: StringName, target_index: int, serial: int) -> void:
	if not is_instance_valid(ability):
		GameLogger.combat("%s tried to use an ability, but none was selected." % caster.name)
		return

	var ability_name: String = AbilityInfo.display_name(ability)
	var category: String = AbilityInfo.category(ability)
	var skill_id: String = AbilityInfo.id(ability)
	var throw_anim_override: String = ""
	var hit_count: int = 1

	if kind == &"SPELL" and caster.has_effect_type(&"LOCK_MAGIC"):
		_toast("%s is silenced and can't cast %s!" % [caster.name, ability_name], true)
		return

	# Ammo availability before spending mana (consume only after the accuracy check lands).
	if kind == &"SKILL" and skill_id == "sk_deadly_throw":
		if not is_instance_valid(_find_throw_blade_or_star(caster)):
			_toast("%s has no knives or stars to throw!" % caster.name, true)
			return
	elif kind == &"SKILL" and skill_id == "sk_dual_flask":
		if not _has_flask_ammo(caster, 2):
			_toast("%s needs at least 2 flasks for Dual Flask!" % caster.name, true)
			return
		hit_count = 2

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

	if kind == &"SKILL" and skill_id == "sk_deadly_throw":
		var thrown: ItemData = _consume_throw_blade_or_star(caster)
		if not is_instance_valid(thrown):
			_toast("%s has no knives or stars to throw!" % caster.name, true)
			return
		throw_anim_override = thrown.get_throw_anim()
	elif kind == &"SKILL" and skill_id == "sk_dual_flask":
		if not _consume_flask_ammo(caster, 2):
			_toast("%s needs at least 2 flasks for Dual Flask!" % caster.name, true)
			return
		throw_anim_override = "big_potion_throw"

	var is_revive: bool = category == "HEAL" and ("revive" in ability_name.to_lower() or "revive" in str(ability.get("spell_id") if "spell_id" in ability else "").to_lower())
	var targets: Array[Combatant] = _resolve_ability_targets(caster, ability, target_index, is_revive)
	if targets.is_empty():
		GameLogger.combat("%s used %s, but there was no valid target." % [caster.name, ability_name])
		return

	# Cast VFX once, then wind up
	var anim_name: String = throw_anim_override
	if anim_name.is_empty():
		anim_name = str(ability.get("animation")) if "animation" in ability else "NONE"
	if ThrowAnimator.has_clip(anim_name):
		SignalBus.throw_requested.emit(anim_name)
	elif anim_name == "potion_throw" or ability_name == "Alchemy Bomb":
		SignalBus.weapon_swing_requested.emit("potion_throw")
	elif anim_name != "NONE" and not anim_name.is_empty():
		var vfx_element: ItemData.ElementalBase = ItemData.ElementalBase.NONE
		if ability is SpellData:
			vfx_element = (ability as SpellData).element
		SignalBus.spell_vfx_requested.emit(anim_name, vfx_element)
		SignalBus.camera_shake_requested.emit(0.6)
	elif kind == &"SKILL" and caster.is_player and category == "DAMAGE":
		_emit_weapon_swing(caster, caster.attack_type)

	await _wait(spell_windup)
	if not _is_same_battle(serial):
		return

	var power: float = CombatMath.ability_power(caster, ability, kind)
	var status_id: String = AbilityInfo.status_id(ability)
	var duration: int = CombatMath.ability_duration(ability, kind)

	for t: Combatant in targets:
		if t.current_hp <= 0 and not is_revive:
			continue
		match category:
			"DAMAGE":
				for _hit: int in range(hit_count):
					if t.current_hp <= 0:
						break
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
					t.add_effect(ActiveEffect.new(AbilityInfo.id(ability), ability_name, duration - 1, &"HOT", &"", power, caster.id))
			"BUFF":
				if not status_id.is_empty():
					_apply_status(t, status_id, caster, duration)
				else:
					t.add_effect(ActiveEffect.new(AbilityInfo.id(ability), ability_name, duration, &"STAT_BUFF", &"defense", power, caster.id))
					GameLogger.combat("%s: %s gains +%.0f defense for %d turns" % [ability_name, t.name, power, duration])
			"DEBUFF":
				if not status_id.is_empty():
					_apply_status(t, status_id, caster, duration)
				else:
					t.add_effect(ActiveEffect.new(AbilityInfo.id(ability), ability_name, duration, &"STAT_BUFF", &"defense", -power, caster.id))
					GameLogger.combat("%s: %s loses %.0f defense for %d turns" % [ability_name, t.name, power, duration])
			_:
				if not status_id.is_empty():
					_apply_status(t, status_id, caster, duration)
				else:
					GameLogger.combat("%s used %s (no combat effect)" % [caster.name, ability_name])


## Ability damage to one target (formula: CombatMath.ability_damage). Adds guard state + logging.
func _calculate_ability_damage(caster: Combatant, target: Combatant, ability: Resource, kind: StringName, power: float) -> int:
	if kind == &"SPELL" and CombatMath.spell_hits_weakness(target, ability):
		GameLogger.combat("%s is weak to magic!" % target.name)
	return CombatMath.ability_damage(caster, target, ability, kind, power, _is_guarding(target), weakness_multiplier)


func _resolve_ability_targets(caster: Combatant, ability: Resource, target_index: int, allow_dead_ally: bool) -> Array[Combatant]:
	return CombatTargeting.resolve_ability_targets(combatants, caster, ability, target_index, allow_dead_ally)


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
			effect = ActiveEffect.new(data.effect_id, data.name, duration, &"STAT_PCT", CombatMath.modifier_stat_name(data.modifier_stat), value, caster_id)
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

	match item.get_battle_target_type():
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
	if item.get_battle_target_type() == ItemData.TargetType.ALL_ENEMIES:
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

	if item.is_throwable:
		_emit_throw_anim(item.get_throw_anim())
		await _wait(player_attack_windup)
		_throw_item(acting_char, item, targets)
		inv.item_used.emit(item)
		inv.consume_one(item_slot_idx)
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


## Thrown items (ItemData.is_throwable): each target rolls to hit off the thrower's DEX vs the target's
## speed, then takes CombatMath.throw_damage (STR-scaled, ignores half the armour), maybe a DEX crit,
## plus the item's granted_status_effects. Formulas + tuning: CombatMath "Throwing".
func _throw_item(acting_char: Combatant, item: ItemData, targets: Array[Combatant]) -> void:
	var dex: int = _thrower_dexterity(acting_char)
	var strength: int = _thrower_strength(acting_char)
	var element: int = int(item.effect_element) if item.effect_element != ItemData.EffectElement.NONE else int(ItemData.EffectElement.RANGED)
	_toast("%s threw %s!" % [acting_char.name, item.item_name], false)
	for t: Combatant in targets:
		var hit_chance: float = CombatMath.throw_hit_chance(dex, t.speed)
		if randf() > hit_chance:
			GameLogger.combat("%s's %s missed %s (%d%% to hit)" % [acting_char.name, item.item_name, t.name, roundi(hit_chance * 100.0)])
			_toast("%s missed %s!" % [item.item_name, t.name], true)
			continue
		var dmg: int = CombatMath.throw_damage(item.get_throw_power(), strength, t, weakness_multiplier, element)
		var crit: bool = randf() < CombatMath.throw_crit_chance(dex)
		if crit:
			dmg = roundi(float(dmg) * CombatMath.THROW_CRIT_MULT)
			_toast("Critical throw!", false)
		GameLogger.combat("%s threw %s at %s: %d damage%s (STR %d, DEX %d, %d%% to hit)" % [
			acting_char.name, item.item_name, t.name, dmg, " CRIT" if crit else "", strength, dex, roundi(hit_chance * 100.0)])
		_apply_damage_to_combatant(t, dmg, acting_char, item, false, "RANGED")
		if t.current_hp > 0:
			for status_id: String in item.granted_status_effects:
				_apply_status(t, status_id, acting_char)


func _thrower_dexterity(c: Combatant) -> int:
	if c.is_player and is_instance_valid(c.ref):
		return CombatMath.cat_attribute(c.ref, &"dexterity", 10)
	return roundi(c.speed)


func _thrower_strength(c: Combatant) -> int:
	if c.is_player and is_instance_valid(c.ref):
		return CombatMath.cat_attribute(c.ref, &"strength", 10)
	return roundi(c.attack)


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
	return CombatMath.is_ammo_item(item)


## First knife / kunai / shuriken in hands or pack (does not consume).
func _find_throw_blade_or_star(acting_char: Combatant) -> ItemData:
	if is_instance_valid(acting_char.ref) and acting_char.ref.has_method("get_equipped_item"):
		for hand: String in ["LEFT_HAND", "RIGHT_HAND"]:
			var equipped: ItemData = acting_char.ref.call("get_equipped_item", hand) as ItemData
			if CombatMath.is_throw_blade_or_star(equipped) and equipped.quantity > 0:
				return equipped
	var inv: Inventory = GameState.inventory if is_instance_valid(GameState) else null
	if not is_instance_valid(inv):
		return null
	for stack: ItemData in inv.get_items():
		if CombatMath.is_throw_blade_or_star(stack) and stack.quantity > 0:
			return stack
	return null


## Consumes one knife / kunai / shuriken from equipped hands or the party pack. Returns the item used.
func _consume_throw_blade_or_star(acting_char: Combatant) -> ItemData:
	if is_instance_valid(acting_char.ref) and acting_char.ref.has_method("get_equipped_item"):
		for hand: String in ["LEFT_HAND", "RIGHT_HAND"]:
			var equipped: ItemData = acting_char.ref.call("get_equipped_item", hand) as ItemData
			if not CombatMath.is_throw_blade_or_star(equipped) or equipped.quantity <= 0:
				continue
			equipped.quantity -= 1
			GameLogger.combat("%s used 1 %s for Deadly Throw (%d left)" % [
				acting_char.name, equipped.item_name, equipped.quantity])
			if equipped.quantity <= 0 and acting_char.ref.has_method("unequip_item"):
				acting_char.ref.call("unequip_item", hand)
			return equipped

	var inv: Inventory = GameState.inventory if is_instance_valid(GameState) else null
	if not is_instance_valid(inv):
		return null
	for stack: ItemData in inv.get_items():
		if not CombatMath.is_throw_blade_or_star(stack) or stack.quantity <= 0:
			continue
		inv.remove_item(stack, 1)
		GameLogger.combat("%s used 1 %s from the pack for Deadly Throw" % [acting_char.name, stack.item_name])
		return stack
	return null


func _find_flask_ammo(acting_char: Combatant) -> Dictionary:
	var result: Dictionary = {"item": null, "slot": ""}
	if not is_instance_valid(acting_char.ref) or not acting_char.ref.has_method("get_equipped_item"):
		return result
	for hand: String in ["LEFT_HAND", "RIGHT_HAND"]:
		var item: ItemData = acting_char.ref.call("get_equipped_item", hand) as ItemData
		if is_instance_valid(item) and "FLASK" in (item.item_name + " " + item.item_id).to_upper():
			result["item"] = item
			result["slot"] = hand
			break
	return result


func _has_flask_ammo(acting_char: Combatant, amount: int) -> bool:
	var found: Dictionary = _find_flask_ammo(acting_char)
	var ammo_item: ItemData = found.get("item") as ItemData
	return is_instance_valid(ammo_item) and ammo_item.quantity >= amount


## Spends `amount` flask ammo from either hand. Returns false when not enough.
func _consume_flask_ammo(acting_char: Combatant, amount: int) -> bool:
	if amount <= 0:
		return true
	var found: Dictionary = _find_flask_ammo(acting_char)
	var ammo_item: ItemData = found.get("item") as ItemData
	var ammo_slot: String = str(found.get("slot", ""))
	if not is_instance_valid(ammo_item) or ammo_item.quantity < amount:
		return false

	ammo_item.quantity -= amount
	GameLogger.combat("%s spent %d flasks (%d remaining)" % [acting_char.name, amount, ammo_item.quantity])
	if ammo_item.quantity <= 0 and acting_char.ref.has_method("unequip_item"):
		acting_char.ref.call("unequip_item", ammo_slot)
		_toast("%s ran out of %s!" % [acting_char.name, ammo_item.item_name], true)
	return true


func _notify_out_of_ammo(acting_char: Combatant, weapon_or_ammo_name: String) -> void:
	var msg: String = "No ammo! %s has no projectiles for %s!" % [acting_char.name, weapon_or_ammo_name]
	GameLogger.combat(msg)
	_toast(msg, true)


# ==============================================================================
# DAMAGE & HEALING
# ==============================================================================
## Weapon damage (formula: CombatMath.physical_damage). Adds guard state + logging.
func _calculate_physical_damage(attacker: Combatant, defender: Combatant, attack_type: String = "UNARMED") -> int:
	if attacker == null or defender == null:
		return 1
	if _is_guarding(defender):
		GameLogger.combat("%s is guarding! (50%% damage)" % defender.name)
	if CombatMath.is_weak_to(defender, CombatMath.element_for_attack_type(attack_type)):
		GameLogger.combat("%s is weak to %s!" % [defender.name, attack_type])
	return CombatMath.physical_damage(attacker, defender, attack_type, _is_guarding(defender), weakness_multiplier)


## Guarding party members take half damage until their next turn.
func _is_guarding(target: Combatant) -> bool:
	return target.is_player and guarding_characters.has(target.slot_index)


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
			msg = "💥 %s %s %s for %d damage!" % [attacker_name, AbilityInfo.hit_verb(hit_kind), target.name, final_damage]
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


# ==============================================================================
# VISUAL / AUDIO FEEDBACK
# ==============================================================================
## Weapon animation at the START of a player attack (the hit lands after player_attack_windup).
## True when the party member's ranged ammo is alchemy flasks (thrown by hand, no bow).
func _throws_flasks(attacker: Combatant) -> bool:
	if not is_instance_valid(attacker.ref) or not attacker.ref.has_method("get_equipped_item"):
		return false
	for hand: String in ["RIGHT_HAND", "LEFT_HAND"]:
		var item: ItemData = attacker.ref.call("get_equipped_item", hand) as ItemData
		if is_instance_valid(item) and "FLASK" in (item.item_name + item.item_id).to_upper():
			return true
	return false


## Throwing knives / stars / big potions go to ThrowAnimator; anything else (flasks) to WeaponAnimator.
func _emit_throw_anim(anim_name: String) -> void:
	if ThrowAnimator.has_clip(anim_name):
		SignalBus.throw_requested.emit(anim_name)
	else:
		SignalBus.weapon_swing_requested.emit(anim_name)


func _emit_weapon_swing(attacker: Combatant, attack_type: String) -> void:
	var weapon: Resource = _get_weapon_resource(attacker, attack_type)
	if is_instance_valid(weapon) and "swing_anim" in weapon:
		var custom: String = str(weapon.get("swing_anim")).strip_edges()
		if not custom.is_empty():
			SignalBus.weapon_swing_requested.emit(custom)
			return
	match attack_type:
		"BASH", "MAGIC":
			SignalBus.weapon_swing_requested.emit("staff_bash")
		"RANGED":
			SignalBus.weapon_swing_requested.emit("bow_shot")
		"POTION", "BOMB", "ALCHEMY_BOMB", "POTION_THROW":
			SignalBus.weapon_swing_requested.emit("potion_throw")
		"BLADE", _:
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
		_party_wiped = true
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
	var wiped: bool = _party_wiped
	_party_wiped = false
	if not victory:
		GameState.take_boss_rewards() # lost / fled: the boss keeps its loot until beaten
	_reset_battle_state()
	SignalBus.combat_ended.emit(victory)

	if wiped:
		# Never save a dead party - the Game Over screen offers the last good save.
		SignalBus.party_defeated.emit()
		return
	if is_instance_valid(gs) and gs.has_method("save_game"):
		gs.save_game()
	if victory:
		SignalBus.popup_requested.emit(&"BATTLE_VICTORY", victory_data)


## Only reached when something OTHER than this manager emits combat_ended (e.g. DebugMenu END BATTLE).
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

	items_dropped.append_array(_grant_boss_rewards())

	return {
		"enemies_killed": enemies_killed,
		"total_xp": total_xp,
		"total_gold": total_gold,
		"items_dropped": items_dropped,
		"living_members": max(1, living_party_members),
		"total_members": max(1, total_party_members),
	}


## Spell Books / Skill Crystals a boss registered for this fight (GameState.register_boss_rewards).
## Adds them to the inventory and returns one entry per item for the victory screen.
func _grant_boss_rewards() -> Array[ItemData]:
	var granted: Array[ItemData] = []
	var rewards: Dictionary = GameState.take_boss_rewards()
	var plan: Array = [
		[BOSS_SPELL_BOOK_PATH, int(rewards.get("spell_books", 0))],
		[BOSS_SKILL_CRYSTAL_PATH, int(rewards.get("skill_crystals", 0))],
	]
	for entry: Array in plan:
		var count: int = int(entry[1])
		if count <= 0 or not ResourceLoader.exists(str(entry[0])):
			continue
		var item: ItemData = load(str(entry[0])) as ItemData
		if GameState.inventory != null:
			GameState.inventory.add_item(item, count)
		for i: int in range(count):
			granted.append(item)
		GameLogger.combat("Boss reward: %d x %s" % [count, item.item_name])
	return granted


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
		"res://Data/Items/Loot/GemDataQuartz.tres",
		"res://Data/Items/Consumables/PotHealthVial.tres",
		"res://Data/Items/Consumables/PotCyberRation.tres",
		"res://Data/Items/Consumables/PotManaStim.tres",
		"res://Data/Items/Loot/GemNeonRuby.tres",
		"res://Data/Items/Loot/GemGlowOpal.tres",
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
## Picks a living opponent of `attacker` (rules: CombatTargeting.pick_opponent).
func _pick_opponent(attacker: Combatant, target_index: int) -> Combatant:
	return CombatTargeting.pick_opponent(combatants, attacker, target_index)


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
	return CombatTargeting.find_by_id(combatants, id)


func _find_combatant_by_slot(slot_idx: int, is_player_target: bool) -> Combatant:
	return CombatTargeting.find_by_slot(combatants, slot_idx, is_player_target)


func _get_average_enemy_speed() -> int:
	return CombatMath.average_speed(combatants, false)


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
