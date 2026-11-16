class_name CloudLayer
extends Node3D

## Total number of active clouds to spawn and drift
@export var cloud_count: int = 20

## Area dimensions (X, Y height variance, Z) over which clouds spawn and wrap around
@export var spawn_bounds: Vector3 = Vector3(120.0, 6.0, 120.0)

## Direction and speed of cloud movement per second
@export var wind_velocity: Vector3 = Vector3(1.5, 0.0, 0.5)

## Scale randomization range for visual variety
@export var min_scale: float = 1
@export var max_scale: float = 2

var _clouds: Array[Node3D] = []

func _ready() -> void:
	_initialize_clouds()

func _process(delta: float) -> void:
	_move_clouds(delta)

func _initialize_clouds() -> void:
	var templates: Array[Node3D] = []
	for child in get_children():
		if child is Node3D:
			templates.append(child)
			
	if templates.is_empty():
		return

	# Duplicate template models and scatter them across spawn_bounds
	for i in range(cloud_count):
		var template: Node3D = templates.pick_random()
		var cloud: Node3D = template.duplicate() as Node3D
		add_child(cloud)
		_clouds.append(cloud)
		
		# Set random position, Y-rotation, and scale
		cloud.position = Vector3(
			randf_range(-spawn_bounds.x * 0.5, spawn_bounds.x * 0.5),
			randf_range(-spawn_bounds.y * 0.5, spawn_bounds.y * 0.5),
			randf_range(-spawn_bounds.z * 0.5, spawn_bounds.z * 0.5)
		)
		cloud.rotation.y = randf_range(0.0, TAU)
		
		var s: float = randf_range(min_scale, max_scale)
		cloud.scale = Vector3(s, s, s)

	# Hide original template meshes so they don't remain static at the origin
	for template in templates:
		template.visible = false

func _move_clouds(delta: float) -> void:
	var half_x: float = spawn_bounds.x * 0.5
	var half_z: float = spawn_bounds.z * 0.5

	for cloud in _clouds:
		cloud.position += wind_velocity * delta
		
		# Seamlessly wrap clouds back to the opposite side when exceeding bounds
		if wind_velocity.x > 0.0 and cloud.position.x > half_x:
			cloud.position.x = -half_x
			cloud.position.z = randf_range(-half_z, half_z)
		elif wind_velocity.x < 0.0 and cloud.position.x < -half_x:
			cloud.position.x = half_x
			cloud.position.z = randf_range(-half_z, half_z)

		if wind_velocity.z > 0.0 and cloud.position.z > half_z:
			cloud.position.z = -half_z
			cloud.position.x = randf_range(-half_x, half_x)
		elif wind_velocity.z < 0.0 and cloud.position.z < -half_z:
			cloud.position.z = half_z
			cloud.position.x = randf_range(-half_x, half_x)
