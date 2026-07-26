class_name GridCommand
extends RefCounted

## Enumeration of all discrete grid actions for exploration and combat
enum Type {
	NONE = -1,
	STEP_FORWARD,
	STEP_BACK,
	MOVE_LEFT,
	MOVE_RIGHT,
	TURN_LEFT,
	TURN_RIGHT,
	ATTACK,
	CAST_SPELL,
	WAIT
}
