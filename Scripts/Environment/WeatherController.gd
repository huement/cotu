# res://Scripts/Environment/WeatherController.gd
class_name WeatherController
extends Node

const PIXEL_SKY_SHADER: String = "res://Shaders/pixel_sky.gdshader"
const THUNDER_PATHS: Array[String] = [
	"res://Audio/Environment/thunder-1.mp3",
	"res://Audio/Environment/thunder-2.mp3",
	"res://Audio/Environment/thunder-3.mp3",
	"res://Audio/Environment/thunder-4.mp3",
]

@export_group("Scene References")
@export var world_environment: WorldEnvironment = null
@export var day_night_cycle: DayNightCycle = null
@export var rain_overlay: PixelRainOverlay = null

@export_group("Storm Tuning")
@export_range(0.0, 1.0, 0.01) var storm_amount: float = 0.0
@export var storm_front: Vector2 = Vector2(1.0, 0.0)
## Multiplier applied to sun_light energy at full storm (0.25 = 75% dimmer).
@export_range(0.05, 1.0, 0.05) var min_sun_energy_mult: float = 0.25
## Multiplier applied to ambient_light_energy at full storm.
@export_range(0.1, 1.0, 0.05) var min_ambient_energy_mult: float = 0.45
@export var storm_ambient_tint: Color = Color(0.24, 0.30, 0.36, 1.0)
## Matches PixelRainOverlay.storm_rain_threshold — rain bed fades in with the overlay.
@export_range(0.0, 0.9, 0.01) var storm_rain_threshold: float = 0.25

@export_group("Storm Fog")
@export_range(0.0, 0.08, 0.001) var max_storm_fog_density: float = 0.018
@export var storm_fog_color: Color = Color(0.20, 0.25, 0.30, 1.0)

@export_group("Lightning & Thunder")
@export var lightning_enabled: bool = true
## Minimum storm_amount before random lightning bolts begin firing.
@export_range(0.1, 0.9, 0.05) var lightning_threshold: float = 0.35
## Peak DirectionalLight3D energy during a close lightning strike.
@export_range(1.0, 12.0, 0.5) var max_lightning_light_energy: float = 4.5
## Average seconds between strikes at storm_amount = 1.0 (longer when weaker).
@export_range(2.0, 30.0, 0.5) var min_strike_interval: float = 4.5
@export_range(5.0, 60.0, 1.0) var max_strike_interval: float = 16.0
## Optional inspector override; empty = auto-load thunder-1..4 from Audio/Environment/.
@export var thunder_streams: Array[AudioStream] = []

@export_group("Ambient Random Storms")
## When outdoors and clear, occasionally roll a storm in on a random interval.
@export var ambient_storms_enabled: bool = true
@export_range(60.0, 1200.0, 1.0) var ambient_min_interval_sec: float = 180.0
@export_range(120.0, 2400.0, 1.0) var ambient_max_interval_sec: float = 480.0
@export_range(10.0, 90.0, 1.0) var ambient_roll_in_sec: float = 25.0
## How long to hold near full storm before starting to clear.
@export_range(20.0, 300.0, 1.0) var ambient_hold_sec: float = 70.0
@export_range(10.0, 120.0, 1.0) var ambient_clear_sec: float = 40.0

@export_group("First Visit Storm")
## Map id (node name) that gets a one-shot delayed storm on first arrival.
@export var first_visit_storm_map: String = "FeroShaw"
@export var first_visit_storm_object_id: String = "feroshaw_arrival_storm"
@export_range(5.0, 60.0, 0.5) var first_visit_delay_min_sec: float = 10.0
@export_range(5.0, 90.0, 0.5) var first_visit_delay_max_sec: float = 20.0
@export_range(10.0, 90.0, 1.0) var first_visit_roll_in_sec: float = 28.0
@export_range(20.0, 300.0, 1.0) var first_visit_hold_sec: float = 90.0

var _is_outdoor_active: bool = false
var _storm_tween: Tween = null
var _lightning_flash: float = 0.0
var _flash_direction: Vector3 = Vector3(1.0, 0.45, 0.0).normalized()
var _next_strike_timer: float = 5.0
var _echo_timer: float = -1.0
var _pending_echo_intensity: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _storm_serial: int = 0
var _rain_audio_active: bool = false
var _ambient_timer_sec: float = 240.0
var _hold_timer_sec: float = -1.0
var _scripted_storm_pending: bool = false

func _ready() -> void:
	# Execute after DayNightCycle (priority 0) so storm lighting layers cleanly on top
	process_priority = 10
	_rng.randomize()

	if rain_overlay == null:
		rain_overlay = get_node_or_null("%PixelRainOverlay") as PixelRainOverlay

	_ensure_thunder_streams()

	var sb: Node = _get_signal_bus()
	if is_instance_valid(sb):
		if sb.has_signal(&"storm_requested") and not sb.storm_requested.is_connected(roll_in_storm):
			sb.storm_requested.connect(roll_in_storm)
		if sb.has_signal(&"weather_clear_requested") and not sb.weather_clear_requested.is_connected(clear_weather):
			sb.weather_clear_requested.connect(clear_weather)
		if sb.has_signal(&"lightning_flash_requested") and not sb.lightning_flash_requested.is_connected(flash_lightning):
			sb.lightning_flash_requested.connect(flash_lightning)

	if not storm_front.is_zero_approx():
		storm_front = storm_front.normalized()
	if is_instance_valid(rain_overlay):
		rain_overlay.set_storm_front(storm_front)
		storm_rain_threshold = rain_overlay.storm_rain_threshold

	_refresh_outdoor_state()
	_emit_weather_changed()

func _exit_tree() -> void:
	_stop_rain_audio()

func _process(delta: float) -> void:
	_refresh_outdoor_state()
	if not _is_outdoor_active:
		return

	_update_ambient_weather(delta)
	_update_lightning(delta)
	_apply_sky_uniforms()
	_apply_world_lighting()

## Called by MapManager when switching maps so outdoor skies and indoor dungeons stay isolated.
func bind_map_context(env_node: WorldEnvironment, cycle_node: DayNightCycle) -> void:
	world_environment = env_node
	day_night_cycle = cycle_node
	_storm_serial += 1
	_lightning_flash = 0.0
	_echo_timer = -1.0
	_hold_timer_sec = -1.0
	_scripted_storm_pending = false

	_refresh_outdoor_state()
	if _is_outdoor_active:
		_emit_weather_changed()
		_reset_ambient_timer()
		_maybe_schedule_first_visit_storm()
	else:
		# Suppress rain overlay / audio and reset sky parameters while inside dungeons/caves
		_notify_weather(0.0)

## Smoothly transitions storm_amount toward target_amount over duration_sec.
func roll_in_storm(target_amount: float = 1.0, duration_sec: float = 30.0, approach_dir: Vector2 = Vector2.ZERO) -> void:
	var clamped_target: float = clampf(target_amount, 0.0, 1.0)
	if not approach_dir.is_zero_approx():
		storm_front = approach_dir.normalized()
		if is_instance_valid(rain_overlay):
			rain_overlay.set_storm_front(storm_front)
	elif clamped_target > storm_amount + 0.05:
		_pick_random_storm_front()

	if _storm_tween != null and _storm_tween.is_valid():
		_storm_tween.kill()

	if duration_sec <= 0.05:
		_set_storm_amount(clamped_target)
		return

	_storm_tween = create_tween()
	_storm_tween.set_trans(Tween.TRANS_SINE)
	_storm_tween.set_ease(Tween.EASE_IN_OUT)
	_storm_tween.tween_method(_set_storm_amount, storm_amount, clamped_target, duration_sec)

## Gradually clears active storm weather back to 0.0.
func clear_weather(duration_sec: float = 45.0) -> void:
	_hold_timer_sec = -1.0
	roll_in_storm(0.0, duration_sec)

## Triggers an immediate lightning bolt (primary flash + secondary echo + delayed thunder).
func flash_lightning(intensity: float = 1.0) -> void:
	if not _is_outdoor_active:
		return

	var strength: float = clampf(intensity, 0.15, 1.0)
	_lightning_flash = strength

	# Pick a sky vector biased toward the incoming storm front and elevated above the horizon
	var front_2d: Vector2 = storm_front if not storm_front.is_zero_approx() else Vector2(1.0, 0.0)
	var jitter: Vector2 = Vector2(_rng.randf_range(-0.45, 0.45), _rng.randf_range(-0.45, 0.45))
	var horiz: Vector2 = (front_2d + jitter).normalized()
	var elevation: float = _rng.randf_range(0.35, 0.70)
	_flash_direction = Vector3(horiz.x, elevation, horiz.y).normalized()

	# Queue classic double-flash echo
	_echo_timer = _rng.randf_range(0.06, 0.14)
	_pending_echo_intensity = strength * _rng.randf_range(0.45, 0.65)

	# Close strikes trigger camera trauma and shorter thunder delay
	var sb: Node = _get_signal_bus()
	if strength > 0.65 and is_instance_valid(sb) and sb.has_signal(&"camera_shake_requested"):
		var trauma: float = lerpf(0.25, 0.65, (strength - 0.65) / 0.35)
		sb.camera_shake_requested.emit(trauma)

	var thunder_delay: float = lerpf(1.5, 0.2, strength)
	_schedule_thunder(thunder_delay, strength)

func _set_storm_amount(value: float) -> void:
	var prev: float = storm_amount
	storm_amount = clampf(value, 0.0, 1.0)
	if not is_equal_approx(prev, storm_amount):
		_emit_weather_changed()

func _emit_weather_changed() -> void:
	_notify_weather(_get_effective_storm())

func _notify_weather(effective_storm: float) -> void:
	var sb: Node = _get_signal_bus()
	if is_instance_valid(sb) and sb.has_signal(&"weather_changed"):
		sb.weather_changed.emit(effective_storm)
	_sync_rain_audio(effective_storm)

func _get_effective_storm() -> float:
	return storm_amount if _is_outdoor_active else 0.0

func _rain_amount_from_storm(effective_storm: float) -> float:
	var threshold: float = storm_rain_threshold
	if is_instance_valid(rain_overlay):
		threshold = rain_overlay.storm_rain_threshold
	var denom: float = maxf(0.001, 1.0 - threshold)
	return clampf((effective_storm - threshold) / denom, 0.0, 1.0)

func _sync_rain_audio(effective_storm: float) -> void:
	var rain_amt: float = _rain_amount_from_storm(effective_storm)
	if not is_instance_valid(AudioManager):
		return
	if rain_amt > 0.001:
		AudioManager.start_rain_loop(rain_amt)
		_rain_audio_active = true
	elif _rain_audio_active:
		_stop_rain_audio()

func _stop_rain_audio() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.stop_rain_loop()
	_rain_audio_active = false

func _ensure_thunder_streams() -> void:
	if not thunder_streams.is_empty():
		return
	for path: String in THUNDER_PATHS:
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path) as AudioStream
			if stream != null:
				thunder_streams.append(stream)

func _refresh_outdoor_state() -> void:
	var sky_mat: ShaderMaterial = _get_pixel_sky_material()
	var was_outdoor: bool = _is_outdoor_active
	_is_outdoor_active = (sky_mat != null and is_instance_valid(day_night_cycle))
	if was_outdoor and not _is_outdoor_active:
		_hold_timer_sec = -1.0
		_scripted_storm_pending = false
		_notify_weather(0.0)

func _reset_ambient_timer() -> void:
	var lo: float = minf(ambient_min_interval_sec, ambient_max_interval_sec)
	var hi: float = maxf(ambient_min_interval_sec, ambient_max_interval_sec)
	_ambient_timer_sec = _rng.randf_range(lo, hi)

func _pick_random_storm_front() -> void:
	var dir: Vector2 = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
	if dir.is_zero_approx():
		dir = Vector2(1.0, 0.0)
	storm_front = dir.normalized()
	if is_instance_valid(rain_overlay):
		rain_overlay.set_storm_front(storm_front)

func _is_storm_busy() -> bool:
	if _scripted_storm_pending:
		return true
	if storm_amount > 0.05:
		return true
	if _storm_tween != null and _storm_tween.is_valid():
		return true
	if _hold_timer_sec > 0.0:
		return true
	return false

func _begin_timed_storm(target_amount: float, roll_in_sec: float, hold_sec: float) -> void:
	_pick_random_storm_front()
	roll_in_storm(target_amount, roll_in_sec, storm_front)
	_hold_timer_sec = maxf(0.1, roll_in_sec + hold_sec)

func _maybe_schedule_first_visit_storm() -> void:
	if first_visit_storm_map.is_empty():
		return
	if not is_instance_valid(GameState) or not GameState.has_method("get_current_map_id"):
		return
	var map_id: String = GameState.get_current_map_id()
	if map_id != first_visit_storm_map:
		return
	var state: Dictionary = {}
	if GameState.has_method("get_object_state"):
		state = GameState.get_object_state(map_id, first_visit_storm_object_id) as Dictionary
	if bool(state.get("fired", false)):
		return

	_scripted_storm_pending = true
	var delay_lo: float = minf(first_visit_delay_min_sec, first_visit_delay_max_sec)
	var delay_hi: float = maxf(first_visit_delay_min_sec, first_visit_delay_max_sec)
	var delay_sec: float = _rng.randf_range(delay_lo, delay_hi)
	var serial_snapshot: int = _storm_serial
	var timer: SceneTreeTimer = get_tree().create_timer(delay_sec)
	timer.timeout.connect(func() -> void:
		if serial_snapshot != _storm_serial or not _is_outdoor_active:
			_scripted_storm_pending = false
			return
		if is_instance_valid(GameState) and GameState.has_method("set_object_state_flag"):
			GameState.set_object_state_flag(map_id, first_visit_storm_object_id, "fired", true)
		_scripted_storm_pending = false
		_begin_timed_storm(1.0, first_visit_roll_in_sec, first_visit_hold_sec)
	)

func _update_ambient_weather(delta: float) -> void:
	# Hold a storm for a while, then clear and restart the random interval.
	if _hold_timer_sec > 0.0:
		_hold_timer_sec -= delta
		if _hold_timer_sec <= 0.0:
			_hold_timer_sec = -1.0
			clear_weather(ambient_clear_sec)
			_reset_ambient_timer()
		return

	if not ambient_storms_enabled:
		return
	if _is_storm_busy():
		return

	_ambient_timer_sec -= delta
	if _ambient_timer_sec > 0.0:
		return

	var intensity: float = _rng.randf_range(0.75, 1.0)
	_begin_timed_storm(intensity, ambient_roll_in_sec, ambient_hold_sec)

func _update_lightning(delta: float) -> void:
	# Decay active flash sharply for crisp retro lightning frames
	if _lightning_flash > 0.0:
		_lightning_flash = maxf(0.0, _lightning_flash - delta * 11.0)

	# Trigger secondary echo flash
	if _echo_timer > 0.0:
		_echo_timer -= delta
		if _echo_timer <= 0.0:
			_echo_timer = -1.0
			_lightning_flash = maxf(_lightning_flash, _pending_echo_intensity)

	if not lightning_enabled or storm_amount < lightning_threshold:
		return

	_next_strike_timer -= delta
	if _next_strike_timer <= 0.0:
		var norm: float = clampf((storm_amount - lightning_threshold) / maxf(0.001, 1.0 - lightning_threshold), 0.0, 1.0)
		var closeness: float = _rng.randf_range(0.3, lerpf(0.55, 1.0, norm))
		flash_lightning(closeness)
		var base_interval: float = lerpf(max_strike_interval, min_strike_interval, norm)
		_next_strike_timer = base_interval * _rng.randf_range(0.65, 1.45)

func _apply_sky_uniforms() -> void:
	var sky_mat: ShaderMaterial = _get_pixel_sky_material()
	if sky_mat == null:
		return

	sky_mat.set_shader_parameter(&"storm_amount", storm_amount)
	sky_mat.set_shader_parameter(&"storm_front", storm_front)
	sky_mat.set_shader_parameter(&"lightning_flash", _lightning_flash)

func _apply_world_lighting() -> void:
	if storm_amount <= 0.001 and _lightning_flash <= 0.001:
		return

	var sun: DirectionalLight3D = day_night_cycle.sun_light if is_instance_valid(day_night_cycle) else null
	if is_instance_valid(sun):
		# Dim orbital sunlight under storm clouds
		var sun_mult: float = lerpf(1.0, min_sun_energy_mult, storm_amount)
		sun.light_energy *= sun_mult

		# Temporarily aim DirectionalLight3D from the sky flash vector during lightning frames
		if _lightning_flash > 0.01:
			sun.global_position = _flash_direction * 200.0
			sun.look_at(Vector3.ZERO, Vector3.UP)
			sun.light_energy = maxf(sun.light_energy, _lightning_flash * max_lightning_light_energy)

	if not is_instance_valid(world_environment) or world_environment.environment == null:
		return

	var env: Environment = world_environment.environment
	var ambient_mult: float = lerpf(1.0, min_ambient_energy_mult, storm_amount)
	env.ambient_light_color = env.ambient_light_color.lerp(storm_ambient_tint, storm_amount * 0.65)
	env.ambient_light_energy *= ambient_mult

	if _lightning_flash > 0.01:
		env.ambient_light_color = env.ambient_light_color.lerp(Color(0.75, 0.85, 1.0, 1.0), _lightning_flash * 0.45)
		env.ambient_light_energy += _lightning_flash * 0.55

	# Layer storm depth fog cleanly on top of any map baseline fog (such as FeroShaw)
	if storm_amount > 0.01 and max_storm_fog_density > 0.0:
		var added_fog: float = max_storm_fog_density * smoothstep(0.15, 1.0, storm_amount)
		var base_density: float = env.fog_density if env.fog_enabled else 0.0
		env.fog_enabled = true
		env.fog_density = maxf(base_density, base_density * 0.5 + added_fog)
		env.fog_light_color = env.fog_light_color.lerp(storm_fog_color, storm_amount * 0.75)

func _schedule_thunder(delay_sec: float, strength: float) -> void:
	var serial_snapshot: int = _storm_serial
	var timer: SceneTreeTimer = get_tree().create_timer(delay_sec)
	timer.timeout.connect(func() -> void:
		if serial_snapshot != _storm_serial or not _is_outdoor_active:
			return
		_play_thunder_sfx(strength)
	)

func _play_thunder_sfx(strength: float) -> void:
	if not is_instance_valid(AudioManager):
		return
	var volume_db: float = lerpf(-10.0, 0.0, strength)
	var pitch: float = _rng.randf_range(0.88, 1.08)
	AudioManager.play_thunder(volume_db, pitch, thunder_streams)

func _get_pixel_sky_material() -> ShaderMaterial:
	if not is_instance_valid(world_environment) or world_environment.environment == null:
		return null
	var env: Environment = world_environment.environment
	if env.sky == null or not (env.sky.sky_material is ShaderMaterial):
		return null
	var mat: ShaderMaterial = env.sky.sky_material as ShaderMaterial
	if mat.shader == null or mat.shader.resource_path != PIXEL_SKY_SHADER:
		return null
	return mat

func _get_signal_bus() -> Node:
	return SignalBus if is_instance_valid(SignalBus) else get_node_or_null("/root/SignalBus")
