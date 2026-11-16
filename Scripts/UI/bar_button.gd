# res://Scripts/UI/bar_button.gd
class_name BarButton
extends Button
## Pixel bar built from ui/kbtns/<Colour>/ slices. Pick the colour with `palette`
## (GREY / BLUE / GREEN / YELLOW / ARC); it can be changed at runtime and the art swaps.
## Stretch uses left / middle / right.
## Square uses the fixed tile (back / forward arrows). Hover and press run the
## portrait shine as one sweep across every slice.

enum Palette { GREY, BLUE, GREEN, YELLOW, ARC }
enum SizeTier { LARGE, SMALL }
enum Shape { STRETCH, SQUARE }
enum IconKind { NONE, BACK, FORWARD }

const SHINE_SHADER: Shader = preload("res://Shaders/portrait_shine.gdshader")
const FONT: Font = preload("res://ui/fonts/RedditMono-Bold.ttf")
const ARROW_BACK: Texture2D = preload("res://ui/icons/menu/chevron_back_24.png")
const ARROW_FORWARD: Texture2D = preload("res://ui/kbtns/arrow_forward.png")

const ART_ROOT: String = "res://ui/kbtns"
const LABEL_COLOR: Color = Color(0.12, 0.14, 0.18)

@export var palette: Palette = Palette.GREY:
	set(value):
		palette = value
		if is_node_ready():
			_apply_art()

@export var size_tier: SizeTier = SizeTier.LARGE:
	set(value):
		size_tier = value
		if is_node_ready():
			_apply_art()

@export var shape: Shape = Shape.STRETCH:
	set(value):
		shape = value
		if is_node_ready():
			_apply_art()

@export var label_text: String = "":
	set(value):
		label_text = value
		if is_node_ready():
			_apply_content()

## Named icon_kind because Button already owns `icon` (a Texture2D).
@export var icon_kind: IconKind = IconKind.NONE:
	set(value):
		icon_kind = value
		if is_node_ready():
			_apply_content()

## Integer scale so the pixel art stays crisp. Large art is 48px tall.
@export var pixel_scale: int = 2:
	set(value):
		pixel_scale = maxi(1, value)
		if is_node_ready():
			_apply_art()

@export_group("Shine")
@export var shine_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var shine_size: float = 0.35
@export var hover_shine_time: float = 0.35
@export var press_shine_time: float = 0.2

@export var hover_scale: Vector2 = Vector2(1.06, 1.06)
@export var click_scale: Vector2 = Vector2(0.96, 0.96)

var _slice_row: HBoxContainer
var _left: TextureRect
var _middle: TextureRect
var _right: TextureRect
var _square: TextureRect
var _content_margin: MarginContainer
var _icon_rect: TextureRect
var _label: Label

var _left_mat: ShaderMaterial
var _middle_mat: ShaderMaterial
var _right_mat: ShaderMaterial
var _square_mat: ShaderMaterial
var _shine_materials: Array[ShaderMaterial] = []

var _shine_tween: Tween
var _pop_tween: Tween
var _built: bool = false


func _ready() -> void:
	flat = true
	text = ""
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_empty_styles()
	_build()
	_apply_art()
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	button_down.connect(_on_click_start)
	button_up.connect(_on_click_end)
	pressed.connect(_on_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built:
		pivot_offset = size * 0.5
		_update_shine_uv()


func _apply_empty_styles() -> void:
	var style_names: Array[StringName] = [&"normal", &"hover", &"pressed", &"disabled"]
	for style_name: StringName in style_names:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())


func _build() -> void:
	if _built:
		return
	_slice_row = HBoxContainer.new()
	_slice_row.name = "SliceRow"
	_slice_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slice_row.add_theme_constant_override("separation", 0)
	_fill(_slice_row)
	add_child(_slice_row)

	_left = _make_slice("Left")
	_middle = _make_slice("Middle")
	_right = _make_slice("Right")
	_middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slice_row.add_child(_left)
	_slice_row.add_child(_middle)
	_slice_row.add_child(_right)

	_square = _make_slice("Square")
	_fill(_square)
	add_child(_square)

	_content_margin = MarginContainer.new()
	_content_margin.name = "Content"
	_content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(_content_margin)
	add_child(_content_margin)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 6)
	_content_margin.add_child(row)

	_icon_rect = TextureRect.new()
	_icon_rect.name = "Icon"
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon_rect)

	_label = Label.new()
	_label.name = "Label"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.add_theme_color_override("font_color", LABEL_COLOR)
	_label.add_theme_font_override("font", FONT)
	row.add_child(_label)

	_left_mat = _bind_shine(_left)
	_middle_mat = _bind_shine(_middle)
	_right_mat = _bind_shine(_right)
	_square_mat = _bind_shine(_square)
	_built = true


func _make_slice(node_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return rect


func _fill(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0
	node.grow_horizontal = Control.GROW_DIRECTION_BOTH
	node.grow_vertical = Control.GROW_DIRECTION_BOTH
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _bind_shine(rect: TextureRect) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHINE_SHADER
	mat.set_shader_parameter(&"shine_progress", -0.5)
	mat.set_shader_parameter(&"shine_size", shine_size)
	mat.set_shader_parameter(&"shine_color", shine_color)
	mat.set_shader_parameter(&"shine_uv_scale", Vector2.ONE)
	mat.set_shader_parameter(&"shine_uv_offset", Vector2.ZERO)
	rect.material = mat
	_shine_materials.append(mat)
	return mat


func _apply_art() -> void:
	if not _built:
		return
	var stretch: bool = shape == Shape.STRETCH
	_slice_row.visible = stretch
	_square.visible = not stretch
	if stretch:
		_left.texture = _tex("l")
		_middle.texture = _tex("m")
		_right.texture = _tex("r")
	else:
		_square.texture = _tex("square")
	_apply_content()


func _apply_content() -> void:
	if not _built:
		return
	var font_size: int = 16 if size_tier == SizeTier.LARGE else 12
	_label.add_theme_font_size_override("font_size", font_size)
	_label.text = label_text
	_label.visible = not label_text.is_empty()

	match icon_kind:
		IconKind.BACK:
			_icon_rect.texture = ARROW_BACK
			_icon_rect.visible = true
		IconKind.FORWARD:
			_icon_rect.texture = ARROW_FORWARD
			_icon_rect.visible = true
		_:
			_icon_rect.texture = null
			_icon_rect.visible = false
	var icon_px: float = _icon_px()
	_icon_rect.custom_minimum_size = Vector2(icon_px, icon_px)

	var pad: int = _content_pad()
	_content_margin.add_theme_constant_override("margin_left", pad)
	_content_margin.add_theme_constant_override("margin_right", pad)
	_content_margin.add_theme_constant_override("margin_top", 0)
	_content_margin.add_theme_constant_override("margin_bottom", 0)
	_refresh_minimum_size(font_size)
	_update_shine_uv()


func _refresh_minimum_size(font_size: int) -> void:
	var height: float = float(_art_height() * pixel_scale)
	if shape == Shape.SQUARE:
		custom_minimum_size = Vector2(height, height)
		return

	var left_cap: float = float(_slice_width(_left) * pixel_scale)
	var right_cap: float = float(_slice_width(_right) * pixel_scale)
	_left.custom_minimum_size = Vector2(left_cap, height)
	_right.custom_minimum_size = Vector2(right_cap, height)

	var content_w: float = 0.0
	if icon_kind != IconKind.NONE:
		content_w += _icon_px()
	if not label_text.is_empty():
		if content_w > 0.0:
			content_w += 6.0
		content_w += FONT.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var middle: float = ceilf(maxf(float(_mid_width() * pixel_scale), content_w))
	_middle.custom_minimum_size = Vector2(middle, height)
	custom_minimum_size = Vector2(left_cap + right_cap + middle, height)


func _update_shine_uv() -> void:
	if not _built:
		return
	if shape == Shape.SQUARE:
		_set_slice_uv(_square_mat, 0.0, 1.0)
		return
	var total: float = size.x
	if total <= 1.0:
		total = custom_minimum_size.x
	if total <= 1.0:
		return
	var left_w: float = float(_slice_width(_left) * pixel_scale)
	var right_w: float = float(_slice_width(_right) * pixel_scale)
	var mid_w: float = maxf(0.0, total - left_w - right_w)
	_set_slice_uv(_left_mat, 0.0, left_w / total)
	_set_slice_uv(_middle_mat, left_w / total, mid_w / total)
	_set_slice_uv(_right_mat, (left_w + mid_w) / total, right_w / total)


func _set_slice_uv(mat: ShaderMaterial, x0: float, width_frac: float) -> void:
	if mat == null:
		return
	mat.set_shader_parameter(&"shine_uv_scale", Vector2(width_frac, 1.0))
	mat.set_shader_parameter(&"shine_uv_offset", Vector2(x0, 0.0))


func _tex(part: String) -> Texture2D:
	var path: String = "%s/%s/bar_square_%s_%s.png" % [ART_ROOT, _palette_dir(), _size_name(), part]
	if not ResourceLoader.exists(path):
		push_error("BarButton missing art: %s" % path)
		return null
	return load(path) as Texture2D


func _palette_dir() -> String:
	match palette:
		Palette.BLUE:
			return "Blue"
		Palette.GREEN:
			return "Green"
		Palette.YELLOW:
			return "Yellow"
		Palette.ARC:
			return "Arc"
		_:
			return "Grey"


## Stretch icons scale with the bar. A square back arrow stays at its native
## size: chevron_back_24 is anti-aliased, and nearest-neighbour × pixel_scale
## turns it into a chunky glyph that fills the tile.
func _icon_px() -> float:
	var tex: Texture2D = _icon_rect.texture if _icon_rect != null else null
	var native: float = 18.0 if tex == null else float(maxi(tex.get_width(), tex.get_height()))
	if shape == Shape.SQUARE and label_text.is_empty():
		return native
	return native * float(pixel_scale)


func _size_name() -> String:
	return "large" if size_tier == SizeTier.LARGE else "small"


func _art_height() -> int:
	return 48 if size_tier == SizeTier.LARGE else 32


## Cap art is not the same width in every palette. Arc's ends are 17 / 11;
## the colour bars are 24 / 16. Read the loaded slice so neither set is stretched.
func _slice_width(rect: TextureRect) -> int:
	if rect != null and rect.texture != null:
		return rect.texture.get_width()
	return 24 if size_tier == SizeTier.LARGE else 16


func _mid_width() -> int:
	return 48 if size_tier == SizeTier.LARGE else 32


## Inset so glyphs clear the pixel border. Caps already cover the outer edge.
func _content_pad() -> int:
	if shape == Shape.SQUARE and label_text.is_empty():
		return 4 * pixel_scale
	return 8 * pixel_scale


func _play_shine_sweep(duration: float) -> void:
	if _shine_materials.is_empty():
		return
	if _shine_tween != null and _shine_tween.is_running():
		_shine_tween.kill()
	for mat: ShaderMaterial in _shine_materials:
		mat.set_shader_parameter(&"shine_progress", -0.5)
		mat.set_shader_parameter(&"shine_size", shine_size)
		mat.set_shader_parameter(&"shine_color", shine_color)
	_shine_tween = create_tween()
	_shine_tween.set_parallel(true)
	for mat: ShaderMaterial in _shine_materials:
		_shine_tween.tween_property(mat, "shader_parameter/shine_progress", 1.5, duration) \
				.set_trans(Tween.TRANS_QUAD) \
				.set_ease(Tween.EASE_OUT)


func _tween_scale(target: Vector2, duration: float) -> void:
	pivot_offset = size * 0.5
	if _pop_tween != null and _pop_tween.is_running():
		_pop_tween.kill()
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, "scale", target, duration) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func _on_hover_start() -> void:
	z_index = 1
	_tween_scale(hover_scale, 0.15)
	_play_shine_sweep(hover_shine_time)


func _on_hover_end() -> void:
	z_index = 0
	_tween_scale(Vector2.ONE, 0.15)


func _on_click_start() -> void:
	_tween_scale(click_scale, 0.05)
	_play_shine_sweep(press_shine_time)


func _on_click_end() -> void:
	if is_hovered():
		_on_hover_start()
	else:
		_on_hover_end()


func _on_pressed() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound("hud-button-press")
