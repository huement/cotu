class_name MenuKitOptionRow
extends MenuKitControl
## One line of the options menu, built from a [MenuKitSetting].
##
## Up / down move between lines, left / right change the value, Enter (or the
## gamepad's A button) switches, cycles or starts rebinding. The mouse can drag
## sliders and click every part.

## A new binding is already used by [param other_action]: the options menu asks
## the player what to do.
signal binding_conflict(row: MenuKitOptionRow, kind: int, event: InputEvent, other_action: StringName)

const NO_PART: int = -99
const KEY_COLUMNS: int = 2

var setting: MenuKitSetting

var _value: Variant = null
var _dragging: bool = false
var _hovered_part: int = NO_PART
var _switch_amount: float = 0.0
var _switch_tween: Tween
var _key_index: int = 0
var _listening: int = -1


func _init(p_setting: MenuKitSetting = null) -> void:
	super()
	setting = p_setting
	press_sound = &""
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func _ready() -> void:
	super()
	MenuKit.setting_changed.connect(_on_setting_changed)
	set_process(false)
	sync_value()


func _exit_tree() -> void:
	if _listening != -1:
		_stop_listening(false)


## Reads the current value of the setting again.
func sync_value(animate: bool = false) -> void:
	if setting == null:
		return
	if setting.type != MenuKitSetting.Type.BINDING:
		_value = MenuKit.settings.get_value(setting.key)
	if setting.type == MenuKitSetting.Type.TOGGLE:
		_animate_switch(1.0 if bool(_value) else 0.0, animate)
	refresh()


func is_listening() -> bool:
	return _listening != -1


func _on_setting_changed(key: String, _new_value: Variant) -> void:
	if setting == null:
		return
	if key == setting.key or (setting.type == MenuKitSetting.Type.BINDING and key.begins_with("bindings/")):
		sync_value(true)


# --------------------------------------------------------------------------
# Size and drawing
# --------------------------------------------------------------------------

func _get_minimum_size() -> Vector2:
	if MenuKit.style == null or setting == null:
		return Vector2.ZERO
	var style: MenuKitStyle = kit_style()
	var controls: float = _controls_width()
	return Vector2(style.text_width(&"label", get_label()) + style.em * 1.5 + controls, style.row_height())


## Label shown on the left.
func get_label() -> String:
	if setting.type == MenuKitSetting.Type.BINDING:
		return tr(MenuKit.input.get_action_label(setting.action))
	return tr(setting.label)


## Text of the current value (as shown / read aloud).
func get_value_text() -> String:
	match setting.type:
		MenuKitSetting.Type.RANGE:
			return setting.format_value(_value)
		MenuKitSetting.Type.TOGGLE:
			return tr("On") if bool(_value) else tr("Off")
		MenuKitSetting.Type.CHOICE, MenuKitSetting.Type.LIST:
			var index: int = setting.find_option(_value)
			return tr(setting.options[index]) if index >= 0 and index < setting.options.size() else ""
		MenuKitSetting.Type.BINDING:
			return _binding_text(_key_index)
	return ""


func get_spoken_text() -> String:
	return get_label() + ", " + get_value_text()


func _draw() -> void:
	if setting == null:
		return
	var style: MenuKitStyle = kit_style()
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var active: bool = has_focus()
	style.draw_row(self, rect, get_label())
	var parts: Dictionary = _layout()
	match setting.type:
		MenuKitSetting.Type.RANGE:
			style.draw_slider(self, parts["slider"] as Rect2, _ratio(), active or _dragging)
			style.draw_value(self, parts["value"] as Rect2, setting.format_value(_value))
		MenuKitSetting.Type.TOGGLE:
			style.draw_switch(self, parts["control"] as Rect2, _switch_amount, active)
		MenuKitSetting.Type.CHOICE:
			style.draw_segments(self, parts["control"] as Rect2, _option_labels(), parts["widths"] as PackedFloat32Array,
				setting.find_option(_value), _hovered_part, active)
		MenuKitSetting.Type.LIST:
			style.draw_stepper(self, parts["control"] as Rect2, get_value_text(),
				_hovered_part if _hovered_part == -1 or _hovered_part == 1 else 0, active)
		MenuKitSetting.Type.BINDING:
			var keys: Array = parts["keys"]
			var time: float = Time.get_ticks_msec() / 1000.0
			for i: int in keys.size():
				var highlighted: bool = (active and _key_index == i) or _hovered_part == i
				style.draw_key(self, keys[i] as Rect2, _binding_text(i), highlighted, _listening == i, time)


## Rects of the parts of the row: control, slider, value, widths, keys.
func _layout() -> Dictionary:
	var style: MenuKitStyle = kit_style()
	var em: float = style.em
	var w: float = size.x
	var h: float = size.y
	var result: Dictionary = {}
	match setting.type:
		MenuKitSetting.Type.RANGE:
			var value_w: float = style.value_width()
			var slider_w: float = clampf((w - value_w - 2.0 * em) * 1.25 / 2.25, 6.0 * em, 17.0 * em)
			result["slider"] = Rect2(w - value_w - em - slider_w, 0, slider_w, h)
			result["value"] = Rect2(w - value_w, 0, value_w, h)
			result["control"] = Rect2(w - value_w - em - slider_w, 0, slider_w + em + value_w, h)
		MenuKitSetting.Type.TOGGLE:
			var switch_size: Vector2 = style.switch_size()
			result["control"] = Rect2(w - switch_size.x, (h - switch_size.y) * 0.5, switch_size.x, switch_size.y)
		MenuKitSetting.Type.CHOICE:
			var widths: PackedFloat32Array = PackedFloat32Array()
			var total: float = 0.0
			for label: String in _option_labels():
				var width: float = style.segment_width(label)
				widths.append(width)
				total += width
			var seg_h: float = style.segment_height()
			result["widths"] = widths
			result["control"] = Rect2(w - total, (h - seg_h) * 0.5, total, seg_h)
		MenuKitSetting.Type.LIST:
			var arrow: float = style.stepper_arrow_size()
			var total_w: float = arrow * 2.0 + style.stepper_value_width()
			result["control"] = Rect2(w - total_w, 0, total_w, h)
			result["left"] = Rect2(w - total_w, (h - arrow) * 0.5, arrow, arrow)
			result["right"] = Rect2(w - arrow, (h - arrow) * 0.5, arrow, arrow)
		MenuKitSetting.Type.BINDING:
			var key_size: Vector2 = style.key_size()
			var gap: float = 0.6 * em
			var keys: Array = []
			for i: int in KEY_COLUMNS:
				var x: float = w - key_size.x * float(KEY_COLUMNS - i) - gap * float(KEY_COLUMNS - 1 - i)
				keys.append(Rect2(x, (h - key_size.y) * 0.5, key_size.x, key_size.y))
			result["keys"] = keys
			result["control"] = Rect2((keys[0] as Rect2).position.x, 0, w - (keys[0] as Rect2).position.x, h)
	return result


func _controls_width() -> float:
	var style: MenuKitStyle = kit_style()
	match setting.type:
		MenuKitSetting.Type.RANGE:
			return style.value_width() + style.em + 8.0 * style.em
		MenuKitSetting.Type.TOGGLE:
			return style.switch_size().x
		MenuKitSetting.Type.CHOICE:
			var total: float = 0.0
			for label: String in _option_labels():
				total += style.segment_width(label)
			return total
		MenuKitSetting.Type.LIST:
			return style.stepper_arrow_size() * 2.0 + style.stepper_value_width()
		MenuKitSetting.Type.BINDING:
			return style.key_size().x * KEY_COLUMNS + 0.6 * style.em * (KEY_COLUMNS - 1)
	return 0.0


func _option_labels() -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	for option: String in setting.options:
		labels.append(tr(option))
	return labels


func _ratio() -> float:
	var span: float = setting.max_value - setting.min_value
	if span <= 0.0:
		return 0.0
	return clampf((float(_value) - setting.min_value) / span, 0.0, 1.0)


func _binding_text(index: int) -> String:
	if _listening == index:
		return tr("Press a key…") if index == 0 else tr("Press a button…")
	var event: InputEvent = MenuKit.input.get_binding(setting.action, index as MenuKitInput.Kind)
	return MenuKitInput.get_event_label(event)


func _part_at(position: Vector2) -> int:
	var parts: Dictionary = _layout()
	match setting.type:
		MenuKitSetting.Type.CHOICE:
			var control: Rect2 = parts["control"]
			if not control.grow(2.0).has_point(position):
				return NO_PART
			var x: float = control.position.x
			var widths: PackedFloat32Array = parts["widths"]
			for i: int in widths.size():
				if position.x < x + widths[i]:
					return i
				x += widths[i]
			return widths.size() - 1
		MenuKitSetting.Type.LIST:
			if (parts["left"] as Rect2).grow(4.0).has_point(position):
				return -1
			if (parts["right"] as Rect2).grow(4.0).has_point(position):
				return 1
			if (parts["control"] as Rect2).has_point(position):
				return 0
		MenuKitSetting.Type.BINDING:
			var keys: Array = parts["keys"]
			for i: int in keys.size():
				if (keys[i] as Rect2).grow(2.0).has_point(position):
					return i
	return NO_PART


# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if setting == null:
		return
	if _listening != -1:
		accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if _dragging:
			_set_from_x(motion.position.x)
		var part: int = _part_at(motion.position)
		if part != _hovered_part:
			_hovered_part = part
			queue_redraw()
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null:
		_handle_mouse_button(mouse)
		return
	if event.is_action_pressed(&"ui_left", true):
		accept_event()
		_nudge(-1)
	elif event.is_action_pressed(&"ui_right", true):
		accept_event()
		_nudge(1)
	elif event.is_action_pressed(&"ui_accept", false, true):
		accept_event()
		_accept()
	elif setting.type == MenuKitSetting.Type.BINDING and event is InputEventKey and event.is_pressed() \
			and ((event as InputEventKey).keycode == KEY_DELETE or (event as InputEventKey).keycode == KEY_BACKSPACE):
		accept_event()
		_clear_binding(_key_index)


func _handle_mouse_button(mouse: InputEventMouseButton) -> void:
	if mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
		if _dragging:
			_dragging = false
			queue_redraw()
		accept_event()
		return
	if not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_RIGHT and setting.type == MenuKitSetting.Type.BINDING:
		var part: int = _part_at(mouse.position)
		if part >= 0:
			accept_event()
			_clear_binding(part)
		return
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if not has_focus():
		grab_focus()
	var parts: Dictionary = _layout()
	match setting.type:
		MenuKitSetting.Type.RANGE:
			if (parts["control"] as Rect2).has_point(mouse.position):
				_dragging = true
				_set_from_x(mouse.position.x)
		MenuKitSetting.Type.TOGGLE:
			_set_value(not bool(_value))
		MenuKitSetting.Type.CHOICE:
			var part: int = _part_at(mouse.position)
			if part >= 0:
				_set_value(setting.get_option_value(part))
		MenuKitSetting.Type.LIST:
			var part: int = _part_at(mouse.position)
			if part == -1:
				_step_list(-1)
			elif part == 1 or part == 0:
				_step_list(1)
		MenuKitSetting.Type.BINDING:
			var part: int = _part_at(mouse.position)
			if part >= 0:
				_key_index = part
				_start_listening()


func _nudge(direction: int) -> void:
	match setting.type:
		MenuKitSetting.Type.RANGE:
			_set_value(float(_value) + setting.get_keyboard_step() * direction)
		MenuKitSetting.Type.TOGGLE:
			_set_value(direction > 0)
		MenuKitSetting.Type.CHOICE:
			var index: int = setting.find_option(_value)
			var next: int = clampi(index + direction, 0, setting.get_option_count() - 1)
			if next != index:
				_set_value(setting.get_option_value(next))
		MenuKitSetting.Type.LIST:
			_step_list(direction)
		MenuKitSetting.Type.BINDING:
			var next_key: int = clampi(_key_index + direction, 0, KEY_COLUMNS - 1)
			if next_key != _key_index:
				_key_index = next_key
				MenuKit.sounds.play(&"move")
				MenuKit.speak(_binding_text(_key_index))
				queue_redraw()


func _accept() -> void:
	match setting.type:
		MenuKitSetting.Type.TOGGLE:
			_set_value(not bool(_value))
		MenuKitSetting.Type.CHOICE:
			var count: int = setting.get_option_count()
			if count > 0:
				_set_value(setting.get_option_value((setting.find_option(_value) + 1) % count))
		MenuKitSetting.Type.LIST:
			_step_list(1)
		MenuKitSetting.Type.BINDING:
			_start_listening()


func _step_list(direction: int) -> void:
	var count: int = setting.get_option_count()
	if count == 0:
		return
	var index: int = maxi(setting.find_option(_value), 0)
	_set_value(setting.get_option_value((index + direction + count) % count))


func _set_from_x(x: float) -> void:
	var slider: Rect2 = _layout()["slider"]
	var ratio: float = clampf((x - slider.position.x) / maxf(slider.size.x, 1.0), 0.0, 1.0)
	_set_value(lerpf(setting.min_value, setting.max_value, ratio))


func _set_value(value: Variant) -> void:
	var clean: Variant = setting.sanitize(value)
	if MenuKitSetting.values_equal(clean, _value):
		return
	MenuKit.settings.set_value(setting.key, clean)
	_value = MenuKit.settings.get_value(setting.key)
	match setting.type:
		MenuKitSetting.Type.RANGE:
			MenuKit.sounds.play(&"tick")
		MenuKitSetting.Type.TOGGLE:
			MenuKit.sounds.play_toggle(bool(_value))
			_animate_switch(1.0 if bool(_value) else 0.0, true)
		MenuKitSetting.Type.CHOICE:
			MenuKit.sounds.play(&"toggle_on")
		MenuKitSetting.Type.LIST:
			MenuKit.sounds.play(&"tick")
	MenuKit.speak(get_value_text())
	queue_redraw()


func _animate_switch(target: float, animate: bool) -> void:
	if _switch_tween != null:
		_switch_tween.kill()
	if not animate or not is_inside_tree():
		_switch_amount = target
		queue_redraw()
		return
	_switch_tween = create_tween()
	_switch_tween.tween_method(_set_switch_amount, _switch_amount, target, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_switch_amount(value: float) -> void:
	_switch_amount = value
	queue_redraw()


# --------------------------------------------------------------------------
# Rebinding
# --------------------------------------------------------------------------

func _start_listening() -> void:
	_listening = _key_index
	MenuKitControl.input_locked = true
	MenuKit.sounds.play(&"select")
	MenuKit.speak(_binding_text(_listening))
	set_process(true)
	queue_redraw()


func _stop_listening(play_sound: bool) -> void:
	_listening = -1
	MenuKitControl.input_locked = false
	set_process(false)
	if play_sound:
		MenuKit.sounds.play(&"back")
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _listening == -1 or event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo():
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE):
		_stop_listening(true)
		return
	var kind: int = _listening
	var binding: InputEvent = MenuKitInput.make_binding(event, kind as MenuKitInput.Kind)
	if binding == null:
		return
	_stop_listening(false)
	var conflict: StringName = MenuKit.input.find_conflict(binding, setting.action)
	if conflict == &"":
		MenuKit.input.set_binding(setting.action, kind as MenuKitInput.Kind, 0, binding)
		MenuKit.sounds.play_toggle(true)
		MenuKit.speak(_binding_text(kind))
	else:
		binding_conflict.emit(self, kind, binding, conflict)


func _clear_binding(index: int) -> void:
	if MenuKit.input.get_binding(setting.action, index as MenuKitInput.Kind) == null:
		return
	MenuKit.input.clear_binding(setting.action, index as MenuKitInput.Kind, 0)
	MenuKit.sounds.play_toggle(false)
