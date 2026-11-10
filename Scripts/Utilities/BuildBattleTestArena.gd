# res://Scripts/Utilities/BuildBattleTestArena.gd
extends SceneTree
## Headless runner for GenerateBattleTestArena.
##   godot --path . --headless -s res://Scripts/Utilities/BuildBattleTestArena.gd

func _initialize() -> void:
	var script: GDScript = load("res://Scripts/Utilities/GenerateBattleTestArena.gd") as GDScript
	if script == null:
		push_error("BuildBattleTestArena: could not load GenerateBattleTestArena.gd")
		quit(1)
		return
	var path: Variant = script.call("build")
	if typeof(path) != TYPE_STRING or str(path).is_empty():
		push_error("BuildBattleTestArena: build failed.")
		quit(1)
		return
	print("BuildBattleTestArena: built %s." % str(path))
	quit(0)
