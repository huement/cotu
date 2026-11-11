# res://Scripts/Utilities/BuildSkills.gd
extends SceneTree
## Headless runner for SkillCompiler.
##   godot --path . --headless -s res://Scripts/Utilities/BuildSkills.gd

const _SkillCompiler = preload("res://Scripts/Utilities/SkillCompiler.gd")


func _initialize() -> void:
	var count: int = _SkillCompiler.compile_skills()
	if count <= 0:
		push_error("BuildSkills: compile failed or wrote 0 skills.")
		quit(1)
		return
	print("BuildSkills: compiled %d skills." % count)
	quit(0)
