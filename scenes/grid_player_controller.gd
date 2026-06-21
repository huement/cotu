extends Node3D

## Grid step size matching your 3D tile asset dimensions (e.g., 3 meters per tile)
const TILE_SIZE: float = 3.0
const TWEEN_TIME: float = 0.25

@onready var camera: Camera3D = $Camera3D
@onready var wall_check: RayCast3D = $WallCheck

## Tracks movement state to prevent input spamming mid-transition
var is_moving: bool = false

## Wizardry Heading Map (Using standard 3D coordinate space)
## Forward in Godot is -Z (North), +Z is South, -X is West, +X is East
var compass_direction: Vector3 = Vector3.FORWARD

func _ready() -> void:
	# Snaps the player to the nearest clean grid integer on start
	position = position.snapped(Vector3(TILE_SIZE, TILE_SIZE, TILE_SIZE))
	_update_raycast_orientation()
	print("Space Cat Squad deployed at grid position: ", position / TILE_SIZE)

func _unhandled_input(event: InputEvent) -> void:
	if is_moving:
		return
		
	if event.is_action_pressed("move_forward"):
		_try_move(compass_direction)
	elif event.is_action_pressed("move_backward"):
		_try_move(-compass_direction)
	elif event.is_action_pressed("turn_left"):
		_try_rotate(90.0)
	elif event.is_action_pressed("turn_right"):
		_try_rotate(-90.0)

## Validates physics paths before executing tweens
func _try_move(direction: Vector3) -> void:
	# Update raycast direction relative to our target movement path
	wall_check.target_position = direction.normalized() * TILE_SIZE
	wall_check.force_raycast_update()
	
	if wall_check.is_colliding():
		SignalBus.game_log_emitted.emit("Ouch! You bumped your snout against a bulkhead.")
		return
		
	# Execute smooth tile interpolation
	is_moving = true
	var target_pos: Vector3 = position + (direction * TILE_SIZE)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", target_pos, TWEEN_TIME)
	tween.finished.connect(func(): is_moving = false)

## Smooth 90-degree camera panning rotations
func _try_rotate(angle_degrees: float) -> void:
	is_moving = true
	var target_rotation: float = rotation.y + deg_to_rad(angle_degrees)
	
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", target_rotation, TWEEN_TIME)
	tween.finished.connect(func():
		is_moving = false
		# Dynamically recalculate our new forward compass heading vector
		compass_direction = -transform.basis.z.normalized()
		_update_raycast_orientation()
	)

func _update_raycast_orientation() -> void:
	# Keep the raycast locked forward relative to the current local look-vector
	wall_check.target_position = Vector3.FORWARD * TILE_SIZE
