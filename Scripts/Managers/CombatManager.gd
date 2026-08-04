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
	var strength: int
	var defense: int
	var ref: Resource

	func _init(p_id: String, p_name: String, p_speed: float, p_is_player: bool, p_slot: int, p_hp: int, p_max_hp: int, p_str: int, p_def: int, p_ref: Resource) -> void:
		id = p_id
		name = p_name
		speed = maxf(1.0, p_speed)
		is_player = p_is_player
		slot_index = p_slot
		current_hp = p_hp
		max_hp = max(1, p_max_hp)
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


## Accepts a single EnemyData Resource, an Array[Resource] of enemies, or an EnemyGroupData resource
func _on_combat_started(enemy_data_or_group: Variant, player_party: Array) -> void:
	combatants.clear()
	turn_queue.clear()
	active_combatant = null

	# 1. Resolve Player Party Combatants
	var valid_party: Array = []
	for slot in player_party:
		if is_instance_valid(slot):
			valid_party.append(slot)

	if valid_party.is_empty():
		var gs: Node = get_tree().root.get_node_or_null("GameState")
		if is_instance_valid(gs) and "current_party" in gs and gs.get("current_party") != null:
			var party_res: Resource = gs.get("current_party") as Resource
			if "slots" in party_res:
				for slot in (party_res.get("slots") as Array):
					if is_instance_valid(slot): valid_party.append(slot)

	for i: int in range(valid_party.size()):
		var cat: Resource = valid_party[i] as Resource
		if cat != null:
			var c_id: String = "party_slot_%d" % i
			var c_speed: float = float(cat.get("speed")) if "speed" in cat else 12.0
			var c_name: String = str(cat.get("name")) if cat.get("name") != null else "Space Cat %d" % (i + 1)
			var c_hp: int = int(cat.get("current_hp")) if "current_hp" in cat else 20
			var c_max_hp: int = int(cat.get("max_hp")) if "max_hp" in cat else 20
			var c_str: int = int(cat.get("strength")) if "strength" in cat else 10
			var c_def: int = int(cat.get("defense")) if "defense" in cat else 2

			var combatant: Combatant = Combatant.new(c_id, c_name, c_speed, true, i, c_hp, c_max_hp, c_str, c_def, cat)
			combatant.meter = 0.0
			combatants.append(combatant)

	# 2. Unpack Enemy Roster (Handles Single Enemy, Array of Enemies, or EnemyGroupData)
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

	GameLogger.combat("Starting Combat w/ %d party members vs %d hostiles" % [valid_party.size(), enemy_resources.size()])

	for e_idx in range(enemy_resources.size()):
		var e_data: Resource = enemy_resources[e_idx]
		if is_instance_valid(e_data):
			var e_speed: float = float(e_data.get("speed")) if "speed" in e_data else (float(e_data.get("initiative_speed")) if "initiative_speed" in e_data else 10.0)
			var e_max_hp: int = int(e_data.get("max_health")) if "max_health" in e_data else 30
			var e_hp: int = int(e_data.get("current_health")) if "current_health" in e_data else e_max_hp
			var e_str: int = int(e_data.get("strength")) if "strength" in e_data else (int(e_data.get("attack_damage")) if "attack_damage" in e_data else 8)
			var e_def: int = int(e_data.get("defense")) if "defense" in e_data else 2
			var e_name: String = str(e_data.get("enemy_name")) if e_data.get("enemy_name") != null else "Cyber-Zombie Cat"

			# Give unique names if multiple enemies share the same name
			if enemy_resources.size() > 1:
				e_name = "%s %c" % [e_name, 65 + e_idx] # e.g. Cyber-Zombie Cat A, B, C

			var enemy_combatant: Combatant = Combatant.new("enemy_%d" % e_idx, e_name, e_speed, false, e_idx, e_hp, e_max_hp, e_str, e_def, e_data)
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

	var victory_data: Dictionary = {}
	if victory:
		var total_xp: int = 0
		var living_party_members: int = 0
		var enemies_killed: int = 0

		# Sum up XP for ALL defeated enemies in this encounter
		for c: Combatant in combatants:
			if not c.is_player and c.current_hp <= 0:
				enemies_killed += 1
				var single_xp: int = 50 # Default XP per enemy
				if is_instance_valid(c.ref) and "xp_value" in c.ref:
					var raw_xp: Variant = c.ref.get("xp_value")
					if typeof(raw_xp) in [TYPE_INT, TYPE_FLOAT] and int(raw_xp) > 0:
						single_xp = int(raw_xp)
				total_xp += single_xp
			elif c.is_player and c.current_hp > 0:
				living_party_members += 1
		
		# If no enemies were tracked, fall back gracefully
		if enemies_killed == 0:
			enemies_killed = 1
			total_xp = 50

		victory_data = {
			"enemies_killed": enemies_killed,
			"total_xp": total_xp,
			"living_members": max(1, living_party_members)
		}

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
	var target_char: Combatant = _find_combatant_by_id("enemy_%d" % target_index)

	# Auto-target first living enemy if target_index is defeated or invalid
	if not is_instance_valid(target_char) or target_char.current_hp <= 0:
		for c in combatants:
			if not c.is_player and c.current_hp > 0:
				target_char = c
				break

	if not is_instance_valid(target_char):
		_reset_combatant_meter(acting_char)
		_unpause_and_continue()
		return

	match action_type:
		&"ATTACK", &"SKILL", &"SPELL":
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

			GameLogger.combat("%s dealt %d damage to %s! Enemy HP: %d/%d" % [
				acting_char.name, damage, target_char.name, target_char.current_hp, target_char.max_hp
			])
			
			if target_char.current_hp <= 0:
				print("[CombatManager] %s defeated!" % target_char.name)
				
				# 🎯 VICTORY GUARD: Only declare victory when ALL hostiles are defeated
				var any_enemies_alive: bool = false
				for c in combatants:
					if not c.is_player and c.current_hp > 0:
						any_enemies_alive = true
						break

				if not any_enemies_alive:
					print("[CombatManager] VICTORY! All hostiles defeated!")
					_on_combat_ended(true)
					return

	_reset_combatant_meter(acting_char)
	_unpause_and_continue()


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
