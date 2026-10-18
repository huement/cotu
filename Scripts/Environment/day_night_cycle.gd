class_name DayNightCycle
extends Node3D

## Total real-world seconds for one full 24-hour cycle
@export var day_duration: float = 120.0

## Time of day from 0.0 (Midnight), 0.25 (Sunrise), 0.5 (Noon), to 0.75 (Sunset)
@export_range(0.0, 1.0) var time_of_day: float = 0.25

@export_group("Node References")
@export var sun_light: DirectionalLight3D
@export var moon_light: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var moon_mesh_node: Node3D

@export_group("Moon Adjustments")
## Orbit radius distance for celestial positions
@export var orbit_distance: float = 200.0
## Self-glow intensity for moon surface details at night (0.2 to 0.5 is ideal)
@export_range(0.0, 2.0) var moon_emission_energy: float = 0.35
## Extra rotational offset (in degrees) to face the moon's detailed side toward camera
@export var moon_rotation_degrees: Vector3 = Vector3.ZERO

@export_group("Ambient Colors")
@export var day_ambient: Color = Color(0.62, 1.0, 0.85, 1.0)
@export var night_ambient: Color = Color(0.04, 0.06, 0.12, 1.0)

signal time_changed(current_time: float)
signal period_changed(is_night: bool)
signal period_name_changed(period_name: String)

var is_night: bool = false
var current_period: String = ""

func _ready() -> void:
	_setup_moon_material()
	_update_cycle()

func _process(delta: float) -> void:
	if day_duration <= 0.0:
		return

	time_of_day += delta / day_duration
	if time_of_day >= 1.0:
		time_of_day -= 1.0

	_update_cycle()

func _update_cycle() -> void:
	# Calculate 24-hour angle (0.0 = Midnight, 0.25 = Sunrise, 0.50 = Noon, 0.75 = Sunset)
	var angle: float = time_of_day * TAU

	# Position vectors for Sun and Moon (opposite sides of a 3D orbit)
	var sun_pos: Vector3 = Vector3(
		0.0,
		-orbit_distance * cos(angle),
		orbit_distance * sin(angle)
	)
	var moon_pos: Vector3 = -sun_pos

	# Factor: +1.0 at Noon, -1.0 at Midnight
	var sun_factor: float = -cos(angle)
	var day_factor: float = clampf((sun_factor + 0.1) * 2.5, 0.0, 1.0)

	# Update Sun Light
	if sun_light:
		sun_light.global_position = sun_pos
		if not sun_pos.is_zero_approx():
			sun_light.look_at(Vector3.ZERO, Vector3.UP)
		sun_light.light_energy = clampf(sun_factor * 1.5, 0.0, 1.2)

	# Update Moon Light
	if moon_light:
		moon_light.global_position = moon_pos
		if not moon_pos.is_zero_approx():
			moon_light.look_at(Vector3.ZERO, Vector3.UP)
		moon_light.light_energy = clampf(-sun_factor * 0.8, 0.0, 0.6)

	# Update Moon Mesh Model
	if moon_mesh_node:
		moon_mesh_node.global_position = moon_pos
		if not moon_pos.is_zero_approx():
			moon_mesh_node.look_at(Vector3.ZERO, Vector3.UP)
			moon_mesh_node.rotate_object_local(Vector3.RIGHT, deg_to_rad(moon_rotation_degrees.x))
			moon_mesh_node.rotate_object_local(Vector3.UP, deg_to_rad(moon_rotation_degrees.y))
			moon_mesh_node.rotate_object_local(Vector3.FORWARD, deg_to_rad(moon_rotation_degrees.z))
		
		# Hide moon completely when below horizon to eliminate "black orb" during day
		moon_mesh_node.visible = (moon_pos.y > -10.0)

	# Update World Environment (Skybox & Lighting)
	if world_environment and world_environment.environment:
		var env: Environment = world_environment.environment
		
		env.background_energy_multiplier = lerpf(0.02, 1.0, day_factor)
		
		var current_ambient: Color = night_ambient.lerp(day_ambient, day_factor)
		env.ambient_light_color = current_ambient
		env.ambient_light_energy = lerpf(0.08, 1.0, day_factor)
		
		if env.volumetric_fog_enabled:
			env.volumetric_fog_albedo = current_ambient * 0.5
			env.volumetric_fog_emission = Color.BLACK.lerp(Color(0.15, 0.25, 0.25), day_factor)
			env.volumetric_fog_density = lerpf(0.03, 0.01, day_factor)

	# Day/Night State Tracking [useful for enemies that only come out at night]
	var new_is_night: bool = sun_factor < 0.0
	if new_is_night != is_night:
		is_night = new_is_night
		period_changed.emit(is_night)
		
		var sb: Node = SignalBus if is_instance_valid(SignalBus) else get_node_or_null("/root/SignalBus")
		if is_instance_valid(sb) and sb.has_signal(&"day_night_changed"):
			sb.day_night_changed.emit(is_night)

	# Period Tracking
	var new_period: String = _calculate_period_name(time_of_day)
	if new_period != current_period:
		current_period = new_period
		period_name_changed.emit(current_period)
		
		var game_state: Node = get_node_or_null("/root/GameState")
		if is_instance_valid(game_state):
			game_state.set("current_time_period", current_period)

	time_changed.emit(time_of_day)

func _calculate_period_name(t: float) -> String:
	if t >= 0.20 and t < 0.35:
		return "MORNING"
	elif t >= 0.35 and t < 0.65:
		return "DAY"
	elif t >= 0.65 and t < 0.80:
		return "EVENING"
	else:
		return "NIGHT"

## Tunes moon materials to retain GLB textures while glowing gently at night
func _setup_moon_material() -> void:
	if not moon_mesh_node:
		return
	_apply_glow_to_materials(moon_mesh_node)

func _apply_glow_to_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst: MeshInstance3D = node as MeshInstance3D
		for i in range(mesh_inst.get_surface_override_material_count()):
			var mat: Material = mesh_inst.get_active_material(i)
			if mat is StandardMaterial3D:
				var std_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
				std_mat.emission_enabled = true
				std_mat.emission = Color(0.8, 0.85, 0.95)
				std_mat.emission_energy_multiplier = moon_emission_energy
				mesh_inst.set_surface_override_material(i, std_mat)
	
	for child in node.get_children():
		_apply_glow_to_materials(child)
