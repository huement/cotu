extends Node
## Singleton (autoload "SettingsManager") that owns the game settings.
##
## - Automatically loads [code]user://settings.cfg[/code] at startup and applies
##   volumes, graphics options and key bindings.
## - Exposes a typed API used by [code]SettingsMenu.tscn[/code], also usable from
##   your own code (e.g. [code]SettingsManager.set_volume("Music", 0.5)[/code]).
## - Only bindings changed by the player are written to the file: if you change a
##   default key in a game update, players who never touched it get the new one.

## Emitted after loading (at startup or through [method load_settings]).
signal settings_loaded
## Emitted after a successful save.
signal settings_saved
## Emitted after [method reset_to_defaults].
signal settings_reset
## Emitted whenever a setting changes ([code]section[/code] is
## [code]"audio"[/code], [code]"graphics"[/code] or [code]"controls"[/code]).
signal setting_changed(section: String, key: String, value: Variant)

const SettingsMenuTranslations := preload("SettingsMenuTranslations.gd")


const SETTINGS_PATH: String = "user://settings.cfg"
const SAVE_FORMAT_VERSION: int = 1

const SECTION_META: String = "meta"
const SECTION_AUDIO: String = "audio"
const SECTION_GRAPHICS: String = "graphics"
const SECTION_CONTROLS: String = "controls"

## Project settings (Project > Project Settings > Settings Menu).
const SETTING_AUDIO_BUSES: String = "settings_menu/audio/buses"
## Project setting: register the built-in French translation of the menu (default: on).
const SETTING_BUILTIN_FRENCH: String = "settings_menu/localization/builtin_french"

const DEFAULT_AUDIO_BUSES: PackedStringArray = ["Master", "Music", "SFX"]

const MIN_LINEAR_VOLUME: float = 0.0001

const COMMON_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(640, 360),
	Vector2i(800, 600),
	Vector2i(1024, 768),
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1280, 800),
	Vector2i(1366, 768),
	Vector2i(1440, 900),
	Vector2i(1600, 900),
	Vector2i(1680, 1050),
	Vector2i(1920, 1080),
	Vector2i(1920, 1200),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]


## Labels shown for the audio buses (can be changed from your code).
var bus_display_names: Dictionary = {
	"Master": "Master Volume",
	"Music": "Music",
	"SFX": "Sound Effects",
}


## Managed audio buses (read from the [constant SETTING_AUDIO_BUSES] project setting).
var audio_buses: PackedStringArray = PackedStringArray()

var _volumes: Dictionary = {}
var _default_volumes: Dictionary = {}

var _resolution: Vector2i = Vector2i(1152, 648)
var _fullscreen: bool = false
var _vsync: bool = true
var _default_resolution: Vector2i = Vector2i(1152, 648)
var _default_fullscreen: bool = false
var _default_vsync: bool = true


var _dirty: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if bool(ProjectSettings.get_setting(SETTING_BUILTIN_FRENCH, true)):
		SettingsMenuTranslations.register()
	audio_buses = PackedStringArray(ProjectSettings.get_setting(SETTING_AUDIO_BUSES, DEFAULT_AUDIO_BUSES))
	_ensure_audio_buses()
	_capture_defaults()
	load_settings()


# --------------------------------------------------------------------------
# Save / load
# --------------------------------------------------------------------------

## Saves every setting to [constant SETTINGS_PATH].
func save_settings() -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION_META, "version", SAVE_FORMAT_VERSION)

	for bus_name: String in audio_buses:
		config.set_value(SECTION_AUDIO, bus_name, get_volume(bus_name))

	config.set_value(SECTION_GRAPHICS, "resolution", _resolution)
	config.set_value(SECTION_GRAPHICS, "fullscreen", _fullscreen)
	config.set_value(SECTION_GRAPHICS, "vsync", _vsync)


	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_error("SettingsManager: could not save %s (error %d)." % [SETTINGS_PATH, error])
		return error
	_dirty = false
	settings_saved.emit()
	return OK


## Reloads the settings from disk (or the defaults when the file does not
## exist) and applies them immediately.
func load_settings() -> void:
	_restore_default_values()

	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(SETTINGS_PATH)
	if error == OK:
		_read_config(config)
	elif error != ERR_FILE_NOT_FOUND:
		push_warning("SettingsManager: %s is unreadable (error %d), using defaults." % [SETTINGS_PATH, error])

	apply_all()
	_dirty = false
	settings_loaded.emit()


## Restores the project defaults and applies them.
## Nothing is written to disk: call [method save_settings] to keep them.
func reset_to_defaults() -> void:
	_restore_default_values()
	apply_all()
	_dirty = true
	settings_reset.emit()


## Applies every current setting (audio + graphics).
## Bindings are applied directly to the InputMap.
func apply_all() -> void:
	for bus_name: String in audio_buses:
		_apply_volume(bus_name)
	apply_graphics()


## [code]true[/code] if settings changed since the last load / save.
func has_unsaved_changes() -> bool:
	return _dirty


func _read_config(config: ConfigFile) -> void:
	for bus_name: String in audio_buses:
		var volume: Variant = config.get_value(SECTION_AUDIO, bus_name, get_volume(bus_name))
		if volume is float or volume is int:
			_volumes[bus_name] = clampf(float(volume), 0.0, 1.0)

	var resolution: Variant = config.get_value(SECTION_GRAPHICS, "resolution", _resolution)
	if resolution is Vector2i and (resolution as Vector2i).x > 0 and (resolution as Vector2i).y > 0:
		_resolution = resolution
	var fullscreen: Variant = config.get_value(SECTION_GRAPHICS, "fullscreen", _fullscreen)
	if fullscreen is bool:
		_fullscreen = fullscreen
	var vsync: Variant = config.get_value(SECTION_GRAPHICS, "vsync", _vsync)
	if vsync is bool:
		_vsync = vsync


func _restore_default_values() -> void:
	for bus_name: String in audio_buses:
		_volumes[bus_name] = float(_default_volumes.get(bus_name, 1.0))
	_resolution = _default_resolution
	_fullscreen = _default_fullscreen
	_vsync = _default_vsync


func _capture_defaults() -> void:
	for bus_name: String in audio_buses:
		var index: int = AudioServer.get_bus_index(bus_name)
		var linear: float = 1.0
		if index != -1 and not AudioServer.is_bus_mute(index):
			linear = clampf(db_to_linear(AudioServer.get_bus_volume_db(index)), 0.0, 1.0)
		elif index != -1:
			linear = 0.0
		_default_volumes[bus_name] = linear

	var width: int = int(ProjectSettings.get_setting("display/window/size/window_width_override", 0))
	var height: int = int(ProjectSettings.get_setting("display/window/size/window_height_override", 0))
	if width <= 0 or height <= 0:
		width = int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
		height = int(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	_default_resolution = Vector2i(width, height)

	var mode: int = int(ProjectSettings.get_setting("display/window/size/mode", DisplayServer.WINDOW_MODE_WINDOWED))
	_default_fullscreen = mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	var vsync_mode: int = int(ProjectSettings.get_setting("display/window/vsync/vsync_mode", DisplayServer.VSYNC_ENABLED))
	_default_vsync = vsync_mode != DisplayServer.VSYNC_DISABLED


# --------------------------------------------------------------------------
# Audio
# --------------------------------------------------------------------------

## Linear volume (0.0 to 1.0) of a bus.
func get_volume(bus_name: String) -> float:
	return float(_volumes.get(bus_name, 1.0))


## Sets the linear volume (0.0 to 1.0) of a bus and applies it immediately.
func set_volume(bus_name: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	if is_equal_approx(get_volume(bus_name), linear) and _volumes.has(bus_name):
		return
	_volumes[bus_name] = linear
	_apply_volume(bus_name)
	_mark_changed(SECTION_AUDIO, bus_name, linear)


## Bus label shown in the menu.
func get_bus_display_name(bus_name: String) -> String:
	return tr(String(bus_display_names.get(bus_name, bus_name)))


func _apply_volume(bus_name: String) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var linear: float = get_volume(bus_name)
	AudioServer.set_bus_mute(index, linear <= MIN_LINEAR_VOLUME)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, MIN_LINEAR_VOLUME)))


## Creates missing buses (routed to Master) so the addon works without setup.
## Create them in the Audio panel instead to see them in the editor.
func _ensure_audio_buses() -> void:
	for bus_name: String in audio_buses:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")


# --------------------------------------------------------------------------
# Graphics
# --------------------------------------------------------------------------

func get_resolution() -> Vector2i:
	return _resolution


func set_resolution(resolution: Vector2i) -> void:
	if resolution.x <= 0 or resolution.y <= 0 or resolution == _resolution:
		return
	_resolution = resolution
	apply_graphics()
	_mark_changed(SECTION_GRAPHICS, "resolution", resolution)


func is_fullscreen() -> bool:
	return _fullscreen


func set_fullscreen(enabled: bool) -> void:
	if enabled == _fullscreen:
		return
	_fullscreen = enabled
	apply_graphics()
	_mark_changed(SECTION_GRAPHICS, "fullscreen", enabled)


func is_vsync_enabled() -> bool:
	return _vsync


func set_vsync(enabled: bool) -> void:
	if enabled == _vsync:
		return
	_vsync = enabled
	apply_graphics()
	_mark_changed(SECTION_GRAPHICS, "vsync", enabled)


## Offered resolutions: common resolutions that fit on the screen, plus the
## project's default resolution and the current one.
func get_available_resolutions() -> Array[Vector2i]:
	var screen_size: Vector2i = Vector2i.ZERO
	if _can_manage_window():
		screen_size = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var result: Array[Vector2i] = []
	for resolution: Vector2i in COMMON_RESOLUTIONS:
		if screen_size == Vector2i.ZERO or (resolution.x <= screen_size.x and resolution.y <= screen_size.y):
			result.append(resolution)
	for extra: Vector2i in [_default_resolution, _resolution]:
		if not result.has(extra):
			result.append(extra)
	result.sort_custom(_compare_resolutions)
	return result


## Applies resolution, window mode and VSync.
func apply_graphics() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if _vsync else DisplayServer.VSYNC_DISABLED
	)
	if _fullscreen:
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# Deferred: some systems ignore a resize made right after leaving fullscreen.
	_apply_window_size.call_deferred()


func _apply_window_size() -> void:
	if _fullscreen or not _can_manage_window():
		return
	DisplayServer.window_set_size(_resolution)
	var screen: int = DisplayServer.window_get_current_screen()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var window_size: Vector2i = DisplayServer.window_get_size()
	DisplayServer.window_set_position(usable.position + (usable.size - window_size) / 2)


func _can_manage_window() -> bool:
	return DisplayServer.get_name() != "headless" \
		and not OS.has_feature("web") \
		and not OS.has_feature("mobile")


func _compare_resolutions(a: Vector2i, b: Vector2i) -> bool:
	if a.x * a.y != b.x * b.y:
		return a.x * a.y < b.x * b.y
	return a.x < b.x


func _mark_changed(section: String, key: String, value: Variant) -> void:
	_dirty = true
	setting_changed.emit(section, key, value)


