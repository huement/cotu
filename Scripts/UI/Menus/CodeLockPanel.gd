# res://Scripts/UI/Menus/CodeLockPanel.gd
class_name CodeLockPanel
extends CanvasLayer
## Full-screen combination lock: big digit dials the player rolls (▲/▼, mouse wheel) or types.
## Pauses the game while open. Wrong code = red shake; right code = green glow, then it closes.
##
##     var lock := CodeLockPanel.open(get_tree(), "1234", "ANCIENT LOCK", "A hint...")
##     lock.solved.connect(_on_lock_solved)
##
## Keys: 0-9 type into the selected dial (and move right), ← → select, ↑ ↓ roll,
## Backspace = back one, Enter = try the code, Esc = leave.

signal solved
signal closed

const DIGIT_FONT: FontFile = preload("res://ui/fonts/GALAXIA.otf")
const ARROW_UP: Texture2D = preload("res://ui/icons/arrow_up.svg")
const ARROW_DOWN: Texture2D = preload("res://ui/icons/arrow_down.svg")
const COLOR_WRONG: Color = Color(1.0, 0.25, 0.3)
const COLOR_RIGHT: Color = Color(0.35, 1.0, 0.55)
const DIGIT_FONT_SIZE: int = 120
const DIAL_SIZE: Vector2 = Vector2(128.0, 168.0)

var code: String = "1234"
var _digits: Array[int] = []
var _selected: int = 0
var _busy: bool = false
var _was_paused: bool = false

var _panel: PanelContainer
var _dial_tiles: Array[PanelContainer] = []
var _dial_labels: Array[Label] = []
var _status: Label
var _unlock_button: Button


## Opens a lock for [param p_code] (its length sets the number of dials).
static func open(tree: SceneTree, p_code: String, title: String = "ANCIENT LOCK", hint: String = "") -> CodeLockPanel:
	var panel := CodeLockPanel.new()
	panel.code = p_code
	tree.root.add_child(panel)
	panel._build(title, hint)
	return panel


func _init() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true


# ------------------------------------------------------------------------------
# UI
# ------------------------------------------------------------------------------
func _build(title: String, hint: String) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", ShardsMenuStyle.panel_box())
	center.add_child(_panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 28)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ShardsMenuStyle.style_title(title_label, 28)
	vbox.add_child(title_label)

	if not hint.is_empty():
		var hint_label := Label.new()
		hint_label.text = hint
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_label.custom_minimum_size = Vector2(560.0, 0.0)
		ShardsMenuStyle.style_body(hint_label, 15, true)
		vbox.add_child(hint_label)

	var dials := HBoxContainer.new()
	dials.alignment = BoxContainer.ALIGNMENT_CENTER
	dials.add_theme_constant_override("separation", 18)
	vbox.add_child(dials)
	for i: int in code.length():
		_digits.append(0)
		dials.add_child(_build_dial(i))

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.text = "Roll the dials or type the code"
	ShardsMenuStyle.style_body(_status, 14, true)
	vbox.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	vbox.add_child(buttons)
	var leave := ShardsMenuStyle.make_row_button("LEAVE")
	leave.focus_mode = Control.FOCUS_NONE
	leave.pressed.connect(close)
	buttons.add_child(leave)
	_unlock_button = ShardsMenuStyle.make_row_button("UNLOCK", null, COLOR_RIGHT)
	_unlock_button.focus_mode = Control.FOCUS_NONE
	_unlock_button.custom_minimum_size = Vector2(200.0, 52.0)
	_unlock_button.pressed.connect(_submit)
	buttons.add_child(_unlock_button)

	_refresh()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.94, 0.94)
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.2)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.3)
	_play_sound("open-menu")


func _build_dial(index: int) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)

	var up := ShardsMenuStyle.make_row_button("", ARROW_UP)
	up.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up.custom_minimum_size = Vector2(DIAL_SIZE.x, 40.0)
	up.focus_mode = Control.FOCUS_NONE
	up.pressed.connect(_roll.bind(index, 1))
	column.add_child(up)

	var tile := PanelContainer.new()
	tile.custom_minimum_size = DIAL_SIZE
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.gui_input.connect(_on_dial_input.bind(index))
	column.add_child(tile)
	_dial_tiles.append(tile)

	var digit := Label.new()
	digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	digit.add_theme_font_override("font", DIGIT_FONT)
	digit.add_theme_font_size_override("font_size", DIGIT_FONT_SIZE)
	digit.add_theme_constant_override("outline_size", 10)
	tile.add_child(digit)
	_dial_labels.append(digit)

	var down := ShardsMenuStyle.make_row_button("", ARROW_DOWN)
	down.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	down.custom_minimum_size = Vector2(DIAL_SIZE.x, 40.0)
	down.focus_mode = Control.FOCUS_NONE
	down.pressed.connect(_roll.bind(index, -1))
	column.add_child(down)
	return column


func _refresh(flash: Color = Color(0, 0, 0, 0)) -> void:
	for i: int in _dial_labels.size():
		var selected: bool = i == _selected
		var accent: Color = flash if flash.a > 0.0 else (ShardsMenuStyle.COLOR_ACCENT if selected else ShardsMenuStyle.COLOR_BORDER)
		var box: StyleBoxFlat = ShardsMenuStyle.box(Color(0.0, 0.0, 0.0, 0.95), accent, 3 if selected or flash.a > 0.0 else 2, 8)
		box.shadow_color = Color(accent, 0.45 if selected or flash.a > 0.0 else 0.0)
		box.shadow_size = 14
		_dial_tiles[i].add_theme_stylebox_override("panel", box)
		_dial_labels[i].text = str(_digits[i])
		var text_color: Color = flash if flash.a > 0.0 else (Color.WHITE if selected else ShardsMenuStyle.COLOR_TEXT)
		_dial_labels[i].add_theme_color_override("font_color", text_color)
		_dial_labels[i].add_theme_color_override("font_outline_color", Color(accent, 0.35))


# ------------------------------------------------------------------------------
# Input
# ------------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if _busy:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
	elif event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		var digit: int = _key_digit(key)
		if digit >= 0:
			_set_digit(_selected, digit)
			_select(mini(_selected + 1, _digits.size() - 1))
		elif key.keycode == KEY_BACKSPACE:
			_select(maxi(_selected - 1, 0))
		elif key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_submit()
		elif key.keycode == KEY_LEFT:
			_select(wrapi(_selected - 1, 0, _digits.size()))
		elif key.keycode == KEY_RIGHT:
			_select(wrapi(_selected + 1, 0, _digits.size()))
		elif key.keycode == KEY_UP:
			_roll(_selected, 1)
		elif key.keycode == KEY_DOWN:
			_roll(_selected, -1)
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


func _on_dial_input(event: InputEvent, index: int) -> void:
	if _busy or not (event is InputEventMouseButton) or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_roll(index, 1)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_roll(index, -1)
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		_select(index)


func _key_digit(key: InputEventKey) -> int:
	if key.keycode >= KEY_0 and key.keycode <= KEY_9:
		return key.keycode - KEY_0
	if key.keycode >= KEY_KP_0 and key.keycode <= KEY_KP_9:
		return key.keycode - KEY_KP_0
	return -1


func _roll(index: int, step: int) -> void:
	if _busy:
		return
	_select(index)
	_set_digit(index, wrapi(_digits[index] + step, 0, 10))


func _set_digit(index: int, value: int) -> void:
	_digits[index] = value
	_play_sound("button-click")
	_refresh()
	# Little roll bounce on the changed dial.
	var label: Label = _dial_labels[index]
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(1.0, 0.75)
	create_tween().tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _select(index: int) -> void:
	_selected = index
	_refresh()


# ------------------------------------------------------------------------------
# Result
# ------------------------------------------------------------------------------
func entered_code() -> String:
	var text: String = ""
	for d: int in _digits:
		text += str(d)
	return text


func _submit() -> void:
	if _busy:
		return
	if entered_code() == code:
		_on_right()
	else:
		_on_wrong()


func _on_wrong() -> void:
	_busy = true
	_play_sound("button-close")
	_status.text = "The lock doesn't budge."
	_status.add_theme_color_override("font_color", COLOR_WRONG)
	_refresh(COLOR_WRONG)
	var start: Vector2 = _panel.position
	var tween: Tween = create_tween()
	for offset: float in [-18.0, 16.0, -12.0, 8.0, -4.0, 0.0]:
		tween.tween_property(_panel, "position:x", start.x + offset, 0.045)
	await tween.finished
	await get_tree().create_timer(0.35, true, false, true).timeout
	_busy = false
	_status.add_theme_color_override("font_color", ShardsMenuStyle.COLOR_MUTED)
	_status.text = "Roll the dials or type the code"
	_select(0) # typing again starts from the first dial


func _on_right() -> void:
	_busy = true
	_play_sound("button-confirm")
	_status.text = "CLICK. The lock gives way!"
	_status.add_theme_color_override("font_color", COLOR_RIGHT)
	_refresh(COLOR_RIGHT)
	var tween: Tween = create_tween().set_parallel(true)
	for label: Label in _dial_labels:
		label.pivot_offset = label.size * 0.5
		tween.tween_property(label, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.0, true, false, true).timeout
	solved.emit()
	close()


func close() -> void:
	if not is_inside_tree():
		return
	get_tree().paused = _was_paused
	closed.emit()
	queue_free()


func _play_sound(sound_name: String) -> void:
	if is_instance_valid(AudioManager) and AudioManager.has_method("play_ui_sound"):
		AudioManager.play_ui_sound(sound_name)
