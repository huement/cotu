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

## Target GridMap cell for initial positioning (Leave at Vector2i.ZERO to auto-detect from 3D Editor placement)
@export var initial_cell: Vector2i = Vector2i.ZERO

## Overworld scale multiplier for the lead enemy model
@export var model_scale: Vector3 = Vector3(0.6, 0.6, 0.6)

## Vertical Y-offset down from cell center (-0.5 grounds feet onto cell floor)
@export var vertical_offset: float = -0.5

@export var enemy_data: EnemyData

@export var enemy_type: String = ""

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
var _is_initialized: bool = false
var _saved_editor_pos: Vector3 = Vector3.ZERO

# ==============================================================================
# 3. LIFECYCLE & SETUP
# ==============================================================================
func _ready() -> void:
	add_to_group(&"world_enemies")
	# Cache exact 3D position placed in Editor before scene initialization
	_saved_editor_pos = global_position
	
	_resolve_enemy_data()
	_setup_enemy_group()
	_instantiate_world_model()
	_connect_trigger_signals()
	
	# Defer grid alignment until MapManager & GridMap are fully ready in tree
	call_deferred("_initialize_enemy")


func _initialize_enemy() -> void:
	_align_to_grid()
	_is_initialized = true


func get_grid_pos() -> Vector2i:
	return _grid_position


## Converts 2D cell coordinates to world space centered on the GridMap tile
func _cell_to_world(cell: Vector2i) -> Vector3:
	var map_mgr: Node3D = get_tree().current_scene.find_child("MapManager", true, false) as Node3D
	if not is_instance_valid(map_mgr):
		map_mgr = get_tree().root.find_child("MapManager", true, false) as Node3D

	if is_instance_valid(map_mgr) and "dungeon_grid" in map_mgr and is_instance_valid(map_mgr.dungeon_grid):
		var grid: GridMap = map_mgr.dungeon_grid as GridMap
		var cell_3d := Vector3i(cell.x, 0, cell.y)
		var local_pos: Vector3 = grid.map_to_local(cell_3d)
		var global_pos: Vector3 = grid.to_global(local_pos)
		return Vector3(global_pos.x, global_pos.y + vertical_offset, global_pos.z)
	
	return Vector3(cell.x * 2.0 + 1.0, vertical_offset, cell.y * 2.0 + 1.0)


## Ensures 'enemy_data' and 'data' are cross-resolved from assigned Inspector resources
func _resolve_enemy_data() -> void:
	if enemy_data == null and data is EnemyData:
		enemy_data = data as EnemyData
	elif data == null and enemy_data != null:
		data = enemy_data
	elif data == null and not enemy_group.is_empty() and enemy_group[0] is EnemyData:
		data = enemy_group[0]
		enemy_data = enemy_group[0] as EnemyData
	# Sync enemy_type fallback from resource if overworld override is empty
	if enemy_type.is_empty() and is_instance_valid(enemy_data) and "enemy_type" in enemy_data:
		enemy_type = enemy_data.enemy_type


## Ensures 'enemy_group' is populated with 'pack_size' duplicated enemy resources
func _setup_enemy_group() -> void:
	var template: Resource = data
	if not is_instance_valid(template):
		template = enemy_data
	if not is_instance_valid(template) and not enemy_group.is_empty():
		template = enemy_group[0]

	# Fallback to compiled Zombie Cat resource if unassigned
	if not is_instance_valid(template):
		if ResourceLoader.exists("res://Data/Enemies/EnZombieCat.tres"):
			template = load("res://Data/Enemies/EnZombieCat.tres") as Resource
		else:
			template = load("res://Data/Enemies/ZombieCat_Base.tres") as Resource
		data = template
		enemy_data = template as EnemyData

	if enemy_group.size() < pack_size or (enemy_group.size() == 1 and pack_size > 1):
		enemy_group.clear()
		for i: int in range(pack_size):
			if is_instance_valid(template):
				enemy_group.append(template.duplicate())


## Converts 3D Editor placement into GridMap cell space and snaps position
func _align_to_grid() -> void:
	var map_mgr: Node3D = get_tree().current_scene.find_child("MapManager", true, false) as Node3D
	if not is_instance_valid(map_mgr):
		map_mgr = get_tree().root.find_child("MapManager", true, false) as Node3D

	var grid: GridMap = null
	if is_instance_valid(map_mgr) and "dungeon_grid" in map_mgr and is_instance_valid(map_mgr.dungeon_grid):
		grid = map_mgr.dungeon_grid as GridMap

	if initial_cell != Vector2i.ZERO:
		_grid_position = initial_cell
	elif is_instance_valid(grid):
		var local_pos: Vector3 = grid.to_local(_saved_editor_pos)
		var map_cell: Vector3i = grid.local_to_map(local_pos)
		_grid_position = Vector2i(map_cell.x, map_cell.z)
		initial_cell = _grid_position
	elif is_instance_valid(map_mgr) and map_mgr.has_method("world_to_grid"):
		var map_cell: Vector3i = map_mgr.world_to_grid(_saved_editor_pos)
		_grid_position = Vector2i(map_cell.x, map_cell.z)
		initial_cell = _grid_position
	else:
		_grid_position = Vector2i(roundi((_saved_editor_pos.x - 1.0) / 2.0), roundi((_saved_editor_pos.z - 1.0) / 2.0))
		initial_cell = _grid_position

	global_position = _cell_to_world(_grid_position)


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
		_apply_material_to_model(model_inst, lead_resource)
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


func _apply_material_to_model(model_node: Node3D, e_data: Resource) -> void:
	if not is_instance_valid(model_node) or not is_instance_valid(e_data):
		return

	var mat: Material = null

	if "custom_material" in e_data and is_instance_valid(e_data.get("custom_material")):
		mat = e_data.get("custom_material") as Material

	if mat == null and "texture_path" in e_data and not str(e_data.get("texture_path")).is_empty():
		var tex_path: String = str(e_data.get("texture_path"))
		if ResourceLoader.exists(tex_path):
			var tex: Texture2D = load(tex_path) as Texture2D
			if is_instance_valid(tex):
				var std_mat := StandardMaterial3D.new()
				std_mat.albedo_texture = tex
				std_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				std_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mat = std_mat

	if is_instance_valid(mat):
		_apply_material_override_recursive(model_node, mat)


func _apply_material_override_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat

	for child in node.get_children():
		_apply_material_override_recursive(child, mat)


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
	if not _is_initialized or _is_in_active_combat or enemy_data == null or _is_moving:
		return

	var step_interval: float = maxf(0.5, enemy_data.movement_speed)
	_move_timer += delta

	if _move_timer >= step_interval:
		_move_timer = 0.0
		_check_pursuit_range()


func _check_pursuit_range() -> void:
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var player_cell: Vector2i = player.current_grid_pos if is_instance_valid(player) and ("current_grid_pos" in player) else Vector2i(-9999, -9999)

	var dist_to_player: int = absi(_grid_position.x - player_cell.x) + absi(_grid_position.y - player_cell.y)

	if dist_to_player <= 1:
		trigger_combat_encounter()
		return

	var enemy_dist_from_home: int = absi(_grid_position.x - initial_cell.x) + absi(_grid_position.y - initial_cell.y)
	var player_dist_from_home: int = absi(player_cell.x - initial_cell.x) + absi(player_cell.y - initial_cell.y)

	if player_dist_from_home <= enemy_data.aggro_range_tiles and enemy_dist_from_home <= enemy_data.aggro_range_tiles:
		_step_toward_target(player_cell)
	elif _grid_position != initial_cell:
		_step_toward_target(initial_cell)
	else:
		_step_patrol()


func _step_patrol() -> void:
	var step_dir: Vector2i = PATROL_OFFSETS[_patrol_index]
	var target_grid_pos: Vector2i = _grid_position + step_dir

	var map_mgr: Node3D = get_tree().current_scene.find_child("MapManager", true, false) as Node3D
	if is_instance_valid(map_mgr) and map_mgr.has_method("is_tile_blocked"):
		var grid_3d := Vector3i(target_grid_pos.x, 0, target_grid_pos.y)
		if map_mgr.is_tile_blocked(grid_3d):
			_patrol_index = (_patrol_index + 1) % PATROL_OFFSETS.size()
			return

	_patrol_index = (_patrol_index + 1) % PATROL_OFFSETS.size()
	_move_to_cell(target_grid_pos)


func _step_toward_target(target_cell: Vector2i) -> void:
	var is_blocked := func(cell: Vector2i) -> bool:
		return _is_cell_blocked(cell)

	var step_dir: Vector2i = _ai.get_smart_step(_grid_position, target_cell, is_blocked)
	if step_dir == Vector2i.ZERO:
		return

	_move_to_cell(_grid_position + step_dir)


func _is_cell_blocked(cell: Vector2i) -> bool:
	var map_mgr: Node3D = get_tree().current_scene.find_child("MapManager", true, false) as Node3D
	if is_instance_valid(map_mgr) and map_mgr.has_method("is_tile_blocked"):
		return map_mgr.is_tile_blocked(Vector3i(cell.x, 0, cell.y))
	return false


func _move_to_cell(target_grid_pos: Vector2i) -> void:
	var target_world_pos: Vector3 = _cell_to_world(target_grid_pos)

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


func _on_body_entered(body: Node) -> void:
	if body.is_in_group(&"player") or body.name == "Player" or body is CharacterBody3D or body is DungeonPlayer:
		trigger_combat_encounter()


func trigger_combat_encounter() -> void:
	if _is_in_active_combat or not visible:
		return

	_is_in_active_combat = true
	hide()

	if is_instance_valid(GameLogger):
		GameLogger.info("Player engaged enemy pack (%d hostiles) at cell Vector2i%s! Triggering combat..." % [enemy_group.size(), _grid_position])

	var party_slots: Array = []
	if "current_party" in GameState and GameState.current_party != null:
		if "slots" in GameState.current_party:
			party_slots = GameState.current_party.slots

	SignalBus.combat_started.emit(enemy_group, party_slots)


func _on_combat_started(enemy_payload: Variant, _party: Array) -> void:
	if not visible or _is_in_active_combat:
		return

	var is_target: bool = false

	if enemy_payload is Array:
		var payload_array: Array = enemy_payload as Array
		if payload_array == enemy_group:
			is_target = true
		else:
			for item in payload_array:
				if item == self:
					is_target = true
					break

	elif enemy_payload is Object and is_instance_valid(enemy_payload):
		if enemy_payload == self:
			is_target = true

	if is_target:
		_is_in_active_combat = true
		hide()


func _is_player_adjacent() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if is_instance_valid(player) and ("current_grid_pos" in player):
		var p_cell: Vector2i = player.current_grid_pos
		var dist: int = absi(_grid_position.x - p_cell.x) + absi(_grid_position.y - p_cell.y)
		return dist <= 1
	return true


func _on_combat_ended(victory: bool) -> void:
	if not _is_in_active_combat:
		return

	if victory:
		queue_free()
	else:
		_is_in_active_combat = false
		show()
