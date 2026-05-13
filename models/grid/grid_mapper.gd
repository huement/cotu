class_name GridMapper
extends RefCounted

static func cell_to_world(cell: Vector2i, cell_size: float, y: float = 0.0) -> Vector3:
    return Vector3(cell.x * cell_size, y, cell.y * cell_size)

static func world_to_cell(pos: Vector3, cell_size: float) -> Vector2i:
    return Vector2i(roundi(pos.x / cell_size), roundi(pos.z / cell_size))