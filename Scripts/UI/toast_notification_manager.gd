# res://Scripts/UI/toast_notification_manager.gd
extends CanvasLayer
class_name ToastNotificationManager

@export var auto_dismiss_time: float = 2.5

var _toast_container: VBoxContainer


func _ready() -> void:
	# 🎯 Layer 100 ensures toasts render above all HUDs, menus, and popups
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
	_toast_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_toast_container.add_theme_constant_override("separation", 8)

	_toast_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_container.offset_top = 24.0
	_toast_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.add_child(_toast_container)


func _on_show_toast(message: String, is_error: bool = false) -> void:
	_spawn_toast(message, is_error)


func _spawn_toast(message: String, is_error: bool) -> void:
	if not is_instance_valid(_toast_container):
		return

	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = Color("#1a0505") if is_error else Color("#03100e")
	style_box.border_color = Color("#fd6644") if is_error else Color("#00ffc8")
	style_box.set_border_width_all(1)
	style_box.set_corner_radius_all(4)
	style_box.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style_box)

	var label: Label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#fd6644") if is_error else Color("#00ffc8"))
	label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)

	_toast_container.add_child(panel)

	panel.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.tween_interval(auto_dismiss_time)
	tween.tween_property(panel, "modulate:a", 0.0, 0.35)
	tween.tween_callback(panel.queue_free)
