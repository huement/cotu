class_name GameStateMachine
extends Node

signal state_changed(previous_state: int, new_state: int)

enum State {
	MENU,
	GAMEPLAY,
	COMBAT,
	GAMEOVER_FAILURE,
	GAMEOVER_SUCCESS,
}

var current_state: State = State.MENU


func transition_to(new_state: State) -> bool:
	if current_state == new_state:
		return false

	var previous := current_state
	current_state = new_state
	state_changed.emit(previous, current_state)
	return true


func to_menu() -> bool:
	return transition_to(State.MENU)


func to_gameplay() -> bool:
	return transition_to(State.GAMEPLAY)


func to_combat() -> bool:
	return transition_to(State.COMBAT)


func to_gameover_failure() -> bool:
	return transition_to(State.GAMEOVER_FAILURE)


func to_gameover_success() -> bool:
	return transition_to(State.GAMEOVER_SUCCESS)


func is_gameplay() -> bool:
	return current_state == State.GAMEPLAY


func is_combat() -> bool:
	return current_state == State.COMBAT


func state_name() -> StringName:
	match current_state:
		State.MENU:
			return &"menu"
		State.GAMEPLAY:
			return &"gameplay"
		State.COMBAT:
			return &"combat"
		State.GAMEOVER_FAILURE:
			return &"gameover_failure"
		State.GAMEOVER_SUCCESS:
			return &"gameover_success"
		_:
			return &"unknown"
