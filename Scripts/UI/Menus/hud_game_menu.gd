# res://Scripts/UI/Menus/hud_game_menu.gd
class_name HudGameMenu
extends CanvasLayer
## In-game menu opened from the HUD's GameMenuButton (or Esc). Pauses the game
## and shows one wide row of icon tiles: Quit, Settings, Save, Party, Load, Help.
##
## Add an entry: append to MENU_ENTRIES and handle its id in _on_entry_pressed().

signal menu_opened
signal menu_closed

const SETTINGS_MENU_SCENE: PackedScene = preload("res://addons/settings_menu/SettingsMenu.tscn")
const HELP_SCREEN_SCENE: PackedScene = preload("res://Scenes/GameMenus/HelpScreen.tscn")

## id, label, icon and whether it is a "danger" (red accent) action. Order = left to right.
const MENU_ENTRIES: Array[Dictionary] = [
	{"id": &"quit", "label": "QUIT", "icon": preload("res://ui/icons/stop_sign.svg"), "danger": true},
	{"id": &"settings", "label": "SETTINGS", "icon": preload("res://ui/icons/cog.svg"), "danger": false},
	{"id": &"save", "label": "SAVE GAME", "icon": preload("res://ui/icons/database.svg"), "danger": false},
	{"id": &"party", "label": "PARTY", "icon": preload("res://ui/icons/chess_knight.svg"), "danger": false},
	{"id": &"load", "label": "LOAD GAME", "icon": preload("res://ui/icons/book.svg"), "danger": false},
	{"id": &"help", "label": "HELP", "icon": preload("res://ui/icons/feather.svg"), "danger": false},
]

@onready var _root: Control = %Root as Control
@onready var _menu_cluster: Control = %MenuCluster as Control
@onready var _menu_panel: PanelContainer = %MenuPanel as PanelContainer
@onready var _title_label: Label = %TitleLabel as Label
@onready var _status_label: Label = %StatusLabel as Label
@onready var _close_button: Button = %CloseButton as Button
@onready var _menu_buttons: HBoxContainer = %MenuButtons as HBoxContainer
@onready var _confirm_panel: PanelContainer = %ConfirmPanel as PanelContainer
@onready var _confirm_title: Label = %ConfirmTitle as Label
@onready var _confirm_message: Label = %ConfirmMessage as Label
@onready var _confirm_buttons: HBoxContainer = %ConfirmButtons as HBoxContainer

var is_open: bool = false

var _buttons: Dictionary = {} # StringName -> Button
var _was_paused: bool = false
var _sub_screen: Control = null
var _last_focused: Button = null
var _status_tween: Tween = null

signal _confirm_chosen(index: int)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.hide()
	_confirm_panel.hide()
	_menu_panel.add_theme_stylebox_override("panel", ShardsMenuStyle.panel_box())
	_confirm_panel.add_theme_stylebox_override("panel", ShardsMenuStyle.panel_box())
	ShardsMenuStyle.style_title(_title_label, 22)
	ShardsMenuStyle.style_body(_status_label, 14, true)
	ShardsMenuStyle.style_title(_confirm_title, 22)
	ShardsMenuStyle.style_body(_confirm_message, 15, true)
	ShardsMenuStyle.style_button(_close_button)
	_close_button.add_theme_constant_override("icon_max_width", 20)
	_close_button.pressed.connect(close_menu)
	_build_buttons()


# ------------------------------------------------------------------------------
# Open / close
# ------------------------------------------------------------------------------
func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	if is_open:
		return
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_refresh_buttons()
	_set_status("")
	_root.show()
	_menu_cluster.show()
	_play_ui_sound("button-press")
	_animate_in()
	_focus_button(_last_focused if is_instance_valid(_last_focused) else _buttons.get(&"settings") as Button)
	menu_opened.emit()


func close_menu() -> void:
	if not is_open:
		return
	if _confirm_panel.visible:
		_confirm_chosen.emit(-1)
	if is_instance_valid(_sub_screen):
		_sub_screen.queue_free()
		_sub_screen = null
	is_open = false
	_root.hide()
	get_tree().paused = _was_paused
	get_viewport().gui_release_focus()
	menu_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	# Settings / Help handle their own Esc in _input before we get here.
	get_viewport().set_input_as_handled()
	if _confirm_panel.visible:
		_confirm_chosen.emit(-1)
	else:
		toggle_menu()


# ------------------------------------------------------------------------------
# Buttons
# ------------------------------------------------------------------------------
func _build_buttons() -> void:
	var ordered: Array[Button] = []
	for entry: Dictionary in MENU_ENTRIES:
		var id: StringName = entry["id"]
		var accent: Color = ShardsMenuStyle.COLOR_DANGER if bool(entry["danger"]) else ShardsMenuStyle.COLOR_ACCENT
		var button: Button = ShardsMenuStyle.make_tile_button(String(entry["label"]), entry["icon"] as Texture2D, accent)
		button.name = String(id).to_pascal_case() + "Button"
		button.pressed.connect(_on_entry_pressed.bind(id))
		button.focus_entered.connect(func() -> void: _last_focused = button)
		_menu_buttons.add_child(button)
		_buttons[id] = button
		ordered.append(button)
	ShardsMenuStyle.link_focus_row(ordered)


## Greys out what can't be used right now (no saving or party edits mid-battle).
func _refresh_buttons() -> void:
	var in_battle: bool = SessionFlow.is_in_battle()
	_set_entry_disabled(&"save", in_battle, "Can't save during battle")
	_set_entry_disabled(&"party", in_battle, "Can't change the party during battle")
	_set_entry_disabled(&"load", not SessionFlow.has_save(), "No save file yet")
	var stamp: String = SessionFlow.get_save_timestamp()
	(_buttons[&"load"] as Button).tooltip_text = "Last save: %s" % stamp if not stamp.is_empty() else ""


func _set_entry_disabled(id: StringName, disabled: bool, reason: String) -> void:
	var button: Button = _buttons.get(id) as Button
	if button == null:
		return
	button.disabled = disabled
	button.focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	button.tooltip_text = reason if disabled else ""


func _on_entry_pressed(id: StringName) -> void:
	_play_ui_sound("button-press")
	match id:
		&"quit":
			_on_quit_pressed()
		&"settings":
			_open_settings()
		&"save":
			_save_game()
		&"party":
			_open_party()
		&"load":
			_on_load_pressed()
		&"help":
			_open_sub_screen(HELP_SCREEN_SCENE.instantiate() as Control)


# ------------------------------------------------------------------------------
# Actions
# ------------------------------------------------------------------------------
func _on_quit_pressed() -> void:
	var options: PackedStringArray = ["CANCEL", "SAVE & QUIT", "QUIT"]
	var message: String = "Progress since your last save will be lost."
	if SessionFlow.is_in_battle():
		options = ["CANCEL", "QUIT"]
		message = "You're in a battle. You can't save right now, so this fight will be lost."
	var choice: int = await _ask("RETURN TO MAIN MENU?", message, options, 0)
	var picked: String = options[choice] if choice >= 0 else "CANCEL"
	match picked:
		"SAVE & QUIT":
			if not GameState.save_game():
				_set_status("Save failed - not quitting.", true)
				return
			_leave_to_main_menu()
		"QUIT":
			_leave_to_main_menu()


func _leave_to_main_menu() -> void:
	is_open = false
	SessionFlow.quit_to_main_menu(get_tree())


## Save tile: save to the session's slot, or pick another slot (the game then keeps saving there,
## leaving the old slot as it was - a second copy of this playthrough).
func _save_game() -> void:
	if GameState.dev_session:
		_write_save()
		return
	var choice: int = await _ask("SAVE GAME", "Current slot: %d" % GameState.save_slot, ["CANCEL", "OTHER SLOT", "SAVE"], 2)
	if choice == 2:
		_write_save()
	elif choice == 1:
		var screen := SaveSlotScreen.new()
		screen.mode = SaveSlotScreen.Mode.SAVE
		screen.slot_chosen.connect(func(slot: int) -> void:
			GameState.set_save_slot(slot)
			_write_save())
		_open_sub_screen(screen)


func _write_save() -> void:
	if GameState.save_game():
		_set_status("Game saved to slot %d  ·  %s" % [GameState.save_slot, SessionFlow.get_save_timestamp()])
		if is_instance_valid(SignalBus):
			SignalBus.show_toast.emit("Game saved", false)
	else:
		_set_status("Save failed! Check the log.", true)
	_refresh_buttons()


func _on_load_pressed() -> void:
	var stamp: String = SessionFlow.get_save_timestamp()
	var message: String = "Unsaved progress will be lost."
	if not stamp.is_empty():
		message = "Last save: %s\nUnsaved progress will be lost." % stamp
	var choice: int = await _ask("LOAD LAST SAVE?", message, ["CANCEL", "LOAD"], 0)
	if choice != 1:
		return
	is_open = false
	if not SessionFlow.load_saved_game(get_tree()):
		is_open = true
		_set_status("That save file couldn't be loaded.", true)


func _open_party() -> void:
	# The character sheet (gear, stats, front/back row) opens from portrait clicks.
	close_menu()
	var slot: int = GameState.active_character_index if "active_character_index" in GameState else 0
	SignalBus.portrait_clicked.emit(slot)


func _open_settings() -> void:
	var menu: Control = SETTINGS_MENU_SCENE.instantiate() as Control
	menu.set("free_on_close", true)
	menu.set("color_preset", "Night")
	menu.set("pause_game_while_open", false) # We already paused the game.
	_open_sub_screen(menu)


## Hides the tile row and shows [param screen] on top until it emits "closed".
func _open_sub_screen(screen: Control) -> void:
	if is_instance_valid(_sub_screen):
		_sub_screen.queue_free()
	_sub_screen = screen
	_menu_cluster.hide()
	_root.add_child(screen)
	screen.connect(&"closed", _on_sub_screen_closed, CONNECT_ONE_SHOT)
	if screen.has_method("open"):
		screen.call("open")


func _on_sub_screen_closed() -> void:
	_sub_screen = null
	if not is_open:
		return
	_menu_cluster.show()
	_refresh_buttons()
	_focus_button(_last_focused)


# ------------------------------------------------------------------------------
# Confirm dialog
# ------------------------------------------------------------------------------
## Shows a question with [param options] and returns the index picked (-1 = cancelled).
func _ask(title: String, message: String, options: PackedStringArray, focus_index: int = 0) -> int:
	for child: Node in _confirm_buttons.get_children():
		child.queue_free()
	_confirm_title.text = title
	_confirm_message.text = message
	var row: Array[Button] = []
	for i: int in options.size():
		var is_danger: bool = options[i] == "QUIT"
		var accent: Color = ShardsMenuStyle.COLOR_DANGER if is_danger else ShardsMenuStyle.COLOR_ACCENT
		var button: Button = ShardsMenuStyle.make_row_button(options[i], null, accent)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: _confirm_chosen.emit(i))
		_confirm_buttons.add_child(button)
		row.append(button)
	ShardsMenuStyle.link_focus_row(row)
	_menu_cluster.modulate.a = 0.25
	_set_tiles_focusable(false)
	_confirm_panel.show()
	_focus_button(row[clampi(focus_index, 0, row.size() - 1)])

	var choice: int = await _confirm_chosen
	_confirm_panel.hide()
	_menu_cluster.modulate.a = 1.0
	_set_tiles_focusable(true)
	if is_open and choice < 0:
		_focus_button(_last_focused)
	return choice


func _set_tiles_focusable(enabled: bool) -> void:
	for button: Button in _buttons.values():
		button.focus_mode = Control.FOCUS_ALL if enabled and not button.disabled else Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	_close_button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
func _focus_button(button: Button) -> void:
	if button == null or button.disabled:
		for candidate: Button in _buttons.values():
			if not candidate.disabled:
				button = candidate
				break
	if button != null:
		button.grab_focus.call_deferred()


func _set_status(text: String, is_error: bool = false) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", ShardsMenuStyle.COLOR_DANGER if is_error else ShardsMenuStyle.COLOR_ACCENT)
	if _status_tween != null:
		_status_tween.kill()
	_status_label.modulate.a = 1.0
	if text.is_empty():
		return
	_status_tween = create_tween()
	_status_tween.tween_interval(3.0)
	_status_tween.tween_property(_status_label, "modulate:a", 0.0, 0.6)


func _animate_in() -> void:
	_menu_cluster.pivot_offset = _menu_cluster.size * 0.5
	_menu_cluster.modulate.a = 0.0
	_menu_cluster.scale = Vector2(0.97, 0.97)
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_menu_cluster, "modulate:a", 1.0, 0.18)
	tween.tween_property(_menu_cluster, "scale", Vector2.ONE, 0.22)


func _play_ui_sound(sound_name: String) -> void:
	if is_instance_valid(AudioManager) and AudioManager.has_method("play_ui_sound"):
		AudioManager.play_ui_sound(sound_name)
