# res://Scripts/Environment/CampfireHeat.gd
class_name CampfireHeat
extends Node3D

## Burns one living party member for 1 HP while they stand near the campfire.
## Same idea as TentacleHazard: an Area3D around the prop, not a fight.
## Never drops anyone to 0 outside of battle.

@export var trigger_radius: float = 2.4
@export var damage: int = 1
@export var cooldown: float = 2.5
@export var edge_flash_color: Color = Color(1.0, 0.45, 0.05, 0.7)
@export var camera_shake: float = 0.28

var _area: Area3D = null
var _player_inside: bool = false
var _is_burning: bool = false


func _ready() -> void:
	_keep_world_size(self)
	var blocker: Node3D = get_parent().get_node_or_null("StaticBody3D") as Node3D
	if is_instance_valid(blocker):
		_keep_world_size(blocker)

	_area = get_node_or_null("TriggerArea") as Area3D
	var col: CollisionShape3D = get_node_or_null("TriggerArea/CollisionShape3D") as CollisionShape3D
	if is_instance_valid(col) and col.shape is SphereShape3D:
		var sphere := (col.shape as SphereShape3D).duplicate() as SphereShape3D
		sphere.radius = trigger_radius
		col.shape = sphere

	if is_instance_valid(_area):
		_area.body_entered.connect(_on_body_entered)
		_area.body_exited.connect(_on_body_exited)
		# A party that loads already next to the fire never gets body_entered.
		call_deferred("_catch_player_already_inside")


## Instance scale (the placed campfires are 1.6x) must not grow the blocker or the heat radius.
func _keep_world_size(node: Node3D) -> void:
	var parent_node: Node3D = node.get_parent() as Node3D
	if not is_instance_valid(parent_node):
		return
	var parent_scale: Vector3 = parent_node.global_transform.basis.get_scale()
	var sx: float = parent_scale.x if absf(parent_scale.x) > 0.001 else 1.0
	var sy: float = parent_scale.y if absf(parent_scale.y) > 0.001 else 1.0
	var sz: float = parent_scale.z if absf(parent_scale.z) > 0.001 else 1.0
	node.scale = Vector3(1.0 / sx, 1.0 / sy, 1.0 / sz)


func _catch_player_already_inside() -> void:
	if not is_instance_valid(_area):
		return
	for body: Node in _area.get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node) -> void:
	if not _is_player(body):
		return
	_player_inside = true
	if not _is_burning:
		_burn()


func _on_body_exited(body: Node) -> void:
	if _is_player(body):
		_player_inside = false


func _is_player(body: Node) -> bool:
	return body.is_in_group(&"player") or body.name == "Player" or body is DungeonPlayer


func _burn() -> void:
	if bool(CombatManager.get("is_combat_active")):
		return
	_is_burning = true
	_land_burn()
	await get_tree().create_timer(maxf(0.2, cooldown)).timeout
	if not is_inside_tree():
		return
	_is_burning = false
	if _player_inside:
		_burn()


func _land_burn() -> void:
	if not ("current_party" in GameState) or GameState.current_party == null:
		return
	var slot_idx: int = _pick_victim()
	if slot_idx < 0:
		return

	var cat: CatCharacter = GameState.current_party.slots[slot_idx] as CatCharacter
	# Same rule as the rock tentacles: a hazard cannot knock someone out.
	var dealt: int = mini(maxi(1, damage), cat.current_hp - 1)
	if dealt <= 0:
		SignalBus.show_toast.emit("%s pulls back from the fire!" % cat.name, false)
		return

	cat.take_damage(dealt)
	SignalBus.character_health_changed.emit(slot_idx, cat.current_hp)
	SignalBus.camera_shake_requested.emit(camera_shake)
	SignalBus.edge_flash_requested.emit(edge_flash_color, 0.35)
	var msg: String = "The campfire burns %s for %d HP!" % [cat.name, dealt]
	GameLogger.combat(msg)
	SignalBus.show_toast.emit(msg, true)


func _pick_victim() -> int:
	var alive: Array[int] = []
	var slots: Array = GameState.current_party.slots
	for i: int in range(slots.size()):
		var cat: CatCharacter = slots[i] as CatCharacter
		if is_instance_valid(cat) and cat.current_hp > 0:
			alive.append(i)
	if alive.is_empty():
		return -1
	return alive[randi() % alive.size()]
