# res://Scripts/Utilities/BuildItems.gd
extends SceneTree
## Headless runner for ItemCompiler.
##   godot --path . --headless -s res://Scripts/Utilities/BuildItems.gd

const _ItemCompiler = preload("res://Scripts/Utilities/ItemCompiler.gd")


func _initialize() -> void:
	var count: int = _ItemCompiler.compile_items()
	if count <= 0:
		push_error("BuildItems: compile failed or wrote 0 items.")
		quit(1)
		return
	print("BuildItems: compiled %d items." % count)
	quit(0)
