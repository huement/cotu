# res://Scripts/Utilities/BuildEnemies.gd
extends SceneTree
## Headless runner for EnemyCompiler.
##   godot --path . --headless -s res://Scripts/Utilities/BuildEnemies.gd

func _initialize() -> void:
	var count: int = EnemyCompiler.compile_enemies()
	if count <= 0:
		push_error("BuildEnemies: compile failed or wrote 0 enemies.")
		quit(1)
		return
	print("BuildEnemies: compiled %d enemies." % count)
	quit(0)
