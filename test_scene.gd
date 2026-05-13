extends Node

func _physics_process(_delta: float) -> void:
    if Input.is_action_just_pressed("move_forward"):
        print("Move forward")
    if Input.is_action_just_pressed("move_back"):
        print("Move backward")
    if Input.is_action_just_pressed("move_left"):
        print("Move left")
    if Input.is_action_just_pressed("move_right"):
        print("Move right")
    if Input.is_action_just_pressed("turn_left"):
        print("Turn left")
    if Input.is_action_just_pressed("turn_right"):
        print("Turn right")