class_name GridDefinitions
extends RefCounted

## Cardinal headings mapped to standard 2D grid coordinates
enum Facing {
	NORTH = 0,
	EAST = 1,
	SOUTH = 2,
	WEST = 3
}

## Converts a cardinal Facing enum into a 2D Grid Vector
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
	return Vector2i.ZERO

## Calculates a 90-degree right turn heading
static func rotate_right(facing: Facing) -> Facing:
	return posmod(facing + 1, 4) as Facing

## Calculates a 90-degree left turn heading
static func rotate_left(facing: Facing) -> Facing:
	return posmod(facing - 1, 4) as Facing
