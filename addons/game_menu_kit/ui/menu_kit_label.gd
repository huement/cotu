class_name MenuKitLabel
extends MenuKitControl
## One line of text drawn with a style role (footer of the main menu, hints...).

var text: String = "":
	set(value):
		text = value
		refresh()
var role: StringName = &"foot"
var align: MenuKitStyle.Align = MenuKitStyle.Align.LEFT:
	set(value):
		align = value
		queue_redraw()


func _init(p_text: String = "", p_role: StringName = &"foot") -> void:
	super()
	text = p_text
	role = p_role
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func _get_minimum_size() -> Vector2:
	if MenuKit.style == null:
		return Vector2.ZERO
	return Vector2(kit_style().text_width(role, tr(text)), kit_style().em * 1.2)


func _draw() -> void:
	draw_set_transform(appear_offset())
	var style: MenuKitStyle = kit_style()
	if role == &"foot":
		style.draw_footer(self, tr(text), Rect2(Vector2.ZERO, size), align)
	else:
		style.draw_text(self, role, tr(text), Rect2(Vector2.ZERO, size), style.muted_color, align)
