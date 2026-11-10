class_name MenuKitOptionsMenu
extends MenuKitPanel
## The options menu. Builds one tab per section of [code]MenuKit.settings[/code],
## with a line per visible setting. Settings are saved when it closes.
##
## Use it on its own (from a pause menu of yours, for example):
## [codeblock]
## var options := MenuKitOptionsMenu.new()
## add_child(options)
## options.open()
## [/codeblock]

var tab_bar: MenuKitTabBar
var scroll: ScrollContainer
var rows: VBoxContainer
var reset_button: MenuKitButton
var back_button: MenuKitButton

var _sections: Array[Dictionary] = []
var _dialog: MenuKitDialog
var _rows_margin: MarginContainer


func _init() -> void:
	super()
	name = "Options"
	title = "Options"
	tag = "SYS.CFG"
	tab_bar = MenuKitTabBar.new()
	tab_bar.name = "Tabs"
	tab_bar.tab_selected.connect(_on_tab_selected)
	content.add_child(tab_bar)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	content.add_child(scroll)
	_rows_margin = MarginContainer.new()
	_rows_margin.name = "Margin"
	_rows_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_margin)
	rows = VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 0)
	_rows_margin.add_child(rows)
	reset_button = add_button("Reset", true)
	reset_button.press_sound = &""
	reset_button.pressed.connect(_on_reset_pressed)
	back_button = add_button("Back")
	back_button.press_sound = &""
	back_button.pressed.connect(close)
	_dialog = MenuKitDialog.new()
	_dialog.name = "OptionsDialog"
	_dialog.opened.connect(func() -> void: MenuKitPanel.set_focus_enabled(_frame, false))
	_dialog.closed.connect(func() -> void: MenuKitPanel.set_focus_enabled(_frame, true))
	add_child(_dialog)
	closed.connect(_on_closed)


func _ready() -> void:
	super()
	MenuKit.style_changed.connect(_style_widgets)
	MenuKit.ui_scale_changed.connect(_style_widgets)
	_style_widgets()


## Opens the menu on [param section] (id such as "audio"), or on the last tab shown.
func open(focus_target: Control = null, section: String = "") -> void:
	rebuild(section)
	super(focus_target if focus_target != null else tab_bar)


## Rebuilds tabs and rows (after adding or hiding settings while the menu is open).
func rebuild(section: String = "") -> void:
	var current_id: String = section
	if current_id.is_empty() and tab_bar.current < _sections.size():
		current_id = String(_sections[tab_bar.current]["id"])
	_sections = MenuKit.settings.get_visible_sections()
	var labels: PackedStringArray = PackedStringArray()
	var index: int = 0
	for i: int in _sections.size():
		labels.append(String(_sections[i]["label"]))
		if String(_sections[i]["id"]) == current_id:
			index = i
	tab_bar.tabs = labels
	tab_bar.current = index
	_fill_rows()


## Id of the tab shown.
func get_current_section() -> String:
	return String(_sections[tab_bar.current]["id"]) if tab_bar.current < _sections.size() else ""


func _unhandled_input(event: InputEvent) -> void:
	if is_open and visible and not _dialog.is_open:
		var direction: int = 0
		var joy: InputEventJoypadButton = event as InputEventJoypadButton
		if joy != null and joy.pressed:
			if joy.button_index == JOY_BUTTON_LEFT_SHOULDER:
				direction = -1
			elif joy.button_index == JOY_BUTTON_RIGHT_SHOULDER:
				direction = 1
		var key: InputEventKey = event as InputEventKey
		if key != null and key.pressed and not key.echo:
			if key.keycode == KEY_PAGEUP:
				direction = -1
			elif key.keycode == KEY_PAGEDOWN:
				direction = 1
		if direction != 0:
			get_viewport().set_input_as_handled()
			var had_row_focus: bool = rows.is_ancestor_of(get_viewport().gui_get_focus_owner())
			tab_bar.select(clampi(tab_bar.current + direction, 0, _sections.size() - 1))
			if had_row_focus:
				_focus_first_row.call_deferred()
			return
	super(event)


func _on_tab_selected(_index: int) -> void:
	_fill_rows()


func _fill_rows() -> void:
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	scroll.scroll_vertical = 0
	if tab_bar.current >= _sections.size():
		return
	var header_added: bool = false
	for setting: MenuKitSetting in MenuKit.settings.get_settings_in(String(_sections[tab_bar.current]["id"])):
		if setting.type == MenuKitSetting.Type.BINDING and not header_added:
			header_added = true
			rows.add_child(_BindingsHeader.new())
		var row: MenuKitOptionRow = MenuKitOptionRow.new(setting)
		row.binding_conflict.connect(_on_binding_conflict)
		rows.add_child(row)


func _focus_first_row() -> void:
	var first: Control = MenuKitPanel.find_first_focusable(rows)
	if first != null:
		first.grab_focus()


func _style_widgets() -> void:
	if MenuKit.style == null:
		return
	content.add_theme_constant_override("separation", roundi(0.8 * MenuKit.style.em))
	# Room for the scrollbar, so it never covers the values.
	_rows_margin.add_theme_constant_override("margin_right", roundi(0.9 * MenuKit.style.em))
	MenuKit.style.style_scroll_container(scroll)


func _on_reset_pressed() -> void:
	MenuKit.sounds.play(&"select")
	var section_label: String = tr(String(_sections[tab_bar.current]["label"])) if tab_bar.current < _sections.size() else ""
	var choice: int = await _dialog.ask("Reset settings?",
		tr("Every setting of the \"%s\" tab goes back to its default value.") % section_label,
		["Cancel", "Reset"])
	if choice == 1:
		MenuKit.settings.reset(get_current_section())
		MenuKit.sounds.play_toggle(false)


func _on_binding_conflict(row: MenuKitOptionRow, kind: int, event: InputEvent, other_action: StringName) -> void:
	var key_label: String = MenuKitInput.get_event_label(event)
	var other_label: String = tr(MenuKit.input.get_action_label(other_action))
	var choice: int = await _dialog.ask("Already in use",
		tr("\"%s\" is already used by \"%s\".\nSwap: \"%s\" gets the old key. Replace: \"%s\" loses it.") \
			% [key_label, other_label, other_label, other_label],
		["Cancel", "Replace", "Swap"])
	var action: StringName = row.setting.action
	match choice:
		1:
			MenuKit.input.replace_binding(action, kind as MenuKitInput.Kind, 0, event, other_action)
			MenuKit.sounds.play_toggle(true)
		2:
			MenuKit.input.swap_binding(action, kind as MenuKitInput.Kind, 0, event, other_action)
			MenuKit.sounds.play_toggle(true)


func _on_closed() -> void:
	if _dialog.is_open:
		_dialog.close(false)
	MenuKit.save_settings()


## Column titles above the key bindings.
class _BindingsHeader:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		MenuKit.ui_scale_changed.connect(update_minimum_size)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSLATION_CHANGED:
			queue_redraw()

	func _get_minimum_size() -> Vector2:
		return Vector2(0, MenuKit.style.em * 2.0) if MenuKit.style != null else Vector2.ZERO

	func _draw() -> void:
		var style: MenuKitStyle = MenuKit.style
		var key: Vector2 = style.key_size()
		var gap: float = 0.6 * style.em
		var columns: Array = [
			Rect2(size.x - key.x * 2.0 - gap, 0, key.x, size.y),
			Rect2(size.x - key.x, 0, key.x, size.y),
		]
		style.draw_bindings_header(self, Rect2(Vector2.ZERO, size), tr("Action"), columns,
			PackedStringArray([tr("Keyboard / Mouse"), tr("Gamepad")]))
