# res://Scripts/Enemies/enemy.gd
class_name WorldEnemy
extends Node3D

## Manages 3D dungeon overworld representation, grid alignment, and multi-enemy combat initiation.

# ==============================================================================
# 1. EXPORTED CONFIGURATION
# ==============================================================================
## Primary enemy resource template
@export var data: Resource

## Explicit list of enemies in this encounter. If populated, overrides 'pack_size'.
@export var enemy_group: Array[Resource] = []

## Number of enemies to spawn when building a pack from 'data'
@export_range(1, 6) var pack_size: int = 2

## Target GridMap cell for initial positioning
@export var initial_cell: Vector2i = Vector2i(10, 1)

## Overworld scale multiplier for the lead enemy model
@export var model_scale: Vector3 = Vector3(0.6, 0.6, 0.6)

## Vertical Y-offset down from cell center (-0.5 grounds feet onto cell floor)
@export var vertical_offset: float = -0.5

@export var enemy_data: EnemyData

# ==============================================================================
# 2. NODE REFERENCES & STATE
# ==============================================================================
@onready var model_holder: Node3D = $ModelHolder as Node3D
@onready var activation_area: Area3D = $ActivationArea as Area3D

var _grid_position: Vector2i = Vector2i.ZERO
var _is_in_active_combat: bool = false
var _move_timer: float = 0.0
var _ai: EnemyAI = EnemyAI.new()
var _is_moving: bool = false

# ==============================================================================
# 3. LIFECYCLE & SETUP
# ==============================================================================
func _ready() -> void:
	_setup_enemy_group()
	_resolve_enemy_data()
	_align_to_grid()
	_instantiate_world_model()
	_connect_trigger_signals()


func get_grid_pos() -> Vector2i:
	return _grid_position


## Ensures 'enemy_data' is populated if only 'data' was assigned in the Inspector
func _resolve_enemy_data() -> void:
	if enemy_data == null:
		if data is EnemyData:
			enemy_data = data as EnemyData
		elif not enemy_group.is_empty() and enemy_group[0] is EnemyData:
			enemy_data = enemy_group[0] as EnemyData


## Ensures 'enemy_group' is populated with the correct number of enemy resources
func _setup_enemy_group() -> void:
	if enemy_group.is_empty():
		if is_instance_valid(data):
			for i: int in range(pack_size):
				enemy_group.append(data)
		else:
			var fallback_cat: Resource = load("res://Data/Enemies/ZombieCat_Base.tres") as Resource
			if is_instance_valid(fallback_cat):
				data = fallback_cat
				for i: int in range(pack_size):
					enemy_group.append(fallback_cat)


## Converts cell coordinates into 3D world space and applies vertical floor grounding
func _align_to_grid() -> void:
	_grid_position = initial_cell
	var map_mgr: Node3D = get_tree().current_scene.find_child("MapManager", true, false) as Node3D
	var base_pos: Vector3 = Vector3(initial_cell.x * 2.0, 0.0, initial_cell.y * 2.0)

	if is_instance_valid(map_mgr) and "dungeon_grid" in map_mgr and is_instance_valid(map_mgr.dungeon_grid):
		var grid: GridMap = map_mgr.dungeon_grid as GridMap
		var cell_3d := Vector3i(initial_cell.x, 0, initial_cell.y)
		base_pos = grid.map_to_local(cell_3d)

	global_position = Vector3(base_pos.x, base_pos.y + vertical_offset, base_pos.z)


## Spawns the 3D overworld mesh representing the pack leader
func _instantiate_world_model() -> void:
	if not is_instance_valid(model_holder):
		return

	var lead_resource: Resource = data
	if not enemy_group.is_empty() and is_instance_valid(enemy_group[0]):
		lead_resource = enemy_group[0]

	var model_scene: PackedScene = null
	if is_instance_valid(lead_resource) and "model_scene" in lead_resource:
		model_scene = lead_resource.get("model_scene") as PackedScene

	if is_instance_valid(model_scene):
		var model_inst: Node3D = model_scene.instantiate() as Node3D
		model_inst.scale = model_scale
		model_holder.add_child(model_inst)
	else:
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 1.2, 0.6)
		mesh_inst.mesh = box

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.RED
		mesh_inst.material_override = mat
		model_holder.add_child(mesh_inst)


# ==============================================================================
# 4. OVERWORLD MOVEMENT & PURSUIT
# ==============================================================================
const PATROL_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), # North
	Vector2i(1, 0),  # East
	Vector2i(0, 1),  # South
	Vector2i(-1, 0)  # West
]

var _patrol_index: int = 0


func _process(delta: float) -> void:
	if _is_in_active_combat or enemy_data == null or _is_moving:
		return

	var step_interval: float = maxf(0.5, enemy_data.movement_speed)
	_move_timer += delta

	if _move_timer >= step_interval:
		_move_timer = 0.0
		_check_pursuit_range()


func _check_pursuit_range() -> void:
	var player: Node3D = get_tree().get_first_node_in_group(&"player")
	var player_cell: Vector2i = player.current_grid_pos if is_instance_valid(player) and ("current_grid_pos" in player) else Vector2i(-9999, -9999)

	var enemy_dist_from_home: int = absi(_grid_position.x - initial_cell.x) + absi(_grid_position.y - initial_cell.y)
	var player_dist_from_home: int = absi(player_cell.x - initial_cell.x) + absi(player_cell.y - initial_cell.y)

	# 1. PURSUE: Player is within territory AND enemy hasn't exceeded leash limit
	if player_dist_from_home <= enemy_data.aggro_range_tiles and enemy_dist_from_home <= enemy_data.aggro_range_tiles:
		_step_toward_target(player_cell)
	# 2. RETURN HOME: Aggro lost or leash broken, walk back to initial_cell
	elif _grid_position != initial_cell:
		_step_toward_target(initial_cell)
	# 3. PATROL: Idle at home cell
	else:
		_step_patrol()


## Steps in a 4-tile cardinal loop when idle/unaggroed
func _step_patrol() -> void:
	var step_dir: Vector2i = PATROL_OFFSETS[_patrol_index]
	var target_grid_pos: Vector2i = _grid_position + step_dir

	# Check wall collisions via MapManager before stepping
	var map_mgr: Node3D = get_tree().current_scene.find_child("MapManager", true, false) as Node3D
	if is_instance_valid(map_mgr) and map_mgr.has_method("is_tile_blocked"):
		var grid_3d := Vector3i(target_grid_pos.x, 0, target_grid_pos.y)
		if map_mgr.is_tile_blocked(grid_3d):
			# Skip to next directional offset if wall-blocked
			_patrol_index = (_patrol_index + 1) % PATROL_OFFSETS.size()
			return

	_patrol_index = (_patrol_index + 1) % PATROL_OFFSETS.size()
	_move_to_cell(target_grid_pos)


## Navigates toward a target cell using AI wall-collision awareness
func _step_toward_target(target_cell: Vector2i) -> void:
	var is_blocked := func(cell: Vector2i) -> bool:
		return _is_cell_blocked(cell)

	var step_dir: Vector2i = _ai.get_smart_step(_grid_position, target_cell, is_blocked)
	if step_dir == Vector2i.ZERO:
		return

	_move_to_cell(_grid_position + step_dir)


## Helper checking MapManager tile blocking
func _is_cell_blocked(cell: Vector2i) -> bool:
	var map_mgr: Node3D = get_tree().current_scene.find_child("MapManager", true, false) as Node3D
	if is_instance_valid(map_mgr) and map_mgr.has_method("is_tile_blocked"):
		return map_mgr.is_tile_blocked(Vector3i(cell.x, 0, cell.y))
	return false


## Generic grid movement interpolation helper
func _move_to_cell(target_grid_pos: Vector2i) -> void:
	var target_world_pos := Vector3(target_grid_pos.x * 2.0, global_position.y, target_grid_pos.y * 2.0)

	_is_moving = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", target_world_pos, 0.25) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)

	tween.finished.connect(func() -> void:
		_grid_position = target_grid_pos
		_is_moving = false
	, CONNECT_ONE_SHOT)


# ==============================================================================
# 5. COMBAT TRIGGERING
# ==============================================================================
func _connect_trigger_signals() -> void:
	if is_instance_valid(activation_area):
		if not activation_area.body_entered.is_connected(_on_body_entered):
			activation_area.body_entered.connect(_on_body_entered)

	var sb: Node = SignalBus
	if is_instance_valid(sb):
		if not sb.combat_started.is_connected(_on_combat_started):
			sb.combat_started.connect(_on_combat_started)
		if not sb.combat_ended.is_connected(_on_combat_ended):
			sb.combat_ended.connect(_on_combat_ended)


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body is CharacterBody3D:
		if is_instance_valid(GameLogger):
			GameLogger.info("Player engaged enemy pack (%d hostiles) at cell Vector2i%s! Triggering combat..." % [enemy_group.size(), _grid_position])

		var party_slots: Array = []
		if "current_party" in GameState and GameState.current_party != null:
			if "slots" in GameState.current_party:
				party_slots = GameState.current_party.slots

		SignalBus.combat_started.emit(enemy_group, party_slots)


func _on_combat_started(enemy_payload: Variant, _party: Array) -> void:
	if not visible:
		return

	var is_target: bool = false
	if enemy_payload == data or enemy_payload == enemy_group:
		is_target = true
	elif enemy_payload is Array:
		if enemy_payload == enemy_group:
			is_target = true
		elif not enemy_group.is_empty() and enemy_payload.has(enemy_group[0]):
			is_target = true

	if is_target:
		_is_in_active_combat = true
		hide()


func _on_combat_ended(victory: bool) -> void:
	if not _is_in_active_combat:
		return

	if victory:
		queue_free()
	else:
		_is_in_active_combat = false
		show()
