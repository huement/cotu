class_name MenuKitPanel
extends Control
## Framed window of the kit (options, save slots, dialogs): a title, a tag, the
## [member content] box and the [member footer] buttons, opened and closed with
## the style's animation. Esc / gamepad B emits [signal back_requested].

signal opened
signal closed
## Esc, gamepad B or a Back button while the panel is on top.
signal back_requested

## Title of the frame (translated).
var title: String = "":
	set(value):
		title = value
		if _frame != null:
			_frame.queue_redraw()
## Small text at the top right of the frame (not translated).
var tag: String = "":
	set(value):
		tag = value
		if _frame != null:
			_frame.queue_redraw()
## Height follows the content (dialogs) instead of the style's panel size.
var fit_height: bool = false
## Close automatically on Esc / gamepad B.
var close_on_back: bool = true
## Your widgets go here.
var content: VBoxContainer
## Buttons at the bottom right.
var footer: HBoxContainer
var is_open: bool = false
## Control focused again when the panel closes (by default, the one focused when it opened).
var return_focus: Control
## 0 to 1 while the style reveals the frame.
var reveal: float = 1.0:
	set(value):
		reveal = value
		_update_clip()

var _clip: Control
var _frame: Control
var _body: VBoxContainer
var _frame_rect: Rect2 = Rect2()
var _tween: Tween
var _backdrop: Control
var _backdrop_style: MenuKitStyle


func _init() -> void:
	name = "Panel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_clip = Control.new()
	_clip.name = "Clip"
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	_frame.draw.connect(_draw_frame)
	_clip.add_child(_frame)
	_body = VBoxContainer.new()
	_body.name = "Body"
	_frame.add_child(_body)
	content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(content)
	footer = HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_END
	_body.add_child(footer)


func _ready() -> void:
	resized.connect(layout)
	MenuKit.ui_scale_changed.connect(layout)
	MenuKit.style_changed.connect(layout)
	layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _frame != null:
		_frame.queue_redraw()


## Maximum size of the frame, in pixels.
func get_frame_size() -> Vector2:
	return MenuKit.style.options_size()


## Rectangle of the frame on screen.
func get_frame_rect() -> Rect2:
	return _frame_rect


## Recomputes the frame size (window resized, text size changed...).
func layout() -> void:
	if not is_inside_tree() or MenuKit.style == null:
		return
	var style: MenuKitStyle = MenuKit.style
	var em: float = style.em
	var view: Vector2 = size
	var pad: Vector2 = style.panel_padding()
	var header: float = style.panel_header_height()
	_body.add_theme_constant_override("separation", roundi(1.1 * em))
	footer.alignment = _footer_alignment()
	footer.add_theme_constant_override("separation", roundi(0.6 * em))
	if style != _backdrop_style:
		_update_backdrop(style)
	var wanted: Vector2 = get_frame_size()
	var width: float = minf(wanted.x, view.x * 0.94)
	var height: float = minf(wanted.y, view.y * 0.92)
	if fit_height:
		_body.size = Vector2(width - pad.x * 2.0, 0.0)
		_prepare_fit(width - pad.x * 2.0)
		height = minf(pad.y * 2.0 + header + _body.get_combined_minimum_size().y, view.y * 0.92)
	_frame_rect = Rect2(((view - Vector2(width, height)) * 0.5).round(), Vector2(width, height).round())
	_frame.size = _frame_rect.size
	_frame.pivot_offset = _frame_rect.size * 0.5
	_body.position = Vector2(pad.x, pad.y + header)
	_body.size = Vector2(_frame_rect.size.x - pad.x * 2.0, _frame_rect.size.y - pad.y * 2.0 - header)
	_update_clip()
	_frame.queue_redraw()


func _update_backdrop(style: MenuKitStyle) -> void:
	_backdrop_style = style
	if _backdrop != null:
		_backdrop.queue_free()
	_backdrop = style.create_panel_backdrop()
	if _backdrop != null:
		_backdrop.name = "Backdrop"
		_backdrop.show_behind_parent = true
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.add_child(_backdrop)
		_frame.move_child(_backdrop, 0)
		_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _footer_alignment() -> BoxContainer.AlignmentMode:
	match MenuKit.style.panel_footer_align():
		MenuKitStyle.Align.LEFT:
			return BoxContainer.ALIGNMENT_BEGIN
		MenuKitStyle.Align.CENTER:
			return BoxContainer.ALIGNMENT_CENTER
	return BoxContainer.ALIGNMENT_END


## Called before measuring a fit_height panel with the width available for the content.
func _prepare_fit(_width: float) -> void:
	pass


## Shows the panel with the style's animation and focuses [param focus_target]
## (or the first focusable widget).
func open(focus_target: Control = null) -> void:
	var owner_focus: Control = get_viewport().gui_get_focus_owner()
	if owner_focus != null and not is_ancestor_of(owner_focus):
		return_focus = owner_focus
	visible = true
	is_open = true
	layout()
	if _tween != null:
		_tween.kill()
	_reset_frame()
	MenuKit.sounds.play(&"open")
	_tween = MenuKit.style.animate_panel(self, _frame, true)
	var target: Control = focus_target if focus_target != null else find_first_focusable(content)
	if target == null:
		target = find_first_focusable(footer)
	if target != null:
		target.grab_focus()
	opened.emit()


## Hides the panel with the style's animation and gives the focus back.
func close(play_sound: bool = true) -> void:
	if not is_open:
		return
	is_open = false
	if play_sound:
		MenuKit.sounds.play(&"back")
	if _tween != null:
		_tween.kill()
	_tween = MenuKit.style.animate_panel(self, _frame, false)
	_tween.finished.connect(_on_close_finished)
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	# Emitted before the focus goes back, so the screen can unlock what is below.
	closed.emit()
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree() \
			and return_focus.focus_mode != Control.FOCUS_NONE:
		return_focus.grab_focus()


## Adds a footer button and returns it.
func add_button(text: String, ghost: bool = false) -> MenuKitButton:
	var button: MenuKitButton = MenuKitButton.new(text, ghost)
	footer.add_child(button)
	return button


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not visible:
		return
	if event.is_action_pressed(&"ui_cancel", false, true):
		get_viewport().set_input_as_handled()
		back_requested.emit()
		if close_on_back:
			close()


func _on_close_finished() -> void:
	if not is_open:
		visible = false
		_reset_frame()


func _reset_frame() -> void:
	reveal = 1.0
	_frame.modulate = Color.WHITE
	_frame.scale = Vector2.ONE
	_frame.rotation = 0.0


func _update_clip() -> void:
	if _clip == null or MenuKit.style == null:
		return
	var local: Rect2 = Rect2(Vector2.ZERO, _frame_rect.size)
	var shown: Rect2 = MenuKit.style.panel_reveal_rect(local, reveal) if reveal < 0.999 else local
	_clip.clip_contents = reveal < 0.999
	if _clip.clip_contents:
		_clip.position = _frame_rect.position + shown.position
		_clip.size = shown.size
		_frame.position = -shown.position
	else:
		_clip.position = _frame_rect.position
		_clip.size = _frame_rect.size
		_frame.position = Vector2.ZERO


func _draw_frame() -> void:
	MenuKit.style.draw_panel(_frame, Rect2(Vector2.ZERO, _frame.size), tr(title), tag)


## First visible widget that can take the focus under [param root].
static func find_first_focusable(root: Node) -> Control:
	for child: Node in root.get_children():
		var control: Control = child as Control
		if control == null or not control.visible:
			continue
		if control.focus_mode == Control.FOCUS_ALL:
			return control
		var nested: Control = find_first_focusable(control)
		if nested != null:
			return nested
	return null


## Turns keyboard / gamepad focus off (or back on) for every widget under [param root],
## so the focus cannot leave the panel on top.
static func set_focus_enabled(root: Node, enabled: bool) -> void:
	for child: Node in root.get_children():
		var control: Control = child as Control
		if control != null:
			if enabled and control.has_meta(&"menu_kit_focus_mode"):
				control.focus_mode = int(control.get_meta(&"menu_kit_focus_mode")) as Control.FocusMode
				control.remove_meta(&"menu_kit_focus_mode")
			elif not enabled and control.focus_mode != Control.FOCUS_NONE:
				control.set_meta(&"menu_kit_focus_mode", control.focus_mode)
				control.focus_mode = Control.FOCUS_NONE
		set_focus_enabled(child, enabled)
