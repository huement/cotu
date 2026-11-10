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
	var tree_nodes: Dictionary = {
		TreeType.TALL_DARK: get_node_or_null("tree_tall_dark"),
		TreeType.PLATEAU_DARK: get_node_or_null("tree_plateau_dark"),
		TreeType.PINE_TALL: get_node_or_null("tree_pine_tall"),
		TreeType.PINE_ROUND: get_node_or_null("tree_pine_round"),
		TreeType.PINE_GROUND: get_node_or_null("tree_pine_ground"),
		TreeType.OAK_FALL: get_node_or_null("tree_oak_fall"),
		TreeType.OAK_DARK: get_node_or_null("tree_oak_dark"),
		TreeType.DETAILED_DARK: get_node_or_null("tree_detailed_dark"),
		TreeType.CONE: get_node_or_null("tree_cone")
	}

	for type_key: TreeType in tree_nodes:
		var node: Node3D = tree_nodes[type_key]
		if node:
			node.visible = (type_key == tree_type)
