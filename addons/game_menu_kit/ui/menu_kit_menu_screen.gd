class_name MenuKitMenuScreen
extends Control
## Base of the main menu and the pause menu: a title, a column of big buttons and a
## footer placed by the style, plus the panels opened from them (options, save
## slots, questions). The screen is dimmed while a panel is open.

## Any big button pressed (ids: continue, new_game, load_game, options, quit, or your own).
signal button_pressed(id: StringName)

## Pause menu look: blurred game behind, smaller title, [method MenuKitStyle.pause_layout].
var pause_screen: bool = false
var background: Control
var overlay: Control
## Title, buttons and footer (dimmed while a panel is open).
var content: Control
var title_node: MenuKitTitle
var buttons: Array[MenuKitMenuButton] = []
var footer: MenuKitLabel
var options: MenuKitOptionsMenu
var dialog: MenuKitDialog

var _buttons_box: Control
var _dim_tween: Tween
var _open_panels: Array[MenuKitPanel] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	resized.connect(_layout)
	MenuKit.ui_scale_changed.connect(_layout)
	MenuKit.style_changed.connect(_on_style_changed)
	_layout()


## Replays the entrance animation and focuses the first button.
func play_intro() -> void:
	MenuKit.style.animate_menu_intro(title_node, _visible_buttons(), footer)
	focus_first_button()


func focus_first_button() -> void:
	var visible_buttons: Array[MenuKitMenuButton] = _visible_buttons()
	if not visible_buttons.is_empty():
		MenuKit.sounds.hush(400)
		visible_buttons[0].grab_focus()


## Adds a button before "Options" (or at [param index]) and returns it.
func add_button(text: String, id: StringName, index: int = -1) -> MenuKitMenuButton:
	var button: MenuKitMenuButton = MenuKitMenuButton.new(text, id)
	button.name = String(id).to_pascal_case()
	button.pressed.connect(_on_button_pressed.bind(id))
	_buttons_box.add_child(button)
	if index < 0:
		var options_button: MenuKitMenuButton = get_button(&"options")
		index = buttons.find(options_button) if options_button != null else buttons.size()
	buttons.insert(index, button)
	_buttons_box.move_child(button, index)
	update_buttons()
	return button


## Button by id, or null.
func get_button(id: StringName) -> MenuKitMenuButton:
	for button: MenuKitMenuButton in buttons:
		if button.id == id:
			return button
	return null


## Shows or hides a button.
func set_button_visible(id: StringName, shown: bool) -> void:
	var button: MenuKitMenuButton = get_button(id)
	if button != null and button.visible != shown:
		button.visible = shown
		update_buttons()


## Call after showing, hiding or changing buttons.
func update_buttons() -> void:
	_update_neighbors()
	_layout()


## Opens the options menu.
func open_options() -> void:
	open_panel(options)


## Opens [param panel] above the screen (dims the screen until it closes).
func open_panel(panel: MenuKitPanel) -> void:
	_push_panel(panel)
	panel.open()


## Asks a question in the screen's dialog and returns the chosen button (-1: backed out).
func ask(p_title: String, p_message: String, p_buttons: PackedStringArray, focus_index: int = -1) -> int:
	_push_panel(dialog)
	return await dialog.ask(p_title, p_message, p_buttons, focus_index)


## True while a panel or a question is open.
func has_open_panel() -> bool:
	return not _open_panels.is_empty()


## Closes every open panel (without sound).
func close_panels() -> void:
	for panel: MenuKitPanel in _open_panels.duplicate():
		panel.close(false)


func _build() -> void:
	background = _create_background()
	background.name = "Background"
	add_child(background)
	content = Control.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	title_node = MenuKitTitle.new()
	title_node.name = "Title"
	title_node.compact = pause_screen
	content.add_child(title_node)
	_buttons_box = Control.new()
	_buttons_box.name = "Buttons"
	_buttons_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_buttons_box)
	_add_buttons()
	_update_neighbors()
	footer = MenuKitLabel.new("", &"foot")
	footer.name = "Footer"
	content.add_child(footer)
	options = MenuKitOptionsMenu.new()
	options.closed.connect(_on_panel_closed.bind(options))
	add_child(options)
	dialog = MenuKitDialog.new()
	dialog.name = "Dialog"
	dialog.closed.connect(_on_panel_closed.bind(dialog))
	add_child(dialog)
	_add_overlay()


## Override to add the screen's buttons with [method _make_button].
func _add_buttons() -> void:
	pass


func _make_button(text: String, id: StringName) -> MenuKitMenuButton:
	var button: MenuKitMenuButton = MenuKitMenuButton.new(text, id)
	button.name = String(id).to_pascal_case()
	button.pressed.connect(_on_button_pressed.bind(id))
	_buttons_box.add_child(button)
	buttons.append(button)
	return button


func _create_background() -> Control:
	return MenuKit.style.create_pause_background() if pause_screen else MenuKit.style.create_background()


func _add_overlay() -> void:
	overlay = MenuKit.style.create_overlay()
	if overlay != null:
		overlay.name = "Overlay"
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(overlay)


func _visible_buttons() -> Array[MenuKitMenuButton]:
	var result: Array[MenuKitMenuButton] = []
	for button: MenuKitMenuButton in buttons:
		if button.visible:
			result.append(button)
	return result


## Places the title, buttons and footer following the style's layout.
func _layout() -> void:
	if MenuKit.style == null or not is_inside_tree() or title_node == null:
		return
	var style: MenuKitStyle = MenuKit.style
	var em: float = style.em
	var layout: Dictionary = style.pause_layout() if pause_screen else style.menu_layout()
	var align: MenuKitStyle.Align = layout["align"]
	var margin: Vector2 = (layout["margin"] as Vector2) * size
	var shown: Array[MenuKitMenuButton] = _visible_buttons()
	title_node.align = align
	var title_size: Vector2 = title_node.get_combined_minimum_size()
	var button_width: float = float(layout["button_min_width"]) * em
	var heights: Array[float] = []
	var total: float = title_size.y + float(layout["logo_gap"]) * em
	for button: MenuKitMenuButton in shown:
		var minimum: Vector2 = button.get_combined_minimum_size()
		button_width = maxf(button_width, minimum.x)
		heights.append(minimum.y)
		total += minimum.y
	total += float(layout["button_gap"]) * em * maxf(0.0, shown.size() - 1)
	var y: float = maxf(margin.y, (size.y - total) * 0.5)
	if layout.has("bottom"):
		# Anchored to the bottom of the screen instead of centered.
		y = maxf(margin.y, size.y * (1.0 - float(layout["bottom"])) - total)
	title_node.size = Vector2(maxf(title_size.x, button_width), title_size.y)
	title_node.position = Vector2(_aligned_x(align, title_node.size.x, margin.x), y).round()
	y += title_size.y + float(layout["logo_gap"]) * em
	_buttons_box.position = Vector2.ZERO
	_buttons_box.size = size
	for i: int in shown.size():
		var button: MenuKitMenuButton = shown[i]
		button.size = Vector2(button_width, heights[i])
		button.position = Vector2(_aligned_x(align, button_width, margin.x), y).round()
		y += heights[i] + float(layout["button_gap"]) * em
	var foot_align: MenuKitStyle.Align = layout["foot_align"]
	footer.align = foot_align
	footer.size = Vector2(size.x - margin.x * 2.0, em * 1.2)
	footer.position = Vector2(margin.x, size.y * (1.0 - float(layout["foot_bottom"])) - footer.size.y).round()
	content.pivot_offset = size * 0.5


func _aligned_x(align: MenuKitStyle.Align, width: float, margin: float) -> float:
	match align:
		MenuKitStyle.Align.CENTER:
			return (size.x - width) * 0.5
		MenuKitStyle.Align.RIGHT:
			return size.x - margin - width
	return margin


func _update_neighbors() -> void:
	# Up / down wrap around the list.
	var shown: Array[MenuKitMenuButton] = _visible_buttons()
	for i: int in shown.size():
		var button: MenuKitMenuButton = shown[i]
		button.focus_neighbor_top = button.get_path_to(shown[(i - 1 + shown.size()) % shown.size()])
		button.focus_neighbor_bottom = button.get_path_to(shown[(i + 1) % shown.size()])
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)


func _on_button_pressed(id: StringName) -> void:
	button_pressed.emit(id)


func _push_panel(panel: MenuKitPanel) -> void:
	# Remember the focused button now: dimming the screen removes its focus.
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and not panel.is_ancestor_of(focused):
		panel.return_focus = focused
	if not _open_panels.has(panel):
		_open_panels.append(panel)
	_set_menu_active(false)


func _on_panel_closed(panel: MenuKitPanel) -> void:
	_open_panels.erase(panel)
	if _open_panels.is_empty():
		_set_menu_active(true)


## Dims the menu and blocks its focus while a panel is open.
func _set_menu_active(active: bool) -> void:
	MenuKitPanel.set_focus_enabled(content, active)
	if _dim_tween != null:
		_dim_tween.kill()
	_dim_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_dim_tween.tween_property(content, "modulate:a", 1.0 if active else 0.3, 0.35)
	_dim_tween.tween_property(content, "scale", Vector2.ONE if active else Vector2(0.985, 0.985), 0.45)


func _on_style_changed() -> void:
	var old_background: Control = background
	background = _create_background()
	background.name = "Background"
	add_child(background)
	move_child(background, 0)
	old_background.queue_free()
	if overlay != null:
		overlay.queue_free()
		overlay = null
	_add_overlay()
	_layout()
