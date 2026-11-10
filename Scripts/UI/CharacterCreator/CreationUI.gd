# res://Scripts/UI/CharacterCreator/CreationUI.gd
class_name CreationUI
extends RefCounted
## Look of the character creation + roster screens (space background, ARCANUM header, white / grey
## outlined lists, pink class text, yellow hex link, green current step). Built on ShardsMenuStyle fonts.

const LOGO: Texture2D = preload("res://ui/LOGOS/arcanum_logo_40.png")
const CREST: Texture2D = preload("res://ui/LOGOS/arcanum_crest_100.png")

const PINK: Color = Color(1.0, 0.12, 0.42)
const YELLOW: Color = Color(1.0, 0.8, 0.18)
const GREEN: Color = Color(0.36, 0.95, 0.52)
const WHITE: Color = Color(0.93, 0.93, 0.95)
const GREY: Color = Color(0.42, 0.44, 0.5)
const DIM_GREY: Color = Color(0.26, 0.27, 0.31)
const GLASS: Color = Color(0.02, 0.025, 0.04, 0.82)
const RED: Color = Color(1.0, 0.38, 0.36)


static func flat(bg: Color, border: Color, width: int = 2, radius: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func glass_panel(border: Color = GREY) -> StyleBoxFlat:
	var s: StyleBoxFlat = flat(GLASS, border, 2, 6)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


## A list row (race / class / spell...). Toggle mode; the pressed one gets the white border.
static func list_button(text: String, accent: Color = WHITE, font_size: int = 17) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 34)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", flat(Color(0, 0, 0, 0.35), DIM_GREY, 1))
	b.add_theme_stylebox_override("hover", flat(Color(1, 1, 1, 0.06), GREY, 1))
	b.add_theme_stylebox_override("focus", flat(Color(0, 0, 0, 0), accent.darkened(0.15), 1))
	b.add_theme_stylebox_override("pressed", flat(Color(1, 1, 1, 0.1), accent, 2))
	b.add_theme_stylebox_override("hover_pressed", flat(Color(1, 1, 1, 0.13), accent, 2))
	b.add_theme_stylebox_override("disabled", flat(Color(0, 0, 0, 0.25), Color(DIM_GREY, 0.5), 1))
	b.add_theme_font_override("font", ShardsMenuStyle.TITLE_FONT)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color(WHITE, 0.82))
	b.add_theme_color_override("font_hover_color", WHITE)
	b.add_theme_color_override("font_focus_color", WHITE)
	b.add_theme_color_override("font_pressed_color", accent)
	b.add_theme_color_override("font_hover_pressed_color", accent)
	b.add_theme_color_override("font_disabled_color", DIM_GREY)
	return b


## Big action button (CONFIRM / BACK / START...). `dot` adds the "●" in front like the mockup.
static func action_button(text: String, accent: Color = GREEN, dot: bool = false, font_size: int = 18) -> Button:
	var b := Button.new()
	b.text = ("●  " if dot else "") + text
	b.custom_minimum_size = Vector2(170, 44)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", flat(Color(0, 0, 0, 0.55), GREY, 2))
	b.add_theme_stylebox_override("hover", flat(Color(accent, 0.12), accent, 2))
	b.add_theme_stylebox_override("focus", flat(Color(accent, 0.08), accent, 2))
	b.add_theme_stylebox_override("pressed", flat(Color(accent, 0.25), accent.lightened(0.2), 3))
	b.add_theme_stylebox_override("disabled", flat(Color(0, 0, 0, 0.4), DIM_GREY, 2))
	b.add_theme_font_override("font", ShardsMenuStyle.TITLE_FONT)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", accent)
	b.add_theme_color_override("font_focus_color", accent)
	b.add_theme_color_override("font_pressed_color", accent.lightened(0.3))
	b.add_theme_color_override("font_disabled_color", DIM_GREY)
	return b


static func small_button(text: String, accent: Color = YELLOW) -> Button:
	var b: Button = action_button(text, accent, false, 14)
	b.custom_minimum_size = Vector2(0, 32)
	return b


static func title(text: String, size: int = 22, color: Color = WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", ShardsMenuStyle.TITLE_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func body(text: String, size: int = 14, color: Color = Color(WHITE, 0.8)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", ShardsMenuStyle.BODY_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func wrap(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## Outlined square image box (pixel art, nearest filter). Returns the TextureRect inside.
static func image_box(box_size: float, border: Color = WHITE) -> Array:
	var panel := PanelContainer.new()
	var s: StyleBoxFlat = flat(Color(0, 0, 0, 0.6), border, 3, 4)
	s.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", s)
	panel.custom_minimum_size = Vector2(box_size, box_size)
	var tex := TextureRect.new()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.custom_minimum_size = Vector2(box_size - 12, box_size - 12)
	panel.add_child(tex)
	return [panel, tex]


## "1  2  3" step indicator; the current step is green, finished ones white, later ones grey.
static func step_indicator(count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i: int in count:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(36, 36)
		var l: Label = title(str(i + 1), 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		row.add_child(p)
	return row


static func set_step(indicator: HBoxContainer, current: int) -> void:
	for i: int in indicator.get_child_count():
		var p: PanelContainer = indicator.get_child(i) as PanelContainer
		var l: Label = p.get_child(0) as Label
		var color: Color = GREEN if i == current else (WHITE if i < current else GREY)
		var s: StyleBoxFlat = flat(Color(color, 0.15) if i == current else Color(0, 0, 0, 0.5), color, 2, 18)
		s.set_content_margin_all(0)
		p.add_theme_stylebox_override("panel", s)
		l.add_theme_color_override("font_color", color)


## Header row: ARCANUM logo · centred screen title · step indicator (or nothing).
static func header(screen_title: String, right: Control = null) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.custom_minimum_size = Vector2(250, 32)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(logo)
	var t: Label = title(screen_title, 18, Color(WHITE, 0.75))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var right_box := Control.new()
	right_box.custom_minimum_size = Vector2(250, 0)
	row.add_child(right_box)
	if right != null:
		right.anchor_left = 1.0
		right.anchor_right = 1.0
		right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		right_box.add_child(right)
	return [row, t]


## Shows a class portrait (pixel art, filled) - or the Arcanum crest placeholder (smooth, centred).
static func set_portrait(rect: TextureRect, tex: Texture2D) -> void:
	rect.texture = tex
	var is_crest: bool = tex != null and tex.resource_path == CharacterCreation.FALLBACK_PORTRAIT
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if is_crest else CanvasItem.TEXTURE_FILTER_NEAREST
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED if is_crest else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.modulate = Color(1, 1, 1, 0.55) if is_crest else Color.WHITE


## Full-screen sizing for a screen whose parent isn't a Control (e.g. added straight to the tree root).
static func fill_viewport(screen: Control) -> void:
	if screen.get_parent() is Control:
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	var vp: Viewport = screen.get_viewport()
	var fit: Callable = func() -> void:
		screen.position = Vector2.ZERO
		screen.size = vp.get_visible_rect().size
	fit.call()
	vp.size_changed.connect(fit)


static func play(sound: String) -> void:
	if is_instance_valid(AudioManager) and AudioManager.has_method("play_ui_sound"):
		AudioManager.play_ui_sound(sound)


## Yellow hexagon with a line through it - joins the race and class images (mockup).
class HexLink:
	extends Control

	var color: Color = YELLOW
	var hex_radius: float = 22.0

	func _init() -> void:
		custom_minimum_size = Vector2(70, 60)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		draw_line(Vector2(0, c.y), Vector2(size.x, c.y), color, 3.0)
		var pts := PackedVector2Array()
		for i: int in 6:
			var a: float = deg_to_rad(60.0 * i)
			pts.append(c + Vector2(cos(a), sin(a)) * hex_radius)
		draw_colored_polygon(pts, Color(0.05, 0.04, 0.0, 0.95))
		pts.append(pts[0])
		draw_polyline(pts, color, 3.0, true)
		var inner := PackedVector2Array()
		for i: int in 6:
			var a2: float = deg_to_rad(60.0 * i)
			inner.append(c + Vector2(cos(a2), sin(a2)) * hex_radius * 0.42)
		draw_colored_polygon(inner, color)
