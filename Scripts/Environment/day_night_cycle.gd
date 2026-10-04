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

@export_group("Ambient Colors")
@export var day_ambient: Color = Color(0.62, 1.0, 0.85, 1.0)
@export var night_ambient: Color = Color(0.08, 0.12, 0.22, 1.0)

signal time_changed(current_time: float)
signal period_changed(is_night: bool)

var is_night: bool = false

func _process(delta: float) -> void:
	if day_duration <= 0.0:
		return

	# Advance time_of_day (0.0 to 1.0)
	time_of_day += delta / day_duration
	if time_of_day >= 1.0:
		time_of_day -= 1.0

	_update_cycle()

func _update_cycle() -> void:
	# Convert time_of_day to radians (0.25 = Sunrise, 0.5 = Noon, 0.75 = Sunset)
	var angle: float = time_of_day * TAU
	var sun_factor: float = sin(angle) # > 0 during day, < 0 during night

	# Rotate Sun and Moon (opposite positions)
	if sun_light:
		sun_light.rotation.x = -angle
		sun_light.light_energy = clampf(sun_factor * 1.5, 0.0, 1.2)

	if moon_light:
		moon_light.rotation.x = -angle + PI
		moon_light.light_energy = clampf(-sun_factor * 1.2, 0.0, 0.6)

	# Track Day/Night state change
	var new_is_night: bool = sun_factor < 0.0
	if new_is_night != is_night:
		is_night = new_is_night
		period_changed.emit(is_night)

	# Transition Ambient Light & Volumetric Fog
	if world_environment and world_environment.environment:
		var env: Environment = world_environment.environment
		var blend: float = clampf((sun_factor + 0.2) * 2.0, 0.0, 1.0)
		var current_ambient: Color = night_ambient.lerp(day_ambient, blend)
		
		env.ambient_light_color = current_ambient
		if env.volumetric_fog_enabled:
			env.volumetric_fog_albedo = current_ambient * 0.6

	time_changed.emit(time_of_day)