class_name MenuKitSystem
extends Node
## Applies the built-in settings to the engine: window, VSync, frame rate,
## 3D resolution and anti-aliasing, camera field of view, audio buses, screen
## filters (brightness, colorblind), FPS counter, autosave timer and text-to-speech.
##
## Created by the MenuKit autoload; you do not need to use it directly.

## Emitted every N minutes when the "Autosave" setting is on.
signal autosave_timeout

const COMMON_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]
const LANGUAGE_NAMES: Dictionary = {
	"en": "English", "fr": "Français", "es": "Español", "de": "Deutsch", "it": "Italiano",
	"pt": "Português", "ru": "Русский", "pl": "Polski", "nl": "Nederlands", "tr": "Türkçe",
	"ja": "日本語", "ko": "한국어", "zh": "中文", "uk": "Українська", "cs": "Čeština",
	"sv": "Svenska", "da": "Dansk", "fi": "Suomi", "nb": "Norsk", "hu": "Magyar", "ro": "Română",
	"ar": "العربية", "el": "Ελληνικά", "id": "Bahasa Indonesia", "vi": "Tiếng Việt", "th": "ไทย",
}
const MIN_LINEAR_VOLUME: float = 0.0001
const FILTER_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float gamma = 1.0;
uniform int mode = 0;

vec3 daltonize(vec3 c, int m) {
	float l = 17.8824 * c.r + 43.5161 * c.g + 4.11935 * c.b;
	float mm = 3.45565 * c.r + 27.1554 * c.g + 3.86714 * c.b;
	float s = 0.0299566 * c.r + 0.184309 * c.g + 1.46709 * c.b;
	if (m == 1) { l = 2.02344 * mm - 2.52581 * s; }
	else if (m == 2) { mm = 0.494207 * l + 1.24827 * s; }
	else { s = -0.395913 * l + 0.801109 * mm; }
	vec3 sim = vec3(
		0.0809444479 * l - 0.130504409 * mm + 0.116721066 * s,
		-0.0102485335 * l + 0.0540193266 * mm - 0.113614708 * s,
		-0.000365296938 * l - 0.00412161469 * mm + 0.693511405 * s);
	vec3 err = c - sim;
	return clamp(c + vec3(0.0, 0.7 * err.r + err.g, 0.7 * err.r + err.b), 0.0, 1.0);
}

void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	if (mode > 0) { c = daltonize(c, mode); }
	COLOR = vec4(pow(max(c, vec3(0.0)), vec3(1.0 / gamma)), 1.0);
}
"""

## Display: 0 = window, 1 = borderless fullscreen, 2 = exclusive fullscreen.
var display_mode: int = 0
var resolution: Vector2i = Vector2i(1280, 720)
## Applies the camera field of view to every perspective Camera3D (see the
## [code]menu_kit/camera/apply_fov[/code] project setting). Add a camera to the
## [code]menu_kit_keep_fov[/code] group to leave it alone.
var apply_fov_to_cameras: bool = true
var fov: float = 75.0
var read_aloud: bool = false

var _layer: CanvasLayer
var _filter: ColorRect
var _filter_material: ShaderMaterial
var _fps_label: Label
var _fps_timer: float = 0.0
var _gamma: float = 1.0
var _colorblind: int = 0
var _mute_unfocused: bool = false
var _autosave_timer: Timer
var _master_linear: float = 1.0


func _enter_tree() -> void:
	if get_child_count() > 0:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.name = "ScreenFilters"
	_layer.layer = 128
	add_child(_layer)
	_filter = ColorRect.new()
	_filter.name = "Filter"
	_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader: Shader = Shader.new()
	shader.code = FILTER_SHADER
	_filter_material = ShaderMaterial.new()
	_filter_material.shader = shader
	_filter.material = _filter_material
	_filter.visible = false
	_layer.add_child(_filter)
	_fps_label = Label.new()
	_fps_label.name = "FPS"
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.position = Vector2(12, 8)
	_fps_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_fps_label.add_theme_constant_override("outline_size", 4)
	_fps_label.visible = false
	_layer.add_child(_fps_label)
	_autosave_timer = Timer.new()
	_autosave_timer.name = "Autosave"
	_autosave_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_autosave_timer.timeout.connect(func() -> void: autosave_timeout.emit())
	add_child(_autosave_timer)
	get_tree().node_added.connect(_on_node_added)
	set_process(false)


func _process(delta: float) -> void:
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.25
		_fps_label.text = "%d FPS" % roundi(Engine.get_frames_per_second())
		var scale: float = maxf(1.0, get_viewport().get_visible_rect().size.y / 720.0)
		_fps_label.add_theme_font_size_override("font_size", roundi(16.0 * scale))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _mute_unfocused:
				AudioServer.set_bus_mute(0, true)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			AudioServer.set_bus_mute(0, _master_linear <= MIN_LINEAR_VOLUME)


# --------------------------------------------------------------------------
# Window and rendering
# --------------------------------------------------------------------------

func set_display_mode(mode: int) -> void:
	display_mode = clampi(mode, 0, 2)
	_apply_window()


func set_resolution(size: Vector2i) -> void:
	if size.x <= 0 or size.y <= 0:
		return
	resolution = size
	if display_mode == 0:
		_apply_window_size.call_deferred()


func set_vsync(enabled: bool) -> void:
	if can_manage_window():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)


## 0 = unlimited.
func set_max_fps(fps: int) -> void:
	Engine.max_fps = maxi(fps, 0)


## 3D resolution in percent of the window (Forward+ and Mobile renderers).
func set_render_scale(percent: float) -> void:
	get_tree().root.scaling_3d_scale = clampf(percent / 100.0, 0.25, 2.0)


## 0 = off, 1 = FXAA, 2 = MSAA 2x, 3 = MSAA 4x, 4 = TAA.
func set_antialiasing(mode: int) -> void:
	var root: Viewport = get_tree().root
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if mode == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	root.msaa_3d = Viewport.MSAA_2X if mode == 2 else (Viewport.MSAA_4X if mode == 3 else Viewport.MSAA_DISABLED)
	root.use_taa = mode == 4


## False where the window cannot be resized (headless, web, mobile, game embedded
## in the editor).
func can_manage_window() -> bool:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web") or OS.has_feature("mobile"):
		return false
	# Godot 4.4+ can run the game inside the editor window.
	if Engine.has_method(&"is_embedded_in_editor") and bool(Engine.call(&"is_embedded_in_editor")):
		return false
	return true


## Resolutions offered in windowed mode: common sizes that fit the screen.
func get_resolution_options() -> Array:
	var screen_size: Vector2i = Vector2i.ZERO
	if can_manage_window():
		screen_size = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var sizes: Array[Vector2i] = []
	for size: Vector2i in COMMON_RESOLUTIONS:
		if screen_size == Vector2i.ZERO or (size.x <= screen_size.x and size.y <= screen_size.y):
			sizes.append(size)
	var project_size: Vector2i = get_project_window_size()
	for extra: Vector2i in [project_size, resolution]:
		if not sizes.has(extra):
			sizes.append(extra)
	sizes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y < b.x * b.y or (a.x * a.y == b.x * b.y and a.x < b.x))
	var labels: PackedStringArray = PackedStringArray()
	var values: Array = []
	for size: Vector2i in sizes:
		labels.append("%d × %d" % [size.x, size.y])
		values.append(size)
	return [labels, values]


## Window size set in the project settings.
static func get_project_window_size() -> Vector2i:
	var width: int = int(ProjectSettings.get_setting("display/window/size/window_width_override", 0))
	var height: int = int(ProjectSettings.get_setting("display/window/size/window_height_override", 0))
	if width <= 0 or height <= 0:
		width = int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
		height = int(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	return Vector2i(width, height)


## Display mode set in the project settings (0 window, 1 borderless, 2 fullscreen).
static func get_project_display_mode() -> int:
	match int(ProjectSettings.get_setting("display/window/size/mode", DisplayServer.WINDOW_MODE_WINDOWED)):
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			return 1
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return 2
	return 0


func _apply_window() -> void:
	if not can_manage_window():
		return
	var wanted: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
	if display_mode == 1:
		wanted = DisplayServer.WINDOW_MODE_FULLSCREEN
	elif display_mode == 2:
		wanted = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	var current: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if display_mode == 0:
		if current != DisplayServer.WINDOW_MODE_WINDOWED and current != DisplayServer.WINDOW_MODE_MAXIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Deferred: some systems ignore a resize made right after leaving fullscreen.
		_apply_window_size.call_deferred()
	elif current != wanted:
		DisplayServer.window_set_mode(wanted)


func _apply_window_size() -> void:
	if display_mode != 0 or not can_manage_window():
		return
	if DisplayServer.window_get_size() == resolution:
		return
	DisplayServer.window_set_size(resolution)
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_position(usable.position + (usable.size - DisplayServer.window_get_size()) / 2)


# --------------------------------------------------------------------------
# Camera
# --------------------------------------------------------------------------

func set_fov(value: float) -> void:
	fov = value
	if not apply_fov_to_cameras or not is_inside_tree():
		return
	for node: Node in get_tree().root.find_children("*", "Camera3D", true, false):
		_apply_fov_to(node as Camera3D)


func _on_node_added(node: Node) -> void:
	if apply_fov_to_cameras and node is Camera3D:
		_apply_fov_to.call_deferred(node as Camera3D)


func _apply_fov_to(camera: Camera3D) -> void:
	if not is_instance_valid(camera) or camera.is_in_group(&"menu_kit_keep_fov"):
		return
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		camera.fov = fov


# --------------------------------------------------------------------------
# Audio
# --------------------------------------------------------------------------

## Linear volume (0 to 1) of a bus. The bus is created (sent to Master) if missing.
func set_bus_volume(bus_name: StringName, linear: float) -> void:
	var index: int = ensure_bus(bus_name)
	linear = clampf(linear, 0.0, 1.0)
	if index == 0:
		_master_linear = linear
	AudioServer.set_bus_mute(index, linear <= MIN_LINEAR_VOLUME)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, MIN_LINEAR_VOLUME)))


## Index of a bus, created and sent to Master when missing.
static func ensure_bus(bus_name: StringName) -> int:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index != -1:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")
	return index


func set_mute_unfocused(enabled: bool) -> void:
	_mute_unfocused = enabled


# --------------------------------------------------------------------------
# Screen filters, FPS counter
# --------------------------------------------------------------------------

## 0 to 100, 50 = unchanged.
func set_brightness(value: float) -> void:
	_gamma = lerpf(0.6, 1.0, value / 50.0) if value <= 50.0 else lerpf(1.0, 1.7, (value - 50.0) / 50.0)
	_update_filter()


## 0 = off, 1 = protanopia, 2 = deuteranopia, 3 = tritanopia.
func set_colorblind_mode(mode: int) -> void:
	_colorblind = clampi(mode, 0, 3)
	_update_filter()


func set_show_fps(enabled: bool) -> void:
	_fps_label.visible = enabled
	_fps_timer = 0.0
	set_process(enabled)


func _update_filter() -> void:
	var active: bool = _colorblind != 0 or not is_equal_approx(_gamma, 1.0)
	_filter.visible = active
	_filter_material.set_shader_parameter("gamma", _gamma)
	_filter_material.set_shader_parameter("mode", _colorblind)


# --------------------------------------------------------------------------
# Autosave, language, text-to-speech
# --------------------------------------------------------------------------

## 0 = off.
func set_autosave_minutes(minutes: float) -> void:
	if minutes <= 0.0:
		_autosave_timer.stop()
		return
	_autosave_timer.wait_time = minutes * 60.0
	_autosave_timer.start()


func set_language(locale: String) -> void:
	if not locale.is_empty() and TranslationServer.get_locale() != locale:
		TranslationServer.set_locale(locale)


## Languages that have a translation loaded, plus English.
func get_language_options() -> Array:
	var codes: PackedStringArray = PackedStringArray(["en"])
	for locale: String in TranslationServer.get_loaded_locales():
		var language: String = locale.get_slice("_", 0)
		if not codes.has(language):
			codes.append(language)
	var labels: PackedStringArray = PackedStringArray()
	var values: Array = []
	for code: String in codes:
		labels.append(String(LANGUAGE_NAMES.get(code, TranslationServer.get_language_name(code))))
		values.append(code)
	return [labels, values]


## Language of the player's system if the game has it, otherwise English.
func get_default_language() -> String:
	var system: String = OS.get_locale_language()
	var options: Array = get_language_options()
	return system if (options[1] as Array).has(system) else "en"


func is_tts_available() -> bool:
	return bool(ProjectSettings.get_setting("audio/general/text_to_speech", false)) \
		and DisplayServer.get_name() != "headless"


## Reads [param text] aloud when "Read menus aloud" is on.
func speak(text: String) -> void:
	if not read_aloud or text.is_empty() or not is_tts_available():
		return
	var voices: PackedStringArray = DisplayServer.tts_get_voices_for_language(TranslationServer.get_locale().get_slice("_", 0))
	if voices.is_empty():
		voices = DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		return
	DisplayServer.tts_speak(text, voices[0], 80, 1.0, 1.1, 0, true)
