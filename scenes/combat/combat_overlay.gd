extends Control

@onready var _player_hp_label: Label = $Center/Panel/Margin/VBox/PlayerHP
@onready var _enemy_hp_label: Label = $Center/Panel/Margin/VBox/EnemyHP
@onready var _status_label: Label = $Center/Panel/Margin/VBox/Status
@onready var _btn_attack: Button = $Center/Panel/Margin/VBox/Actions/Attack
@onready var _btn_defend: Button = $Center/Panel/Margin/VBox/Actions/Defend
@onready var _btn_use_item: Button = $Center/Panel/Margin/VBox/Actions/UseItem

var _world: Node


func _ready() -> void:
	_world = _resolve_world_context()
	if _btn_attack != null and not _btn_attack.pressed.is_connected(_on_attack_pressed):
		_btn_attack.pressed.connect(_on_attack_pressed)
	if _btn_defend != null and not _btn_defend.pressed.is_connected(_on_defend_pressed):
		_btn_defend.pressed.connect(_on_defend_pressed)
	if _btn_use_item != null and not _btn_use_item.pressed.is_connected(_on_use_item_pressed):
		_btn_use_item.pressed.connect(_on_use_item_pressed)

	_refresh_view()


func _process(_delta: float) -> void:
	_refresh_view()


func request_overlay_focus() -> void:
	if _btn_attack != null:
		_btn_attack.grab_focus()


func _refresh_view() -> void:
	if _world == null:
		_world = _resolve_world_context()
		if _world == null:
			return

	var player_stats: CharacterStats = null
	if _world.has_method("get_player_stats"):
		player_stats = _world.call("get_player_stats") as CharacterStats

	if player_stats != null:
		_player_hp_label.text = "Player HP: %d/%d" % [player_stats.health, player_stats.max_health]
	else:
		_player_hp_label.text = "Player HP: --"

	var enemy_count := 0
	var first_enemy_hp := "--"
	if _world.has_method("get_enemies"):
		var enemies := _world.call("get_enemies") as Array
		for enemy in enemies:
			if enemy == null or enemy.stats == null or enemy.stats.is_dead():
				continue
			enemy_count += 1
			if first_enemy_hp == "--":
				first_enemy_hp = "%d/%d" % [enemy.stats.health, enemy.stats.max_health]

	_enemy_hp_label.text = "Enemies: %d  Lead HP: %s" % [enemy_count, first_enemy_hp]

	var combat_active := false
	if _world.has_method("is_combat_state_active"):
		combat_active = bool(_world.call("is_combat_state_active"))

	_btn_attack.disabled = not combat_active
	_btn_defend.disabled = not combat_active
	_btn_use_item.disabled = not combat_active
	_status_label.text = "Choose an action" if combat_active else "Waiting..."


func _resolve_world_context() -> Node:
	var cursor: Node = self
	while cursor != null:
		if cursor.has_method("get_player_stats") and cursor.has_method("submit_combat_intent"):
			return cursor
		cursor = cursor.get_parent()

	return get_tree().current_scene


func _on_attack_pressed() -> void:
	_submit_intent(GridCommand.Type.ATTACK)


func _on_defend_pressed() -> void:
	_submit_intent(GridCommand.Type.DEFEND)


func _on_use_item_pressed() -> void:
	_submit_intent(GridCommand.Type.USE_ITEM)


func _submit_intent(cmd: GridCommand.Type) -> void:
	if _world != null and _world.has_method("submit_combat_intent"):
		_world.call("submit_combat_intent", cmd)
