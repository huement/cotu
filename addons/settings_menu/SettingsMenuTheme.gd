extends RefCounted
## Builds the menu theme from a colour palette.
## Everything is generated in code (StyleBoxFlat, textures drawn pixel by pixel):
## no image or font files are needed.
##
## Available type variations (theme_type_variation property):
## SettingsPanel, SettingsCard, SettingsTitle, SettingsSubtitle, SettingsLabel,
## SettingsHint, SettingsValue, SettingsStatus, SettingsColumnHeader,
## PrimaryButton, KeyButton, KeyButtonActive.

## Ready-made palettes:
## [accent, panel background, card background, text, muted text, text on accent].
const PRESETS: Dictionary = {
	"Night": [
		Color(0.42, 0.52, 1.0), Color(0.075, 0.085, 0.12), Color(0.12, 0.135, 0.185),
		Color(0.92, 0.94, 0.97), Color(0.56, 0.6, 0.7), Color(1, 1, 1),
	],
	"Light": [
		Color(0.33, 0.4, 0.98), Color(0.955, 0.962, 0.985), Color(1, 1, 1),
		Color(0.12, 0.14, 0.22), Color(0.42, 0.45, 0.55), Color(1, 1, 1),
	],
	"Ocean": [
		Color(0.28, 0.86, 0.76), Color(0.1, 0.26, 0.4), Color(0.15, 0.33, 0.49),
		Color(0.95, 0.98, 1.0), Color(0.66, 0.8, 0.88), Color(0.04, 0.18, 0.2),
	],
	"Candy": [
		Color(1.0, 0.4, 0.6), Color(0.97, 0.94, 1.0), Color(1, 1, 1),
		Color(0.2, 0.15, 0.3), Color(0.5, 0.44, 0.6), Color(1, 1, 1),
	],
	"Dusk": [
		Color(1.0, 0.56, 0.34), Color(0.18, 0.13, 0.26), Color(0.26, 0.19, 0.36),
		Color(1.0, 0.96, 0.92), Color(0.8, 0.7, 0.85), Color(0.2, 0.08, 0.04),
	],
}


## Builds the theme of a [constant PRESETS] palette.
static func build_preset(preset_name: String, radius: int) -> Theme:
	var colors: Array = PRESETS.get(preset_name, PRESETS["Night"])
	return build(colors[0], colors[1], colors[2], colors[3], colors[4], colors[5], radius)


## Builds a complete Theme. [param radius] sets the corner rounding.
static func build(accent: Color, panel: Color, surface: Color, text: Color, muted: Color, on_accent: Color, radius: int) -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 17

	var bold: FontVariation = FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.6

	var small_radius: int = maxi(radius - 6, 4)
	var light: bool = panel.get_luminance() > 0.5
	var raised: Color = _shift(surface, light, 0.06)
	var border: Color = Color(text, 0.1 if light else 0.07)
	var accent_text: Color = accent.darkened(0.2) if light else accent.lightened(0.3)
	var shadow: Color = Color(0.1, 0.1, 0.25, 0.14) if light else Color(0.0, 0.0, 0.0, 0.45)

	# --- Containers --------------------------------------------------------
	theme.set_type_variation(&"SettingsPanel", &"PanelContainer")
	var panel_box: StyleBoxFlat = _box(panel, radius + 4, 32.0, 28.0)
	panel_box.border_color = border
	panel_box.set_border_width_all(1)
	panel_box.shadow_color = shadow
	panel_box.shadow_size = 32
	panel_box.shadow_offset = Vector2(0.0, 10.0)
	theme.set_stylebox(&"panel", &"SettingsPanel", panel_box)

	theme.set_type_variation(&"SettingsCard", &"PanelContainer")
	var card: StyleBoxFlat = _box(surface, radius, 20.0, 14.0)
	card.border_color = border
	card.set_border_width_all(1)
	theme.set_stylebox(&"panel", &"SettingsCard", card)

	# --- Labels --------------------------------------------------------------
	theme.set_color(&"font_color", &"Label", text)
	_label_variation(theme, &"SettingsTitle", text, 30, bold)
	_label_variation(theme, &"SettingsSubtitle", muted, 15, null)
	_label_variation(theme, &"SettingsLabel", text, 17, bold)
	_label_variation(theme, &"SettingsHint", muted, 14, null)
	_label_variation(theme, &"SettingsValue", accent_text, 16, bold)
	_label_variation(theme, &"SettingsStatus", accent_text, 15, null)
	_label_variation(theme, &"SettingsColumnHeader", muted, 13, bold)

	# --- Tabs (segmented control) -----------------------------------------
	var tab_panel: StyleBoxEmpty = StyleBoxEmpty.new()
	tab_panel.content_margin_top = 18.0
	theme.set_stylebox(&"panel", &"TabContainer", tab_panel)
	var tab_bar_bg: StyleBoxFlat = _box(surface, radius, 5.0, 5.0)
	tab_bar_bg.border_color = border
	tab_bar_bg.set_border_width_all(1)
	theme.set_stylebox(&"tabbar_background", &"TabContainer", tab_bar_bg)
	theme.set_stylebox(&"tab_selected", &"TabContainer", _box(accent, small_radius, 22.0, 9.0))
	theme.set_stylebox(&"tab_unselected", &"TabContainer", _box(Color(0, 0, 0, 0), small_radius, 22.0, 9.0))
	theme.set_stylebox(&"tab_hovered", &"TabContainer", _box(Color(text, 0.07), small_radius, 22.0, 9.0))
	theme.set_stylebox(&"tab_disabled", &"TabContainer", _box(Color(0, 0, 0, 0), small_radius, 22.0, 9.0))
	theme.set_stylebox(&"tab_focus", &"TabContainer", _focus_ring(accent, small_radius))
	theme.set_color(&"font_selected_color", &"TabContainer", on_accent)
	theme.set_color(&"font_unselected_color", &"TabContainer", muted)
	theme.set_color(&"font_hovered_color", &"TabContainer", text)
	theme.set_font(&"font", &"TabContainer", bold)
	theme.set_font_size(&"font_size", &"TabContainer", 16)
	theme.set_constant(&"side_margin", &"TabContainer", 0)

	# --- Buttons -----------------------------------------------------------
	_button_styles(theme, &"Button", raised, border, small_radius, accent, light)
	theme.set_color(&"font_color", &"Button", text)
	theme.set_color(&"font_hover_color", &"Button", text)
	theme.set_color(&"font_pressed_color", &"Button", text)
	theme.set_color(&"font_focus_color", &"Button", text)
	theme.set_color(&"font_disabled_color", &"Button", Color(muted, 0.5))

	theme.set_type_variation(&"PrimaryButton", &"Button")
	_button_styles(theme, &"PrimaryButton", accent, Color(0, 0, 0, 0), small_radius, accent, false)
	theme.set_font(&"font", &"PrimaryButton", bold)
	for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		theme.set_color(color_name, &"PrimaryButton", on_accent)

	theme.set_type_variation(&"KeyButton", &"Button")
	var key_normal: StyleBoxFlat = _box(_shift(surface, light, 0.09), 8, 12.0, 7.0)
	key_normal.border_width_bottom = 3
	key_normal.border_color = surface.darkened(0.22 if light else 0.35)
	var key_hover: StyleBoxFlat = key_normal.duplicate() as StyleBoxFlat
	key_hover.bg_color = _shift(surface, light, 0.14)
	key_hover.border_color = accent
	var key_pressed: StyleBoxFlat = key_normal.duplicate() as StyleBoxFlat
	key_pressed.bg_color = accent
	key_pressed.border_width_bottom = 1
	key_pressed.content_margin_top = 9.0
	theme.set_stylebox(&"normal", &"KeyButton", key_normal)
	theme.set_stylebox(&"hover", &"KeyButton", key_hover)
	theme.set_stylebox(&"pressed", &"KeyButton", key_pressed)
	theme.set_stylebox(&"focus", &"KeyButton", _focus_ring(accent, 8))
	theme.set_color(&"font_color", &"KeyButton", text)
	theme.set_color(&"font_hover_color", &"KeyButton", text)
	theme.set_color(&"font_pressed_color", &"KeyButton", on_accent)
	theme.set_font(&"font", &"KeyButton", bold)
	theme.set_font_size(&"font_size", &"KeyButton", 15)

	theme.set_type_variation(&"KeyButtonActive", &"Button")
	var key_active: StyleBoxFlat = _box(Color(accent, 0.22), 8, 12.0, 7.0)
	key_active.border_color = accent
	key_active.set_border_width_all(2)
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		theme.set_stylebox(style_name, &"KeyButtonActive", key_active)
	theme.set_color(&"font_color", &"KeyButtonActive", accent_text)
	theme.set_color(&"font_hover_color", &"KeyButtonActive", accent_text)
	theme.set_font_size(&"font_size", &"KeyButtonActive", 14)

	# --- Dropdown ----------------------------------------------------------
	_button_styles(theme, &"OptionButton", raised, border, small_radius, accent, light)
	theme.set_color(&"font_color", &"OptionButton", text)
	theme.set_color(&"font_hover_color", &"OptionButton", text)
	theme.set_color(&"font_disabled_color", &"OptionButton", Color(muted, 0.6))
	var popup: StyleBoxFlat = _box(_shift(surface, light, 0.03), small_radius, 6.0, 6.0)
	popup.border_color = border
	popup.set_border_width_all(1)
	popup.shadow_color = shadow
	popup.shadow_size = 12
	theme.set_stylebox(&"panel", &"PopupMenu", popup)
	theme.set_stylebox(&"hover", &"PopupMenu", _box(Color(accent, 0.3), 6, 8.0, 4.0))
	theme.set_color(&"font_color", &"PopupMenu", text)
	theme.set_color(&"font_hover_color", &"PopupMenu", text)
	theme.set_constant(&"v_separation", &"PopupMenu", 8)

	# --- Switches ---------------------------------------------------------
	var switch_on: ImageTexture = _switch_texture(true, accent, Color(text, 0.18))
	var switch_off: ImageTexture = _switch_texture(false, accent, Color(text, 0.18))
	theme.set_icon(&"checked", &"CheckButton", switch_on)
	theme.set_icon(&"unchecked", &"CheckButton", switch_off)
	theme.set_icon(&"checked_disabled", &"CheckButton", switch_on)
	theme.set_icon(&"unchecked_disabled", &"CheckButton", switch_off)
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		theme.set_stylebox(style_name, &"CheckButton", empty)
	theme.set_stylebox(&"focus", &"CheckButton", _focus_ring(accent, small_radius))
	theme.set_color(&"font_color", &"CheckButton", muted)
	theme.set_color(&"font_pressed_color", &"CheckButton", text)
	theme.set_color(&"font_hover_color", &"CheckButton", text)
	theme.set_color(&"font_hover_pressed_color", &"CheckButton", text)
	theme.set_color(&"font_focus_color", &"CheckButton", text)
	theme.set_constant(&"h_separation", &"CheckButton", 12)

	# --- Sliders ----------------------------------------------------------
	var track: StyleBoxFlat = _box(Color(text, 0.13), 4, 0.0, 3.0)
	var filled: StyleBoxFlat = _box(accent, 4, 0.0, 3.0)
	var filled_hover: StyleBoxFlat = _box(_shift(accent, light, 0.12), 4, 0.0, 3.0)
	theme.set_stylebox(&"slider", &"HSlider", track)
	theme.set_stylebox(&"grabber_area", &"HSlider", filled)
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", filled_hover)
	theme.set_icon(&"grabber", &"HSlider", _knob_texture(20, Color.WHITE, accent))
	theme.set_icon(&"grabber_highlight", &"HSlider", _knob_texture(22, Color.WHITE, _shift(accent, light, 0.15)))
	theme.set_stylebox(&"focus", &"HSlider", _focus_ring(accent, 6))

	# --- Scroll bars -----------------------------------------------------
	var scroll_bg: StyleBoxFlat = _box(Color(0, 0, 0, 0), 4, 3.0, 3.0)
	theme.set_stylebox(&"scroll", &"VScrollBar", scroll_bg)
	theme.set_stylebox(&"grabber", &"VScrollBar", _box(Color(text, 0.18), 4, 3.0, 3.0))
	theme.set_stylebox(&"grabber_highlight", &"VScrollBar", _box(Color(text, 0.3), 4, 3.0, 3.0))
	theme.set_stylebox(&"grabber_pressed", &"VScrollBar", _box(accent, 4, 3.0, 3.0))
	theme.set_stylebox(&"scroll", &"HScrollBar", scroll_bg)
	theme.set_stylebox(&"grabber", &"HScrollBar", _box(Color(text, 0.18), 4, 3.0, 3.0))
	theme.set_stylebox(&"grabber_highlight", &"HScrollBar", _box(Color(text, 0.3), 4, 3.0, 3.0))
	theme.set_stylebox(&"grabber_pressed", &"HScrollBar", _box(accent, 4, 3.0, 3.0))

	# --- Dialog window ---------------------------------------------------
	var window: StyleBoxFlat = _box(panel, radius, 0.0, 0.0)
	window.border_color = border
	window.set_border_width_all(1)
	window.expand_margin_left = 10.0
	window.expand_margin_right = 10.0
	window.expand_margin_bottom = 10.0
	window.expand_margin_top = 42.0
	window.shadow_color = shadow
	window.shadow_size = 24
	theme.set_stylebox(&"embedded_border", &"Window", window)
	theme.set_stylebox(&"embedded_unfocused_border", &"Window", window)
	theme.set_constant(&"title_height", &"Window", 40)
	theme.set_font(&"title_font", &"Window", bold)
	theme.set_color(&"title_color", &"Window", text)
	theme.set_stylebox(&"panel", &"AcceptDialog", _box(panel, radius, 16.0, 12.0))

	# --- Misc --------------------------------------------------------------
	theme.set_color(&"font_color", &"LinkButton", accent_text)
	theme.set_color(&"font_hover_color", &"LinkButton", _shift(accent_text, light, 0.2))
	theme.set_font(&"font", &"LinkButton", bold)
	theme.set_stylebox(&"panel", &"TooltipPanel", _box(_shift(surface, light, 0.1), 6, 10.0, 6.0))
	theme.set_color(&"font_color", &"TooltipLabel", text)
	return theme


static func _box(color: Color, radius: int, margin_h: float, margin_v: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	box.anti_aliasing = true
	return box


static func _focus_ring(accent: Color, radius: int) -> StyleBoxFlat:
	var ring: StyleBoxFlat = _box(Color(0, 0, 0, 0), radius + 2, 0.0, 0.0)
	ring.draw_center = false
	ring.border_color = Color(accent, 0.9)
	ring.set_border_width_all(2)
	ring.set_expand_margin_all(3.0)
	return ring


static func _button_styles(theme: Theme, type: StringName, base: Color, border: Color, radius: int, accent: Color, light: bool) -> void:
	var normal: StyleBoxFlat = _box(base, radius, 20.0, 10.0)
	normal.border_color = border
	normal.set_border_width_all(1)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = _shift(base, light, 0.1)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = base.darkened(0.15)
	var disabled: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(base, base.a * 0.45)
	theme.set_stylebox(&"normal", type, normal)
	theme.set_stylebox(&"hover", type, hover)
	theme.set_stylebox(&"pressed", type, pressed)
	theme.set_stylebox(&"hover_pressed", type, pressed)
	theme.set_stylebox(&"disabled", type, disabled)
	theme.set_stylebox(&"focus", type, _focus_ring(accent, radius))


## Lightens on dark backgrounds, darkens on light ones (for hover states).
static func _shift(color: Color, light: bool, amount: float) -> Color:
	return color.darkened(amount * 0.6) if light else color.lightened(amount)


static func _label_variation(theme: Theme, type: StringName, color: Color, size: int, font: Font) -> void:
	theme.set_type_variation(type, &"Label")
	theme.set_color(&"font_color", type, color)
	theme.set_font_size(&"font_size", type, size)
	if font != null:
		theme.set_font(&"font", type, font)


## Pill-shaped switch, antialiased with a distance field.
static func _switch_texture(on: bool, track_on: Color, track_off: Color) -> ImageTexture:
	var width: int = 46
	var height: int = 26
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var radius: float = height / 2.0
	var knob_center: Vector2 = Vector2(width - radius if on else radius, radius)
	var track_color: Color = track_on if on else track_off
	for y: int in height:
		for x: int in width:
			var point: Vector2 = Vector2(x + 0.5, y + 0.5)
			var axis_point: Vector2 = Vector2(clampf(point.x, radius, width - radius), radius)
			var track_alpha: float = clampf(radius + 0.5 - point.distance_to(axis_point), 0.0, 1.0)
			var knob_alpha: float = clampf(radius - 3.0 + 0.5 - point.distance_to(knob_center), 0.0, 1.0)
			var color: Color = Color(track_color, track_color.a * track_alpha)
			color = color.blend(Color(1.0, 1.0, 1.0, knob_alpha))
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


## Round slider knob (filled disc ringed with the accent colour).
static func _knob_texture(size: int, fill: Color, ring: Color) -> ImageTexture:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(size / 2.0, size / 2.0)
	var outer: float = size / 2.0 - 0.5
	for y: int in size:
		for x: int in size:
			var distance: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
			var ring_alpha: float = clampf(outer + 0.5 - distance, 0.0, 1.0)
			var fill_alpha: float = clampf(outer - 3.0 + 0.5 - distance, 0.0, 1.0)
			var color: Color = Color(ring, ring_alpha)
			color = color.blend(Color(fill, fill_alpha))
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
