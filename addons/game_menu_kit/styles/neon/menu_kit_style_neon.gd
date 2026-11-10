class_name MenuKitStyleNeon
extends MenuKitStyle
## Neon: synthwave sci-fi for action, shooters, arcade and cyberpunk games.
## Retro grid scrolling towards the player, flickering glowing title, bevelled
## buttons that fill with a short glitch, panels that open like a CRT screen.

const ORBITRON: FontFile = preload("../../fonts/Orbitron-Variable.ttf")
const RAJDHANI_SEMIBOLD: FontFile = preload("../../fonts/Rajdhani-SemiBold.ttf")
const RAJDHANI_BOLD: FontFile = preload("../../fonts/Rajdhani-Bold.ttf")
const BACKGROUND_SHADER: Shader = preload("neon_background.gdshader")
const OVERLAY_SHADER: Shader = preload("neon_overlay.gdshader")

## Titles, values and keys.
@export var title_font: Font = ORBITRON
## Labels and texts.
@export var ui_font: Font = RAJDHANI_SEMIBOLD
## Buttons and tabs.
@export var ui_font_bold: Font = RAJDHANI_BOLD
@export var title_color: Color = Color("f4fdff")
@export var panel_top_color: Color = Color(0.063, 0.043, 0.149, 0.95)
@export var panel_bottom_color: Color = Color(0.027, 0.016, 0.071, 0.95)
@export var show_sun: bool = true
@export var scanlines: bool = true
@export var grid_speed: float = 0.45


func _init() -> void:
	accent = Color("35f0ff")
	accent_2 = Color("ff3fb4")
	text_color = Color("e8f7ff")
	muted_color = Color("8a9cc2")
	background_color = Color("05030d")
	base_em = 19.2
	sound_pitch = 1.12
	sound_room = 0.05


func font_spec(role: StringName) -> Array:
	match role:
		&"title", &"title_2":
			return [title_font, 900, 3.5, 0.05, true, 0.72]
		&"pause_title":
			return [title_font, 900, 2.3, 0.05, true, 0.72]
		&"curtain":
			return [title_font, 600, 1.4, 0.2, true, 0.72]
		&"kicker":
			return [ui_font, 0, 0.85, 0.38, true, 0.643]
		&"menu_button":
			return [ui_font_bold, 0, 1.12, 0.2, true, 0.643]
		&"menu_sub":
			return [ui_font, 0, 0.672, 0.16, true, 0.643]
		&"foot":
			return [ui_font, 0, 0.72, 0.24, true, 0.643]
		&"panel_title":
			return [title_font, 700, 1.3, 0.16, true, 0.72]
		&"panel_tag", &"header":
			return [ui_font, 0, 0.7, 0.2, true, 0.643]
		&"tab":
			return [ui_font_bold, 0, 0.9, 0.2, true, 0.643]
		&"label":
			return [ui_font, 0, 1.0, 0.1, true, 0.643]
		&"value":
			return [title_font, 600, 0.8, 0.0, true, 0.72]
		&"option":
			return [ui_font_bold, 0, 0.85, 0.14, true, 0.643]
		&"key":
			return [title_font, 700, 0.8, 0.02, true, 0.72]
		&"button":
			return [ui_font_bold, 0, 0.95, 0.2, true, 0.643]
		&"message":
			return [ui_font, 0, 1.0, 0.02, false, 0.643]
		&"loading_title":
			return [title_font, 700, 1.2, 0.2, true, 0.72]
		&"loading_value":
			return [title_font, 700, 1.0, 0.0, true, 0.72]
		&"loading_tip":
			return [ui_font, 0, 1.0, 0.06, false, 0.643]
		&"slot_name":
			return [ui_font, 0, 0.72, 0.14, true, 0.643]
		&"slot_title":
			return [ui_font_bold, 0, 1.05, 0.06, false, 0.643]
		&"slot_meta":
			return [ui_font, 0, 0.78, 0.02, false, 0.643]
	return [ui_font, 0, 1.0, 0.0, false, 0.643]


# --------------------------------------------------------------------------
# Main menu
# --------------------------------------------------------------------------

func menu_layout() -> Dictionary:
	return {
		"align": Align.LEFT,
		"margin": Vector2(0.07, 0.06),
		"logo_gap": 2.1,
		"button_gap": 0.42,
		"button_min_width": 16.0,
		"foot_align": Align.LEFT,
		"foot_bottom": 0.055,
	}


func menu_button_size(text: String, sub: String) -> Vector2:
	var fe: float = 1.12 * em
	var width: float = maxf(text_width(&"menu_button", text), text_width(&"menu_sub", sub)) + 2.7 * fe
	var height: float = fe * 2.1
	if not sub.is_empty():
		height += get_font_size(&"menu_sub") * 1.5
	return Vector2(ceilf(width), ceilf(height))


func draw_menu_button(c: MenuKitControl, text: String, sub: String) -> void:
	var f: float = c.focus_amount
	var fe: float = 1.12 * em
	var rect: Rect2 = Rect2(Vector2(0.6 * fe * f, 0.0), c.size)
	var points: PackedVector2Array = bevel_points(rect, 0.75 * fe, 0.62)
	fill_gradient_h(c, points, rect.position.x, rect.end.x, [[0.0, Color(accent, 0.1)], [0.85, Color(accent, 0.0)]])
	if f > 0.002:
		var fill: PackedVector2Array = clip_polygon_x(points, -INF, rect.position.x + rect.size.x * f)
		fill_gradient_h(c, fill, rect.position.x, rect.end.x,
			[[0.0, accent], [0.55, Color(accent, 0.75)], [1.0, Color(accent_2, 0.7)]])
	var bar: Rect2 = Rect2(rect.position, Vector2(maxf(2.0, 0.16 * fe), rect.size.y))
	var glow: float = minf(0.6 * fe, bar.size.y * 0.3)
	draw_glow(c, bar.grow_individual(0, -glow, 0, -glow), Color(accent, 0.45), glow)
	c.draw_rect(bar, accent)

	var label: Rect2 = Rect2(rect.position.x + 1.1 * fe, 0.55 * fe, rect.size.x, fe)
	var color: Color = text_color.lerp(background_color, ease_out(f * 1.4))
	var jitter: float = 0.0
	var age: float = c.focus_age()
	if f > 0.0 and age < 0.3 and c.has_focus() and not MenuKit.reduce_flashing:
		var step: int = clampi(int(age / 0.1), 0, 2)
		var shadow: float = [0.09, -0.07, 0.04][step] * fe
		jitter = [0.06, -0.06, 0.0][step] * fe
		draw_text(c, &"menu_button", text, label, Color(accent_2, 0.9), Align.LEFT, Vector2(jitter + shadow, 0))
		draw_text(c, &"menu_button", text, label, Color(1, 1, 1, 0.8), Align.LEFT, Vector2(jitter - shadow, 0))
	draw_text(c, &"menu_button", text, label, color, Align.LEFT, Vector2(jitter, 0))
	if not sub.is_empty():
		var sub_size: float = get_font_size(&"menu_sub")
		var sub_rect: Rect2 = Rect2(label.position.x, label.end.y + 0.35 * sub_size, rect.size.x, sub_size)
		draw_text(c, &"menu_sub", sub, sub_rect, muted_color.lerp(Color(background_color, 0.72), ease_out(f * 1.4)))


func title_size(kicker: String, lines: PackedStringArray, compact: bool = false) -> Vector2:
	var te: float = get_font_size(title_role(0, compact))
	var width: float = text_width(&"kicker", kicker + "_")
	var height: float = 0.0
	if not kicker.is_empty():
		height = 1.35 * em
	for i: int in lines.size():
		width = maxf(width, text_width(title_role(i, compact), lines[i]))
		height += te * 0.98
	return Vector2(ceilf(width + te * 0.1), ceilf(height + te * 0.08))


func draw_title(c: Control, kicker: String, lines: PackedStringArray, time: float, align: Align,
		compact: bool = false) -> void:
	var te: float = get_font_size(title_role(0, compact))
	var y: float = 0.0
	if not kicker.is_empty():
		var rect: Rect2 = Rect2(0, 0, c.size.x, 0.85 * em)
		var shown: String = kicker + ("_" if fmod(time, 1.0) < 0.5 else "")
		var origin: Vector2 = text_origin(&"kicker", kicker + "_", rect, align)
		c.draw_string(get_font(&"kicker"), origin, format_text(&"kicker", shown), HORIZONTAL_ALIGNMENT_LEFT, -1,
			get_font_size(&"kicker"), accent)
		y = 1.35 * em
	var flicker: float = 1.0 if MenuKit.reduce_flashing else _flicker(fmod(time, 7.0) / 7.0)
	for i: int in lines.size():
		var role: StringName = title_role(i, compact)
		var rect: Rect2 = Rect2(0, y, c.size.x, te * 0.98)
		var origin: Vector2 = text_origin(role, lines[i], rect, align)
		var font: Font = get_font(role)
		var formatted: String = format_text(role, lines[i])
		if i == 0:
			draw_text_glow(c, role, lines[i], origin, Color(accent, 0.3 * flicker), 0.7 * te, 5)
			draw_text_glow(c, role, lines[i], origin, Color(accent, 0.75 * flicker), 0.28 * te, 4)
			draw_text_glow(c, role, lines[i], origin, Color(1, 1, 1, 0.5 * flicker), 0.07 * te, 2)
			c.draw_string(font, origin, formatted, HORIZONTAL_ALIGNMENT_LEFT, -1, get_font_size(role),
				Color(title_color, flicker))
		else:
			draw_text_glow(c, role, lines[i], origin, Color(accent_2, 0.45), 0.3 * te, 4)
			c.draw_string_outline(font, origin, formatted, HORIZONTAL_ALIGNMENT_LEFT, -1, get_font_size(role),
				maxi(2, roundi(0.028 * te * 2.0)), accent_2)
		y += te * 0.98


func _flicker(t: float) -> float:
	var keys: Array = [[0.0, 1.0], [0.91, 1.0], [0.92, 0.55], [0.935, 1.0], [0.95, 0.8], [0.96, 1.0], [1.0, 1.0]]
	for i: int in keys.size() - 1:
		if t <= float(keys[i + 1][0]):
			var a: float = float(keys[i][0])
			var b: float = float(keys[i + 1][0])
			return lerpf(float(keys[i][1]), float(keys[i + 1][1]), (t - a) / maxf(b - a, 0.0001))
	return 1.0


func appear_transform(c: Control, appear: float) -> Array:
	if c is MenuKitTitle:
		if MenuKit.reduce_flashing:
			return [Vector2.ZERO, ease_out(appear)]
		var keys: Array = [[0.0, 0.0], [0.3, 1.0], [0.45, 0.3], [0.6, 1.0], [1.0, 1.0]]
		for i: int in keys.size() - 1:
			if appear <= float(keys[i + 1][0]):
				var a: float = float(keys[i][0])
				var b: float = float(keys[i + 1][0])
				return [Vector2.ZERO, lerpf(float(keys[i][1]), float(keys[i + 1][1]), (appear - a) / (b - a))]
		return [Vector2.ZERO, 1.0]
	var k: float = ease_out(appear)
	return [Vector2(-2.0 * em * (1.0 - k), 0.0), k]


func draw_footer(c: Control, text: String, rect: Rect2, align: Align) -> void:
	draw_text(c, &"foot", text, rect, muted_color, align)


# --------------------------------------------------------------------------
# Panels
# --------------------------------------------------------------------------

func panel_padding() -> Vector2:
	return Vector2(1.7 * em, 1.4 * em)


func panel_header_height() -> float:
	return 2.2 * em


func draw_panel(c: Control, rect: Rect2, title: String, tag: String) -> void:
	draw_glow(c, rect, Color(accent, 0.12), 2.5 * em)
	fill_gradient_v(c, rect, panel_top_color, panel_bottom_color)
	draw_inner_glow(c, rect, Color(accent, 0.07), 2.0 * em)
	c.draw_rect(rect.grow(-0.5), Color(accent, 0.28), false, 1.0)
	var corner: float = 1.4 * em
	c.draw_rect(Rect2(rect.position, Vector2(corner, 2)), accent)
	c.draw_rect(Rect2(rect.position, Vector2(2, corner)), accent)
	c.draw_rect(Rect2(rect.end - Vector2(corner, 2), Vector2(corner, 2)), accent_2)
	c.draw_rect(Rect2(rect.end - Vector2(2, corner), Vector2(2, corner)), accent_2)
	if title.is_empty():
		return
	var pad: Vector2 = panel_padding()
	var header: Rect2 = Rect2(rect.position.x + pad.x, rect.position.y + pad.y, rect.size.x - pad.x * 2.0, 1.3 * em)
	var prefix: String = "// "
	var prefix_width: float = text_width(&"panel_title", prefix) + float(get_font(&"panel_title").spacing_glyph)
	draw_text(c, &"panel_title", prefix, header, accent_2)
	var title_rect: Rect2 = Rect2(header.position.x + prefix_width, header.position.y, header.size.x - prefix_width, header.size.y)
	draw_text_glow(c, &"panel_title", title, text_origin(&"panel_title", title, title_rect), Color(accent, 0.55), 0.35 * em, 3)
	draw_text(c, &"panel_title", title, title_rect, title_color)
	draw_text(c, &"panel_tag", tag, header, accent, Align.RIGHT)


func panel_reveal_rect(rect: Rect2, t: float) -> Rect2:
	var line: float = maxf(2.0, rect.size.y * 0.008)
	var width: float = rect.size.x
	var height: float = rect.size.y
	if t < 0.35:
		width = rect.size.x * ease_out(t / 0.35)
		height = line
	else:
		height = lerpf(line, rect.size.y, ease_out((t - 0.35) / 0.65))
	return Rect2(rect.get_center() - Vector2(width, height) * 0.5, Vector2(width, height))


func animate_panel(panel: Control, frame: Control, opening: bool) -> Tween:
	if not opening:
		return super(panel, frame, opening)
	var tween: Tween = panel.create_tween()
	_open_step(0.0, panel, frame)
	tween.tween_method(_open_step.bind(panel, frame), 0.0, 1.0, 0.42)
	return tween


func _open_step(t: float, panel: Control, frame: Control) -> void:
	panel.set(&"reveal", t)
	var brightness: float = lerpf(2.5, 2.0, t / 0.35) if t < 0.35 else lerpf(2.0, 1.0, ease_out((t - 0.35) / 0.65))
	if MenuKit.reduce_flashing:
		brightness = 1.0
	frame.modulate = Color(brightness, brightness, brightness, 1.0)


# --------------------------------------------------------------------------
# Tabs and rows
# --------------------------------------------------------------------------

func tab_bar_height() -> float:
	return 2.0 * em


func tab_width(text: String) -> float:
	return text_width(&"tab", text) + 1.8 * em


func draw_tab_bar(c: Control, rect: Rect2) -> void:
	c.draw_rect(Rect2(rect.position.x, rect.end.y - 1.0, rect.size.x, 1.0), Color(accent, 0.18))


func draw_tab(c: Control, rect: Rect2, text: String, selected: bool, focused: bool, hovered: bool) -> void:
	var color: Color = accent if selected else muted_color
	if focused or hovered:
		color = Color.WHITE
	if selected:
		var line: Rect2 = Rect2(rect.position.x, rect.end.y - 2.0, rect.size.x, 2.0)
		draw_glow(c, line, Color(accent, 0.35), 0.6 * em)
		c.draw_rect(line, accent)
	draw_text(c, &"tab", text, rect, color, Align.CENTER)


func row_height() -> float:
	return 2.75 * em


func draw_row(c: MenuKitControl, rect: Rect2, label: String) -> void:
	var f: float = c.focus_amount
	if f > 0.0:
		var band: Rect2 = rect.grow_individual(0.6 * em, -1.0, 0.0, -1.0)
		fill_gradient_h(c, PackedVector2Array([band.position, Vector2(band.end.x, band.position.y), band.end,
			Vector2(band.position.x, band.end.y)]), band.position.x, band.end.x,
			[[0.0, Color(accent, 0.1 * f)], [0.7, Color(accent, 0.0)]])
		c.draw_rect(Rect2(band.position, Vector2(2.0, band.size.y)), Color(accent, f))
	draw_text(c, &"label", label, Rect2(rect.position.x + 0.3 * em * f, rect.position.y, rect.size.x, rect.size.y),
		text_color.lerp(Color.WHITE, f))
	c.draw_dashed_line(Vector2(rect.position.x, rect.end.y - 0.5), Vector2(rect.end.x, rect.end.y - 0.5),
		Color(accent, 0.14), 1.0, 3.0)


func value_width() -> float:
	return 3.4 * em


func draw_value(c: Control, rect: Rect2, text: String) -> void:
	draw_text(c, &"value", text, rect, accent, Align.RIGHT)


func draw_slider(c: MenuKitControl, rect: Rect2, ratio: float, active: bool) -> void:
	var h: float = maxf(2.0, 0.22 * em)
	var track: Rect2 = Rect2(rect.position.x, roundf(rect.get_center().y - h * 0.5), rect.size.x, h)
	c.draw_rect(track, Color(1, 1, 1, 0.12))
	c.draw_rect(Rect2(track.position, Vector2(track.size.x * ratio, h)), accent)
	var side: float = 0.85 * em * (1.15 if active else 1.0)
	var center: Vector2 = Vector2(track.position.x + track.size.x * ratio, track.get_center().y)
	c.draw_set_transform(center, PI * 0.25, Vector2.ONE)
	var square: Rect2 = Rect2(Vector2(-side, -side) * 0.5, Vector2(side, side))
	draw_box(c, square, background_color, accent, 2.0, 0.0, Color(accent, 0.55 if active else 0.4), 0.6 * em)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func switch_size() -> Vector2:
	return Vector2(3.0 * em, 1.6 * em)


func draw_switch(c: MenuKitControl, rect: Rect2, amount: float, active: bool) -> void:
	var on: float = clampf(amount, 0.0, 1.0)
	if active:
		c.draw_rect(rect.grow(2.0), accent, false, 2.0)
	c.draw_rect(rect, Color(1, 1, 1, 0.04).lerp(Color(accent, 0.18), on))
	c.draw_rect(rect.grow(-0.5), Color(accent, 0.45), false, 1.0)
	var knob: float = 1.2 * em
	var knob_rect: Rect2 = Rect2(rect.position.x + 0.2 * em + 1.4 * em * amount, rect.get_center().y - knob * 0.5, knob, knob)
	if on > 0.0:
		draw_glow(c, knob_rect, Color(accent, 0.5 * on), 0.6 * em)
	c.draw_rect(knob_rect, muted_color.lerp(accent, on))


func segment_height() -> float:
	return 1.6 * em


func segment_width(text: String) -> float:
	return text_width(&"option", text) + 1.3 * em


func draw_segments(c: MenuKitControl, rect: Rect2, labels: PackedStringArray, widths: PackedFloat32Array,
		selected: int, hovered: int, active: bool) -> void:
	var x: float = rect.position.x
	for i: int in labels.size():
		var r: Rect2 = Rect2(x, rect.position.y, widths[i], rect.size.y)
		var color: Color = muted_color
		if i == selected:
			c.draw_rect(r, accent)
			color = background_color
		elif i == hovered:
			color = Color.WHITE
		draw_text(c, &"option", labels[i], r, color, Align.CENTER)
		x += widths[i]
	c.draw_rect(rect.grow(-0.5), Color(accent, 0.7 if active else 0.35), false, 1.0)


func stepper_arrow_size() -> float:
	return 1.8 * em


func stepper_value_width() -> float:
	return 8.7 * em


func draw_stepper(c: MenuKitControl, rect: Rect2, text: String, hovered_side: int, active: bool) -> void:
	var a: float = stepper_arrow_size()
	var left: Rect2 = Rect2(rect.position.x, roundf(rect.get_center().y - a * 0.5), a, a)
	var right: Rect2 = Rect2(rect.end.x - a, left.position.y, a, a)
	for side: int in [-1, 1]:
		var r: Rect2 = left if side == -1 else right
		if hovered_side == side or active:
			c.draw_rect(r, Color(accent, 0.18 if hovered_side == side else 0.08))
		c.draw_rect(r.grow(-0.5), Color(accent, 0.4 if hovered_side != side else 0.8), false, 1.0)
		draw_arrow(c, r.get_center(), side, 0.22 * em, accent, maxf(1.5, 0.09 * em))
	draw_text(c, &"label", text, Rect2(left.end.x, rect.position.y, right.position.x - left.end.x, rect.size.y),
		Color.WHITE if active else text_color, Align.CENTER)


func key_size() -> Vector2:
	return Vector2(6.8 * em, 1.8 * em)


func draw_key(c: MenuKitControl, rect: Rect2, text: String, highlighted: bool, listening: bool, time: float) -> void:
	var pulse: float = 0.45 + 0.55 * (0.5 + 0.5 * cos(time * TAU / 0.9)) if listening else 1.0
	if highlighted:
		c.draw_rect(rect, Color(accent, 0.14))
	c.draw_rect(Rect2(rect.position.x, rect.end.y - 0.18 * em, rect.size.x, 0.18 * em), Color(accent, 0.25))
	c.draw_rect(rect.grow(-0.5), Color(accent, 0.85 if highlighted else 0.45), false, 1.0)
	draw_text_fit(c, &"key", text, rect.grow_individual(-0.5 * em, 0, -0.5 * em, -0.1 * em), Color(accent, pulse))


func draw_bindings_header(c: Control, rect: Rect2, title: String, columns: Array, captions: PackedStringArray) -> void:
	draw_text(c, &"header", title, rect, muted_color)
	for i: int in mini(columns.size(), captions.size()):
		draw_text_fit(c, &"header", captions[i], columns[i] as Rect2, muted_color)


# --------------------------------------------------------------------------
# Buttons
# --------------------------------------------------------------------------

func button_size(text: String) -> Vector2:
	var fe: float = 0.95 * em
	return Vector2(ceilf(text_width(&"button", text) + 2.6 * fe), ceilf(2.2 * fe))


func draw_button(c: MenuKitControl, text: String, ghost: bool) -> void:
	var f: float = c.focus_amount
	var color: Color = accent_2 if ghost else accent
	var rect: Rect2 = Rect2(Vector2.ZERO, c.size)
	var points: PackedVector2Array = bevel_points(rect.grow(-0.5), 0.57 * em, 0.6)
	if f > 0.0:
		c.draw_colored_polygon(points, Color(color, f))
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	c.draw_polyline(outline, color, 1.0)
	draw_text(c, &"button", text, rect, color.lerp(background_color, f), Align.CENTER)


# --------------------------------------------------------------------------
# Screens
# --------------------------------------------------------------------------

func create_background() -> Control:
	var rect: MenuKitShaderRect = MenuKitShaderRect.new(BACKGROUND_SHADER)
	rect.color = background_color
	rect.set_param(&"grid_color", accent)
	rect.set_param(&"horizon_color", accent_2)
	rect.set_param(&"sun_bottom", accent_2)
	rect.set_param(&"show_sun", show_sun)
	rect.set_param(&"speed", grid_speed)
	return rect


func create_overlay() -> Control:
	if not scanlines:
		return null
	return MenuKitShaderRect.new(OVERLAY_SHADER)


# --------------------------------------------------------------------------
# Quit
# --------------------------------------------------------------------------

func quit_text() -> String:
	return "Signal lost"


func draw_curtain(c: Control, rect: Rect2, text: String) -> void:
	c.draw_rect(rect, Color.BLACK)
	var origin: Vector2 = text_origin(&"curtain", text, rect, Align.CENTER)
	draw_text_glow(c, &"curtain", text, origin, Color(accent, 0.35), 0.4 * em, 3)
	draw_text(c, &"curtain", text, rect, Color(1, 1, 1, 0.85), Align.CENTER)
