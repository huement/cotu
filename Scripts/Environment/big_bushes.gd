@tool
extends Node3D
## Marsh bush with a swappable model (same idea as BigShroom / AllTimber).
## Pick the model in the Inspector with `bush_type`; only that one is shown.
## One shared collision cylinder (StaticBody3D) blocks the grid cell, like AllTimber.
## To add a model: add an enum entry, instance the .glb as a child, add it to the map below.

enum BushType {
	LARGE,
	WITH_FLOWERS,
	MEDIUM,
	CLUMPS_MEDIUM,
}

@export var bush_type: BushType = BushType.LARGE:
	set(value):
		bush_type = value
		if Engine.is_editor_hint():
			_update_visibility()


func _ready() -> void:
	_update_visibility()


func _update_visibility() -> void:
	if not is_inside_tree():
		return

	var model_nodes: Dictionary = {
		BushType.LARGE: get_node_or_null("BushLarge"),
		BushType.WITH_FLOWERS: get_node_or_null("BushFlowers"),
		BushType.MEDIUM: get_node_or_null("BushMedium"),
		BushType.CLUMPS_MEDIUM: get_node_or_null("BushClumps"),
	}

	for type_key: BushType in model_nodes:
		var node: Node3D = model_nodes[type_key] as Node3D
		if node:
			node.visible = (type_key == bush_type)
