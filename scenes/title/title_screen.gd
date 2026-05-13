extends Control

@export_file("*.tscn") var gameplay_scene_path := "res://scenes/world/main.tscn"

@onready var _start_button: Button = get_node_or_null("Center/Panel/Margin/VBox/StartButton")
@onready var _quit_button: Button = get_node_or_null("Center/Panel/Margin/VBox/QuitButton")


func _ready() -> void:
	if _start_button != null:
		_start_button.pressed.connect(_on_start_pressed)
		_start_button.call_deferred("grab_focus")
	if _quit_button != null:
		_quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if not event.is_pressed():
		return

	if event.is_action_pressed("ui_accept"):
		_start_game()
		get_viewport().set_input_as_handled()


func _on_start_pressed() -> void:
	_start_game()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _start_game() -> void:
	if gameplay_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(gameplay_scene_path)
