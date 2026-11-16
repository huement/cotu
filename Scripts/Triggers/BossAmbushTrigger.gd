# res://Scripts/Triggers/BossAmbushTrigger.gd
class_name BossAmbushTrigger
extends Area3D
## Walk into this area and a SCRIPTED BlobBossController boss (e.g. BeastKing) bursts out of the
## ground in front of the party: the party is frozen, the ground quakes, the screen strobes
## red / black (GhostScareFX blood mode) and the battle starts when the boss is up.
## The boss's own entrance_sound plays while it rises.
##
## Beating the boss is remembered (GameState) - it won't come back. Lose or flee and it sinks
## back down; it ambushes again the next time the party walks back into the area.
##
## Works with the area's CollisionShape3D (a BoxShape3D) - the party is checked against the
## box footprint every time it moves, so the box's height doesn't matter.

## The boss to raise (a BlobBossController with trigger_mode = Scripted).
@export var boss: NodePath
## Save-state id (must be unique across the game).
@export var object_id: String = "boss_ambush_01"
## How far in front of the party the boss erupts (metres).
@export var rise_distance: float = 8.0
## Red/black strobes while the boss rises (spread evenly over its rise time).
@export_range(0, 12) var rise_strobes: int = 5
## Big strobe when the battle opens.
@export var battle_strobe: bool = true

var _boss_node: BlobBossController = null
var _fired: bool = false
var _defeated: bool = false
## After a lost / fled fight the party must leave the area once before it re-arms.
var _wait_for_exit: bool = false


func _ready() -> void:
	monitoring = true
	_boss_node = get_node_or_null(boss) as BlobBossController
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(gs) and gs.has_method("get_object_state"):
		_defeated = bool((gs.get_object_state(_map_id(), object_id) as Dictionary).get("boss_defeated", false))
	if _defeated:
		if is_instance_valid(_boss_node):
			_boss_node.queue_free()
		return
	if not is_instance_valid(_boss_node):
		push_warning("BossAmbushTrigger '%s': 'boss' must point at a BlobBossController." % name)
		return
	_boss_node.defeated.connect(_on_boss_defeated)
	body_entered.connect(_on_body_entered)
	if is_instance_valid(SignalBus):
		SignalBus.party_moved.connect(_on_party_moved)
		SignalBus.combat_ended.connect(_on_combat_ended)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group(&"player"):
		_check_party()


func _on_party_moved(_grid_pos: Vector3i, _facing: Variant) -> void:
	_check_party()


func _check_party() -> void:
	if _fired or _defeated or not is_instance_valid(_boss_node):
		return
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if not is_instance_valid(player):
		return
	var inside: bool = is_point_inside(player.global_position)
	if _wait_for_exit:
		if not inside:
			_wait_for_exit = false
		return
	if inside:
		_spring_ambush(player)


## True when [param world_pos] is inside the footprint (x / z) of this area's box shapes.
func is_point_inside(world_pos: Vector3) -> bool:
	for child: Node in get_children():
		var cs := child as CollisionShape3D
		if cs == null or not (cs.shape is BoxShape3D):
			continue
		var local: Vector3 = cs.global_transform.affine_inverse() * world_pos
		var half: Vector3 = (cs.shape as BoxShape3D).size * 0.5
		if absf(local.x) <= half.x and absf(local.z) <= half.z:
			return true
	return false


func _spring_ambush(player: Node3D) -> void:
	_fired = true
	if player.has_method("set_movement_locked"):
		player.call("set_movement_locked", true)
	# Erupt straight ahead of the party, on the boss's ground height.
	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD
	var spot: Vector3 = player.global_position + forward * rise_distance
	spot.y = player.global_position.y # ground level where the party stands
	if is_instance_valid(GameLogger):
		GameLogger.combat("The marsh floor splits open...")
	_boss_node.emerge_at(spot)
	_strobe_during_rise()
	if battle_strobe and is_instance_valid(SignalBus):
		SignalBus.combat_started.connect(_on_battle_opened, CONNECT_ONE_SHOT)


func _strobe_during_rise() -> void:
	if rise_strobes <= 0:
		return
	var gap: float = _boss_node.rise_duration / float(rise_strobes)
	GhostScareFX.play_blood(get_tree(), 1, 0.9, 0.07)
	for i: int in range(1, rise_strobes):
		await get_tree().create_timer(gap).timeout
		if not is_inside_tree():
			return
		GhostScareFX.play_blood(get_tree(), 1 + (i % 2), 0.75 + 0.05 * i, 0.06)


func _on_battle_opened(_enemies: Variant, _party: Array, _facing: String) -> void:
	GhostScareFX.play_blood(get_tree(), 3, 1.0, 0.07)


func _on_combat_ended(victory: bool) -> void:
	if not _fired or _defeated or victory:
		return
	# Lost or fled: the boss sank back down. Re-arm once the party has stepped out of the area.
	_fired = false
	_wait_for_exit = true


func _on_boss_defeated() -> void:
	_defeated = true
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(gs) and gs.has_method("set_object_state_flag"):
		gs.set_object_state_flag(_map_id(), object_id, "boss_defeated", true)


func _map_id() -> String:
	return GameState.get_current_map_id()
