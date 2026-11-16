class_name MenuKitInput
extends RefCounted
## Key rebinding: keyboard / mouse and gamepad inputs of your InputMap actions.
##
## Actions come from Project > Project Settings > Input Map (every action except
## the built-in [code]ui_*[/code] ones, see the [code]menu_kit/controls/*[/code]
## project settings). Only bindings changed by the player are saved, so a default
## key changed in a game update reaches players who never touched it.

## Emitted when the inputs of an action change.
signal bindings_changed(action: StringName)

## Device type of a binding.
enum Kind { KEYBOARD_MOUSE, GAMEPAD }

## Stick / trigger movement above this value counts as an input while rebinding.
const AXIS_THRESHOLD: float = 0.5
const SECTION: String = "bindings"

## Labels for common keys (other keys use Godot's key name).
const KEY_LABELS: Dictionary = {
	KEY_SPACE: "Space",
	KEY_ENTER: "Enter",
	KEY_KP_ENTER: "Numpad Enter",
	KEY_ESCAPE: "Esc",
	KEY_TAB: "Tab",
	KEY_BACKSPACE: "Backspace",
	KEY_DELETE: "Delete",
	KEY_INSERT: "Insert",
	KEY_SHIFT: "Shift",
	KEY_CTRL: "Ctrl",
	KEY_ALT: "Alt",
	KEY_CAPSLOCK: "Caps Lock",
	KEY_LEFT: "←",
	KEY_RIGHT: "→",
	KEY_UP: "↑",
	KEY_DOWN: "↓",
	KEY_PAGEUP: "Page Up",
	KEY_PAGEDOWN: "Page Down",
	KEY_HOME: "Home",
	KEY_END: "End",
}

const MOUSE_BUTTON_LABELS: Dictionary = {
	MOUSE_BUTTON_LEFT: "Left Click",
	MOUSE_BUTTON_RIGHT: "Right Click",
	MOUSE_BUTTON_MIDDLE: "Middle Click",
	MOUSE_BUTTON_WHEEL_UP: "Wheel Up",
	MOUSE_BUTTON_WHEEL_DOWN: "Wheel Down",
	MOUSE_BUTTON_WHEEL_LEFT: "Wheel Left",
	MOUSE_BUTTON_WHEEL_RIGHT: "Wheel Right",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4",
	MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}

const JOY_BUTTON_LABELS: Dictionary = {
	JOY_BUTTON_A: "A / Cross",
	JOY_BUTTON_B: "B / Circle",
	JOY_BUTTON_X: "X / Square",
	JOY_BUTTON_Y: "Y / Triangle",
	JOY_BUTTON_BACK: "Select / Back",
	JOY_BUTTON_GUIDE: "Guide / Home",
	JOY_BUTTON_START: "Start / Options",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB / L1",
	JOY_BUTTON_RIGHT_SHOULDER: "RB / R1",
	JOY_BUTTON_DPAD_UP: "D-Pad ↑",
	JOY_BUTTON_DPAD_DOWN: "D-Pad ↓",
	JOY_BUTTON_DPAD_LEFT: "D-Pad ←",
	JOY_BUTTON_DPAD_RIGHT: "D-Pad →",
	JOY_BUTTON_MISC1: "Share / Capture",
	JOY_BUTTON_PADDLE1: "Paddle 1",
	JOY_BUTTON_PADDLE2: "Paddle 2",
	JOY_BUTTON_PADDLE3: "Paddle 3",
	JOY_BUTTON_PADDLE4: "Paddle 4",
	JOY_BUTTON_TOUCHPAD: "Touchpad",
}

## For each axis: [negative direction label, positive direction label].
const JOY_AXIS_LABELS: Dictionary = {
	JOY_AXIS_LEFT_X: ["L Stick ←", "L Stick →"],
	JOY_AXIS_LEFT_Y: ["L Stick ↑", "L Stick ↓"],
	JOY_AXIS_RIGHT_X: ["R Stick ←", "R Stick →"],
	JOY_AXIS_RIGHT_Y: ["R Stick ↑", "R Stick ↓"],
	JOY_AXIS_TRIGGER_LEFT: ["LT / L2", "LT / L2"],
	JOY_AXIS_TRIGGER_RIGHT: ["RT / R2", "RT / R2"],
}

## Labels shown for actions: [code]{ &"jump": "Jump" }[/code]. Without an entry the
## action name is formatted automatically ([code]"move_left"[/code] -> "Move Left").
var action_labels: Dictionary = {}

var _actions: Array[StringName] = []
var _defaults: Dictionary = {}
# Last settings file read, for actions registered after it (their saved bindings).
var _last_config: ConfigFile


## Picks the actions shown in the Controls tab: [param explicit] when not empty,
## otherwise every InputMap action not starting with one of [param excluded_prefixes].
func collect_actions(explicit: PackedStringArray, excluded_prefixes: PackedStringArray) -> void:
	_actions.clear()
	if not explicit.is_empty():
		for action_name: String in explicit:
			if InputMap.has_action(action_name):
				_add_action(StringName(action_name))
			else:
				push_warning("MenuKit: action \"%s\" not found in the Input Map." % action_name)
		return
	for action: StringName in InputMap.get_actions():
		var action_name: String = String(action)
		var excluded: bool = false
		for prefix: String in excluded_prefixes:
			if not prefix.is_empty() and action_name.begins_with(prefix):
				excluded = true
				break
		if not excluded:
			_add_action(action)


## Adds a rebindable action from code. If it is not in the InputMap it is created
## with [param default_events]. Returns false when it was already registered.
func register_action(action: StringName, default_events: Array[InputEvent] = []) -> bool:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		for event: InputEvent in default_events:
			InputMap.action_add_event(action, event)
	if _actions.has(action):
		return false
	_add_action(action)
	_read_action(_last_config, action)
	return true


## Actions shown in the Controls tab, in order.
func get_actions() -> Array[StringName]:
	return _actions.duplicate()


## Label of an action in the menu.
func get_action_label(action: StringName) -> String:
	if action_labels.has(action):
		return String(action_labels[action])
	if action_labels.has(String(action)):
		return String(action_labels[String(action)])
	return String(action).replace("/", " ").capitalize()


## Every event bound to an action.
func get_events(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	if InputMap.has_action(action):
		events.assign(InputMap.action_get_events(action))
	return events


## Events of one device type, in order.
func get_events_of_kind(action: StringName, kind: Kind) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	for event: InputEvent in get_events(action):
		if get_input_kind(event) == kind:
			result.append(event)
	return result


## Event in a slot, or [code]null[/code] when the slot is empty.
func get_binding(action: StringName, kind: Kind, slot: int = 0) -> InputEvent:
	var events: Array[InputEvent] = get_events_of_kind(action, kind)
	return events[slot] if slot >= 0 and slot < events.size() else null


## Binds [param event] to a slot (call [method find_conflict] first to avoid
## sharing an input between two actions).
func set_binding(action: StringName, kind: Kind, slot: int, event: InputEvent) -> void:
	if not InputMap.has_action(action) or event == null or get_input_kind(event) != kind:
		return
	var same_kind: Array[InputEvent] = get_events_of_kind(action, kind)
	var others: Array[InputEvent] = []
	for existing: InputEvent in get_events(action):
		if get_input_kind(existing) != kind:
			others.append(existing)
	for i: int in range(same_kind.size() - 1, -1, -1):
		if i != slot and is_same_input(same_kind[i], event):
			same_kind.remove_at(i)
			if i < slot:
				slot -= 1
	if slot >= 0 and slot < same_kind.size():
		same_kind[slot] = event
	else:
		same_kind.append(event)
	var merged: Array[InputEvent] = []
	if kind == Kind.KEYBOARD_MOUSE:
		merged.append_array(same_kind)
		merged.append_array(others)
	else:
		merged.append_array(others)
		merged.append_array(same_kind)
	_set_events(action, merged)


## Empties a slot.
func clear_binding(action: StringName, kind: Kind, slot: int = 0) -> void:
	var target: InputEvent = get_binding(action, kind, slot)
	if target == null:
		return
	var events: Array[InputEvent] = get_events(action)
	events.erase(target)
	_set_events(action, events)


## Action (other than [param ignored_action]) already using [param event], or
## [code]&""[/code].
func find_conflict(event: InputEvent, ignored_action: StringName = &"") -> StringName:
	for action: StringName in _actions:
		if action == ignored_action:
			continue
		for existing: InputEvent in get_events(action):
			if is_same_input(existing, event):
				return action
	return &""


## Conflict resolution: [param event] goes to the slot and the slot's previous input
## goes to [param other_action].
func swap_binding(action: StringName, kind: Kind, slot: int, event: InputEvent, other_action: StringName) -> void:
	var previous: InputEvent = get_binding(action, kind, slot)
	_replace_in_action(other_action, event, previous)
	set_binding(action, kind, slot, event)


## Conflict resolution: [param other_action] loses [param event].
func replace_binding(action: StringName, kind: Kind, slot: int, event: InputEvent, other_action: StringName) -> void:
	_replace_in_action(other_action, event, null)
	set_binding(action, kind, slot, event)


## Restores the project's default inputs of every action.
func reset_all() -> void:
	for action: StringName in _actions:
		_set_events(action, _get_defaults(action))


## Writes the bindings changed by the player to [param config].
func write(config: ConfigFile) -> void:
	for action: StringName in _actions:
		var events: Array[InputEvent] = get_events(action)
		if _same_lists(events, _get_defaults(action)):
			continue
		var serialized: Array = []
		for event: InputEvent in events:
			var data: Dictionary = event_to_dict(event)
			if not data.is_empty():
				serialized.append(data)
		config.set_value(SECTION, String(action), serialized)


## Restores defaults, then applies the bindings saved in [param config].
func read(config: ConfigFile) -> void:
	_last_config = config
	for action: StringName in _actions:
		_set_events(action, _get_defaults(action), false)
		_read_action(config, action)


func _add_action(action: StringName) -> void:
	_actions.append(action)
	var events: Array[InputEvent] = []
	for event: InputEvent in InputMap.action_get_events(action):
		events.append(event.duplicate() as InputEvent)
	_defaults[action] = events


func _read_action(config: ConfigFile, action: StringName) -> void:
	if config == null or not config.has_section_key(SECTION, String(action)):
		return
	var raw: Variant = config.get_value(SECTION, String(action), [])
	if not raw is Array:
		return
	var events: Array[InputEvent] = []
	for item: Variant in raw as Array:
		if item is Dictionary:
			var event: InputEvent = dict_to_event(item as Dictionary)
			if event != null:
				events.append(event)
	_set_events(action, events, false)


func _replace_in_action(action: StringName, old_event: InputEvent, new_event: InputEvent) -> void:
	var result: Array[InputEvent] = []
	var already_has_new: bool = false
	if new_event != null:
		for existing: InputEvent in get_events(action):
			if is_same_input(existing, new_event):
				already_has_new = true
	for existing: InputEvent in get_events(action):
		if is_same_input(existing, old_event):
			if new_event != null and not already_has_new:
				result.append(new_event.duplicate() as InputEvent)
		else:
			result.append(existing)
	_set_events(action, result)


func _get_defaults(action: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	if _defaults.has(action):
		for event: InputEvent in _defaults[action] as Array[InputEvent]:
			result.append(event.duplicate() as InputEvent)
	return result


func _set_events(action: StringName, events: Array[InputEvent], notify: bool = true) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)
	if notify:
		bindings_changed.emit(action)


func _same_lists(a: Array[InputEvent], b: Array[InputEvent]) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if not is_same_input(a[i], b[i]):
			return false
	return true


# --------------------------------------------------------------------------
# Event helpers
# --------------------------------------------------------------------------

## Device type of an event, or -1 if it cannot be bound.
static func get_input_kind(event: InputEvent) -> int:
	if event is InputEventKey or event is InputEventMouseButton:
		return Kind.KEYBOARD_MOUSE
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return Kind.GAMEPAD
	return -1


## Compares two events, ignoring the device and irrelevant details.
static func is_same_input(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventKey and b is InputEventKey:
		return _key_identity(a as InputEventKey) == _key_identity(b as InputEventKey)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		var motion_a: InputEventJoypadMotion = a as InputEventJoypadMotion
		var motion_b: InputEventJoypadMotion = b as InputEventJoypadMotion
		return motion_a.axis == motion_b.axis and signf(motion_a.axis_value) == signf(motion_b.axis_value)
	return false


## Readable label of an event ("Space", "Left Click", "A / Cross", "L Stick ←"...).
static func get_event_label(event: InputEvent) -> String:
	if event == null:
		return "—"
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		var keycode: Key = key_event.keycode
		if key_event.physical_keycode != KEY_NONE:
			keycode = key_event.physical_keycode
			# Show the key of the player's keyboard layout (AZERTY, QWERTZ...).
			if DisplayServer.get_name() != "headless":
				keycode = DisplayServer.keyboard_get_keycode_from_physical(key_event.physical_keycode)
		if KEY_LABELS.has(keycode):
			return _tr(String(KEY_LABELS[keycode]))
		var text: String = OS.get_keycode_string(keycode)
		return text if not text.is_empty() else key_event.as_text()
	if event is InputEventMouseButton:
		var index: int = (event as InputEventMouseButton).button_index
		if MOUSE_BUTTON_LABELS.has(index):
			return _tr(String(MOUSE_BUTTON_LABELS[index]))
		return _tr("Mouse %d") % index
	if event is InputEventJoypadButton:
		var button: int = (event as InputEventJoypadButton).button_index
		if JOY_BUTTON_LABELS.has(button):
			return _tr(String(JOY_BUTTON_LABELS[button]))
		return _tr("Button %d") % button
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		if JOY_AXIS_LABELS.has(motion.axis):
			var labels: Array = JOY_AXIS_LABELS[motion.axis]
			return _tr(String(labels[1 if motion.axis_value > 0.0 else 0]))
		return _tr("Axis %d %s") % [motion.axis, "+" if motion.axis_value > 0.0 else "-"]
	return event.as_text()


## Converts an event to a Dictionary that can be saved (empty if unsupported).
static func event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		return {
			"type": "key",
			"physical_keycode": int(key_event.physical_keycode),
			"keycode": int(key_event.keycode),
		}
	if event is InputEventMouseButton:
		return {"type": "mouse_button", "button_index": int((event as InputEventMouseButton).button_index)}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button_index": int((event as InputEventJoypadButton).button_index)}
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		return {"type": "joy_motion", "axis": int(motion.axis), "axis_value": signf(motion.axis_value)}
	return {}


## Rebuilds an event saved with [method event_to_dict] ([code]null[/code] if invalid).
static func dict_to_event(data: Dictionary) -> InputEvent:
	match String(data.get("type", "")):
		"key":
			var key_event: InputEventKey = InputEventKey.new()
			key_event.physical_keycode = int(data.get("physical_keycode", 0)) as Key
			key_event.keycode = int(data.get("keycode", 0)) as Key
			if key_event.physical_keycode == KEY_NONE and key_event.keycode == KEY_NONE:
				return null
			return key_event
		"mouse_button":
			var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
			mouse_event.button_index = int(data.get("button_index", 0)) as MouseButton
			return mouse_event if mouse_event.button_index != MOUSE_BUTTON_NONE else null
		"joy_button":
			var joy_button: InputEventJoypadButton = InputEventJoypadButton.new()
			joy_button.device = -1
			joy_button.button_index = int(data.get("button_index", -1)) as JoyButton
			return joy_button if joy_button.button_index != JOY_BUTTON_INVALID else null
		"joy_motion":
			var joy_motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
			joy_motion.device = -1
			joy_motion.axis = int(data.get("axis", -1)) as JoyAxis
			joy_motion.axis_value = 1.0 if float(data.get("axis_value", 1.0)) >= 0.0 else -1.0
			return joy_motion if joy_motion.axis != JOY_AXIS_INVALID else null
	return null


## Builds a clean binding from a pressed input, or [code]null[/code] when it is not
## of the [param kind] device type (used by the menu while waiting for an input).
static func make_binding(event: InputEvent, kind: Kind) -> InputEvent:
	if not event.is_pressed() or event.is_echo():
		return null
	if kind == Kind.KEYBOARD_MOUSE:
		if event is InputEventKey:
			var source_key: InputEventKey = event as InputEventKey
			var key_event: InputEventKey = InputEventKey.new()
			if source_key.physical_keycode != KEY_NONE:
				key_event.physical_keycode = source_key.physical_keycode
			elif source_key.keycode != KEY_NONE:
				key_event.keycode = source_key.keycode
			else:
				return null
			return key_event
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
			mouse_event.button_index = (event as InputEventMouseButton).button_index
			return mouse_event
	else:
		if event is InputEventJoypadButton:
			var joy_button: InputEventJoypadButton = InputEventJoypadButton.new()
			joy_button.device = -1
			joy_button.button_index = (event as InputEventJoypadButton).button_index
			return joy_button
		if event is InputEventJoypadMotion:
			var source_motion: InputEventJoypadMotion = event as InputEventJoypadMotion
			if absf(source_motion.axis_value) < AXIS_THRESHOLD:
				return null
			var joy_motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
			joy_motion.device = -1
			joy_motion.axis = source_motion.axis
			joy_motion.axis_value = signf(source_motion.axis_value)
			return joy_motion
	return null


static func _key_identity(key_event: InputEventKey) -> int:
	if key_event.physical_keycode != KEY_NONE:
		return int(key_event.physical_keycode)
	return int(key_event.keycode)


static func _tr(text: String) -> String:
	return String(TranslationServer.translate(text))
