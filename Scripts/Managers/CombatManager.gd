# res://Scripts/Managers/CombatManager.gd
class_name CombatManager
extends Node

## Strongly-typed wrapper tracking runtime ATB state for a combatant
class Combatant:
	var id: String
	var name: String
	var speed: float
	var meter: float = 0.0
	var is_player: bool
	var slot_index: int
	var ref: Resource # CatCharacter or EnemyData

	func _init(p_id: String, p_name: String, p_speed: float, p_is_player: bool, p_slot: int, p_ref: Resource) -> void:
		id = p_id
		name = p_name
		speed = maxf(1.0, p_speed)
		is_player = p_is_player
		slot_index = p_slot
		ref = p_ref

const MAX_TURN_METER: float = 100.0
const BASE_TICK_RATE: float = 15.0

@export var is_combat_active: bool = false
@export var is_paused_for_input: bool = false

var combatants: Array[Combatant] = []
var turn_queue: Array[Combatant] = []
var active_combatant: Combatant = null


# ==============================================================================
# 1. LIFECYCLE & SIGNAL CONNECTIONS
# ==============================================================================
func _ready() -> void:
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb:
		if sb.has_signal("combat_started"):
			sb.combat_started.connect(_on_combat_started)
		if sb.has_signal("combat_ended"):
			sb.combat_ended.connect(_on_combat_ended)
		# 🎯 LISTEN FOR PLAYER ACTIONS FROM BATTLE HUD
		if sb.has_signal("player_action_selected"):
			sb.player_action_selected.connect(execute_player_action)

func _process(delta: float) -> void:
	if not is_combat_active or is_paused_for_input:
		return
		
	_tick_turn_meters(delta)


# ==============================================================================
# 2. COMBAT INITIALIZATION (Round 1 Rules)
# ==============================================================================
func _on_combat_started(enemy_data: EnemyData, player_party: Array) -> void:
	combatants.clear()
	turn_queue.clear()
	active_combatant = null
	
	# 1. Populate Player Party Combatants (Slots 0-5)
	for i: int in range(player_party.size()):
		var cat: CatCharacter = player_party[i] as CatCharacter
		if cat != null:
			var c_id: String = "party_slot_%d" % i
			var cat_speed: float = float(cat.speed) if "speed" in cat else 10.0
			var combatant: Combatant = Combatant.new(c_id, cat.name, cat_speed, true, i, cat)
			
			# 🎯 ROUND 1 RULE: Player party starts pre-filled at 100% ATB
			combatant.meter = MAX_TURN_METER
			combatants.append(combatant)

	# 2. Populate Enemy Combatant
	if enemy_data:
		var e_speed: float = float(enemy_data.speed) if "speed" in enemy_data else 8.0
		var enemy_combatant: Combatant = Combatant.new("enemy_0", enemy_data.enemy_name, e_speed, false, 0, enemy_data)
		enemy_combatant.meter = 0.0 # Enemies start at 0%
		combatants.append(enemy_combatant)

	is_combat_active = true
	
	# 3. Sort Round 1 Turn Queue: Front Row (Slots 0-2) -> Back Row (Slots 3-5)
	_setup_round_one_queue()
	_process_turn_queue()

func _setup_round_one_queue() -> void:
	var front_row: Array[Combatant] = []
	var back_row: Array[Combatant] = []

	for c: Combatant in combatants:
		if c.is_player and c.meter >= MAX_TURN_METER:
			if c.slot_index < 3:
				front_row.append(c)
			else:
				back_row.append(c)

	# Front row cats sorted by speed, followed by back row cats
	front_row.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.speed > b.speed)
	back_row.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.speed > b.speed)

	turn_queue.append_array(front_row)
	turn_queue.append_array(back_row)

func _on_combat_ended(_victory: bool) -> void:
	is_combat_active = false
	is_paused_for_input = false
	combatants.clear()
	turn_queue.clear()
	active_combatant = null


# ==============================================================================
# 3. ATB TICKING & TURN QUEUE ENGINE
# ==============================================================================
func _tick_turn_meters(delta: float) -> void:
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")

	for c: Combatant in combatants:
		if c.meter < MAX_TURN_METER:
			c.meter = minf(c.meter + (c.speed * delta * BASE_TICK_RATE), MAX_TURN_METER)
			
			if sb and sb.has_signal("turn_meter_updated"):
				sb.turn_meter_updated.emit(c.id, c.meter / MAX_TURN_METER)

			# Queue combatant when meter hits 100%
			if c.meter >= MAX_TURN_METER and not turn_queue.has(c) and active_combatant != c:
				turn_queue.append(c)

	if not turn_queue.is_empty() and not is_paused_for_input:
		_process_turn_queue()

func _process_turn_queue() -> void:
	if turn_queue.is_empty() or is_paused_for_input:
		return

	active_combatant = turn_queue.pop_front()
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")

	if active_combatant.is_player:
		is_paused_for_input = true
		if sb and sb.has_signal("combatant_turn_ready"):
			sb.combatant_turn_ready.emit(active_combatant.id, active_combatant.slot_index)
	else:
		_execute_enemy_ai(active_combatant)


# ==============================================================================
# 4. ACTION RESOLUTION
# ==============================================================================
func execute_player_action(slot_index: int, action_type: String, target_index: int = 0) -> void:
	if active_combatant == null or active_combatant.slot_index != slot_index:
		return

	# Reset acting character's turn meter
	_reset_combatant_meter(active_combatant)
	active_combatant = null
	
	# Request hit confirm visual effect on UI
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb and sb.has_signal("chevron_flash_requested"):
		sb.chevron_flash_requested.emit(false) 

	is_paused_for_input = false
	
	# Continue to next turn in queue or resume ticking
	_process_turn_queue()

func _execute_enemy_ai(enemy: Combatant) -> void:
	# Enemy attacks a player party member
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb and sb.has_signal("chevron_flash_requested"):
		sb.chevron_flash_requested.emit(true) # Flashes red (Player Hit)

	_reset_combatant_meter(enemy)
	active_combatant = null
	_process_turn_queue()

func _reset_combatant_meter(combatant: Combatant) -> void:
	combatant.meter = 0.0
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb and sb.has_signal("turn_meter_updated"):
		sb.turn_meter_updated.emit(combatant.id, 0.0)
