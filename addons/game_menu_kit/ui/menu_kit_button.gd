class_name MenuKitButton
extends MenuKitControl
## Button of panels and dialogs (Back, Reset, Confirm...).

var text: String = "":
	set(value):
		text = value
		refresh()
## Secondary look (Reset, Cancel...).
var ghost: bool = false:
	set(value):
		ghost = value
		queue_redraw()


func _init(p_text: String = "", p_ghost: bool = false) -> void:
	super()
	text = p_text
	ghost = p_ghost


func _get_minimum_size() -> Vector2:
	return kit_style().button_size(tr(text)) if MenuKit.style != null else Vector2.ZERO


func _draw() -> void:
	draw_set_transform(appear_offset())
	kit_style().draw_button(self, tr(text), ghost)


func get_spoken_text() -> String:
	return tr(text)
