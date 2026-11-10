class_name MenuKitMainMenu
extends MenuKitMenuScreen
## Main menu of the game: animated background, title, buttons, options and
## quit confirmation, all drawn by the active style.
##
## Put [code]main_menu.tscn[/code] in your title scene (or use this script on a
## full-screen Control), fill the title in the Inspector and pick the scene
## started by "New Game". Connect the signals for anything else.

## "New Game" pressed (the menu also opens [member new_game_scene] when set).
signal new_game_requested
## "Quit" confirmed. Without a connection, the game quits.
signal quit_requested

## Small line above the title.
@export var kicker: String = "Sector 7 // online"
## One or two lines of title.
@export var title_lines: PackedStringArray = PackedStringArray(["Starfall", "Protocol"])
## Your logo, drawn instead of the title text.
@export var logo: Texture2D
## Line at the bottom of the screen (version, controls...).
@export var footer_text: String = "v1.0.0 · ↑↓ navigate · enter select · esc back"
## Scene started by "New Game".
@export_file("*.tscn", "*.scn") var new_game_scene: String = ""
## Ask before quitting.
@export var confirm_quit: bool = true


func _ready() -> void:
	super()
	title_node.kicker = kicker
	title_node.lines = title_lines
	title_node.logo = logo
	footer.text = footer_text
	MenuKit.register_main_menu(self)
	update_buttons()
	play_intro()


## Asks to quit, then quits (or emits [signal quit_requested]).
func ask_quit() -> void:
	if confirm_quit:
		var choice: int = await ask("Quit game?", "Anything since your last save will be lost.", ["Stay", "Quit"])
		if choice != 1:
			return
	if quit_requested.get_connections().is_empty():
		MenuKit.quit_game()
	else:
		quit_requested.emit()


func _add_buttons() -> void:
	_make_button("New Game", &"new_game")
	_make_button("Options", &"options")
	if not OS.has_feature("web"):
		_make_button("Quit", &"quit")


func _on_button_pressed(id: StringName) -> void:
	super(id)
	match id:
		&"new_game":
			new_game_requested.emit()
			if not new_game_scene.is_empty():
				MenuKit.start_new_game(new_game_scene)
		&"options":
			open_options()
		&"quit":
			ask_quit()


