# res://Scripts/Managers/CombatManager.gd
extends Node


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
		c.meter = minf(MAX_TURN_METER, c.speed * 5.0)
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
		var living_party_members: int = 0
		var enemies_killed: int = 0

		for c: Combatant in combatants:
			if not c.is_player and c.current_hp <= 0:
				enemies_killed += 1
				var single_xp: int = 50
				if is_instance_valid(c.ref) and "xp_value" in c.ref:
					var raw_xp: Variant = c.ref.get("xp_value")
					if typeof(raw_xp) in [TYPE_INT, TYPE_FLOAT] and int(raw_xp) > 0:
						single_xp = int(raw_xp)
				total_xp += single_xp
			elif c.is_player and c.current_hp > 0:
				living_party_members += 1

		if enemies_killed == 0:
			enemies_killed = 1
			total_xp = 50

		victory_data = { "enemies_killed": enemies_killed, "total_xp": total_xp, "living_members": max(1, living_party_members) }

	combatants.clear()
	turn_queue.clear()
	active_combatant = null

	SignalBus.combat_ended.emit(victory)

	if victory:
		SignalBus.popup_requested.emit(&"BATTLE_VICTORY", victory_data)


func _tick_turn_meters(delta: float) -> void:
	for c: Combatant in combatants:
		if c.meter < MAX_TURN_METER:
			c.meter = minf(c.meter + (c.speed * delta * BASE_TICK_RATE), MAX_TURN_METER)
			SignalBus.turn_meter_updated.emit(c.id, c.meter / MAX_TURN_METER)

			if c.meter >= MAX_TURN_METER and not turn_queue.has(c) and active_combatant != c:
				turn_queue.append(c)

	if not turn_queue.is_empty() and not is_paused_for_input:
		_process_turn_queue()


func _process_turn_queue() -> void:
	if turn_queue.is_empty() or is_paused_for_input:
		return

	active_combatant = turn_queue.pop_front()

	if active_combatant.is_player:
		is_paused_for_input = true
		SignalBus.combatant_turn_ready.emit(active_combatant.id, active_combatant.slot_index)
	else:
		_execute_enemy_ai(active_combatant)


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
			for c in combatants:
				if not c.is_player and c.current_hp > 0:
					target_char = c
					break

		if is_instance_valid(target_char):
			var damage: int = _calculate_physical_damage(acting_char, target_char)
			target_char.current_hp = max(0, target_char.current_hp - damage)

			if is_instance_valid(target_char.ref):
				if "current_health" in target_char.ref:
					target_char.ref.set("current_health", target_char.current_hp)
				elif "current_hp" in target_char.ref:
					target_char.ref.set("current_hp", target_char.current_hp)

			SignalBus.enemy_damaged_visual.emit(target_char.id, damage)
			SignalBus.enemy_health_changed.emit(target_char.id, target_char.current_hp, target_char.max_hp)
			SignalBus.chevron_flash_requested.emit(false)

			GameLogger.combat("%s ATTACKED %s dealing %d damage! Enemy HP: %d/%d" % [acting_char.name, target_char.name, damage, target_char.current_hp, target_char.max_hp])

			if target_char.current_hp <= 0:
				var any_enemies_alive: bool = false
				for c in combatants:
					if not c.is_player and c.current_hp > 0:
						any_enemies_alive = true
						break
				if not any_enemies_alive:
					_on_combat_ended(true)
					return

		_reset_combatant_meter(acting_char)
		_unpause_and_continue()


func _execute_ability_use_in_combat(acting_char: Combatant, action_type: StringName, target_index: int) -> void:
	var target_mgr: Node = get_tree().root.get_node_or_null("TargetSelectionManager")
	var ability: Resource = target_mgr.get_pending_ability() if is_instance_valid(target_mgr) and target_mgr.has_method("get_pending_ability") else null

	var target_type_val: Variant = null
	if is_instance_valid(ability):
		if "target_type" in ability:
			target_type_val = ability.get("target_type")
		elif "target" in ability:
			target_type_val = ability.get("target")

	var is_ally: bool = false
	if is_instance_valid(target_mgr) and target_mgr.has_method("is_ally_targeting"):
		is_ally = target_mgr.call("is_ally_targeting", target_type_val)
	else:
		is_ally = (target_type_val == 0 or target_type_val == 1 or str(target_type_val).to_upper().contains("PARTY"))

	var target_char: Combatant = null
	if is_ally:
		target_char = _find_combatant_by_slot(target_index, true)
		if not is_instance_valid(target_char):
			target_char = acting_char
	else:
		target_char = _find_combatant_by_id("enemy_%d" % target_index)
		if not is_instance_valid(target_char) or target_char.current_hp <= 0:
			for c in combatants:
				if not c.is_player and c.current_hp > 0:
					target_char = c
					break

	if not is_instance_valid(target_char):
		return

	if is_ally:
		var heal_amt: int = 0
		if is_instance_valid(ability):
			if "heal_amount" in ability:
				heal_amt = int(ability.get("heal_amount"))
			elif "health_restore" in ability:
				heal_amt = int(ability.get("health_restore"))
			elif "heal" in ability:
				heal_amt = int(ability.get("heal"))
		if heal_amt == 0:
			heal_amt = 25

		target_char.current_hp = min(target_char.max_hp, target_char.current_hp + heal_amt)
		if is_instance_valid(target_char.ref):
			if "current_hp" in target_char.ref:
				target_char.ref.set("current_hp", target_char.current_hp)
			elif "current_health" in target_char.ref:
				target_char.ref.set("current_health", target_char.current_hp)

		SignalBus.character_health_changed.emit(target_char.slot_index, target_char.current_hp)
		GameLogger.combat("%s used %s on %s restoring %d HP! (HP: %d/%d)" % [acting_char.name, action_type, target_char.name, heal_amt, target_char.current_hp, target_char.max_hp])
	else:
		var damage: int = _calculate_physical_damage(acting_char, target_char)
		if action_type == &"SPELL":
			damage = int(damage * 1.5)

		target_char.current_hp = max(0, target_char.current_hp - damage)
		if is_instance_valid(target_char.ref):
			if "current_health" in target_char.ref:
				target_char.ref.set("current_health", target_char.current_hp)
			elif "current_hp" in target_char.ref:
				target_char.ref.set("current_hp", target_char.current_hp)

		SignalBus.enemy_damaged_visual.emit(target_char.id, damage)
		SignalBus.enemy_health_changed.emit(target_char.id, target_char.current_hp, target_char.max_hp)
		SignalBus.chevron_flash_requested.emit(false)

		GameLogger.combat("%s used %s on %s dealing %d damage! Enemy HP: %d/%d" % [acting_char.name, action_type, target_char.name, damage, target_char.current_hp, target_char.max_hp])

		if target_char.current_hp <= 0:
			var any_enemies_alive: bool = false
			for c in combatants:
				if not c.is_player and c.current_hp > 0:
					any_enemies_alive = true
					break
			if not any_enemies_alive:
				_on_combat_ended(true)


func _execute_item_use_in_combat(acting_char: Combatant, target_slot_index: int) -> void:
	GameLogger.combat("_execute_item_use_in_combat fired for %s targeting slot %d" % [acting_char.name, target_slot_index])
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if not is_instance_valid(gs) or not "inventory" in gs or gs.inventory == null:
		return

	var inv: Inventory = gs.inventory as Inventory
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

	if is_instance_valid(target_cat):
		var success: bool = inv.use_item(item_slot_idx, target_cat)

		if success:
			for c in combatants:
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
	return max(1, attacker.strength - defender.defense)


func _execute_enemy_ai(enemy: Combatant) -> void:
	SignalBus.enemy_attack_started.emit(enemy.id)

	var alive_party: Array[Combatant] = []
	for c in combatants:
		if c.is_player and c.current_hp > 0:
			alive_party.append(c)

	if not alive_party.is_empty():
		var target: Combatant = alive_party.pick_random()
		var damage: int = _calculate_physical_damage(enemy, target)
		target.current_hp = max(0, target.current_hp - damage)

		if is_instance_valid(target.ref):
			if "current_hp" in target.ref:
				target.ref.set("current_hp", target.current_hp)

		SignalBus.character_health_changed.emit(target.slot_index, target.current_hp)
		SignalBus.chevron_flash_requested.emit(true)

		var any_party_alive: bool = false
		for c in combatants:
			if c.is_player and c.current_hp > 0:
				any_party_alive = true
				break

		if not any_party_alive:
			_on_combat_ended(false)
			return

	_reset_combatant_meter(enemy)
	_unpause_and_continue()


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
