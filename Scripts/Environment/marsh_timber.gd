@tool
extends Node3D
## Marsh tree with a swappable model (same idea as AllTimber).
## Pick the model in the Inspector with `tree_type`; only that one is shown.
## One shared collision cylinder (StaticBody3D) blocks the grid cell, like AllTimber.
## To add a model: add an enum entry, instance the .glb as a child, add it to the map below.

enum TreeType {
	ELM_GREEN,
	MAPLE_RED,
	OAK_LARGE_GREEN,
	OAK_MEDIUM_GREEN,
	PARK_LARGE_GREEN,
	SIMPLE_LARGE,
	WINDSWEPT_DARK_GREEN,
}

@export var tree_type: TreeType = TreeType.ELM_GREEN:
	set(value):
		tree_type = value
		if Engine.is_editor_hint():
			_update_visibility()


func _ready() -> void:
	_update_visibility()


func _update_visibility() -> void:
	if not is_inside_tree():
		return

	var model_nodes: Dictionary = {
		TreeType.ELM_GREEN: get_node_or_null("TreeElm"),
		TreeType.MAPLE_RED: get_node_or_null("TreeMaple"),
		TreeType.OAK_LARGE_GREEN: get_node_or_null("TreeOakLarge"),
		TreeType.OAK_MEDIUM_GREEN: get_node_or_null("TreeOakMedium"),
		TreeType.PARK_LARGE_GREEN: get_node_or_null("TreePark"),
		TreeType.SIMPLE_LARGE: get_node_or_null("TreeSimple"),
		TreeType.WINDSWEPT_DARK_GREEN: get_node_or_null("TreeWindswept"),
	}

	for type_key: TreeType in model_nodes:
		var node: Node3D = model_nodes[type_key] as Node3D
		if node:
			node.visible = (type_key == tree_type)
