class_name Enemy
extends GridEntity

@export var ai_enabled: bool = true

@onready var _ai: EnemyAI = get_node_or_null("EnemyAI") as EnemyAI


func _ready() -> void:
	super()
	add_to_group("grid_enemies")


func tick_ai(player) -> bool:
	if not ai_enabled or _ai == null:
		return false
	if movement_controller == null or movement_controller.is_busy:
		return false

	var cmd := _ai.choose_command(self, player)
	if cmd == EnemyAI.NO_COMMAND:
		return false

	return execute_command(cmd as GridCommand.Type)


func choose_combat_intent(player) -> GridCommand.Type:
	if _ai == null:
		return GridCommand.Type.ATTACK

	var cmd := _ai.choose_combat_intent(self, player)
	if cmd == EnemyAI.NO_COMMAND:
		return GridCommand.Type.DEFEND

	return cmd as GridCommand.Type


func _on_action_completed(cmd: GridCommand.Type, new_state: GridState) -> void:
	super(cmd, new_state)
