class_name GridState
extends Resource

@export var cell: Vector2i
@export var facing: GridDefinitions.Facing

func _init(start_cell: Vector2i = Vector2i.ZERO, start_facing: GridDefinitions.Facing = GridDefinitions.Facing.NORTH) -> void:
	cell = start_cell
	facing = start_facing
