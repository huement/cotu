class_name GridDefinitions
extends RefCounted

enum Facing {
    NORTH,
    EAST,
    SOUTH,
    WEST
}

static func facing_to_vec2i(facing: Facing) -> Vector2i:
    match facing:
        Facing.NORTH:
            return Vector2i(0, -1)
        Facing.EAST:
            return Vector2i(1, 0)
        Facing.SOUTH:
            return Vector2i(0, 1)
        Facing.WEST:
            return Vector2i(-1, 0)
        _:
            return Vector2i(0, -1)


static func rotate_left(facing: Facing) -> Facing:
    return wrapi(int(facing) - 1, 0, 4) as Facing

static func rotate_right(facing: Facing) -> Facing:
    return wrapi(int(facing) + 1, 0, 4) as Facing
