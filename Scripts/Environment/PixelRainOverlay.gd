# res://Scripts/Environment/PixelRainOverlay.gd
class_name PixelRainOverlay
extends CanvasLayer

const RAIN_SHADER_PATH: String = "res://Shaders/pixel_rain.gdshader"

@export var overlay_layer: int = 85
@export var storm_rain_threshold: float = 0.25
@export var max_wind_slant: float = 0.45

var _rain_rect: ColorRect = null
var _rain_material: ShaderMaterial = null
var _current_rain_amount: float = 0.0
var _storm_front: Vector2 = Vector2(1.0, 0.0)

func _ready() -> void:
	layer = overlay_layer
	_setup_overlay()

	var sb: Node = SignalBus if is_instance_valid(SignalBus) else get_node_or_null("/root/SignalBus")
	if is_instance_valid(sb) and sb.has_signal(&"weather_changed"):
		if not sb.weather_changed.is_connected(_on_weather_changed):
			sb.weather_changed.connect(_on_weather_changed)

func _process(_delta: float) -> void:
	if _current_rain_amount <= 0.001 or _rain_material == null:
		return

	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return

	# Project 2D storm approach vector onto camera's local X axis so 90° turns shift wind slant naturally
	var front_3d: Vector3 = Vector3(_storm_front.x, 0.0, _storm_front.y).normalized()
	var lateral_wind: float = -cam.global_basis.x.dot(front_3d)
	var slant: float = lateral_wind * max_wind_slant * lerpf(0.35, 1.0, _current_rain_amount)
	_rain_material.set_shader_parameter(&"wind_slant", slant)

func set_storm_front(front: Vector2) -> void:
	if not front.is_zero_approx():
		_storm_front = front.normalized()

func _setup_overlay() -> void:
	_rain_rect = get_node_or_null("RainColorRect") as ColorRect
	if _rain_rect == null:
		_rain_rect = ColorRect.new()
		_rain_rect.name = "RainColorRect"
		_rain_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_rain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rain_rect.color = Color.WHITE
		add_child(_rain_rect)

	var shader: Shader = load(RAIN_SHADER_PATH) as Shader
	if shader != null:
		_rain_material = ShaderMaterial.new()
		_rain_material.shader = shader
		_rain_material.set_shader_parameter(&"rain_amount", 0.0)
		_rain_rect.material = _rain_material

	_rain_rect.visible = false

func _on_weather_changed(storm_amount: float) -> void:
	var denom: float = maxf(0.001, 1.0 - storm_rain_threshold)
	_current_rain_amount = clampf((storm_amount - storm_rain_threshold) / denom, 0.0, 1.0)

	if _rain_material != null:
		_rain_material.set_shader_parameter(&"rain_amount", _current_rain_amount)
	if _rain_rect != null:
		_rain_rect.visible = _current_rain_amount > 0.001