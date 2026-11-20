@tool
extends Node3D

enum TreeType {
	TALL_DARK,
	PLATEAU_DARK,
	PINE_TALL,
	PINE_ROUND,
	PINE_GROUND,
	OAK_FALL,
	OAK_DARK,
	DETAILED_DARK,
	CONE
}

## World-space trunk radius used for movement blocking (ignores visual scale).
@export var collision_radius: float = 0.7

@export var tree_type: TreeType = TreeType.TALL_DARK:
	set(value):
		tree_type = value
		_update_visibility()

func _ready() -> void:
	_update_visibility()
	_normalize_collision_scale()

func _normalize_collision_scale() -> void:
	# Visual meshes are often scaled 2–3x on the root; if the StaticBody inherits that,
	# a 0.8 radius cylinder becomes a multi-cell invisible wall. Keep collision in world units.
	var body: StaticBody3D = get_node_or_null("StaticBody3D") as StaticBody3D
	if body == null:
		return
	var shape_node: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		return

	var parent_scale: Vector3 = global_transform.basis.get_scale()
	var safe_x: float = parent_scale.x if absf(parent_scale.x) > 0.001 else 1.0
	var safe_y: float = parent_scale.y if absf(parent_scale.y) > 0.001 else 1.0
	var safe_z: float = parent_scale.z if absf(parent_scale.z) > 0.001 else 1.0
	shape_node.scale = Vector3(1.0 / safe_x, 1.0 / safe_y, 1.0 / safe_z)

	var cylinder: CylinderShape3D = shape_node.shape as CylinderShape3D
	if cylinder != null:
		var unique_shape: CylinderShape3D = cylinder.duplicate() as CylinderShape3D
		unique_shape.radius = collision_radius
		shape_node.shape = unique_shape

func _update_visibility() -> void:
	# The old nine Kenney shapes collapse onto three pixel meshes. The enum
	# values stay so maps that already picked a tree_type do not move.
	var mesh_for_type: Dictionary = {
		TreeType.TALL_DARK: "tree_pine",
		TreeType.PINE_TALL: "tree_pine",
		TreeType.DETAILED_DARK: "tree_pine",
		TreeType.CONE: "tree_pine",
		TreeType.PLATEAU_DARK: "tree_oak",
		TreeType.PINE_ROUND: "tree_oak",
		TreeType.OAK_FALL: "tree_oak",
		TreeType.OAK_DARK: "tree_oak",
		TreeType.PINE_GROUND: "tree_bush",
	}
	var shown: String = str(mesh_for_type.get(tree_type, "tree_pine"))
	for node_name: String in ["tree_pine", "tree_oak", "tree_bush"]:
		var node: Node3D = get_node_or_null(node_name) as Node3D
		if node:
			node.visible = node.name == shown
