# res://Scripts/Utilities/BuildVeroWoodDungeon.gd
extends SceneTree
## Headless runner for GenerateVeroWoodDungeon.
##   godot --path . --headless -s res://Scripts/Utilities/BuildVeroWoodDungeon.gd

func _initialize() -> void:
	var script: GDScript = load("res://Scripts/Utilities/GenerateVeroWoodDungeon.gd") as GDScript
	if script == null:
		push_error("BuildVeroWoodDungeon: could not load GenerateVeroWoodDungeon.gd")
		quit(1)
		return
	var saved: Variant = script.call("build_all")
	if typeof(saved) != TYPE_ARRAY or (saved as Array).is_empty():
		push_error("BuildVeroWoodDungeon: build failed.")
		quit(1)
		return
	print("BuildVeroWoodDungeon: built %s." % ", ".join(saved as Array))
	quit(0)
