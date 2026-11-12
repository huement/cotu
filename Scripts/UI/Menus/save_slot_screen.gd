# res://Scripts/UI/Menus/save_slot_screen.gd
class_name SaveSlotScreen
extends Control
## The list of save slots (GameState.SAVE_SLOT_COUNT of them), opened from the main menu.
##   * Mode.LOAD (Load Game): pick a used slot to load it. DELETE (press twice) empties a slot.
##   * Mode.PICK_NEW (New Game when every slot is used): pick the slot the new game replaces
##     (press twice). Emits `slot_chosen`, then closes.
##   * Mode.SAVE (in-game menu > Save > Other Slot): pick any slot to save into. An empty slot or
##     the current one saves at once; another used slot needs a second press. Emits `slot_chosen`.
## Each row shows who is in the party, where they are, when it was saved and the play time.

signal closed
## Mode.PICK_NEW / Mode.SAVE: the slot the player chose.
signal slot_chosen(slot: int)

enum Mode { LOAD, PICK_NEW, SAVE }

const TITLES: Dictionary = {
	Mode.LOAD: ["LOAD GAME", "Pick a saved game."],
	Mode.PICK_NEW: ["ALL SLOTS ARE FULL", "Pick the save your new game will replace."],
	Mode.SAVE: ["SAVE TO SLOT", "Pick a slot. The game keeps saving there from now on."],
}

var mode: Mode = Mode.LOAD
var free_on_close: bool = true

var _rows: VBoxContainer = null
var _status: Label = null
var _back_button: Button = null
## Slot whose DELETE / REPLACE button was pressed once and now waits for the second press.
var _armed_slot: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_rebuild_rows()


func open() -> void:
	show()


func close() -> void:
	if not visible:
		return
	_play_click()
	hide()
	closed.emit()
	if free_on_close:
		queue_free()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# ==============================================================================
# Build
# ==============================================================================
func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760.0, 0.0)
	panel.add_theme_stylebox_override("panel", ShardsMenuStyle.panel_box())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.text = str(TITLES[mode][0])
	ShardsMenuStyle.style_title(title, 30)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = str(TITLES[mode][1])
	ShardsMenuStyle.style_body(subtitle, 14, true)
	root.add_child(subtitle)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	root.add_child(_rows)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)
	_back_button = ShardsMenuStyle.make_row_button("BACK")
	_back_button.pressed.connect(close)
	footer.add_child(_back_button)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ShardsMenuStyle.style_body(_status, 13, true)
	footer.add_child(_status)


func _rebuild_rows() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	var first_focus: Button = null
	for slot: int in range(1, GameState.SAVE_SLOT_COUNT + 1):
		var save: SaveGame = GameState.read_slot(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_rows.add_child(row)

		var main := ShardsMenuStyle.make_row_button(SessionFlow.describe_save(slot, save))
		main.alignment = HORIZONTAL_ALIGNMENT_LEFT
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.custom_minimum_size = Vector2(0.0, 64.0)
		main.clip_text = true
		main.add_theme_font_override("font", ShardsMenuStyle.BODY_FONT)
		main.add_theme_font_size_override("font_size", 14)
		# Empty slots can't be loaded or replaced, but they can be saved into.
		main.disabled = save == null and mode != Mode.SAVE
		main.focus_mode = Control.FOCUS_NONE if main.disabled else Control.FOCUS_ALL
		if mode == Mode.SAVE and slot == GameState.save_slot and not GameState.dev_session:
			main.text = main.text.replace("SLOT %d" % slot, "SLOT %d (current)" % slot)
		row.add_child(main)

		if mode == Mode.LOAD:
			main.pressed.connect(_on_load_pressed.bind(slot))
			var delete := ShardsMenuStyle.make_row_button("SURE?" if _armed_slot == slot else "DELETE", null, ShardsMenuStyle.COLOR_DANGER)
			delete.custom_minimum_size = Vector2(110.0, 64.0)
			delete.disabled = save == null
			delete.focus_mode = Control.FOCUS_NONE if save == null else Control.FOCUS_ALL
			delete.pressed.connect(_on_delete_pressed.bind(slot))
			row.add_child(delete)
		else:
			if _armed_slot == slot:
				main.text = "REPLACE THIS SAVE?  Press again to confirm.\n" + main.text.get_slice("\n", 1)
			# Saving into an empty slot or over your own slot needs no confirmation.
			var needs_confirm: bool = mode == Mode.PICK_NEW or (save != null and (slot != GameState.save_slot or GameState.dev_session))
			main.pressed.connect(_on_replace_pressed.bind(slot, needs_confirm))

		if first_focus == null and not main.disabled:
			first_focus = main

	(first_focus if first_focus != null else _back_button).grab_focus.call_deferred()


# ==============================================================================
# Actions
# ==============================================================================
func _on_load_pressed(slot: int) -> void:
	_play_click()
	if not SessionFlow.load_slot(get_tree(), slot):
		_status.text = "Slot %d couldn't be loaded - the file is missing or damaged." % slot
		_rebuild_rows()


func _on_delete_pressed(slot: int) -> void:
	_play_click()
	if _armed_slot != slot:
		_armed_slot = slot
		_status.text = "Press again to delete slot %d for good." % slot
	else:
		GameState.delete_slot(slot)
		_armed_slot = 0
		_status.text = "Slot %d deleted." % slot
	_rebuild_rows()


func _on_replace_pressed(slot: int, needs_confirm: bool) -> void:
	_play_click()
	if needs_confirm and _armed_slot != slot:
		_armed_slot = slot
		_status.text = ("Slot %d will be replaced when the new party sets out." if mode == Mode.PICK_NEW else "Slot %d will be overwritten with this game.") % slot
		_rebuild_rows()
		return
	slot_chosen.emit(slot)
	close()


func _play_click() -> void:
	if is_instance_valid(AudioManager) and AudioManager.has_method("play_ui_sound"):
		AudioManager.play_ui_sound("button-press")
