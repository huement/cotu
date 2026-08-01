# res://Scripts/Enemies/enemy.gd
class_name WorldEnemy
extends Node3D

## Manages 3D dungeon overworld representation, grid alignment, and multi-enemy combat initiation.

# ==============================================================================
# 1. EXPORTED CONFIGURATION
# ==============================================================================
## Primary enemy resource template (used for single encounters or auto-generating packs)
@export var data: Resource

## Explicit list of enemies in this encounter. If populated in Inspector, overrides 'pack_size'.
@export var enemy_group: Array[Resource] = []

## Number of enemies to spawn when building a pack from a single 'data' resource
@export_range(1, 6) var pack_size: int = 2

## Target GridMap cell for initial positioning
@export var initial_cell: Vector2i = Vector2i(10, 1)

## Overworld scale multiplier for the lead enemy model
@export var model_scale: Vector3 = Vector3(0.6, 0.6, 0.6)

## Vertical Y-offset down from cell center (-1.0 grounds feet onto 2-unit cell floors)
@export var vertical_offset: float = -0.5

# ==============================================================================
# 2. NODE REFERENCES
# ==============================================================================
@onready var model_holder: Node3D = $ModelHolder as Node3D
@onready var activation_area: Area3D = $ActivationArea as Area3D

# ==============================================================================
# 3. LIFECYCLE & SETUP
# ==============================================================================
func _ready() -> void:
	_setup_enemy_group()
	_align_to_grid()
	_instantiate_world_model()
	_connect_trigger_signals()

## Ensures 'enemy_group' is populated with the correct number of enemy resources
func _setup_enemy_group() -> void:
	# If no explicit group array was built in the Inspector, build one using 'data' and 'pack_size'
	if enemy_group.is_empty():
		if is_instance_valid(data):
			for i: int in range(pack_size):
				enemy_group.append(data)
		else:
			# Fallback: Load default Zombie Cat resource if no data is assigned
			var fallback_cat: Resource = load("res://Data/Enemies/ZombieCat_Base.tres") as Resource
			if is_instance_valid(fallback_cat):
				data = fallback_cat
				for i: int in range(pack_size):
					enemy_group.append(fallback_cat)

## Converts cell coordinates into 3D world space and applies vertical floor grounding
func _align_to_grid() -> void:
	var map_mgr: Node3D = get_tree().current_scene.find_child("MapManager", true, false) as Node3D
	var base_pos: Vector3 = Vector3(initial_cell.x * 2.0, 0.0, initial_cell.y * 2.0)

	if is_instance_valid(map_mgr) and "dungeon_grid" in map_mgr and is_instance_valid(map_mgr.dungeon_grid):
		var grid: GridMap = map_mgr.dungeon_grid as GridMap
		var cell_3d := Vector3i(initial_cell.x, 0, initial_cell.y)
		base_pos = grid.map_to_local(cell_3d)

	global_position = Vector3(base_pos.x, base_pos.y + vertical_offset, base_pos.z)

## Spawns the 3D overworld mesh representing the pack leader in the dungeon corridor
func _instantiate_world_model() -> void:
	if not is_instance_valid(model_holder):
		return

	# Resolve lead resource for overworld visual preview
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
		# Fallback debug mesh if no GLTF model scene is bound
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 1.2, 0.6)
		mesh_inst.mesh = box

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.RED
		mesh_inst.material_override = mat
		model_holder.add_child(mesh_inst)

# ==============================================================================
# 4. COMBAT TRIGGERING
# ==============================================================================
func _connect_trigger_signals() -> void:
	if is_instance_valid(activation_area):
		if not activation_area.body_entered.is_connected(_on_body_entered):
			activation_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body is CharacterBody3D:
		if is_instance_valid(GameLogger):
			GameLogger.info("Player engaged enemy pack (%d hostiles) at cell Vector2i%s! Triggering combat..." % [enemy_group.size(), initial_cell])

		# 🎯 Correctly extract the slots Array from the DungeonParty Resource
		var party_slots: Array = []
		if "current_party" in GameState and GameState.current_party != null:
			if "slots" in GameState.current_party:
				party_slots = GameState.current_party.slots

		SignalBus.combat_started.emit(enemy_group, party_slots)
		queue_free()
