# res://Scripts/UI/GameOverScreen.gd
class_name GameOverScreen
extends CanvasLayer
## Shown when the whole party falls (SignalBus.party_defeated). Fades to black, plays the game-over sting,
## shows ui/GAME/game_over.png and offers Load Last Save / Quit to Main Menu.
## Lives in world.tscn. The game is paused while it's up; the dead party is never saved
## (CombatManager skips the save on a wipe), so Load Last Save goes back to the last good save.

const SHINE_SHADER: Shader = preload("res://Shaders/portrait_shine.gdshader")
## BackButton uses icon_max_width 22. These sit at half that.
const ICON_MAX_WIDTH: int = 11

## Seconds after the wipe before the screen starts (lets the defeat toast / death anims play).
@export var start_delay: float = 1.2
@export var fade_duration: float = 1.0
@export var game_over_sound: AudioStream = preload("res://Audio/UI/game_over.mp3")

@onready var _black: ColorRect = %Black as ColorRect
@onready var _art: TextureRect = %GameOverArt as TextureRect
@onready var _buttons: HBoxContainer = %Buttons as HBoxContainer
@onready var _load_button: Button = %LoadButton as Button
@onready var _quit_button: Button = %QuitButton as Button
@onready var _status_label: Label = %StatusLabel as Label
@onready var _sound: AudioStreamPlayer = %Sound as AudioStreamPlayer

var is_showing: bool = false
var _shine_materials: Dictionary = {}
var _shine_tweens: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_style_action_button(_load_button, ShardsMenuStyle.COLOR_ACCENT)
	_style_action_button(_quit_button, ShardsMenuStyle.COLOR_DANGER)
	ShardsMenuStyle.style_body(_status_label, 14, true)
	_load_button.pressed.connect(_on_load_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_load_button.focus_neighbor_right = _load_button.get_path_to(_quit_button)
	_quit_button.focus_neighbor_left = _quit_button.get_path_to(_load_button)
	_sound.bus = &"Music" if AudioServer.get_bus_index("Music") != -1 else &"Master"
	if is_instance_valid(SignalBus) and SignalBus.has_signal(&"party_defeated"):
		SignalBus.party_defeated.connect(show_game_over)


func show_game_over() -> void:
	if is_showing:
		return
	is_showing = true
	await get_tree().create_timer(start_delay, true, false, true).timeout
	get_tree().paused = true
	if is_instance_valid(AudioManager):
		AudioManager.hold_music = true
		AudioManager.stop_bgm()
		AudioManager.stop_level_sound()
		AudioManager.stop_battle_music()
		if AudioManager.has_method("stop_all_enemy_loops"):
			AudioManager.stop_all_enemy_loops()

	var has_save: bool = SessionFlow.has_save()
	_load_button.disabled = not has_save
	_load_button.tooltip_text = "" if has_save else "No save file yet"
	var stamp: String = SessionFlow.get_save_timestamp()
	_status_label.text = ("Last save: %s" % stamp) if has_save and not stamp.is_empty() else ("" if has_save else "No save file")

	_black.modulate.a = 0.0
	_art.modulate.a = 0.0
	_art.pivot_offset = _art.size * 0.5
	_art.scale = Vector2(1.12, 1.12)
	_buttons.modulate.a = 0.0
	_status_label.modulate.a = 0.0
	_set_buttons_enabled(false)
	visible = true
	if game_over_sound != null:
		_sound.stream = game_over_sound
		_sound.play()

	var tw: Tween = create_tween()
	tw.tween_property(_black, "modulate:a", 1.0, fade_duration)
	tw.tween_property(_art, "modulate:a", 1.0, 0.8)
	tw.parallel().tween_property(_art, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_buttons, "modulate:a", 1.0, 0.4).set_delay(1.0)
	tw.parallel().tween_property(_status_label, "modulate:a", 1.0, 0.4).set_delay(1.0)
	await tw.finished
	_set_buttons_enabled(true)
	(_load_button if not _load_button.disabled else _quit_button).grab_focus()


func _set_buttons_enabled(on: bool) -> void:
	_quit_button.disabled = not on
	if not on:
		_load_button.disabled = true
	else:
		_load_button.disabled = not SessionFlow.has_save()


func _on_load_pressed() -> void:
	_play_click()
	_set_buttons_enabled(false)
	_release_audio()
	if not SessionFlow.load_saved_game(get_tree()):
		_status_label.text = "Couldn't load the save file."
		_set_buttons_enabled(true)
		_load_button.disabled = true


func _on_quit_pressed() -> void:
	_play_click()
	_set_buttons_enabled(false)
	_release_audio()
	SessionFlow.quit_to_main_menu(get_tree())


func _release_audio() -> void:
	_sound.stop()
	if is_instance_valid(AudioManager):
		AudioManager.hold_music = false


func _play_click() -> void:
	if is_instance_valid(AudioManager) and AudioManager.has_method("play_ui_sound"):
		AudioManager.play_ui_sound("button-press")


## Outline row button, same shape as the shard-menu Back button, with a shine sweep.
func _style_action_button(button: Button, accent: Color) -> void:
	button.text = button.text.to_upper()
	button.add_theme_stylebox_override("normal", _outline_box(ShardsMenuStyle.COLOR_TEXT, 2))
	button.add_theme_stylebox_override("hover", _outline_box(accent, 2))
	button.add_theme_stylebox_override("pressed", _outline_box(accent.lightened(0.2), 3))
	button.add_theme_stylebox_override("disabled", _outline_box(ShardsMenuStyle.COLOR_DISABLED, 2))
	var focus: StyleBoxFlat = _outline_box(accent, 2)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_font_override("font", ShardsMenuStyle.TITLE_FONT)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", ShardsMenuStyle.COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_color_override("font_focus_color", accent)
	button.add_theme_color_override("font_pressed_color", accent.lightened(0.2))
	button.add_theme_color_override("font_disabled_color", ShardsMenuStyle.COLOR_DISABLED)
	button.add_theme_color_override("icon_normal_color", ShardsMenuStyle.COLOR_TEXT)
	button.add_theme_color_override("icon_hover_color", accent)
	button.add_theme_color_override("icon_focus_color", accent)
	button.add_theme_color_override("icon_pressed_color", accent.lightened(0.2))
	button.add_theme_color_override("icon_disabled_color", ShardsMenuStyle.COLOR_DISABLED)
	button.add_theme_constant_override("icon_max_width", ICON_MAX_WIDTH)
	button.add_theme_constant_override("h_separation", 10)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_setup_shine(button)
	button.mouse_entered.connect(_play_shine.bind(button, 0.35))
	button.button_down.connect(_play_shine.bind(button, 0.2))


func _outline_box(border: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(12.0)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	return style


func _setup_shine(button: Button) -> void:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHINE_SHADER
	mat.set_shader_parameter(&"shine_progress", -0.5)
	mat.set_shader_parameter(&"shine_size", 0.35)
	mat.set_shader_parameter(&"shine_color", Color(1.0, 1.0, 1.0, 0.9))
	button.material = mat
	_shine_materials[button] = mat


func _play_shine(button: Button, duration: float) -> void:
	if button.disabled:
		return
	var mat: ShaderMaterial = _shine_materials.get(button) as ShaderMaterial
	if not is_instance_valid(mat):
		return
	var running: Tween = _shine_tweens.get(button) as Tween
	if running != null and running.is_running():
		running.kill()
	mat.set_shader_parameter(&"shine_progress", -0.5)
	var tween: Tween = create_tween()
	tween.tween_property(mat, "shader_parameter/shine_progress", 1.5, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shine_tweens[button] = tween
