@tool
extends Node3D

enum MushroomType {
	RED,
	GROUP,
	TALL,
	TAN,
	TGROUP
}

@export var mushroom_type: MushroomType = MushroomType.RED:
	set(value):
		mushroom_type = value
		if Engine.is_editor_hint():
			_update_visibility()

func _ready() -> void:
	_update_visibility()

func _update_visibility() -> void:
	if not is_inside_tree():
		return

	var mushroom_nodes: Dictionary = {
		MushroomType.RED: get_node_or_null("RedModel"),
		MushroomType.GROUP: get_node_or_null("GroupModel"),
		MushroomType.TALL: get_node_or_null("TallModel"),
		MushroomType.TAN: get_node_or_null("TanModel"),
		MushroomType.TGROUP: get_node_or_null("TGroupModel")
	}

	for type_key: MushroomType in mushroom_nodes:
		var node: Node3D = mushroom_nodes[type_key]
		if node:
			node.visible = (type_key == mushroom_type)