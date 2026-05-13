extends Control

signal restart_requested
signal return_to_title_requested

@export var result_title := "Victory"
@export var result_subtitle := "Run complete."
@export var restart_button_text := "Play Again"
@export var menu_button_text := "Return To Title"

@onready var _title_label: Label = get_node_or_null("Center/Panel/Margin/VBox/Title")
@onready var _subtitle_label: Label = get_node_or_null("Center/Panel/Margin/VBox/Subtitle")
@onready var _restart_button: Button = get_node_or_null("Center/Panel/Margin/VBox/RestartButton")
@onready var _menu_button: Button = get_node_or_null("Center/Panel/Margin/VBox/MenuButton")


func _ready() -> void:
	if _title_label != null:
		_title_label.text = result_title
	if _subtitle_label != null:
		_subtitle_label.text = result_subtitle
	if _restart_button != null:
		_restart_button.text = restart_button_text
		_restart_button.pressed.connect(_on_restart_pressed)
		_restart_button.call_deferred("grab_focus")
	if _menu_button != null:
		_menu_button.text = menu_button_text
		_menu_button.pressed.connect(_on_menu_pressed)


func request_overlay_focus() -> void:
	if _restart_button != null:
		_restart_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if not event.is_pressed():
		return

	if event.is_action_pressed("ui_accept"):
		restart_requested.emit()
		get_viewport().set_input_as_handled()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_menu_pressed() -> void:
	return_to_title_requested.emit()
