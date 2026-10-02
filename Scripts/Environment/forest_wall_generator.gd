@tool
extends MultiMeshInstance3D

@export var tree_mesh_pool: Array[Mesh] = []

@export var tree_count: int = 4:
	set(value):
		tree_count = value
		if is_inside_tree():
			generate_trees()

@export var grid_size: float = 2.0:
	set(value):
		grid_size = value
		if is_inside_tree():
			generate_trees()

@export var tree_scale_min: float = 3.0:
	set(value):
		tree_scale_min = value
		if is_inside_tree():
			generate_trees()

@export var tree_scale_max: float = 4.5:
	set(value):
		tree_scale_max = value
		if is_inside_tree():
			generate_trees()

@export var generate: bool = false:
	set(value):
		generate = value
		if value and is_inside_tree():
			generate_trees()

func _ready() -> void:
	generate_trees()

func generate_trees() -> void:
	if not multimesh:
		return
		
	if tree_mesh_pool.size() > 0:
		multimesh.mesh = tree_mesh_pool.pick_random()
		
	if not multimesh.mesh:
		return
		
	multimesh.instance_count = tree_count
	
	for i in range(tree_count):
		var pos_x: float = randf_range(-grid_size / 2.0, grid_size / 2.0)
		var pos_z: float = randf_range(-grid_size / 2.0, grid_size / 2.0)
		var pos: Vector3 = Vector3(pos_x, 0.0, pos_z)
		
		var rot_y: float = randf_range(0.0, TAU)
		var scale_rand: float = randf_range(tree_scale_min, tree_scale_max)
		
		var t: Transform3D = Transform3D.IDENTITY
		t = t.scaled(Vector3(scale_rand, scale_rand, scale_rand))
		t = t.rotated(Vector3.UP, rot_y)
		t.origin = pos
		
		multimesh.set_instance_transform(i, t)
