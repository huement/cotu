extends Node
class_name WorldOverlayModule

signal restart_requested
signal return_to_title_requested
signal overlay_opened(kind: StringName)
signal overlay_closed(previous_kind: StringName)

var _overlay_mount: Control
var _overlay_scene_paths: Dictionary = {}
var _active_overlay: Control
var _active_overlay_kind: StringName = StringName()


func configure(overlay_mount: Control, overlay_scene_paths: Dictionary) -> void:
	_overlay_mount = overlay_mount
	_overlay_scene_paths = overlay_scene_paths.duplicate(true)


func set_overlay_scene_paths(overlay_scene_paths: Dictionary) -> void:
	_overlay_scene_paths = overlay_scene_paths.duplicate(true)


func has_active_overlay() -> bool:
	return is_instance_valid(_active_overlay)


func active_overlay_kind() -> StringName:
	return _active_overlay_kind


func open_overlay(kind: StringName) -> bool:
	if _overlay_mount == null:
		return false

	if _active_overlay_kind == kind and has_active_overlay():
		return false

	_close_internal()

	var scene := _scene_for_overlay(kind)
	if scene == null:
		return false

	var overlay := scene.instantiate() as Control
	if overlay == null:
		return false

	_overlay_mount.add_child(overlay)
	if overlay.has_signal("close_requested"):
		overlay.connect("close_requested", _on_overlay_close_requested)
	if overlay.has_signal("restart_requested"):
		overlay.connect("restart_requested", _on_overlay_restart_requested)
	if overlay.has_signal("return_to_title_requested"):
		overlay.connect("return_to_title_requested", _on_overlay_return_to_title_requested)

	_active_overlay = overlay
	_active_overlay_kind = kind
	overlay_opened.emit(kind)

	if overlay.has_method("request_overlay_focus"):
		overlay.call_deferred("request_overlay_focus")

	return true


func close_overlay() -> bool:
	if not has_active_overlay():
		return false

	_close_internal()
	return true


func _scene_for_overlay(kind: StringName) -> PackedScene:
	var scene_path := String(_overlay_scene_paths.get(kind, ""))
	if scene_path.is_empty():
		return null

	return load(scene_path) as PackedScene


func _close_internal() -> void:
	var previous_kind := _active_overlay_kind
	if has_active_overlay():
		_active_overlay.queue_free()

	_active_overlay = null
	_active_overlay_kind = StringName()

	if previous_kind != StringName():
		overlay_closed.emit(previous_kind)


func _on_overlay_close_requested() -> void:
	close_overlay()


func _on_overlay_restart_requested() -> void:
	restart_requested.emit()


func _on_overlay_return_to_title_requested() -> void:
	return_to_title_requested.emit()
