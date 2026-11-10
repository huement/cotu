# res://Scripts/Utilities/BuildLoot.gd
extends SceneTree
## Headless runner for LootCompiler.
##   godot --path . --headless -s res://Scripts/Utilities/BuildLoot.gd

const _LootCompiler = preload("res://Scripts/Utilities/LootCompiler.gd")


func _initialize() -> void:
	var count: int = _LootCompiler.compile_loot()
	if count <= 0:
		push_error("BuildLoot: compile failed or wrote 0 loot items.")
		quit(1)
		return
	print("BuildLoot: compiled %d loot items." % count)
	quit(0)
