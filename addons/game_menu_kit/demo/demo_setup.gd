extends RefCounted
## Makes the demo run in any project: its texts, its input actions (added only when
## the project does not have them), the main menu scene and the loading tips.

const DemoTranslations := preload("res://addons/game_menu_kit/demo/demo_translations.gd")
const MAIN_MENU: String = "res://addons/game_menu_kit/demo/demo.tscn"
const TIPS: PackedStringArray = [
	"Tip: dashing through a laser grid costs half your shield, not all of it.",
	"Tip: hold boost to cross a sector in a few seconds.",
	"Tip: the pause menu saves a screenshot with your game.",
]
const LABELS: Dictionary = {
	&"move_up": "Move up", &"move_down": "Move down", &"move_left": "Move left",
	&"move_right": "Move right", &"jump": "Boost", &"interact": "Interact", &"map": "Map", &"pause": "Pause",
}


static func run() -> void:
	DemoTranslations.register()
	if MenuKit.main_menu_scene.is_empty():
		MenuKit.main_menu_scene = MAIN_MENU
	_add_action(&"move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add_action(&"move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add_action(&"move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add_action(&"move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add_action(&"jump", [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_add_action(&"interact", [_key(KEY_E), _button(JOY_BUTTON_X)])
	_add_action(&"map", [_key(KEY_M), _button(JOY_BUTTON_BACK)])
	_add_action(&"pause", [_key(KEY_P), _button(JOY_BUTTON_START)])
	# Names shown for the demo's actions in Options > Controls.
	MenuKit.input.action_labels.merge(LABELS)


static func _add_action(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.5)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	return event


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


static func _button(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	return event
