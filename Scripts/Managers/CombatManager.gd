# res://Scripts/Managers/CombatManager.gd
extends Node


class ActiveEffect:
	var id: String
	var name: String
	var duration: int # Remaining turns
	var effect_type: StringName # &"STAT_BUFF", &"DOT", &"HOT"
	var stat_target: StringName # e.g. &"strength", &"defense", &"speed"
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


class Combatant:
	var id: String
	var name: String
	var speed: float
	var meter: float = 0.0
	var is_player: bool
	var slot_index: int
	var current_hp: int
	var max_hp: int
	var current_mp: int
	var max_mp: int
	var strength: int
	var defense: int
	var ref: Resource
	var active_effects: Array[ActiveEffect] = []


	func _init(p_id: String, p_name: String, p_speed: float, p_is_player: bool, p_slot: int, p_hp: int, p_max_hp: int, p_mp: int, p_max_mp: int, p_str: int, p_def: int, p_ref: Resource) -> void:
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


	func add_effect(effect: ActiveEffect) -> void:
		for existing: ActiveEffect in active_effects:
			if existing.id == effect.id:
				existing.duration = max(existing.duration, effect.duration)
				existing.value = effect.value
				return
		active_effects.append(effect)


	func get_effective_stat(stat_name: StringName, base_val: int) -> int:
		var modifier: float = 0.0
		for eff: ActiveEffect in active_effects:
			if eff.effect_type == &"STAT_BUFF" and eff.stat_target == stat_name:
				modifier += eff.value
		return max(1, base_val + int(modifier))


	func get_effective_strength() -> int:
		return get_effective_stat(&"strength", strength)


	func get_effective_defense() -> int:
		return get_effective_stat(&"defense", defense)


	func get_effective_speed() -> float:
		var base_spd: int = int(speed)
		return float(get_effective_stat(&"speed", base_spd))


const MAX_TURN_METER: float = 100.0
const BASE_TICK_RATE: float = 25.0

@export var is_combat_active: bool = false
@export var is_paused_for_input: bool = false

var combatants: Array[Combatant] = []
var turn_queue: Array[Combatant] = []
var active_combatant: Combatant = null


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
	if not is_combat_active or is_paused_for_input:
		return

	_tick_turn_meters(delta)


func _on_combat_started(enemy_data_or_group: Variant, player_party: Array) -> void:
	combatants.clear()
	turn_queue.clear()
	active_combatant = null

	var registered_cats: int = 0
	for i in range(player_party.size()):
		var cat: Resource = player_party[i] as Resource
		if is_instance_valid(cat):
			registered_cats += 1
			var c_id: String = "party_slot_%d" % i
			var c_speed: float = float(cat.get("speed")) if "speed" in cat else 12.0
			var c_name: String = str(cat.get("name")) if cat.get("name") != null else "Space Cat %d" % (i + 1)
			var c_hp: int = int(cat.get("current_hp")) if "current_hp" in cat else 20
			var c_max_hp: int = int(cat.get("max_hp")) if "max_hp" in cat else 20

			var c_mp: int = 10
			if "current_mp" in cat:
				c_mp = int(cat.get("current_mp"))
			elif "current_mana" in cat:
				c_mp = int(cat.get("current_mana"))
			elif "mp" in cat:
				c_mp = int(cat.get("mp"))

			var c_max_mp: int = 10
			if "max_mp" in cat:
				c_max_mp = int(cat.get("max_mp"))
			elif "max_mana" in cat:
				c_max_mp = int(cat.get("max_mana"))

			var c_str: int = int(cat.get("strength")) if "strength" in cat else 10
			var c_def: int = int(cat.get("defense")) if "defense" in cat else 2

			var combatant: Combatant = Combatant.new(c_id, c_name, c_speed, true, i, c_hp, c_max_hp, c_mp, c_max_mp, c_str, c_def, cat)
			combatant.meter = 0.0
			combatants.append(combatant)

	var enemy_resources: Array[Resource] = []
	if enemy_data_or_group is Array:
		for item in (enemy_data_or_group as Array):
			if item is Resource:
				enemy_resources.append(item as Resource)
	elif is_instance_valid(enemy_data_or_group):
		if "members" in enemy_data_or_group and enemy_data_or_group.get("members") is Array:
			for member in (enemy_data_or_group.get("members") as Array):
				if member is Resource:
					enemy_resources.append(member as Resource)
		elif enemy_data_or_group is Resource:
			enemy_resources.append(enemy_data_or_group as Resource)

	GameLogger.combat("Starting Combat w/ %d party members vs %d hostiles" % [registered_cats, enemy_resources.size()])

	for e_idx in range(enemy_resources.size()):
		var e_data: Resource = enemy_resources[e_idx]
		if is_instance_valid(e_data):
			var e_speed: float = float(e_data.get("speed")) if "speed" in e_data else (float(e_data.get("initiative_speed")) if "initiative_speed" in e_data else 10.0)
			var e_max_hp: int = int(e_data.get("max_health")) if "max_health" in e_data else 30
			var e_hp: int = int(e_data.get("current_health")) if "current_health" in e_data else e_max_hp
			var e_str: int = int(e_data.get("strength")) if "strength" in e_data else (int(e_data.get("attack_damage")) if "attack_damage" in e_data else 8)
			var e_def: int = int(e_data.get("defense")) if "defense" in e_data else 2
			var e_name: String = str(e_data.get("enemy_name")) if e_data.get("enemy_name") != null else "Cyber-Zombie Cat"

			if enemy_resources.size() > 1:
				e_name = "%s %c" % [e_name, 65 + e_idx]

			var enemy_combatant: Combatant = Combatant.new("enemy_%d" % e_idx, e_name, e_speed, false, e_idx, e_hp, e_max_hp, 0, 0, e_str, e_def, e_data)
			enemy_combatant.meter = 0.0
			combatants.append(enemy_combatant)

	is_combat_active = true
	is_paused_for_input = false

	for c: Combatant in combatants:
		c.meter = minf(MAX_TURN_METER, c.get_effective_speed() * 5.0)
		SignalBus.turn_meter_updated.emit(c.id, c.meter / MAX_TURN_METER)


func _on_combat_ended(victory: bool) -> void:
	if not is_combat_active:
		return

	GameLogger.combat("BATTLE ENDED!")
	is_combat_active = false
	is_paused_for_input = false

	var victory_data: Dictionary = { }
	if victory:
		var total_xp: int = 0
		var total_gold: int = 0
		var living_party_members: int = 0
		var total_party_members: int = 0
		var enemies_killed: int = 0
		var items_dropped: Array[ItemData] = []
		var gs: Node = get_tree().root.get_node_or_null("GameState")

		for c: Combatant in combatants:
			if c.is_player:
				total_party_members += 1
				if c.current_hp > 0:
					living_party_members += 1
			else:
				if c.current_hp <= 0:
					enemies_killed += 1
					var single_xp: int = 50
					var single_gold: int = 25

					if is_instance_valid(c.ref):
						if "xp_value" in c.ref and int(c.ref.get("xp_value")) > 0:
							single_xp = int(c.ref.get("xp_value"))
						if "gold_value" in c.ref and int(c.ref.get("gold_value")) > 0:
							single_gold = int(c.ref.get("gold_value"))

						# Roll Enemy Loot Table (or Fallback if null)
						var rolled: Array[ItemData] = _resolve_enemy_loot(c.ref)
						items_dropped.append_array(rolled)

						if is_instance_valid(gs) and "inventory" in gs and gs.inventory != null:
							for dropped_item: ItemData in rolled:
								if gs.inventory.has_method("add_item"):
									gs.inventory.add_item(dropped_item)

					total_xp += single_xp
					total_gold += single_gold

		if enemies_killed == 0:
			enemies_killed = 1
			total_xp = 50
			total_gold = 25

		# Award Gold to Party Wallet
		if is_instance_valid(gs) and gs.has_method("add_gold"):
			gs.add_gold(total_gold)

		victory_data = {
			"enemies_killed": enemies_killed,
			"total_xp": total_xp,
			"total_gold": total_gold,
			"items_dropped": items_dropped,
			"living_members": max(1, living_party_members),
			"total_members": max(1, total_party_members),
		}

	combatants.clear()
	turn_queue.clear()
	active_combatant = null

	SignalBus.combat_ended.emit(victory)

	if victory:
		SignalBus.popup_requested.emit(&"BATTLE_VICTORY", victory_data)


## Resolves loot for a defeated enemy. Uses enemy's LootTable if assigned, otherwise falls back to compiled item pool.
func _resolve_enemy_loot(enemy_ref: Resource) -> Array[ItemData]:
	if not is_instance_valid(enemy_ref):
		return _generate_fallback_loot()

	# 1. Custom assigned LootTable
	if "loot_table" in enemy_ref and is_instance_valid(enemy_ref.get("loot_table")):
		var table: LootTable = enemy_ref.get("loot_table") as LootTable
		return table.roll_table()

	# 2. Fallback loot if enemy has no loot_table assigned
	return _generate_fallback_loot()


## Generates 1-2 random loot items from compiled .tres files in res://Data/Items/
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
	for p in item_paths:
		if ResourceLoader.exists(p):
			var item: ItemData = load(p) as ItemData
			if is_instance_valid(item):
				pool.append(item)

	if not pool.is_empty():
		drops.append(pool.pick_random())

	return drops


func _tick_turn_meters(delta: float) -> void:
	for c: Combatant in combatants:
		if c.current_hp <= 0:
			continue

		if c.meter < MAX_TURN_METER:
			c.meter = minf(c.meter + (c.get_effective_speed() * delta * BASE_TICK_RATE), MAX_TURN_METER)
			SignalBus.turn_meter_updated.emit(c.id, c.meter / MAX_TURN_METER)

			if c.meter >= MAX_TURN_METER and not turn_queue.has(c) and active_combatant != c:
				turn_queue.append(c)

	if not turn_queue.is_empty() and not is_paused_for_input:
		_process_turn_queue()


func _process_turn_queue() -> void:
	if turn_queue.is_empty() or is_paused_for_input:
		return

	active_combatant = turn_queue.pop_front()

	if not is_instance_valid(active_combatant) or active_combatant.current_hp <= 0:
		_unpause_and_continue()
		return

	_start_combatant_turn(active_combatant)

	if active_combatant.current_hp <= 0:
		_reset_combatant_meter(active_combatant)
		_unpause_and_continue()
		return

	if active_combatant.is_player:
		is_paused_for_input = true
		SignalBus.combatant_turn_ready.emit(active_combatant.id, active_combatant.slot_index)
	else:
		_execute_enemy_ai(active_combatant)


func _start_combatant_turn(c: Combatant) -> void:
	var expired_effects: Array[ActiveEffect] = []

	for eff: ActiveEffect in c.active_effects:
		if eff.effect_type == &"DOT":
			var dot_damage: int = int(eff.value)
			c.current_hp = max(0, c.current_hp - dot_damage)
			_sync_hp_to_ref(c)

			if c.is_player:
				SignalBus.character_health_changed.emit(c.slot_index, c.current_hp)
			else:
				SignalBus.enemy_damaged_visual.emit(c.id, dot_damage)
				SignalBus.enemy_health_changed.emit(c.id, c.current_hp, c.max_hp)

			SignalBus.camera_shake_requested.emit(0.35)
			GameLogger.combat("%s took %d %s damage from %s! (HP: %d/%d)" % [c.name, dot_damage, eff.id, eff.name, c.current_hp, c.max_hp])

		elif eff.effect_type == &"HOT":
			var hot_heal: int = int(eff.value)
			c.current_hp = min(c.max_hp, c.current_hp + hot_heal)
			_sync_hp_to_ref(c)

			if c.is_player:
				SignalBus.character_health_changed.emit(c.slot_index, c.current_hp)

			GameLogger.combat("%s healed %d HP from %s! (HP: %d/%d)" % [c.name, hot_heal, eff.name, c.current_hp, c.max_hp])

		eff.duration -= 1
		if eff.duration <= 0:
			expired_effects.append(eff)

	for exp: ActiveEffect in expired_effects:
		c.active_effects.erase(exp)
		GameLogger.combat("%s effect expired on %s" % [exp.name, c.name])

	_check_battle_state()


func _on_player_action_selected(slot_index: int, action_type: StringName, target_index: int) -> void:
	if active_combatant == null or active_combatant.slot_index != slot_index:
		return

	var acting_char: Combatant = active_combatant

	if action_type == &"ITEM":
		_execute_item_use_in_combat(acting_char, target_index)
		_reset_combatant_meter(acting_char)
		_unpause_and_continue()
		return

	if action_type == &"SPELL" or action_type == &"SKILL":
		_execute_ability_use_in_combat(acting_char, action_type, target_index)
		_reset_combatant_meter(acting_char)
		_unpause_and_continue()
		return

	if action_type == &"ATTACK":
		var target_char: Combatant = _find_combatant_by_id("enemy_%d" % target_index)
		if not is_instance_valid(target_char) or target_char.current_hp <= 0:
			for c: Combatant in combatants:
				if not c.is_player and c.current_hp > 0:
					target_char = c
					break

		if is_instance_valid(target_char):
			var damage: int = _calculate_physical_damage(acting_char, target_char)
			target_char.current_hp = max(0, target_char.current_hp - damage)
			_sync_hp_to_ref(target_char)

			SignalBus.enemy_damaged_visual.emit(target_char.id, damage)
			SignalBus.enemy_health_changed.emit(target_char.id, target_char.current_hp, target_char.max_hp)
			SignalBus.chevron_flash_requested.emit(false)
			SignalBus.camera_shake_requested.emit(0.5)

			GameLogger.combat("%s ATTACKED %s dealing %d damage! Enemy HP: %d/%d" % [acting_char.name, target_char.name, damage, target_char.current_hp, target_char.max_hp])

			if _check_battle_state():
				return

		_reset_combatant_meter(acting_char)
		_unpause_and_continue()


func _execute_ability_use_in_combat(acting_char: Combatant, action_type: StringName, target_index: int) -> void:
	var target_mgr: Node = get_tree().root.get_node_or_null("TargetSelectionManager")
	var ability: Resource = target_mgr.get_pending_ability() if is_instance_valid(target_mgr) and target_mgr.has_method("get_pending_ability") else null

	if not is_instance_valid(ability):
		return

	var spell_name: String = str(ability.get("spell_name")) if "spell_name" in ability else (str(ability.get("name")) if "name" in ability else "Ability")
	var spell_id: String = (
		str(ability.get("id"))
		if "id" in ability
		else (str(ability.get("spell_id")) if "spell_id" in ability else (str(ability.get("skill_id")) if "skill_id" in ability else spell_name.to_snake_case()))
	)

	# 1. Energy / MP Cost Validation & Deduction
	var energy_cost: int = int(ability.get("energy_cost")) if "energy_cost" in ability else 0
	if acting_char.current_mp < energy_cost:
		GameLogger.combat("%s does not have enough Energy/MP to cast %s! (Cost: %d, Current: %d)" % [acting_char.name, spell_name, energy_cost, acting_char.current_mp])
		return

	acting_char.current_mp = max(0, acting_char.current_mp - energy_cost)
	_sync_mp_to_ref(acting_char)
	if acting_char.is_player:
		SignalBus.character_mana_changed.emit(acting_char.slot_index, acting_char.current_mp, acting_char.max_mp)

	# 2. Skill Accuracy Check
	if action_type == &"SKILL" and ability.has_method("roll_success_check"):
		if not ability.roll_success_check():
			GameLogger.combat("%s used %s, but the attack MISSED!" % [acting_char.name, spell_name])
			if is_instance_valid(target_mgr) and target_mgr.has_method("clear_pending_ability"):
				target_mgr.clear_pending_ability()
			return

	# 3. Standardized Target Type Resolution (Enum Integer & String Compatible)
	var raw_target_val: Variant = ability.get("target_type") if "target_type" in ability else ability.get("target")
	var is_all_enemies: bool = false
	var is_all_allies: bool = false
	var is_single_ally: bool = false
	var is_self: bool = false

	if typeof(raw_target_val) in [TYPE_INT, TYPE_FLOAT]:
		var target_int: int = int(raw_target_val)
		match target_int:
			1:
				is_all_enemies = true
			2:
				is_single_ally = true
			3:
				is_all_allies = true
			4:
				is_self = true
	else:
		var target_str: String = str(raw_target_val).to_upper()
		if "ALL_ENEM" in target_str or "ENEMIES" in target_str or target_str == "1":
			is_all_enemies = true
		elif "ALL_PART" in target_str or "ALL_ALL" in target_str or "PARTY" in target_str or target_str == "3":
			is_all_allies = true
		elif "SINGLE_ALL" in target_str or "ALLY" in target_str or target_str == "2":
			is_single_ally = true
		elif "SELF" in target_str or target_str == "4":
			is_self = true

	var targets: Array[Combatant] = []
	if is_all_enemies:
		for c: Combatant in combatants:
			if not c.is_player and c.current_hp > 0:
				targets.append(c)
	elif is_all_allies:
		for c: Combatant in combatants:
			if c.is_player and c.current_hp > 0:
				targets.append(c)
	elif is_single_ally:
		var ally: Combatant = _find_combatant_by_slot(target_index, true)
		if is_instance_valid(ally) and ally.current_hp > 0:
			targets.append(ally)
		else:
			targets.append(acting_char)
	elif is_self:
		targets.append(acting_char)
	else: # SINGLE_ENEMY
		var enemy_target: Combatant = _find_combatant_by_id("enemy_%d" % target_index)
		if is_instance_valid(enemy_target) and enemy_target.current_hp > 0:
			targets.append(enemy_target)
		else:
			for c: Combatant in combatants:
				if not c.is_player and c.current_hp > 0:
					targets.append(c)
					break

	# 4. Potency & Caster Stat Scaling
	var stat_name: String = str(ability.get("stat_scaling")).to_lower() if "stat_scaling" in ability else "int"
	var caster_stat_val: int = 10
	if is_instance_valid(acting_char.ref) and stat_name in acting_char.ref:
		caster_stat_val = int(acting_char.ref.get(stat_name))

	var power_val: float = 10.0
	if ability.has_method("calculate_potency"):
		power_val = float(ability.calculate_potency(caster_stat_val))
	elif "base_amount" in ability:
		power_val = float(ability.get("base_amount"))
	elif "effect_amount" in ability:
		power_val = float(ability.get("effect_amount"))

	# 5. Duration Calculation (Spells: Base Duration * Level/Tier)
	var base_duration: int = 1
	if "duration" in ability:
		base_duration = int(ability.get("duration"))
	elif "turn_length" in ability:
		base_duration = int(ability.get("turn_length"))

	var total_duration: int = base_duration
	if action_type == &"SPELL":
		var spell_level: int = 1
		if "spell_level" in ability:
			spell_level = int(ability.get("spell_level"))
		elif "level" in ability:
			spell_level = int(ability.get("level"))
		elif "tier" in ability:
			spell_level = int(ability.get("tier"))

		total_duration = base_duration * max(1, spell_level)

	# 6. Action Category & Status Identification
	var action_category: String = ""
	if "action_type" in ability:
		action_category = str(ability.get("action_type")).to_upper()
	elif "category" in ability:
		action_category = str(ability.get("category")).to_upper()
	elif "effect_type" in ability:
		action_category = str(ability.get("effect_type")).to_upper()

	var status_effect: String = ""
	if "status_effect" in ability:
		status_effect = str(ability.get("status_effect")).to_upper()

	# 7. Apply Ability Effects to Selected Targets
	for t: Combatant in targets:
		if action_category == "BUFF" or status_effect == "SHIELD" or status_effect == "HASTE":
			var stat_to_buff: StringName = &"defense"
			if status_effect == "HASTE":
				stat_to_buff = &"speed"
			elif "stat_target" in ability:
				stat_to_buff = StringName(str(ability.get("stat_target")).to_lower())

			var buff_effect: ActiveEffect = ActiveEffect.new(spell_id, spell_name, total_duration, &"STAT_BUFF", stat_to_buff, power_val, acting_char.id)
			t.add_effect(buff_effect)
			GameLogger.combat("%s cast %s on %s! Boosted %s by %.0f for %d turns." % [acting_char.name, spell_name, t.name, stat_to_buff, power_val, total_duration])

		elif action_category == "DEBUFF" or status_effect == "DEFENSE_DOWN" or status_effect == "SLOW":
			var stat_to_debuff: StringName = &"defense"
			if status_effect == "SLOW":
				stat_to_debuff = &"speed"

			var debuff_effect: ActiveEffect = ActiveEffect.new(spell_id, spell_name, total_duration, &"STAT_BUFF", stat_to_debuff, -power_val, acting_char.id)
			t.add_effect(debuff_effect)
			GameLogger.combat("%s cast %s on %s! Debuffed %s by %.0f for %d turns." % [acting_char.name, spell_name, t.name, stat_to_debuff, power_val, total_duration])

		elif status_effect == "POISON" or action_category == "DOT" or (action_category == "DAMAGE" and "POISON" in str(ability.get("element")).to_upper()):
			var dot_effect: ActiveEffect = ActiveEffect.new(spell_id, spell_name, total_duration, &"DOT", &"", power_val, acting_char.id)
			t.add_effect(dot_effect)
			GameLogger.combat("%s afflicted %s with %s (Poison DoT: %.0f/turn for %d turns)!" % [acting_char.name, t.name, spell_name, power_val, total_duration])

		elif status_effect == "STUN":
			t.meter = 0.0
			SignalBus.turn_meter_updated.emit(t.id, 0.0)
			GameLogger.combat("%s STUNNED %s! Turn meter reset." % [acting_char.name, t.name])

		elif action_category == "HEAL":
			var heal_amt: int = int(power_val)
			t.current_hp = min(t.max_hp, t.current_hp + heal_amt)
			_sync_hp_to_ref(t)

			if t.is_player:
				SignalBus.character_health_changed.emit(t.slot_index, t.current_hp)

			GameLogger.combat("%s used %s on %s restoring %d HP!" % [acting_char.name, spell_name, t.name, heal_amt])

			if total_duration > 1 and action_type == &"SPELL":
				var hot_effect: ActiveEffect = ActiveEffect.new(spell_id, spell_name, total_duration - 1, &"HOT", &"", power_val, acting_char.id)
				t.add_effect(hot_effect)

		else: # Direct Magic or Skill Damage
			var damage: int = int(power_val)
			t.current_hp = max(0, t.current_hp - damage)
			_sync_hp_to_ref(t)

			if not t.is_player:
				SignalBus.enemy_damaged_visual.emit(t.id, damage)
				SignalBus.enemy_health_changed.emit(t.id, t.current_hp, t.max_hp)

			GameLogger.combat("%s cast %s on %s dealing %d damage!" % [acting_char.name, spell_name, t.name, damage])

	# 8. Clear pending ability state
	if is_instance_valid(target_mgr) and target_mgr.has_method("clear_pending_ability"):
		target_mgr.clear_pending_ability()

	_check_battle_state()


func _execute_item_use_in_combat(acting_char: Combatant, target_slot_index: int) -> void:
	GameLogger.combat("_execute_item_use_in_combat fired for %s targeting slot %d" % [acting_char.name, target_slot_index])
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if not is_instance_valid(gs) or not "inventory" in gs or gs.inventory == null:
		return

	var inv: Resource = gs.inventory as Resource
	var target_mgr: Node = get_tree().root.get_node_or_null("TargetSelectionManager")
	var item_slot_idx: int = target_mgr.get_pending_slot_index() if is_instance_valid(target_mgr) and target_mgr.has_method("get_pending_slot_index") else -1

	if item_slot_idx < 0:
		GameLogger.combat("CombatManager: Invalid item slot index %d requested!" % item_slot_idx)
		return

	var target_cat: Resource = null
	if "current_party" in gs and gs.current_party:
		var slots: Array = gs.current_party.get("slots") as Array
		if target_slot_index >= 0 and target_slot_index < slots.size():
			target_cat = slots[target_slot_index] as Resource

	if not is_instance_valid(target_cat):
		target_cat = acting_char.ref

	if is_instance_valid(target_cat) and inv.has_method("use_item"):
		var success: bool = inv.use_item(item_slot_idx, target_cat)

		if success:
			for c: Combatant in combatants:
				if c.ref == target_cat:
					if "current_hp" in c.ref:
						c.current_hp = int(c.ref.get("current_hp"))
					if "current_mp" in c.ref:
						c.current_mp = int(c.ref.get("current_mp"))
					elif "current_energy" in c.ref:
						c.current_mp = int(c.ref.get("current_energy"))

					SignalBus.character_health_changed.emit(c.slot_index, c.current_hp)
					SignalBus.character_mana_changed.emit(c.slot_index, c.current_mp, c.max_mp)

		GameLogger.combat("CombatManager: Battle item used on target slot %d (Success = %s)" % [target_slot_index, str(success)])


func _calculate_physical_damage(attacker: Combatant, defender: Combatant) -> int:
	return max(1, attacker.get_effective_strength() - defender.get_effective_defense())


func _execute_enemy_ai(enemy: Combatant) -> void:
	SignalBus.enemy_attack_started.emit(enemy.id)

	var alive_party: Array[Combatant] = []
	for c: Combatant in combatants:
		if c.is_player and c.current_hp > 0:
			alive_party.append(c)

	if not alive_party.is_empty():
		var target: Combatant = alive_party.pick_random()
		var damage: int = _calculate_physical_damage(enemy, target)
		target.current_hp = max(0, target.current_hp - damage)

		_sync_hp_to_ref(target)

		SignalBus.character_health_changed.emit(target.slot_index, target.current_hp)
		SignalBus.chevron_flash_requested.emit(true)
		SignalBus.camera_shake_requested.emit(0.35)

		if _check_battle_state():
			return

	_reset_combatant_meter(enemy)
	_unpause_and_continue()


func _sync_hp_to_ref(c: Combatant) -> void:
	if is_instance_valid(c.ref):
		if "current_hp" in c.ref:
			c.ref.set("current_hp", c.current_hp)
		elif "current_health" in c.ref:
			c.ref.set("current_health", c.current_hp)


func _sync_mp_to_ref(c: Combatant) -> void:
	if is_instance_valid(c.ref):
		if "current_mp" in c.ref:
			c.ref.set("current_mp", c.current_mp)
		elif "current_mana" in c.ref:
			c.ref.set("current_mana", c.current_mp)
		elif "current_energy" in c.ref:
			c.ref.set("current_energy", c.current_mp)


func _check_battle_state() -> bool:
	var any_enemies_alive: bool = false
	var any_party_alive: bool = false

	for c in combatants:
		if c.current_hp > 0:
			if c.is_player:
				any_party_alive = true
			else:
				any_enemies_alive = true

	if not any_enemies_alive:
		_on_combat_ended(true)
		return true

	if not any_party_alive:
		_on_combat_ended(false)
		return true

	return false


func _reset_combatant_meter(combatant: Combatant) -> void:
	combatant.meter = 0.0
	SignalBus.turn_meter_updated.emit(combatant.id, 0.0)


func _unpause_and_continue() -> void:
	active_combatant = null
	is_paused_for_input = false
	_process_turn_queue()


func _find_combatant_by_id(id: String) -> Combatant:
	for c: Combatant in combatants:
		if c.id == id:
			return c
	return null


func _find_combatant_by_slot(slot_idx: int, is_player_target: bool) -> Combatant:
	for c in combatants:
		if c.is_player == is_player_target and c.slot_index == slot_idx:
			return c
	return null
