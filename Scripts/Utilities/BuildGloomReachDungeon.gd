# res://Scripts/Utilities/BuildGloomReachDungeon.gd
extends SceneTree
## Headless runner for GenerateGloomReachDungeon.
##   godot --path . --headless -s res://Scripts/Utilities/BuildGloomReachDungeon.gd

func _initialize() -> void:
	var script: GDScript = load("res://Scripts/Utilities/GenerateGloomReachDungeon.gd") as GDScript
	if script == null:
		push_error("BuildGloomReachDungeon: could not load GenerateGloomReachDungeon.gd")
		quit(1)
		return
	var saved: Variant = script.call("build_all")
	if typeof(saved) != TYPE_ARRAY or (saved as Array).is_empty():
		push_error("BuildGloomReachDungeon: build failed.")
		quit(1)
		return
	print("BuildGloomReachDungeon: built %s." % ", ".join(saved as Array))
	quit(0)
