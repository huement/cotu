class_name MenuKitDialog
extends MenuKitPanel
## Small question window: a title, a message and 1 to 3 buttons.
##
## [codeblock]
## var dialog := MenuKitDialog.new()
## add_child(dialog)
## var choice: int = await dialog.ask("Quit game?", "Unsaved progress will be lost.", ["Stay", "Quit"])
## if choice == 1: get_tree().quit()
## [/codeblock]

## Index of the chosen button, or -1 when the player backs out.
signal answered(index: int)

var message: MenuKitText
var _buttons: Array[MenuKitButton] = []
var _answered: bool = true


func _init() -> void:
	super()
	name = "Dialog"
	fit_height = true
	close_on_back = false
	message = MenuKitText.new()
	message.name = "Message"
	content.add_child(message)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	back_requested.connect(_on_back)


func _footer_alignment() -> BoxContainer.AlignmentMode:
	return BoxContainer.ALIGNMENT_CENTER


func get_frame_size() -> Vector2:
	return Vector2(MenuKit.style.dialog_width(), 100000.0)


func _prepare_fit(width: float) -> void:
	message.fit_width(width)


## Opens the dialog and waits for the answer. The last button is the main one
## (focused first unless [param focus_index] says otherwise); the others use the
## secondary look.
func ask(p_title: String, p_message: String, buttons: PackedStringArray, focus_index: int = -1) -> int:
	title = p_title
	message.text = p_message
	message.visible = not p_message.is_empty()
	for button: MenuKitButton in _buttons:
		button.queue_free()
		footer.remove_child(button)
	_buttons.clear()
	for i: int in buttons.size():
		var button: MenuKitButton = add_button(buttons[i], i < buttons.size() - 1)
		if i == 0 and buttons.size() > 1:
			button.press_sound = &"back"
		button.pressed.connect(_answer.bind(i))
		_buttons.append(button)
	if focus_index < 0 or focus_index >= _buttons.size():
		focus_index = _buttons.size() - 1
	_answered = false
	open(_buttons[focus_index] if not _buttons.is_empty() else null)
	var index: int = await answered
	return index


func _answer(index: int) -> void:
	if _answered:
		return
	_answered = true
	# The confirm sound already played on the button; close silently.
	close(false)
	answered.emit(index)


func _on_back() -> void:
	if _answered:
		return
	_answered = true
	close()
	answered.emit(-1)
