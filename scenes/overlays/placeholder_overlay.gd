extends Control

signal close_requested

@export var overlay_title := "Placeholder"
@export var overlay_subtitle := "Scene shell"

@onready var _title_label: Label = get_node_or_null("Center/Panel/Margin/VBox/Title")
@onready var _subtitle_label: Label = get_node_or_null("Center/Panel/Margin/VBox/Subtitle")
@onready var _close_button: Button = get_node_or_null("Center/Panel/Margin/VBox/CloseButton")


func _ready() -> void:
	if _title_label != null:
		_title_label.text = overlay_title
	if _subtitle_label != null:
		_subtitle_label.text = overlay_subtitle
	if _close_button != null:
		_close_button.pressed.connect(_on_close_pressed)
		_close_button.call_deferred("grab_focus")


func request_overlay_focus() -> void:
	if _close_button != null:
		_close_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if not event.is_pressed():
		return

	if event.is_action_pressed("close_overlay") or event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _on_close_pressed() -> void:
	close_requested.emit()
