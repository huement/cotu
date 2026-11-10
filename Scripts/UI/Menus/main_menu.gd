# res://Scripts/UI/Menus/main_menu.gd
class_name ShardsMainMenu
extends MenuKitMainMenu
## Title screen, built on Game Menu Kit Lite (neon style).
## New Game · Load Game · Settings · About · Help · Party Builder · Quit
##
## New Game opens the roster (RosterScreen, START mode: create characters, pick a party, start).
## Party Builder opens the same roster to create / edit characters without starting a game.
## Settings uses the Settings Menu Lite addon; About / Help are MenuScreenTemplate screens.

const SETTINGS_MENU_SCENE: PackedScene = preload("res://addons/settings_menu/SettingsMenu.tscn")
const ABOUT_SCREEN_SCENE: PackedScene = preload("res://Scenes/GameMenus/AboutScreen.tscn")
const HELP_SCREEN_SCENE: PackedScene = preload("res://Scenes/GameMenus/HelpScreen.tscn")

var _overlay: Control = null


func _ready() -> void:
	super()
	MenuKit.main_menu_scene = SessionFlow.MAIN_MENU_SCENE
	_refresh_load_button()


## Animated pixel-art space instead of the kit's style background (pause menus keep the kit's).
func _create_background() -> Control:
	if pause_screen:
		return super()
	var space := SpaceBackground.new()
	space.preset = SpaceBackground.Preset.MAIN_MENU
	return space


func _add_buttons() -> void:
	_make_button("New Game", &"new_game")
	_make_button("Load Game", &"load_game")
	_make_button("Settings", &"settings")
	_make_button("About", &"about")
	_make_button("Help", &"help")
	_make_button("Party Builder", &"party_builder")
	if not OS.has_feature("web"):
		_make_button("Quit", &"quit")


func _on_button_pressed(id: StringName) -> void:
	button_pressed.emit(id)
	if is_instance_valid(_overlay):
		return
	match id:
		&"new_game":
			_on_new_game_pressed()
		&"load_game":
			_on_load_game_pressed()
		&"settings":
			_open_overlay(_make_settings_menu())
		&"about":
			_open_overlay(ABOUT_SCREEN_SCENE.instantiate() as Control)
		&"help":
			_open_overlay(HELP_SCREEN_SCENE.instantiate() as Control)
		&"party_builder":
			_open_overlay(_make_roster(RosterScreen.Mode.MANAGE))
		&"quit":
			ask_quit()


func _on_new_game_pressed() -> void:
	if SessionFlow.has_save():
		var choice: int = await ask("Start a new game?", "Your current save will be replaced when the new party sets out.", ["Cancel", "New Game"], 0)
		if choice != 1:
			return
	new_game_requested.emit()
	_open_overlay(_make_roster(RosterScreen.Mode.START))


func _make_roster(roster_mode: RosterScreen.Mode) -> Control:
	var screen := RosterScreen.new()
	screen.mode = roster_mode
	return screen


func _on_load_game_pressed() -> void:
	if not SessionFlow.has_save():
		await ask("No save found", "Start a new game first. Saves are made from the in-game menu.", ["OK"])
		return
	if not SessionFlow.load_saved_game(get_tree()):
		await ask("Couldn't load", "The save file is missing or damaged. Try starting a new game.", ["OK"])


## Shows the save date under "Load Game" (second line of the button).
func _refresh_load_button() -> void:
	var button: MenuKitMenuButton = get_button(&"load_game")
	if button == null:
		return
	var stamp: String = SessionFlow.get_save_timestamp()
	button.sub_text = "Saved %s" % stamp if not stamp.is_empty() else ("No save yet" if not SessionFlow.has_save() else "")
	update_buttons()


func _make_settings_menu() -> Control:
	var menu: Control = SETTINGS_MENU_SCENE.instantiate() as Control
	menu.set("free_on_close", true)
	menu.set("color_preset", "Night")
	return menu


## Opens [param screen] over the menu; the menu is dimmed and can't take focus until it closes.
func _open_overlay(screen: Control) -> void:
	_overlay = screen
	add_child(screen)
	_set_menu_active(false)
	screen.connect(&"closed", _on_overlay_closed, CONNECT_ONE_SHOT)
	if screen.has_method("open"):
		screen.call("open")


func _on_overlay_closed() -> void:
	_overlay = null
	_set_menu_active(true)
	_refresh_load_button()
	focus_first_button()
