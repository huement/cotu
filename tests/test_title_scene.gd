extends GutTest

const TITLE_SCENE := preload("res://scenes/title/title_screen.tscn")


func test_title_scene_has_start_and_quit_buttons() -> void:
	var title := TITLE_SCENE.instantiate() as Control
	add_child_autofree(title)
	await get_tree().process_frame

	var start_button := title.get_node_or_null("Center/Panel/Margin/VBox/StartButton") as Button
	var quit_button := title.get_node_or_null("Center/Panel/Margin/VBox/QuitButton") as Button
	assert_not_null(start_button)
	assert_not_null(quit_button)
	assert_eq(start_button.text, "Start Game")
	assert_eq(quit_button.text, "Quit")
