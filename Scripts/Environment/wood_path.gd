@tool
extends Node3D

enum WoodType {
	STRAIGHT,
	CORNER,
	END
}

@export var type: WoodType = WoodType.STRAIGHT:
	set(value):
		type = value
		_update_visibility()

func _ready() -> void:
	_update_visibility()

func _update_visibility() -> void:
	var path_wood: Node3D = get_node_or_null("%path_wood")
	var path_wood_corner: Node3D = get_node_or_null("%path_wood_corner")
	var path_wood_end: Node3D = get_node_or_null("%path_wood_end")

	if path_wood:
		path_wood.visible = (type == WoodType.STRAIGHT)
	if path_wood_corner:
		path_wood_corner.visible = (type == WoodType.CORNER)
	if path_wood_end:
		path_wood_end.visible = (type == WoodType.END)
