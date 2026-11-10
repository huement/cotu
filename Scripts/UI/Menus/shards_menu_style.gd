# res://Scripts/UI/Menus/shards_menu_style.gd
class_name ShardsMenuStyle
extends RefCounted
## Shared look for the in-game menus (HUD menu, placeholder screens).
## Black tiles, light-grey icons that light up in the accent colour on hover / focus.
## Icons are tinted through the Button icon colour overrides, so any of the
## light-grey SVGs in res://ui/icons/ can be used as-is.

const COLOR_PANEL: Color = Color(0.035, 0.04, 0.05, 0.97)
const COLOR_TILE: Color = Color(0.0, 0.0, 0.0, 0.92)
const COLOR_TILE_HOVER: Color = Color(0.06, 0.08, 0.1, 0.96)
const COLOR_BORDER: Color = Color(0.3, 0.32, 0.36)
const COLOR_ACCENT: Color = Color(0.38, 0.86, 1.0)
const COLOR_DANGER: Color = Color(1.0, 0.42, 0.38)
const COLOR_TEXT: Color = Color(0.88, 0.88, 0.88)
const COLOR_MUTED: Color = Color(0.55, 0.57, 0.62)
const COLOR_DISABLED: Color = Color(0.28, 0.29, 0.31)

const TITLE_FONT: FontFile = preload("res://ui/fonts/Nexa-Heavy.otf")
const BODY_FONT: FontFile = preload("res://ui/fonts/RedditMono-Bold.ttf")

const TILE_MIN_SIZE: Vector2 = Vector2(118.0, 118.0)
const TILE_ICON_SIZE: int = 44


static func box(bg: Color, border: Color, border_width: int = 2, radius: int = 6) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(12.0)
	return style


static func panel_box() -> StyleBoxFlat:
	var style: StyleBoxFlat = box(COLOR_PANEL, COLOR_BORDER, 2, 8)
	style.set_content_margin_all(0.0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	style.shadow_size = 18
	return style


## Applies the black tile look to [param button]. [param accent] colours the
## hover / focus border and icon (use COLOR_DANGER for destructive actions).
static func style_button(button: Button, accent: Color = COLOR_ACCENT, font_size: int = 15) -> void:
	button.add_theme_stylebox_override("normal", box(COLOR_TILE, COLOR_BORDER))
	button.add_theme_stylebox_override("hover", box(COLOR_TILE_HOVER, accent))
	button.add_theme_stylebox_override("pressed", box(COLOR_TILE_HOVER, accent.lightened(0.25), 3))
	button.add_theme_stylebox_override("disabled", box(Color(0.0, 0.0, 0.0, 0.6), COLOR_DISABLED.darkened(0.3)))
	var focus: StyleBoxFlat = box(Color(0.0, 0.0, 0.0, 0.0), accent, 2)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)

	button.add_theme_font_override("font", TITLE_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_color_override("font_focus_color", accent)
	button.add_theme_color_override("font_pressed_color", accent.lightened(0.25))
	button.add_theme_color_override("font_hover_pressed_color", accent.lightened(0.25))
	button.add_theme_color_override("font_disabled_color", COLOR_DISABLED)

	button.add_theme_color_override("icon_normal_color", COLOR_TEXT)
	button.add_theme_color_override("icon_hover_color", accent)
	button.add_theme_color_override("icon_focus_color", accent)
	button.add_theme_color_override("icon_pressed_color", accent.lightened(0.25))
	button.add_theme_color_override("icon_hover_pressed_color", accent.lightened(0.25))
	button.add_theme_color_override("icon_disabled_color", COLOR_DISABLED)
	button.add_theme_constant_override("h_separation", 10)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Big square tile: icon on top, label underneath. Grows to share the row width.
static func make_tile_button(label: String, icon: Texture2D, accent: Color = COLOR_ACCENT) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.icon = icon
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.custom_minimum_size = TILE_MIN_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	style_button(button, accent)
	button.add_theme_constant_override("icon_max_width", TILE_ICON_SIZE)
	return button


## Wide row button (icon left, text right) used for Back / dialog choices.
static func make_row_button(label: String, icon: Texture2D = null, accent: Color = COLOR_ACCENT) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.icon = icon
	button.custom_minimum_size = Vector2(150.0, 48.0)
	button.focus_mode = Control.FOCUS_ALL
	style_button(button, accent, 15)
	button.add_theme_constant_override("icon_max_width", 22)
	return button


static func style_title(label: Label, font_size: int = 30) -> void:
	label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_TEXT)


static func style_body(label: Control, font_size: int = 15, muted: bool = false) -> void:
	var color: Color = COLOR_MUTED if muted else COLOR_TEXT
	if label is RichTextLabel:
		label.add_theme_font_override("normal_font", BODY_FONT)
		label.add_theme_font_override("bold_font", TITLE_FONT)
		label.add_theme_font_size_override("normal_font_size", font_size)
		label.add_theme_font_size_override("bold_font_size", font_size + 2)
		label.add_theme_color_override("default_color", color)
	else:
		label.add_theme_font_override("font", BODY_FONT)
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", color)


## Makes arrow keys / d-pad cycle through [param buttons] left-right (wrapping),
## and keeps up / down from escaping to controls hidden behind the menu.
static func link_focus_row(buttons: Array[Button]) -> void:
	var count: int = buttons.size()
	for i: int in count:
		var button: Button = buttons[i]
		var left: Button = buttons[(i - 1 + count) % count]
		var right: Button = buttons[(i + 1) % count]
		button.focus_neighbor_left = button.get_path_to(left)
		button.focus_neighbor_right = button.get_path_to(right)
		button.focus_neighbor_top = button.get_path_to(button)
		button.focus_neighbor_bottom = button.get_path_to(button)
		button.focus_previous = button.get_path_to(left)
		button.focus_next = button.get_path_to(right)
