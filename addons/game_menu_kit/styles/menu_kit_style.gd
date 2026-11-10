class_name MenuKitStyle
extends Resource
## Look of the kit's menus: colors, fonts, sizes, drawing and animations.
##
## Built-in styles extend this class and override its [code]draw_*[/code] methods.
## To change the colors of a style: FileSystem > right click > New Resource >
## pick the style (e.g. MenuKitStyleNeon), edit the colors, then set the file in
## Project Settings > Menu Kit > Style > Style (or call [code]MenuKit.set_style(path)[/code]).
##
## Every size is expressed in em: 1 em = [member base_em] pixels at 720p, scaled
## with the window height and the "Text size" setting.

## Horizontal alignment used by layouts.
enum Align { LEFT, CENTER, RIGHT }

## Size of the generated slot pictures.
const THUMB_SIZE: Vector2i = Vector2i(192, 108)
const BLUR_SHADER: Shader = preload("../ui/menu_kit_blur.gdshader")

## Main color: focus, selected values, glows.
@export var accent: Color = Color("35f0ff")
## Second color (details, secondary buttons).
@export var accent_2: Color = Color("ff3fb4")
@export var text_color: Color = Color("e8f7ff")
@export var muted_color: Color = Color("8a9cc2")
## Screen background behind the animated background.
@export var background_color: Color = Color("05030d")
## Size of 1 em at 720p, in pixels.
@export var base_em: float = 19.0
## Pitch of the interface sounds (1.0 = normal).
@export var sound_pitch: float = 1.0
## Room reverb of the interface sounds (0 = dry).
@export var sound_room: float = 0.05

## Current size of 1 em in pixels (set by the MenuKit autoload).
var em: float = 19.0

var _fonts: Dictionary = {}
var _spacing: Dictionary = {}
var _box: StyleBoxFlat = StyleBoxFlat.new()
var _textures: Dictionary = {}


## Called by the kit when the window or text size changes.
func set_em(value: float) -> void:
	em = maxf(value, 1.0)
	_fonts.clear()
	_spacing.clear()


# --------------------------------------------------------------------------
# Text
# --------------------------------------------------------------------------

## Font description of a text role: [code][font, weight, size_em, spacing_em, uppercase, cap_height][/code].
## Roles: title, title_2, pause_title, kicker, menu_button, menu_sub, foot, panel_title,
## panel_tag, tab, label, value, option, key, button, message, header, slot_name, slot_title,
## slot_meta, loading_title, loading_value, loading_tip, curtain.
func font_spec(role: StringName) -> Array:
	var size: float = 1.0
	match role:
		&"title":
			size = 3.2
		&"title_2":
			size = 3.2
		&"pause_title":
			size = 2.2
		&"curtain":
			size = 1.4
		&"panel_title":
			size = 1.3
		&"menu_button":
			size = 1.1
		&"kicker", &"menu_sub", &"foot", &"panel_tag", &"header", &"slot_meta":
			size = 0.72
		&"tab", &"option", &"key", &"button":
			size = 0.9
		&"loading_title":
			size = 1.2
	return [null, 0, size, 0.0, false, 0.7]


## Font of a text role, with the style's weight and letter spacing.
func get_font(role: StringName) -> Font:
	if _fonts.has(role):
		return _fonts[role] as Font
	var spec: Array = font_spec(role)
	var base: Font = spec[0] as Font
	if base == null:
		base = ThemeDB.fallback_font
	var variation: FontVariation = FontVariation.new()
	variation.base_font = base
	var weight: int = int(spec[1])
	if weight > 0:
		var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
		variation.variation_opentype = {tag: weight}
	var spacing: int = roundi(float(spec[3]) * get_font_size(role))
	variation.spacing_glyph = spacing
	_fonts[role] = variation
	_spacing[role] = spacing
	return variation


## Font size of a text role, in pixels.
func get_font_size(role: StringName) -> int:
	return maxi(1, roundi(float(font_spec(role)[2]) * em))


## Applies the role's letter case.
func format_text(role: StringName, text: String) -> String:
	return text.to_upper() if bool(font_spec(role)[4]) else text


## Width of a text, without the letter spacing after the last letter.
func text_width(role: StringName, text: String) -> float:
	var font: Font = get_font(role)
	var formatted: String = format_text(role, text)
	if formatted.is_empty():
		return 0.0
	return font.get_string_size(formatted, HORIZONTAL_ALIGNMENT_LEFT, -1, get_font_size(role)).x \
		- float(_spacing.get(role, 0))


## Height of the capital letters of a role (used to center text).
func cap_height(role: StringName) -> float:
	return float(font_spec(role)[5]) * get_font_size(role)


## Draws one line of text, centered vertically in [param rect] (on the capital letters).
func draw_text(c: CanvasItem, role: StringName, text: String, rect: Rect2, color: Color,
		align: Align = Align.LEFT, offset: Vector2 = Vector2.ZERO) -> void:
	if text.is_empty() or color.a <= 0.0:
		return
	var font: Font = get_font(role)
	var size: int = get_font_size(role)
	var formatted: String = format_text(role, text)
	c.draw_string(font, text_origin(role, text, rect, align) + offset, formatted,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Baseline position used by [method draw_text].
func text_origin(role: StringName, text: String, rect: Rect2, align: Align = Align.LEFT) -> Vector2:
	var x: float = rect.position.x
	if align != Align.LEFT:
		var width: float = text_width(role, text)
		x += (rect.size.x - width) * (0.5 if align == Align.CENTER else 1.0)
	return Vector2(roundf(x), roundf(rect.get_center().y + cap_height(role) * 0.5))


## Like [method draw_text], but shrinks the text (down to 55 %) when it is wider than [param rect].
func draw_text_fit(c: CanvasItem, role: StringName, text: String, rect: Rect2, color: Color,
		align: Align = Align.CENTER) -> void:
	var width: float = text_width(role, text)
	if width <= rect.size.x or width <= 0.0:
		draw_text(c, role, text, rect, color, align)
		return
	var font: Font = get_font(role)
	var ratio: float = maxf(rect.size.x / width, 0.55)
	var size: int = maxi(1, floori(get_font_size(role) * ratio))
	var formatted: String = format_text(role, text)
	var real_width: float = font.get_string_size(formatted, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x - float(_spacing.get(role, 0))
	var x: float = rect.position.x
	if align == Align.CENTER:
		x += (rect.size.x - real_width) * 0.5
	elif align == Align.RIGHT:
		x += rect.size.x - real_width
	var baseline: float = rect.get_center().y + float(font_spec(role)[5]) * size * 0.5
	c.draw_string(font, Vector2(roundf(x), roundf(baseline)), formatted, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Draws a text with a soft glow around it (stacked outlines).
func draw_text_glow(c: CanvasItem, role: StringName, text: String, origin: Vector2, color: Color,
		radius: float, steps: int = 4) -> void:
	if color.a <= 0.0 or radius <= 0.0:
		return
	var font: Font = get_font(role)
	var size: int = get_font_size(role)
	var formatted: String = format_text(role, text)
	for i: int in steps:
		var k: float = 1.0 - float(i) / float(steps)
		var outline: int = maxi(1, roundi(radius * 2.0 * k))
		var alpha: float = color.a * (1.2 / float(steps)) * (1.0 - k * 0.5)
		c.draw_string_outline(font, origin, formatted, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline,
			Color(color, alpha))


# --------------------------------------------------------------------------
# Drawing helpers
# --------------------------------------------------------------------------

## Draws a StyleBoxFlat configured by [param setup] (reused, no allocation).
func draw_box(c: CanvasItem, rect: Rect2, bg: Color, border: Color = Color.TRANSPARENT,
		border_width: float = 0.0, radius: float = 0.0, shadow: Color = Color.TRANSPARENT,
		shadow_size: float = 0.0, shadow_offset: Vector2 = Vector2.ZERO) -> void:
	_box.bg_color = bg
	_box.draw_center = bg.a > 0.0
	_box.border_color = border
	var width: int = roundi(border_width) if border.a > 0.0 else 0
	if border.a > 0.0 and border_width > 0.0:
		width = maxi(1, width)
	_box.set_border_width_all(width)
	_box.set_corner_radius_all(roundi(radius))
	_box.corner_detail = 8 if radius > 0.0 else 1
	_box.shadow_color = shadow
	_box.shadow_size = roundi(shadow_size) if shadow.a > 0.0 else 0
	_box.shadow_offset = shadow_offset
	_box.anti_aliasing = radius > 0.0
	_box.draw(c.get_canvas_item(), rect)


## Soft glow around a rectangle.
func draw_glow(c: CanvasItem, rect: Rect2, color: Color, size: float, radius: float = 0.0) -> void:
	if color.a <= 0.0 or size <= 0.0:
		return
	draw_box(c, rect, Color.TRANSPARENT, Color.TRANSPARENT, 0.0, radius, color, size)


## Fills a convex polygon with a horizontal gradient between [param x0] and [param x1].
## [param stops] is a list of [code][position 0..1, Color][/code].
func fill_gradient_h(c: CanvasItem, points: PackedVector2Array, x0: float, x1: float, stops: Array) -> void:
	if points.size() < 3 or stops.is_empty():
		return
	var span: float = x1 - x0
	if absf(span) < 0.001:
		c.draw_colored_polygon(points, stops[0][1] as Color)
		return
	var bounds: Array[float] = [-INF]
	for stop: Array in stops:
		bounds.append(x0 + float(stop[0]) * span)
	bounds.append(INF)
	for i: int in bounds.size() - 1:
		var a: float = bounds[i]
		var b: float = bounds[i + 1]
		if b <= a:
			continue
		var part: PackedVector2Array = clip_polygon_x(points, a, b)
		if part.size() < 3 or absf(_area(part)) < 0.5:
			continue
		var colors: PackedColorArray = PackedColorArray()
		for p: Vector2 in part:
			colors.append(gradient_at(stops, (p.x - x0) / span))
		c.draw_polygon(part, colors)


static func _area(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in points.size():
		total += points[i].cross(points[(i + 1) % points.size()])
	return total * 0.5


## Fills a rectangle with a vertical gradient from [param top] to [param bottom].
func fill_gradient_v(c: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	c.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]), PackedColorArray([top, top, bottom, bottom]))


## Soft glow on the inside edges of a rectangle.
func draw_inner_glow(c: CanvasItem, rect: Rect2, color: Color, size: float) -> void:
	var clear: Color = Color(color, 0.0)
	var p: Vector2 = rect.position
	var e: Vector2 = rect.end
	size = minf(size, minf(rect.size.x, rect.size.y) * 0.5)
	var colors: PackedColorArray = PackedColorArray([color, color, clear, clear])
	c.draw_polygon(PackedVector2Array([p, Vector2(e.x, p.y), Vector2(e.x - size, p.y + size), p + Vector2(size, size)]), colors)
	c.draw_polygon(PackedVector2Array([Vector2(e.x, p.y), e, e - Vector2(size, size), Vector2(e.x - size, p.y + size)]), colors)
	c.draw_polygon(PackedVector2Array([e, Vector2(p.x, e.y), Vector2(p.x + size, e.y - size), e - Vector2(size, size)]), colors)
	c.draw_polygon(PackedVector2Array([Vector2(p.x, e.y), p, p + Vector2(size, size), Vector2(p.x + size, e.y - size)]), colors)


## Color of a gradient ([code][[position, Color], ...][/code]) at [param t].
static func gradient_at(stops: Array, t: float) -> Color:
	if t <= float(stops[0][0]):
		return stops[0][1]
	for i: int in stops.size() - 1:
		var a: float = float(stops[i][0])
		var b: float = float(stops[i + 1][0])
		if t <= b:
			var k: float = 0.0 if b - a < 0.00001 else (t - a) / (b - a)
			return (stops[i][1] as Color).lerp(stops[i + 1][1] as Color, k)
	return stops[stops.size() - 1][1]


## Keeps the part of a convex polygon between two vertical lines.
static func clip_polygon_x(points: PackedVector2Array, x_min: float, x_max: float) -> PackedVector2Array:
	return _clip_side(_clip_side(points, x_min, true), x_max, false)


static func _clip_side(points: PackedVector2Array, x: float, keep_right: bool) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var count: int = points.size()
	if count == 0 or is_inf(x):
		return points
	for i: int in count:
		var current: Vector2 = points[i]
		var previous: Vector2 = points[(i + count - 1) % count]
		var current_in: bool = current.x >= x if keep_right else current.x <= x
		var previous_in: bool = previous.x >= x if keep_right else previous.x <= x
		if current_in != previous_in:
			var t: float = (x - previous.x) / (current.x - previous.x)
			result.append(previous.lerp(current, t))
		if current_in:
			result.append(current)
	return result


## Keeps the part of a convex polygon inside [param rect].
static func clip_polygon_rect(points: PackedVector2Array, rect: Rect2) -> PackedVector2Array:
	var result: PackedVector2Array = clip_polygon_x(points, rect.position.x, rect.end.x)
	return _clip_side_y(_clip_side_y(result, rect.position.y, true), rect.end.y, false)


static func _clip_side_y(points: PackedVector2Array, y: float, keep_below: bool) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var count: int = points.size()
	if count == 0:
		return points
	for i: int in count:
		var current: Vector2 = points[i]
		var previous: Vector2 = points[(i + count - 1) % count]
		var current_in: bool = current.y >= y if keep_below else current.y <= y
		var previous_in: bool = previous.y >= y if keep_below else previous.y <= y
		if current_in != previous_in:
			var t: float = (y - previous.y) / (current.y - previous.y)
			result.append(previous.lerp(current, t))
		if current_in:
			result.append(current)
	return result


## Outline of a rectangle with rounded corners.
static func rounded_rect_points(rect: Rect2, radius: float, segments: int = 5) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	radius = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if radius <= 0.5:
		return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)])
	var centers: Array[Vector2] = [
		rect.position + Vector2(radius, radius), Vector2(rect.end.x - radius, rect.position.y + radius),
		rect.end - Vector2(radius, radius), Vector2(rect.position.x + radius, rect.end.y - radius),
	]
	for corner: int in 4:
		for i: int in segments + 1:
			var angle: float = PI + corner * PI * 0.5 + PI * 0.5 * float(i) / float(segments)
			var point: Vector2 = centers[corner] + Vector2(cos(angle), sin(angle)) * radius
			# Pills (radius = half the height) would repeat a point: triangulation fails on those.
			if points.is_empty() or not point.is_equal_approx(points[points.size() - 1]):
				points.append(point)
	if points.size() > 1 and points[0].is_equal_approx(points[points.size() - 1]):
		points.remove_at(points.size() - 1)
	return points


## Draws [param texture] stretched over [param rect], with rounded corners.
func draw_texture_rounded(c: CanvasItem, texture: Texture2D, rect: Rect2, radius: float,
		modulate: Color = Color.WHITE) -> void:
	var points: PackedVector2Array = rounded_rect_points(rect, radius)
	var uvs: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		uvs.append((p - rect.position) / rect.size)
	c.draw_polygon(points, PackedColorArray([modulate]), uvs, texture)


## Rectangle with its bottom-right corner cut ([param cut] in pixels).
static func bevel_points(rect: Rect2, cut: float, cut_start: float = 0.6) -> PackedVector2Array:
	var p: Vector2 = rect.position
	var s: Vector2 = rect.size
	return PackedVector2Array([
		p, Vector2(p.x + s.x, p.y), Vector2(p.x + s.x, p.y + s.y * cut_start),
		Vector2(p.x + s.x - cut, p.y + s.y), Vector2(p.x, p.y + s.y),
	])


## Smooth 0..1 easing used by focus animations (like CSS cubic-bezier(.2, .8, .2, 1)).
static func ease_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


# --------------------------------------------------------------------------
# Main menu
# --------------------------------------------------------------------------

## Layout of the main menu.
func menu_layout() -> Dictionary:
	return {
		"align": Align.CENTER,
		"margin": Vector2(0.07, 0.07),
		"logo_gap": 2.0,
		"button_gap": 0.45,
		"button_min_width": 12.0,
		"foot_align": Align.CENTER,
		"foot_bottom": 0.055,
		# Optional "bottom": fraction of the screen height kept below the buttons
		# (the title and buttons are then anchored to the bottom instead of centered).
	}


func menu_button_size(text: String, sub: String) -> Vector2:
	var width: float = maxf(text_width(&"menu_button", text), text_width(&"menu_sub", sub)) + 2.4 * em
	var height: float = 2.3 * em + (0.9 * em if not sub.is_empty() else 0.0)
	return Vector2(width, height)


func draw_menu_button(c: MenuKitControl, text: String, sub: String) -> void:
	var f: float = c.focus_amount
	var rect: Rect2 = Rect2(Vector2.ZERO, c.size)
	draw_box(c, rect, Color(accent, 0.12 + 0.5 * f), Color(accent, 0.3 + 0.7 * f), 1.0, 0.4 * em)
	var color: Color = text_color.lerp(background_color, f)
	if sub.is_empty():
		draw_text(c, &"menu_button", text, rect, color, Align.CENTER)
	else:
		draw_text(c, &"menu_button", text, Rect2(0, 0, rect.size.x, rect.size.y * 0.62), color, Align.CENTER)
		draw_text(c, &"menu_sub", sub, Rect2(0, rect.size.y * 0.5, rect.size.x, rect.size.y * 0.4),
			muted_color.lerp(background_color, f * 0.8), Align.CENTER)


func title_size(kicker: String, lines: PackedStringArray, compact: bool = false) -> Vector2:
	var width: float = text_width(&"kicker", kicker)
	var height: float = (1.3 * em if not kicker.is_empty() else 0.0)
	for i: int in lines.size():
		var role: StringName = title_role(i, compact)
		width = maxf(width, text_width(role, lines[i]))
		height += get_font_size(role) * 1.02
	return Vector2(width, height)


## [param align] is the menu alignment. [param compact]: smaller title of the pause menu.
func draw_title(c: Control, kicker: String, lines: PackedStringArray, time: float, align: Align,
		compact: bool = false) -> void:
	var y: float = 0.0
	if not kicker.is_empty():
		draw_text(c, &"kicker", kicker, Rect2(0, 0, c.size.x, 1.0 * em), accent, align)
		y = 1.3 * em
	for i: int in lines.size():
		var role: StringName = title_role(i, compact)
		var h: float = get_font_size(role) * 1.02
		draw_text(c, role, lines[i], Rect2(0, y, c.size.x, h), text_color if i == 0 else accent, align)
		y += h


## Text role of a title line: "title", "title_2", or "pause_title" for the pause menu.
static func title_role(line: int, compact: bool) -> StringName:
	if compact:
		return &"pause_title"
	return &"title" if line == 0 else &"title_2"


func draw_footer(c: Control, text: String, rect: Rect2, align: Align) -> void:
	draw_text(c, &"foot", text, rect, muted_color, align)


# --------------------------------------------------------------------------
# Panels and dialogs
# --------------------------------------------------------------------------

## Inner margins of a panel, in pixels.
func panel_padding() -> Vector2:
	return Vector2(1.6 * em, 1.4 * em)


## Height of the title line of a panel.
func panel_header_height() -> float:
	return 2.4 * em


func draw_panel(c: Control, rect: Rect2, title: String, tag: String) -> void:
	draw_box(c, rect, Color(background_color, 0.95), Color(accent, 0.35), 1.0, 0.6 * em,
		Color(0, 0, 0, 0.35), 1.2 * em, Vector2(0, 0.3 * em))
	var pad: Vector2 = panel_padding()
	var header: Rect2 = Rect2(rect.position.x + pad.x, rect.position.y + pad.y,
		rect.size.x - pad.x * 2.0, panel_header_height() * 0.6)
	draw_text(c, &"panel_title", title, header, text_color)
	draw_text(c, &"panel_tag", tag, header, accent, Align.RIGHT)


## Optional layer drawn behind each panel frame and sized to it (frosted glass...),
## or null. It follows the frame's animation.
func create_panel_backdrop() -> Control:
	return null


## Visible part of the panel while it opens ([param t] from 0 to 1).
func panel_reveal_rect(rect: Rect2, _t: float) -> Rect2:
	return rect


## Opening / closing animation. [param frame] is the panel's frame (its pivot is centered).
func animate_panel(panel: Control, frame: Control, opening: bool) -> Tween:
	var tween: Tween = panel.create_tween().set_parallel(true)
	if opening:
		frame.modulate.a = 0.0
		frame.scale = Vector2(0.97, 0.97)
		tween.tween_property(frame, "modulate:a", 1.0, 0.25)
		tween.tween_property(frame, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(frame, "modulate:a", 0.0, 0.18)
		tween.tween_property(frame, "scale", Vector2(0.97, 0.97), 0.18)
	return tween


## Alignment of the buttons at the bottom of panels (dialogs are always centered).
func panel_footer_align() -> Align:
	return Align.RIGHT


## Width of a dialog, in pixels.
func dialog_width() -> float:
	return 24.0 * em


## Default size of the options panel, in pixels.
func options_size() -> Vector2:
	return Vector2(44.0 * em, 31.0 * em)


# --------------------------------------------------------------------------
# Tabs
# --------------------------------------------------------------------------

## True to center the tabs in the tab bar.
func tabs_centered() -> bool:
	return false


func tab_bar_height() -> float:
	return 2.3 * em


func tab_width(text: String) -> float:
	return text_width(&"tab", text) + 2.0 * em


func draw_tab_bar(c: Control, rect: Rect2) -> void:
	c.draw_line(Vector2(rect.position.x, rect.end.y - 1.0), Vector2(rect.end.x, rect.end.y - 1.0), Color(accent, 0.2), 1.0)


func draw_tab(c: Control, rect: Rect2, text: String, selected: bool, focused: bool, hovered: bool) -> void:
	var color: Color = accent if selected else muted_color
	if focused or hovered:
		color = text_color if not selected else accent.lightened(0.3)
	draw_text(c, &"tab", text, rect, color, Align.CENTER)
	if selected:
		c.draw_rect(Rect2(rect.position.x, rect.end.y - 2.0, rect.size.x, 2.0), accent)


# --------------------------------------------------------------------------
# Option rows
# --------------------------------------------------------------------------

func row_height() -> float:
	return 2.5 * em


## Background, label and separator of a row. [code]c.focus_amount[/code] is the focus.
func draw_row(c: MenuKitControl, rect: Rect2, label: String) -> void:
	if c.focus_amount > 0.0:
		draw_box(c, rect.grow_individual(0.5 * em, 0, 0.5 * em, 0), Color(accent, 0.08 * c.focus_amount), Color.TRANSPARENT, 0.0, 0.3 * em)
	draw_text(c, &"label", label, rect, text_color)
	c.draw_line(Vector2(rect.position.x, rect.end.y - 0.5), Vector2(rect.end.x, rect.end.y - 0.5), Color(accent, 0.12), 1.0)


## Width of the value shown next to sliders.
func value_width() -> float:
	return 3.2 * em


func draw_value(c: Control, rect: Rect2, text: String) -> void:
	draw_text(c, &"value", text, rect, accent, Align.RIGHT)


## [param rect] is the whole slider area; [param ratio] the position from 0 to 1.
func draw_slider(c: MenuKitControl, rect: Rect2, ratio: float, active: bool) -> void:
	var h: float = 0.22 * em
	var track: Rect2 = Rect2(rect.position.x, rect.get_center().y - h * 0.5, rect.size.x, h)
	draw_box(c, track, Color(1, 1, 1, 0.14), Color.TRANSPARENT, 0.0, h * 0.5)
	draw_box(c, Rect2(track.position, Vector2(track.size.x * ratio, h)), accent, Color.TRANSPARENT, 0.0, h * 0.5)
	var knob: float = 0.9 * em * (1.15 if active else 1.0)
	var center: Vector2 = Vector2(track.position.x + track.size.x * ratio, track.get_center().y)
	c.draw_circle(center, knob * 0.5, text_color)


func switch_size() -> Vector2:
	return Vector2(3.0 * em, 1.6 * em)


## [param amount] goes from 0 (off) to 1 (on), animated with a small overshoot.
func draw_switch(c: MenuKitControl, rect: Rect2, amount: float, active: bool) -> void:
	var on: float = clampf(amount, 0.0, 1.0)
	draw_box(c, rect, Color(accent, 0.1 + 0.4 * on), Color(accent, 0.5 if active else 0.3), 1.0, rect.size.y * 0.5)
	var knob: float = rect.size.y - 0.4 * em
	var x: float = rect.position.x + 0.2 * em + (rect.size.x - knob - 0.4 * em) * amount
	c.draw_circle(Vector2(x + knob * 0.5, rect.get_center().y), knob * 0.5, muted_color.lerp(text_color, on))


func segment_height() -> float:
	return 1.8 * em


func segment_width(text: String) -> float:
	return text_width(&"option", text) + 1.5 * em


## [param widths] are the widths of each segment; [param hovered] is -1 or an index.
func draw_segments(c: MenuKitControl, rect: Rect2, labels: PackedStringArray, widths: PackedFloat32Array,
		selected: int, hovered: int, active: bool) -> void:
	draw_box(c, rect, Color.TRANSPARENT, Color(accent, 0.45 if active else 0.3), 1.0, 0.3 * em)
	var x: float = rect.position.x
	for i: int in labels.size():
		var r: Rect2 = Rect2(x, rect.position.y, widths[i], rect.size.y)
		if i == selected:
			draw_box(c, r.grow(-2.0), accent, Color.TRANSPARENT, 0.0, 0.25 * em)
		var color: Color = background_color if i == selected else (text_color if i == hovered else muted_color)
		draw_text(c, &"option", labels[i], r, color, Align.CENTER)
		x += widths[i]


func stepper_arrow_size() -> float:
	return 1.8 * em


func stepper_value_width() -> float:
	return 7.5 * em


## [param hovered_side] is -1 (left arrow), 1 (right arrow) or 0.
func draw_stepper(c: MenuKitControl, rect: Rect2, text: String, hovered_side: int, active: bool) -> void:
	var a: float = stepper_arrow_size()
	var left: Rect2 = Rect2(rect.position.x, rect.get_center().y - a * 0.5, a, a)
	var right: Rect2 = Rect2(rect.end.x - a, left.position.y, a, a)
	for side: int in [-1, 1]:
		var r: Rect2 = left if side == -1 else right
		var hot: bool = hovered_side == side
		draw_box(c, r, Color(accent, 0.2 if hot else 0.0), Color(accent, 0.5 if active or hot else 0.3), 1.0, 0.3 * em)
		draw_arrow(c, r.get_center(), side, 0.28 * em, accent)
	draw_text(c, &"option", text, Rect2(left.end.x, rect.position.y, right.position.x - left.end.x, rect.size.y), text_color, Align.CENTER)


## Small chevron pointing left (-1) or right (1).
func draw_arrow(c: CanvasItem, center: Vector2, direction: int, size: float, color: Color, width: float = 0.0) -> void:
	var d: float = float(direction)
	var w: float = width if width > 0.0 else maxf(1.5, em * 0.1)
	c.draw_polyline(PackedVector2Array([
		center + Vector2(-d * size * 0.5, -size), center + Vector2(d * size * 0.5, 0.0),
		center + Vector2(-d * size * 0.5, size),
	]), color, w, true)


func key_size() -> Vector2:
	return Vector2(6.6 * em, 1.8 * em)


## [param highlighted]: the key is selected in a focused row. [param listening]:
## waiting for the player's input.
func draw_key(c: MenuKitControl, rect: Rect2, text: String, highlighted: bool, listening: bool, time: float) -> void:
	var pulse: float = 0.55 + 0.45 * cos(time * TAU / 0.9) if listening else 1.0
	draw_box(c, rect, Color(accent, 0.2 if highlighted else 0.05), Color(accent, 0.6 if highlighted else 0.35), 1.0, 0.3 * em)
	draw_text_fit(c, &"key", text, rect.grow_individual(-0.4 * em, 0, -0.4 * em, 0), Color(accent, pulse))


## Column titles above key bindings ([param columns] are the rects of each key column).
func draw_bindings_header(c: Control, rect: Rect2, title: String, columns: Array, captions: PackedStringArray) -> void:
	draw_text(c, &"header", title, rect, muted_color)
	for i: int in mini(columns.size(), captions.size()):
		draw_text(c, &"header", captions[i], columns[i] as Rect2, muted_color, Align.CENTER)


# --------------------------------------------------------------------------
# Buttons
# --------------------------------------------------------------------------

func button_size(text: String) -> Vector2:
	return Vector2(text_width(&"button", text) + 2.6 * em, 2.2 * em)


## Panel button. [param ghost] is the secondary look (Reset, Cancel...).
func draw_button(c: MenuKitControl, text: String, ghost: bool) -> void:
	var f: float = c.focus_amount
	var color: Color = accent_2 if ghost else accent
	var rect: Rect2 = Rect2(Vector2.ZERO, c.size)
	draw_box(c, rect, Color(color, f), color, 1.0, 0.35 * em)
	draw_text(c, &"button", text, rect, color.lerp(background_color, f), Align.CENTER)


func style_scroll_container(scroll: ScrollContainer) -> void:
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var grabber: StyleBoxFlat = StyleBoxFlat.new()
	grabber.bg_color = Color(accent, 0.45)
	grabber.set_corner_radius_all(roundi(0.15 * em))
	grabber.content_margin_left = roundi(0.15 * em)
	grabber.content_margin_right = roundi(0.15 * em)
	var grabber_hot: StyleBoxFlat = grabber.duplicate() as StyleBoxFlat
	grabber_hot.bg_color = Color(accent, 0.75)
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(accent, 0.06)
	track.set_corner_radius_all(roundi(0.15 * em))
	track.content_margin_left = roundi(0.15 * em)
	track.content_margin_right = roundi(0.15 * em)
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber_hot)
	bar.add_theme_stylebox_override("grabber_pressed", grabber_hot)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)


# --------------------------------------------------------------------------
# Screens
# --------------------------------------------------------------------------

## Animated background of the menus (full screen, below everything).
func create_background() -> Control:
	var rect: ColorRect = ColorRect.new()
	rect.color = background_color
	return rect


## Effects drawn above the menus (scanlines, vignette...), or null.
func create_overlay() -> Control:
	return null


## Entrance of the main menu: logo, then each button with a small delay.
func animate_menu_intro(logo: MenuKitControl, buttons: Array, footer: MenuKitControl) -> void:
	var nodes: Array = [logo]
	nodes.append_array(buttons)
	nodes.append(footer)
	for i: int in nodes.size():
		var node: MenuKitControl = nodes[i] as MenuKitControl
		if node == null:
			continue
		node.appear = 0.0
		var tween: Tween = node.create_tween()
		tween.tween_interval(0.0 if i == 0 else 0.12 + 0.065 * (i - 1))
		tween.tween_property(node, "appear", 1.0, 0.7 if i == 0 else 0.55)


## Offset and opacity of a control during its entrance ([param appear] 0..1).
func appear_transform(_c: Control, appear: float) -> Array:
	var k: float = ease_out(appear)
	return [Vector2(0, (1.0 - k) * 0.8 * em), k]


# --------------------------------------------------------------------------
# Pause menu and quit
# --------------------------------------------------------------------------

## Layout of the pause menu (same keys as [method menu_layout]).
func pause_layout() -> Dictionary:
	var layout: Dictionary = menu_layout()
	layout["logo_gap"] = 1.5
	return layout


## Background of the pause menu, over the paused game (blurred and darkened).
## The kit animates its [code]amount[/code] shader parameter from 0 to 1.
func create_pause_background() -> Control:
	var rect: MenuKitShaderRect = MenuKitShaderRect.new(BLUR_SHADER)
	rect.set_param(&"tint", Color(background_color, 0.7))
	return rect


## Text shown on the black screen when the game quits.
func quit_text() -> String:
	return "See you soon"


## Black screen shown when the game quits.
func draw_curtain(c: Control, rect: Rect2, text: String) -> void:
	c.draw_rect(rect, Color.BLACK)
	draw_text(c, &"curtain", text, rect, Color(1, 1, 1, 0.85), Align.CENTER)
