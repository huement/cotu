extends Node
class_name WorldStateOrchestrator

const GAME_STATE_MENU := &"menu"
const GAME_STATE_GAMEPLAY := &"gameplay"
const GAME_STATE_COMBAT := &"combat"
const GAME_STATE_GAMEOVER_FAILURE := &"gameover_failure"
const GAME_STATE_GAMEOVER_SUCCESS := &"gameover_success"

var _game_state_machine: GameStateMachine
var _on_state_side_effects: Callable


func configure(on_state_side_effects: Callable) -> void:
	_on_state_side_effects = on_state_side_effects


func setup(initial_state_raw: String) -> void:
	if _game_state_machine == null:
		_game_state_machine = GameStateMachine.new()
		add_child(_game_state_machine)
		_game_state_machine.state_changed.connect(_on_game_state_changed)

	set_state(_normalized_game_state_name(initial_state_raw))


func current_game_state() -> StringName:
	if _game_state_machine == null:
		return GAME_STATE_MENU
	return _game_state_machine.state_name()


func is_gameplay_state_active() -> bool:
	return current_game_state() == GAME_STATE_GAMEPLAY


func is_combat_state_active() -> bool:
	return current_game_state() == GAME_STATE_COMBAT


func start_combat() -> void:
	set_state(GAME_STATE_COMBAT)


func end_combat() -> void:
	set_state(GAME_STATE_GAMEPLAY)


func go_to_menu() -> void:
	set_state(GAME_STATE_MENU)


func start_gameplay() -> void:
	set_state(GAME_STATE_GAMEPLAY)


func finish_with_failure() -> void:
	set_state(GAME_STATE_GAMEOVER_FAILURE)


func finish_with_success() -> void:
	set_state(GAME_STATE_GAMEOVER_SUCCESS)


func set_state(state_name: StringName) -> void:
	if _game_state_machine == null:
		return

	match state_name:
		GAME_STATE_MENU:
			_game_state_machine.to_menu()
		GAME_STATE_GAMEPLAY:
			_game_state_machine.to_gameplay()
		GAME_STATE_COMBAT:
			_game_state_machine.to_combat()
		GAME_STATE_GAMEOVER_FAILURE:
			_game_state_machine.to_gameover_failure()
		GAME_STATE_GAMEOVER_SUCCESS:
			_game_state_machine.to_gameover_success()
		_:
			_game_state_machine.to_menu()

	_apply_state_side_effects()


func _normalized_game_state_name(raw_name: String) -> StringName:
	var key := raw_name.strip_edges().to_lower()
	match key:
		"menu":
			return GAME_STATE_MENU
		"gameplay":
			return GAME_STATE_GAMEPLAY
		"gameoverfailure", "gameover_failure", "failure":
			return GAME_STATE_GAMEOVER_FAILURE
		"gameoversuccess", "gameover_success", "success":
			return GAME_STATE_GAMEOVER_SUCCESS
		_:
			return GAME_STATE_MENU


func _on_game_state_changed(_previous_state: int, _new_state: int) -> void:
	_apply_state_side_effects()


func _apply_state_side_effects() -> void:
	if _on_state_side_effects.is_valid():
		_on_state_side_effects.call()
