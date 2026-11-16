extends Node
## Demo of the Game Menu Kit: the title screen of a small game ("New Game" opens
## demo/level/demo_level.tscn).

const DemoSetup := preload("res://addons/game_menu_kit/demo/demo_setup.gd")


func _enter_tree() -> void:
	DemoSetup.run()
