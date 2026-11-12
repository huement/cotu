# res://Scripts/boot.gd
extends Node
## First scene of the game (Scenes/Boot.tscn = project main scene).
## Players (and every exported build) go to the main menu.
## In the editor, when MapManager's "Dev Start Override" is ticked in Scenes/world.tscn, it opens
## the world directly instead - MapManager then loads the test party on its "Default Map Scene".


func _ready() -> void:
	var target: String = SessionFlow.MAIN_MENU_SCENE
	if OS.has_feature("editor") and _dev_start_enabled():
		target = SessionFlow.GAME_SCENE
	get_tree().change_scene_to_file.call_deferred(target)


## Reads the switch straight from the scene file (text .tscn, editor only) so the heavy world
## scene is not loaded just to look at one checkbox.
func _dev_start_enabled() -> bool:
	var text: String = FileAccess.get_file_as_string(SessionFlow.GAME_SCENE)
	return text.contains("dev_start_override = true")
