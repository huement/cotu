class_name GridCommand
extends RefCounted

enum Type {
    STEP_FORWARD,
    STEP_BACK,
    MOVE_LEFT,
    MOVE_RIGHT,
    TURN_LEFT,
    TURN_RIGHT,
    ATTACK,
    DEFEND,
    USE_ITEM,
}