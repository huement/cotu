extends Node
## Game Menu Kit, autoload "MenuKit" (added when the plugin is enabled).
##
## Owns the player settings, the generated interface sounds and the active style.
## The kit's menus use it, and so can your game:
## [codeblock]
## var fov: float = MenuKit.settings.get_value("camera/fov")
## MenuKit.setting_changed.connect(_on_setting_changed)
## MenuKit.change_scene("res://levels/level_2.tscn")
## [/codeblock]

## Emitted when a setting changes (key "section/name"; bindings use "bindings/<action>").
signal setting_changed(key: String, value: Variant)
## Emitted after [method set_style].
signal style_changed
## Emitted when the size of the menus changes (window resized, text size setting).
signal ui_scale_changed

const DefaultSettings := preload("core/menu_kit_default_settings.gd")
const Translations := preload("core/menu_kit_translations.gd")

## Project settings (Project > Project Settings > Menu Kit).
const SETTING_STYLE: String = "menu_kit/style/style"
const SETTING_SOUND_PACK: String = "menu_kit/sounds/pack"
const SETTING_BUILTIN_FRENCH: String = "menu_kit/localization/builtin_french"
const SETTING_REBINDABLE_ACTIONS: String = "menu_kit/controls/rebindable_actions"
const SETTING_EXCLUDED_PREFIXES: String = "menu_kit/controls/excluded_prefixes"
const SETTING_APPLY_FOV: String = "menu_kit/camera/apply_fov"
const SETTING_DEFAULT_FOV: String = "menu_kit/camera/default_fov"
const SETTING_MAIN_MENU_SCENE: String = "menu_kit/scenes/main_menu"

const DEFAULT_STYLE: String = "neon"
const DEFAULT_EXCLUDED_PREFIXES: PackedStringArray = ["ui_"]
## Built-in styles, by name.
const STYLES: Dictionary = {
	"neon": "styles/neon/menu_kit_style_neon.gd",
}
## Height (in pixels) at which the menus are drawn at 100 %.
const REFERENCE_HEIGHT: float = 720.0
const REFERENCE_WIDTH: float = 1060.0
const SAVE_DELAY: float = 0.8

var settings: MenuKitSettings
var input: MenuKitInput
var sounds: MenuKitSounds
var system: MenuKitSystem
## Scene of the main menu (see [method go_to_main_menu]). Found
## automatically when a main menu opens, or set in Project Settings.
var main_menu_scene: String = ""
## Active style of every kit menu.
var style: MenuKitStyle
## 1.0 at 720p. Every size of the kit's menus is multiplied by it.
var ui_scale: float = 1.0
## Extra scale from the "Text size" setting.
var text_scale: float = 1.0:
	set(value):
		text_scale = clampf(value, 0.5, 2.0)
		_update_ui_scale()
## True when "Reduce flashing" is on: the menus skip flicker and glitch effects.
var reduce_flashing: bool = false

var _save_timer: Timer
var _quitting: bool = false


# Set up in _enter_tree (not _ready): the main scene enters the tree before the
# autoloads are ready, and its _enter_tree may already use MenuKit.
func _enter_tree() -> void:
	if settings != null:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	if bool(ProjectSettings.get_setting(SETTING_BUILTIN_FRENCH, true)):
		Translations.register()

	input = MenuKitInput.new()
	input.collect_actions(
		PackedStringArray(ProjectSettings.get_setting(SETTING_REBINDABLE_ACTIONS, PackedStringArray())),
		PackedStringArray(ProjectSettings.get_setting(SETTING_EXCLUDED_PREFIXES, DEFAULT_EXCLUDED_PREFIXES))
	)
	sounds = MenuKitSounds.new()
	sounds.name = "Sounds"
	sounds.pack = String(ProjectSettings.get_setting(SETTING_SOUND_PACK, "soft"))
	add_child(sounds)
	system = MenuKitSystem.new()
	system.name = "System"
	system.apply_fov_to_cameras = bool(ProjectSettings.get_setting(SETTING_APPLY_FOV, true))
	add_child(system)

	main_menu_scene = String(ProjectSettings.get_setting(SETTING_MAIN_MENU_SCENE, ""))

	settings = MenuKitSettings.new(input)
	settings.changed.connect(_on_setting_changed)
	DefaultSettings.register(self, settings, system, sounds)

	_save_timer = Timer.new()
	_save_timer.name = "SaveTimer"
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(save_settings)
	add_child(_save_timer)

	set_style(String(ProjectSettings.get_setting(SETTING_STYLE, DEFAULT_STYLE)))
	settings.load_from_disk()
	get_viewport().size_changed.connect(_update_ui_scale)
	_update_ui_scale()
	sounds.warm_up.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if settings != null and settings.is_dirty():
			settings.save_to_disk()


## Changes the style of every kit menu: a built-in name ("neon"), the path of
## a style resource (.tres) or a [MenuKitStyle].
func set_style(value: Variant) -> void:
	var new_style: MenuKitStyle = null
	if value is MenuKitStyle:
		new_style = value
	elif value is String or value is StringName:
		var text: String = String(value)
		if STYLES.has(text):
			var script: GDScript = load(_addon_path(String(STYLES[text]))) as GDScript
			new_style = script.new() as MenuKitStyle
		elif text.begins_with("res://") or text.begins_with("uid://"):
			new_style = load(text) as MenuKitStyle
	if new_style == null:
		push_warning("MenuKit: unknown style %s, using \"%s\"." % [str(value), DEFAULT_STYLE])
		var fallback: GDScript = load(_addon_path(String(STYLES[DEFAULT_STYLE]))) as GDScript
		new_style = fallback.new() as MenuKitStyle
	style = new_style
	style.set_em(style.base_em * ui_scale)
	sounds.set_tint(style.sound_pitch, style.sound_room)
	style_changed.emit()


## Names of the built-in styles.
func get_style_names() -> PackedStringArray:
	return PackedStringArray(STYLES.keys())


## Saves the settings now (they are also saved a moment after each change).
func save_settings() -> Error:
	_save_timer.stop()
	return settings.save_to_disk()


## Starts a new game: opens [param scene_path].
func start_new_game(scene_path: String) -> void:
	if is_loading():
		return
	change_scene(scene_path)


## Leaves the game for the main menu ([member main_menu_scene]).
func go_to_main_menu() -> void:
	if is_loading():
		return
	if main_menu_scene.is_empty():
		push_warning("MenuKit: no main menu scene; set Project Settings > Menu Kit > Scenes > Main Menu.")
		return
	change_scene(main_menu_scene)


## Opens [param path] ([param _title] is ignored).
func change_scene(path: String, _title: String = "") -> void:
	if path.is_empty():
		push_error("MenuKit: change_scene() needs a scene path.")
		return
	get_viewport().gui_release_focus()
	get_tree().change_scene_to_file.call_deferred(path)


## Always false: scenes open directly.
func is_loading() -> bool:
	return false


## Fades to black with the style's goodbye line, saves the settings and quits.
func quit_game(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	save_settings()
	var curtain: MenuKitCurtain = MenuKitCurtain.new(style.quit_text())
	add_child(curtain)
	await curtain.play()
	get_tree().quit(exit_code)


## Called by [MenuKitMainMenu]: the game is not running anymore, and
## [method go_to_main_menu] now knows where the main menu is.
func register_main_menu(menu: Node) -> void:
	var scene: Node = get_tree().current_scene
	if main_menu_scene.is_empty() and scene != null and (scene == menu or scene.is_ancestor_of(menu)):
		main_menu_scene = scene.scene_file_path


## Reads [param text] aloud when the "Read menus aloud" setting is on.
func speak(text: String) -> void:
	system.speak(text)


## Rumble that respects the "Controller vibration" setting.
func vibrate(device: int, weak: float, strong: float, duration: float = 0.2) -> void:
	if bool(settings.get_value("controls/vibration", true)):
		Input.start_joy_vibration(device, weak, strong, duration)


## Size in pixels of 1 em of the active style (the base text size of the menus).
func em() -> float:
	return style.em


func _on_setting_changed(key: String, value: Variant) -> void:
	_save_timer.start()
	setting_changed.emit(key, value)


func _update_ui_scale() -> void:
	if not is_inside_tree():
		return
	var size: Vector2 = get_viewport().get_visible_rect().size
	var scale: float = minf(size.y / REFERENCE_HEIGHT, size.x / REFERENCE_WIDTH) * text_scale
	scale = clampf(scale, 0.4, 8.0)
	if is_equal_approx(scale, ui_scale) and style != null and is_equal_approx(style.em, style.base_em * scale):
		return
	ui_scale = scale
	if style != null:
		style.set_em(style.base_em * ui_scale)
	ui_scale_changed.emit()


func _addon_path(relative: String) -> String:
	return (get_script() as Script).resource_path.get_base_dir().path_join(relative)
