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

@export var tree_type: TreeType = TreeType.TALL_DARK:
	set(value):
		tree_type = value
		_update_visibility()

func _ready() -> void:
	_update_visibility()

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
