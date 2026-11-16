class_name MenuKitMenuButton
extends MenuKitControl
## Large button of the main menu and pause menu, with an optional second line
## ("Chapter III · The Hollow Gate" under Continue, for example).

## Main text (English, translated automatically).
var text: String = "":
	set(value):
		text = value
		refresh()
## Second line, shown smaller (not translated: it usually comes from a save).
var sub_text: String = "":
	set(value):
		sub_text = value
		refresh()
## Id sent by the menu's [code]button_pressed[/code] signal.
var id: StringName = &""


func _init(p_text: String = "", p_id: StringName = &"") -> void:
	super()
	text = p_text
	id = p_id


func _process(_delta: float) -> void:
	# Keeps redrawing during time-based effects (glitch right after the focus).
	if focus_age() > 0.6:
		set_process(false)
	queue_redraw()


func _on_focus_entered() -> void:
	super()
	set_process(true)


func _get_minimum_size() -> Vector2:
	return kit_style().menu_button_size(tr(text), sub_text) if MenuKit.style != null else Vector2.ZERO


func _draw() -> void:
	draw_set_transform(appear_offset())
	kit_style().draw_menu_button(self, tr(text), sub_text)


func get_spoken_text() -> String:
	return tr(text) + (". " + sub_text if not sub_text.is_empty() else "")
