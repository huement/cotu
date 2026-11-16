class_name MenuKitText
extends Control
## Paragraph of wrapped text drawn with a style role (dialog messages).

var text: String = "":
	set(value):
		text = value
		update_minimum_size()
		queue_redraw()
var role: StringName = &"message"
var align: MenuKitStyle.Align = MenuKitStyle.Align.CENTER

var _width: float = 0.0


func _init(p_text: String = "", p_role: StringName = &"message") -> void:
	text = p_text
	role = p_role
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(_on_resized)


func _on_resized() -> void:
	if not is_equal_approx(size.x, _width):
		fit_width(size.x)


## Height needed for [param width] (call before the container lays it out).
func fit_width(width: float) -> void:
	_width = width
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	if MenuKit.style == null or text.is_empty() or _width <= 0.0:
		return Vector2.ZERO
	var style: MenuKitStyle = MenuKit.style
	var font: Font = style.get_font(role)
	var font_size: int = style.get_font_size(role)
	var height: float = font.get_multiline_string_size(style.format_text(role, tr(text)),
		_h_align(), _width, font_size).y
	return Vector2(0, ceilf(height))


func _draw() -> void:
	if MenuKit.style == null or text.is_empty():
		return
	var style: MenuKitStyle = MenuKit.style
	var font: Font = style.get_font(role)
	var font_size: int = style.get_font_size(role)
	draw_multiline_string(font, Vector2(0, font.get_ascent(font_size)), style.format_text(role, tr(text)),
		_h_align(), size.x, font_size, -1, Color(style.text_color, 0.82))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		update_minimum_size()
		queue_redraw()


func _h_align() -> HorizontalAlignment:
	match align:
		MenuKitStyle.Align.CENTER:
			return HORIZONTAL_ALIGNMENT_CENTER
		MenuKitStyle.Align.RIGHT:
			return HORIZONTAL_ALIGNMENT_RIGHT
	return HORIZONTAL_ALIGNMENT_LEFT
