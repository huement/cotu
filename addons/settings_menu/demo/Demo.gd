extends Control
## Demo scene: run it (F6) to try the menu.
## Move the square, open the settings, change the volumes or the keys
## and see the effect right away.

const SETTINGS_MENU: PackedScene = preload("../SettingsMenu.tscn")
const SettingsManagerScript := preload("../SettingsManager.gd")
const SettingsMenuScript := preload("../SettingsMenu.gd")

const SPEED: float = 380.0
const MIX_RATE: int = 22050

## Actions created by the demo if they don't exist in your project.
const DEMO_ACTIONS: Dictionary = {
	&"demo_left": ["Move Left", KEY_LEFT, JOY_AXIS_LEFT_X, -1.0],
	&"demo_right": ["Move Right", KEY_RIGHT, JOY_AXIS_LEFT_X, 1.0],
	&"demo_up": ["Move Up", KEY_UP, JOY_AXIS_LEFT_Y, -1.0],
	&"demo_down": ["Move Down", KEY_DOWN, JOY_AXIS_LEFT_Y, 1.0],
	&"demo_jump": ["Jump", KEY_SPACE, JOY_BUTTON_A, 0.0],
}

const PLAYER_COLORS: Array[Color] = [
	Color(0.35, 0.65, 1.0),
	Color(1.0, 0.55, 0.35),
	Color(0.5, 0.9, 0.5),
	Color(0.95, 0.8, 0.3),
	Color(0.85, 0.5, 1.0),
]

@onready var _play_area: Control = %PlayArea
@onready var _player: ColorRect = %Player
@onready var _settings_button: Button = %SettingsButton
@onready var _music: AudioStreamPlayer = %Music
@onready var _sfx: AudioStreamPlayer = %Sfx

var _menu: SettingsMenuScript = null
var _color_index: int = 0
var _manager: SettingsManagerScript = null


func _ready() -> void:
	_register_demo_actions()
	_music.stream = _make_music()
	_music.bus = &"Music"
	_music.play()
	_sfx.stream = _make_blip()
	_sfx.bus = &"SFX"

	_menu = SETTINGS_MENU.instantiate() as SettingsMenuScript
	_menu.pause_game_while_open = true
	_menu.hide()
	add_child(_menu)
	_menu.closed.connect(_on_menu_closed)
	_settings_button.pressed.connect(open_settings)

	_manager = get_node_or_null(^"/root/SettingsManager") as SettingsManagerScript
	if _manager != null:
		_manager.setting_changed.connect(_on_setting_changed)
	_player.color = PLAYER_COLORS[0]
	_center_player.call_deferred()


func _process(delta: float) -> void:
	var direction: Vector2 = Input.get_vector(&"demo_left", &"demo_right", &"demo_up", &"demo_down")
	if direction == Vector2.ZERO:
		return
	var max_position: Vector2 = _play_area.size - _player.size
	_player.position = (_player.position + direction * SPEED * delta).clamp(Vector2.ZERO, max_position)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"demo_jump"):
		_jump()
	elif event.is_action_pressed(&"ui_cancel") and not _menu.visible:
		get_viewport().set_input_as_handled()
		open_settings()


## Opens the settings menu.
func open_settings() -> void:
	_menu.open()


func _jump() -> void:
	_color_index = (_color_index + 1) % PLAYER_COLORS.size()
	_player.color = PLAYER_COLORS[_color_index]
	_player.pivot_offset = _player.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(_player, "scale", Vector2(1.35, 1.35), 0.08)
	tween.tween_property(_player, "scale", Vector2.ONE, 0.14)
	_sfx.play()


func _center_player() -> void:
	_player.position = (_play_area.size - _player.size) / 2.0


func _on_menu_closed() -> void:
	_settings_button.grab_focus()


func _on_setting_changed(section: String, key: String, _value: Variant) -> void:
	# Short "blip" so the SFX volume can be heard while adjusting it.
	if section == "audio" and key == "SFX" and not _sfx.playing:
		_sfx.play()


func _register_demo_actions() -> void:
	for action: StringName in DEMO_ACTIONS:
		var definition: Array = DEMO_ACTIONS[action]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key_event: InputEventKey = InputEventKey.new()
			key_event.physical_keycode = definition[1] as Key
			InputMap.action_add_event(action, key_event)
			if action == &"demo_jump":
				var button: InputEventJoypadButton = InputEventJoypadButton.new()
				button.device = -1
				button.button_index = definition[2] as JoyButton
				InputMap.action_add_event(action, button)
			else:
				var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
				motion.device = -1
				motion.axis = definition[2] as JoyAxis
				motion.axis_value = float(definition[3])
				InputMap.action_add_event(action, motion)


# --------------------------------------------------------------------------
# Sounds generated in code (no audio files needed)
# --------------------------------------------------------------------------

func _make_music() -> AudioStreamWAV:
	var notes: Array[float] = [261.63, 329.63, 392.0, 523.25, 392.0, 329.63, 293.66, 349.23]
	var bass: Array[float] = [130.81, 130.81, 130.81, 130.81, 98.0, 98.0, 110.0, 110.0]
	var note_length: float = 0.22
	var samples_per_note: int = int(MIX_RATE * note_length)
	var data: PackedByteArray = PackedByteArray()
	data.resize(notes.size() * samples_per_note * 2)
	for n: int in notes.size():
		for i: int in samples_per_note:
			var t: float = float(i) / MIX_RATE
			var envelope: float = minf(1.0, t * 80.0) * minf(1.0, (note_length - t) * 30.0)
			var value: float = (sin(TAU * notes[n] * t) * 0.22 + sin(TAU * bass[n] * t) * 0.12) * envelope
			data.encode_s16((n * samples_per_note + i) * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = notes.size() * samples_per_note
	return stream


func _make_blip() -> AudioStreamWAV:
	var length: float = 0.12
	var count: int = int(MIX_RATE * length)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var frequency: float = lerpf(660.0, 1320.0, t / length)
		var value: float = sin(TAU * frequency * t) * 0.4 * (1.0 - t / length)
		data.encode_s16(i * 2, int(value * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = data
	return stream
