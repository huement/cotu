class_name MenuKitTabBar
extends MenuKitControl
## Row of tabs (options menu). Left / right, a click or the gamepad shoulder
## buttons change the tab.

signal tab_selected(index: int)

var tabs: PackedStringArray = PackedStringArray():
	set(value):
		tabs = value
		current = clampi(current, 0, maxi(0, tabs.size() - 1))
		refresh()
var current: int = 0

var _hovered: int = -1
var _scroll: float = 0.0


func _init() -> void:
	super()
	press_sound = &""


func select(index: int, play_sound: bool = true) -> void:
	index = clampi(index, 0, tabs.size() - 1)
	if index == current or tabs.is_empty():
		return
	current = index
	if play_sound:
		MenuKit.sounds.play(&"toggle_on")
	MenuKit.speak(tr(tabs[current]))
	queue_redraw()
	tab_selected.emit(current)


func _get_minimum_size() -> Vector2:
	return Vector2(0, kit_style().tab_bar_height()) if MenuKit.style != null else Vector2.ZERO


func _gui_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		var hovered: int = _tab_at(motion.position.x)
		if hovered != _hovered:
			_hovered = hovered
			queue_redraw()
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		var index: int = _tab_at(mouse.position.x)
		if index != -1:
			grab_focus()
			select(index)
		accept_event()
		return
	if event.is_action_pressed(&"ui_left", true):
		if current > 0:
			select(current - 1)
		accept_event()
	elif event.is_action_pressed(&"ui_right", true):
		if current < tabs.size() - 1:
			select(current + 1)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hovered != -1:
		_hovered = -1
		queue_redraw()


func _draw() -> void:
	var style: MenuKitStyle = kit_style()
	style.draw_tab_bar(self, Rect2(Vector2.ZERO, size))
	var rects: Array[Rect2] = _tab_rects()
	for i: int in rects.size():
		style.draw_tab(self, rects[i], tr(tabs[i]), i == current, has_focus() and i == current, i == _hovered)


func get_spoken_text() -> String:
	return tr(tabs[current]) if not tabs.is_empty() else ""


func _tab_rects() -> Array[Rect2]:
	var style: MenuKitStyle = kit_style()
	var rects: Array[Rect2] = []
	var x: float = 0.0
	for tab: String in tabs:
		var width: float = style.tab_width(tr(tab))
		rects.append(Rect2(x, 0, width, size.y))
		x += width
	# Scrolls when the tabs are wider than the bar, keeping the current tab visible.
	var total: float = x
	if total <= size.x:
		_scroll = -(size.x - total) * 0.5 if style.tabs_centered() else 0.0
	elif not rects.is_empty():
		var selected: Rect2 = rects[current]
		if selected.position.x - _scroll < 0.0:
			_scroll = selected.position.x
		elif selected.end.x - _scroll > size.x:
			_scroll = selected.end.x - size.x
		_scroll = clampf(_scroll, 0.0, total - size.x)
	for i: int in rects.size():
		rects[i].position.x -= _scroll
	return rects


func _tab_at(x: float) -> int:
	var rects: Array[Rect2] = _tab_rects()
	for i: int in rects.size():
		if x >= rects[i].position.x and x < rects[i].end.x:
			return i
	return -1
