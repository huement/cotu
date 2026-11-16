extends Control
## Settings menu (Audio / Graphics).
##
## Instance [code]SettingsMenu.tscn[/code] in your scene (or from code), then call
## [method open]. The [signal closed] signal is emitted when it closes.
## Changes apply live; "Save" writes them to disk.

## Emitted when the menu closes ("Close" button or ui_cancel action).
signal closed

const SettingsManagerScript := preload("SettingsManager.gd")
const SettingsMenuTheme := preload("SettingsMenuTheme.gd")

## Pauses the scene tree while the menu is open.
@export var pause_game_while_open: bool = false
## Frees the menu when it closes instead of just hiding it.
@export var free_on_close: bool = false
## On close, reverts unsaved changes (reloads the settings file).
@export var revert_unsaved_on_close: bool = true
## Lets the ui_cancel action (Esc / B button) close the menu.
@export var close_on_cancel: bool = true

@export_group("Appearance")
## Colour preset. "Custom" uses the colours below.
@export_enum("Night", "Light", "Ocean", "Candy", "Dusk", "Custom") var color_preset: String = "Candy"
## ("Custom" preset) Main colour (active tab, Save button, sliders, switches).
@export var accent_color: Color = Color(0.42, 0.52, 1.0)
## Background of the menu window.
@export var panel_color: Color = Color(0.075, 0.085, 0.12)
## Background of the setting cards.
@export var surface_color: Color = Color(0.12, 0.135, 0.185)
@export var text_color: Color = Color(0.92, 0.94, 0.97)
@export var muted_text_color: Color = Color(0.56, 0.6, 0.7)
## Colour of text drawn on the main colour.
@export var on_accent_color: Color = Color(1, 1, 1)
@export_range(0, 32) var corner_radius: int = 14
## Maximum panel size (below it, the panel uses 92% of the screen).
@export var max_panel_size: Vector2 = Vector2(1100.0, 760.0)
## Open / close animations.
@export var animate: bool = true
## Custom theme: when set, it replaces the theme generated from the colours above.
@export var custom_theme: Theme = null

@onready var _dim: ColorRect = %Dim
@onready var _frame: MarginContainer = %Frame
@onready var _tabs: TabContainer = %Tabs
@onready var _audio_list: VBoxContainer = %AudioList
@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _vsync_check: CheckButton = %VSyncCheck
@onready var _status_label: Label = %StatusLabel
@onready var _save_button: Button = %SaveButton
@onready var _defaults_button: Button = %DefaultsButton
@onready var _close_button: Button = %CloseButton

var _manager: SettingsManagerScript = null
var _audio_sliders: Dictionary = {}
var _audio_value_labels: Dictionary = {}
var _resolutions: Array[Vector2i] = []

var _was_paused: bool = false
var _is_ready: bool = false
var _tween: Tween = null
var _status_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_theme()
	_frame.anchor_left = 0.0
	_frame.anchor_top = 0.0
	_frame.anchor_right = 1.0
	_frame.anchor_bottom = 1.0
	resized.connect(_update_frame_size)
	_update_frame_size()
	_tabs.set_tab_title(0, tr("Audio"))
	_tabs.set_tab_title(1, tr("Graphics"))

	_save_button.pressed.connect(_on_save_pressed)
	_defaults_button.pressed.connect(_on_defaults_pressed)
	_close_button.pressed.connect(close)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_vsync_check.toggled.connect(_on_vsync_toggled)


	_manager = await _resolve_manager()
	_build_audio_tab()
	_manager.settings_loaded.connect(_refresh_all)
	_manager.settings_reset.connect(_refresh_all)
	_manager.setting_changed.connect(_on_setting_changed)
	visibility_changed.connect(_on_visibility_changed)

	_is_ready = true
	_refresh_all()
	_set_status("")
	if visible:
		_on_visibility_changed()


## Shows the menu.
func open() -> void:
	show()


## (Re)builds the theme from the exported colours. Call it after changing
## them from code.
func apply_theme() -> void:
	if custom_theme != null:
		theme = custom_theme
	elif SettingsMenuTheme.PRESETS.has(color_preset):
		theme = SettingsMenuTheme.build_preset(color_preset, corner_radius)
	else:
		theme = SettingsMenuTheme.build(
			accent_color, panel_color, surface_color, text_color, muted_text_color, on_accent_color, corner_radius
		)
	var preset: Array = SettingsMenuTheme.PRESETS.get(color_preset, [])
	var panel: Color = preset[1] if not preset.is_empty() else panel_color
	_dim.color = Color(0.12, 0.12, 0.22, 0.45) if panel.get_luminance() > 0.5 else Color(panel.darkened(0.6), 0.72)


## Closes the menu (reverts unsaved changes when
## [member revert_unsaved_on_close] is on).
func close() -> void:
	if _manager != null and revert_unsaved_on_close and _manager.has_unsaved_changes():
		_manager.load_settings()
	if animate and visible and is_inside_tree():
		_kill_tween()
		_tween = _new_tween()
		_tween.tween_property(_frame, "modulate:a", 0.0, 0.14)
		_tween.tween_property(_frame, "scale", Vector2(0.97, 0.97), 0.14)
		_tween.tween_property(_dim, "modulate:a", 0.0, 0.14)
		_tween.finished.connect(_finish_close, CONNECT_ONE_SHOT)
	else:
		_finish_close()


func _finish_close() -> void:
	hide()
	_frame.modulate.a = 1.0
	_frame.scale = Vector2.ONE
	_dim.modulate.a = 1.0
	closed.emit()
	if free_on_close:
		queue_free()


func _input(event: InputEvent) -> void:
	if not visible or not _is_ready:
		return


	if close_on_cancel and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# --------------------------------------------------------------------------
# Building the UI
# --------------------------------------------------------------------------

func _resolve_manager() -> SettingsManagerScript:
	var existing: Node = get_node_or_null(^"/root/SettingsManager")
	if existing is SettingsManagerScript:
		return existing as SettingsManagerScript
	push_warning("SettingsMenu: SettingsManager autoload not found (plugin disabled?). Creating a temporary instance.")
	var manager: SettingsManagerScript = SettingsManagerScript.new()
	manager.name = "SettingsManager"
	get_tree().root.add_child.call_deferred(manager)
	await manager.ready
	return manager


func _build_audio_tab() -> void:
	for child: Node in _audio_list.get_children():
		child.queue_free()
	_audio_sliders.clear()
	_audio_value_labels.clear()

	for bus_name: String in _manager.audio_buses:
		var card: PanelContainer = PanelContainer.new()
		card.theme_type_variation = &"SettingsCard"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 20)
		card.add_child(row)

		var label: Label = Label.new()
		label.theme_type_variation = &"SettingsLabel"
		label.text = _manager.get_bus_display_name(bus_name)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_stretch_ratio = 1.0
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(label)

		var slider: HSlider = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.size_flags_stretch_ratio = 2.0
		slider.custom_minimum_size = Vector2(120.0, 24.0)
		slider.value_changed.connect(_on_volume_changed.bind(bus_name))
		row.add_child(slider)

		var value_label: Label = Label.new()
		value_label.theme_type_variation = &"SettingsValue"
		value_label.custom_minimum_size = Vector2(64.0, 0.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)

		_audio_list.add_child(card)
		_audio_sliders[bus_name] = slider
		_audio_value_labels[bus_name] = value_label


# --------------------------------------------------------------------------
# Refreshing
# --------------------------------------------------------------------------

func _refresh_all() -> void:
	if not _is_ready:
		return
	_refresh_audio()
	_refresh_graphics()


func _refresh_audio() -> void:
	for bus_name: String in _audio_sliders:
		var slider: HSlider = _audio_sliders[bus_name]
		var percent: float = roundf(_manager.get_volume(bus_name) * 100.0)
		slider.set_value_no_signal(percent)
		(_audio_value_labels[bus_name] as Label).text = "%d %%" % int(percent)


func _refresh_graphics() -> void:
	_resolutions = _manager.get_available_resolutions()
	_resolution_option.clear()
	var current: Vector2i = _manager.get_resolution()
	for i: int in _resolutions.size():
		var resolution: Vector2i = _resolutions[i]
		_resolution_option.add_item("%d × %d" % [resolution.x, resolution.y], i)
		if resolution == current:
			_resolution_option.select(i)
	_fullscreen_check.set_pressed_no_signal(_manager.is_fullscreen())
	_vsync_check.set_pressed_no_signal(_manager.is_vsync_enabled())
	_resolution_option.disabled = _manager.is_fullscreen()
	_resolution_option.tooltip_text = tr("Turn off fullscreen to choose the resolution.") \
		if _manager.is_fullscreen() else ""


# --------------------------------------------------------------------------
# Audio / Graphics
# --------------------------------------------------------------------------

func _on_volume_changed(value: float, bus_name: String) -> void:
	_manager.set_volume(bus_name, value / 100.0)
	(_audio_value_labels[bus_name] as Label).text = "%d %%" % int(value)


func _on_resolution_selected(index: int) -> void:
	if index >= 0 and index < _resolutions.size():
		_manager.set_resolution(_resolutions[index])


func _on_fullscreen_toggled(enabled: bool) -> void:
	_manager.set_fullscreen(enabled)
	_refresh_graphics()


func _on_vsync_toggled(enabled: bool) -> void:
	_manager.set_vsync(enabled)


# --------------------------------------------------------------------------
# Footer buttons and status
# --------------------------------------------------------------------------

func _on_save_pressed() -> void:
	if _manager.save_settings() == OK:
		_set_status(tr("Settings saved."))
	else:
		_set_status(tr("Error: could not save the settings."))


func _on_defaults_pressed() -> void:
	_manager.reset_to_defaults()
	_set_status(tr("Defaults restored. Click \"Save\" to keep them."))


func _on_setting_changed(_section: String, _key: String, _value: Variant) -> void:
	_set_status(tr("Unsaved changes."))


func _on_visibility_changed() -> void:
	if not _is_ready:
		return
	if visible:
		_refresh_all()
		if pause_game_while_open:
			_was_paused = get_tree().paused
			get_tree().paused = true
		_tabs.get_tab_bar().grab_focus.call_deferred()
		_play_open_animation()
	else:
		if pause_game_while_open:
			get_tree().paused = _was_paused


func _set_status(text: String) -> void:
	if text == _status_label.text:
		return
	_status_label.text = text
	if text.is_empty() or not animate or not is_inside_tree():
		return
	if _status_tween != null and _status_tween.is_valid():
		_status_tween.kill()
	_status_label.modulate.a = 0.0
	_status_tween = _new_tween()
	_status_tween.tween_property(_status_label, "modulate:a", 1.0, 0.25)


# --------------------------------------------------------------------------
# Layout and animations
# --------------------------------------------------------------------------

func _update_frame_size() -> void:
	var target: Vector2 = Vector2(
		minf(size.x * 0.92, max_panel_size.x),
		minf(size.y * 0.92, max_panel_size.y)
	)
	var margin: Vector2 = Vector2(maxf((size.x - target.x) / 2.0, 0.0), maxf((size.y - target.y) / 2.0, 0.0))
	_frame.offset_left = margin.x
	_frame.offset_right = -margin.x
	_frame.offset_top = margin.y
	_frame.offset_bottom = -margin.y
	_frame.pivot_offset = target / 2.0


func _play_open_animation() -> void:
	if not animate:
		return
	_kill_tween()
	_frame.pivot_offset = _frame.size / 2.0
	_frame.scale = Vector2(0.96, 0.96)
	_frame.modulate.a = 0.0
	_dim.modulate.a = 0.0
	_tween = _new_tween()
	_tween.tween_property(_frame, "scale", Vector2.ONE, 0.24)
	_tween.tween_property(_frame, "modulate:a", 1.0, 0.18)
	_tween.tween_property(_dim, "modulate:a", 1.0, 0.2)


func _new_tween() -> Tween:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	return tween


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
