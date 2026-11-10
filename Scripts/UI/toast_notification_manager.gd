# res://Scripts/UI/toast_notification_manager.gd
extends CanvasLayer
class_name ToastNotificationManager

## Compact sci-fi toasts: accent bar + glass body, stacked top-left.

const TOAST_BAR: Texture2D = preload("res://ui/BATTLE/660_25_bar.png")
const TOAST_WIDTH: float = 320.0
const BAR_SOURCE_WIDTH: float = 660.0
const BAR_SOURCE_HEIGHT: float = 25.0
const BAR_HEIGHT: float = TOAST_WIDTH * (BAR_SOURCE_HEIGHT / BAR_SOURCE_WIDTH)

@export var auto_dismiss_time: float = 2.5
@export var margin_left: float = 14.0
@export var margin_top: float = 10.0

var _toast_container: VBoxContainer


func _ready() -> void:
	# Layer 100 ensures toasts render above all HUDs, menus, and popups
	layer = 100

	_build_ui_hierarchy()

	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb and sb.has_signal("show_toast"):
		sb.show_toast.connect(_on_show_toast)


func _build_ui_hierarchy() -> void:
	var overlay: Control = Control.new()
	overlay.name = "ToastOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	_toast_container = VBoxContainer.new()
	_toast_container.name = "ToastContainer"
	_toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_container.add_theme_constant_override("separation", 6)

	_toast_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_toast_container.offset_left = margin_left
	_toast_container.offset_top = margin_top
	_toast_container.offset_right = margin_left + TOAST_WIDTH
	_toast_container.grow_horizontal = Control.GROW_DIRECTION_END
	_toast_container.grow_vertical = Control.GROW_DIRECTION_END
	overlay.add_child(_toast_container)


func _on_show_toast(message: String, is_error: bool = false) -> void:
	_spawn_toast(message, is_error)


func _spawn_toast(message: String, is_error: bool) -> void:
	if not is_instance_valid(_toast_container):
		return

	var accent: Color = Color("#fd6644") if is_error else Color("#41ead4")
	var text_color: Color = Color("#ff8f78") if is_error else Color("#9ef7ec")

	var root: VBoxContainer = VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 0)
	root.custom_minimum_size = Vector2(TOAST_WIDTH, 0.0)
	root.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var bar: TextureRect = TextureRect.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.texture = TOAST_BAR
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.stretch_mode = TextureRect.STRETCH_SCALE
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.custom_minimum_size = Vector2(TOAST_WIDTH, BAR_HEIGHT)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_error:
		bar.modulate = Color(1.0, 0.45, 0.38, 1.0)
	root.add_child(bar)

	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = Color(0.04, 0.01, 0.01, 0.82) if is_error else Color(0.02, 0.03, 0.04, 0.78)
	style_box.border_color = accent
	style_box.border_width_left = 1
	style_box.border_width_top = 0
	style_box.border_width_right = 1
	style_box.border_width_bottom = 1
	style_box.set_corner_radius_all(0)
	style_box.content_margin_left = 8
	style_box.content_margin_right = 8
	style_box.content_margin_top = 4
	style_box.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style_box)

	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(TOAST_WIDTH - 16.0, 0.0)
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_font_size_override("font_size", 12)
	panel.add_child(label)
	root.add_child(panel)

	_toast_container.add_child(root)

	root.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.12)
	tween.tween_interval(auto_dismiss_time)
	tween.tween_property(root, "modulate:a", 0.0, 0.28)
	tween.tween_callback(root.queue_free)
