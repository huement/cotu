@tool
extends Node3D

## Number of trees to spawn FOR EACH tree type (e.g. 2 = 2 Oaks + 2 Pines = 4 total per cell)
@export var tree_count_per_type: int = 2:
	set(value):
		tree_count_per_type = value
		if is_inside_tree():
			generate_trees()

@export var grid_size: float = 2.0:
	set(value):
		grid_size = value
		if is_inside_tree():
			generate_trees()

## Minimum and maximum scale multiplier for tree models
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
	var child_count: int = 0
	
	for child in get_children():
		if child is MultiMeshInstance3D and child.multimesh and child.multimesh.mesh:
			_scatter_multimesh(child)
			child_count += 1

func _scatter_multimesh(mmi: MultiMeshInstance3D) -> void:
	mmi.multimesh.instance_count = tree_count_per_type
	
	for i in range(tree_count_per_type):
		var pos_x: float = randf_range(-grid_size / 2.0, grid_size / 2.0)
		var pos_z: float = randf_range(-grid_size / 2.0, grid_size / 2.0)
		var pos: Vector3 = Vector3(pos_x, 0.0, pos_z)
		
		var rot_y: float = randf_range(0.0, TAU)
		var scale_rand: float = randf_range(tree_scale_min, tree_scale_max)
		
		var t: Transform3D = Transform3D.IDENTITY
		t = t.scaled(Vector3(scale_rand, scale_rand, scale_rand))
		t = t.rotated(Vector3.UP, rot_y)
		t.origin = pos
		
		mmi.multimesh.set_instance_transform(i, t)
