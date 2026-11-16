class_name MenuKitTitle
extends MenuKitControl
## Game title of the main menu: a small line above ([member kicker]) and one or two
## big lines, drawn and animated by the style. Set [member logo] to show your own
## image instead of the text.

var kicker: String = "":
	set(value):
		kicker = value
		refresh()
var lines: PackedStringArray = PackedStringArray():
	set(value):
		lines = value
		refresh()
## Optional logo image, drawn instead of the text title.
var logo: Texture2D = null:
	set(value):
		logo = value
		refresh()
## Height of the logo image, in em.
var logo_height: float = 7.0
## Smaller title (pause menu).
var compact: bool = false:
	set(value):
		compact = value
		refresh()
var align: MenuKitStyle.Align = MenuKitStyle.Align.LEFT:
	set(value):
		align = value
		queue_redraw()


func _init() -> void:
	super()
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func _ready() -> void:
	super()
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _get_minimum_size() -> Vector2:
	if MenuKit.style == null:
		return Vector2.ZERO
	var style: MenuKitStyle = kit_style()
	if logo != null:
		var height: float = logo_height * style.em
		var size: Vector2 = Vector2(logo.get_width() * height / maxf(1.0, logo.get_height()), height)
		if not kicker.is_empty():
			size.y += 1.3 * style.em
		return size
	return style.title_size(tr(kicker), _translated_lines(), compact)


func _draw() -> void:
	draw_set_transform(appear_offset())
	var style: MenuKitStyle = kit_style()
	if logo == null:
		style.draw_title(self, tr(kicker), _translated_lines(), Time.get_ticks_msec() / 1000.0, align, compact)
		return
	var y: float = 0.0
	if not kicker.is_empty():
		style.draw_text(self, &"kicker", tr(kicker), Rect2(0, 0, size.x, style.em), style.accent, align)
		y = 1.3 * style.em
	var height: float = size.y - y
	var width: float = logo.get_width() * height / maxf(1.0, logo.get_height())
	var x: float = 0.0
	if align == MenuKitStyle.Align.CENTER:
		x = (size.x - width) * 0.5
	elif align == MenuKitStyle.Align.RIGHT:
		x = size.x - width
	draw_texture_rect(logo, Rect2(x, y, width, height), false)


func _translated_lines() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for line: String in lines:
		result.append(tr(line))
	return result
