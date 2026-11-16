class_name MenuKitControl
extends Control
## Base of the kit's widgets: drawn by the active [MenuKitStyle], focused when the
## mouse moves over them (mouse, keyboard and gamepad share one highlight), with a
## soft sound when the focus moves.

## Emitted on click, Enter / Space or the gamepad's A button.
signal pressed

## True while a widget captures every input (waiting for a key to bind): the
## mouse no longer moves the focus.
static var input_locked: bool = false

## Focus highlight, animated from 0 to 1.
var focus_amount: float = 0.0
## Press feedback, animated from 1 to 0 after a press.
var press_amount: float = 0.0
## Entrance animation, from 0 (hidden) to 1.
var appear: float = 1.0:
	set(value):
		appear = value
		_update_appear()
## Time (seconds) when the control got the focus.
var focus_time: float = -10.0
## Disabled controls stay visible but cannot be used.
var disabled: bool = false:
	set(value):
		disabled = value
		modulate.a = 0.4 if disabled else 1.0
		queue_redraw()
## Sound played by [method activate] ("" for none).
var press_sound: StringName = &"select"
## Text read aloud when focused (see the "Read menus aloud" setting).
var spoken_text: String = ""

var _focus_tween: Tween
var _press_tween: Tween
var _mouse_down: bool = false


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_entered.connect(_on_mouse_entered)
	MenuKit.ui_scale_changed.connect(refresh)
	MenuKit.style_changed.connect(refresh)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Recomputes the size and redraws (after a change of text, style or scale).
func refresh() -> void:
	update_minimum_size()
	queue_redraw()


func kit_style() -> MenuKitStyle:
	return MenuKit.style


## Seconds since the control got the focus.
func focus_age() -> float:
	return Time.get_ticks_msec() / 1000.0 - focus_time


## Presses the control (same as a click).
func activate() -> void:
	if MenuKit.is_loading():
		return
	if disabled:
		MenuKit.sounds.play(&"deny")
		return
	if not press_sound.is_empty():
		MenuKit.sounds.play(press_sound)
	_animate_press()
	pressed.emit()


func _gui_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:
		if mouse.pressed:
			_mouse_down = true
			if not has_focus():
				grab_focus()
			accept_event()
		elif _mouse_down:
			_mouse_down = false
			accept_event()
			if Rect2(Vector2.ZERO, size).has_point(mouse.position):
				activate()
		return
	if event.is_action_pressed(&"ui_accept", false, true):
		accept_event()
		activate()


func _on_mouse_entered() -> void:
	if not has_focus() and is_visible_in_tree() and focus_mode != Control.FOCUS_NONE and not input_locked:
		grab_focus()


func _on_focus_entered() -> void:
	focus_time = Time.get_ticks_msec() / 1000.0
	_animate_focus(1.0)
	MenuKit.sounds.play(&"move")
	var text: String = get_spoken_text()
	if not text.is_empty():
		MenuKit.speak(text)


func _on_focus_exited() -> void:
	_animate_focus(0.0)


## Text read aloud on focus.
func get_spoken_text() -> String:
	return spoken_text


func _animate_focus(target: float) -> void:
	if _focus_tween != null:
		_focus_tween.kill()
	var duration: float = 0.24 if target > focus_amount else 0.2
	_focus_tween = create_tween()
	_focus_tween.tween_method(_set_focus_amount, focus_amount, target, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_focus_amount(value: float) -> void:
	focus_amount = value
	queue_redraw()


func _animate_press() -> void:
	if _press_tween != null:
		_press_tween.kill()
	press_amount = 1.0
	_press_tween = create_tween()
	_press_tween.tween_method(_set_press_amount, 1.0, 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_press_amount(value: float) -> void:
	press_amount = value
	queue_redraw()


func _update_appear() -> void:
	var transform: Array = kit_style().appear_transform(self, appear) if MenuKit.style != null else [Vector2.ZERO, appear]
	self_modulate.a = float(transform[1])
	queue_redraw()


## Draw offset of the entrance animation (styles call draw_set_transform with it).
func appear_offset() -> Vector2:
	if appear >= 1.0 or MenuKit.style == null:
		return Vector2.ZERO
	return kit_style().appear_transform(self, appear)[0] as Vector2
