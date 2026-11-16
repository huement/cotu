@tool
extends Node3D
## Tall rock with a swappable model (same idea as BigShroom).
## Pick the rock in the Inspector with `stone_type`. Only the chosen model is
## visible and only its collision box is active, so hidden rocks never block movement.
##
## Nodes: StoneA..StoneH (models) and StaticBody3D/StoneACollision..StoneHCollision.
## To add a rock: add an enum entry, a "Stone<X>" model and a "Stone<X>Collision" shape.

enum StoneType {
	TALL_A,
	TALL_B,
	TALL_C,
	TALL_D,
	TALL_E,
	TALL_F,
	TALL_G,
	TALL_H,
}

## Node-name suffix for each StoneType ("A" -> StoneA / StoneACollision).
const STONE_SUFFIXES: Dictionary = {
	StoneType.TALL_A: "A",
	StoneType.TALL_B: "B",
	StoneType.TALL_C: "C",
	StoneType.TALL_D: "D",
	StoneType.TALL_E: "E",
	StoneType.TALL_F: "F",
	StoneType.TALL_G: "G",
	StoneType.TALL_H: "H",
}

@export var stone_type: StoneType = StoneType.TALL_A:
	set(value):
		stone_type = value
		if Engine.is_editor_hint():
			_update_stone()


func _ready() -> void:
	_update_stone()


func _update_stone() -> void:
	if not is_inside_tree():
		return

	for type_key: StoneType in STONE_SUFFIXES:
		var suffix: String = STONE_SUFFIXES[type_key]
		var is_active: bool = type_key == stone_type

		var model: Node3D = get_node_or_null("Stone" + suffix) as Node3D
		if model:
			model.visible = is_active

		var shape: CollisionShape3D = get_node_or_null("StaticBody3D/Stone%sCollision" % suffix) as CollisionShape3D
		if shape:
			shape.set_deferred("disabled", not is_active)
