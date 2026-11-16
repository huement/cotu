# res://Scripts/Utilities/BuildStatusEffects.gd
extends SceneTree
## Headless runner for StatusEffectCompiler.
##   godot --path . --headless -s res://Scripts/Utilities/BuildStatusEffects.gd

const _StatusEffectCompiler = preload("res://Scripts/Utilities/StatusEffectCompiler.gd")


func _initialize() -> void:
	var count: int = _StatusEffectCompiler.compile_status_effects()
	if count <= 0:
		push_error("BuildStatusEffects: compile failed or wrote 0 effects.")
		quit(1)
		return
	print("BuildStatusEffects: compiled %d status effects." % count)
	quit(0)
