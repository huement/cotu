# res://Scripts/Environment/BattleConfigTerminal.gd
class_name BattleConfigTerminal
extends DungeonInteractable
## Wall / room interactable for the Battle Test Arena. Opens BattleConfigMenu; on confirm it
## fades out (GloomReach BossStatue style), teleports the party to `fight_start` facing
## `enemy_spawn`, fades in, then starts combat with the configured EnemyData pack.

const MENU_SCRIPT: GDScript = preload("res://Scripts/UI/BattleConfigMenu.gd")
const MAX_PACK: int = 5

@export_group("Arena")
## Where the party stands when the fight starts.
@export var fight_start: Node3D
## Look-at point for the party (enemy pack faces them from here in combat framing).
@export var enemy_spawn: Node3D
@export var fade_time: float = 0.5
@export var fade_color: Color = Color.BLACK
@export var pause_before_fight: float = 0.25

var _sequence_running: bool = false
var _fade_rect: ColorRect = null
var _menu: CanvasLayer = null


func _ready() -> void:
	snap_to_floor_center = false
	is_blocking = false
	super._ready()
	if not SignalBus.combat_ended.is_connected(_on_combat_ended):
		SignalBus.combat_ended.connect(_on_combat_ended)


func interact(player: Node3D) -> void:
	if _sequence_running:
		return
	if SessionFlow.is_in_battle():
		return
	_ensure_menu()
	if is_instance_valid(player) and player.has_method("set_movement_locked"):
		player.call("set_movement_locked", true)
	if is_instance_valid(AudioManager):
		AudioManager.play_mask_sound("good")
	_menu.call("open")


func _ensure_menu() -> void:
	if is_instance_valid(_menu):
		return
	_menu = MENU_SCRIPT.new() as CanvasLayer
	_menu.name = "BattleConfigMenu"
	add_child(_menu)
	_menu.connect("fight_confirmed", _on_fight_confirmed)
	_menu.connect("cancelled", _on_menu_cancelled)


func _on_menu_cancelled() -> void:
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if is_instance_valid(player) and player.has_method("set_movement_locked"):
		player.call("set_movement_locked", false)


func _on_fight_confirmed(config: Dictionary) -> void:
	_run_battle_sequence(config)


func _run_battle_sequence(config: Dictionary) -> void:
	if _sequence_running:
		return
	var pack: Array[Resource] = _build_enemy_pack(config)
	if pack.is_empty():
		push_warning("BattleConfigTerminal: empty enemy pack — aborting.")
		_on_menu_cancelled()
		return
	if not is_instance_valid(fight_start) or not is_instance_valid(enemy_spawn):
		push_warning("BattleConfigTerminal '%s': fight_start and enemy_spawn must both be set." % name)
		_on_menu_cancelled()
		return

	_sequence_running = true
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if is_instance_valid(player) and player.has_method("set_movement_locked"):
		player.call("set_movement_locked", true)
	if GameState.has_method("lock_encounters"):
		GameState.lock_encounters(60.0)

	GameLogger.combat("BattleConfigTerminal: fading into configured fight (%d enemies)..." % pack.size())
	await _fade_to(1.0)

	if is_instance_valid(player) and player.has_method("teleport_to"):
		player.call("teleport_to", fight_start.global_position, enemy_spawn.global_position)
	await _fade_to(0.0)
	await get_tree().create_timer(maxf(0.01, pause_before_fight)).timeout

	var party_slots: Array = []
	if is_instance_valid(GameState) and GameState.current_party != null and "slots" in GameState.current_party:
		party_slots = GameState.current_party.slots

	if GameState.has_method("clear_encounter_lock"):
		GameState.clear_encounter_lock()
	SignalBus.combat_started.emit(pack, party_slots, "SOUTH")


func _build_enemy_pack(config: Dictionary) -> Array[Resource]:
	var pack: Array[Resource] = []
	var main_path: String = str(config.get("main_path", ""))
	var main_count: int = clampi(int(config.get("main_count", 1)), 1, 3)
	var main: EnemyData = _load_enemy(main_path)
	if main == null:
		return pack
	for _i: int in main_count:
		pack.append(main.duplicate(true))

	for key: String in ["minion_a_path", "minion_b_path"]:
		var path: String = str(config.get(key, ""))
		if path.is_empty():
			continue
		var minion: EnemyData = _load_enemy(path)
		if minion != null:
			pack.append(minion.duplicate(true))
		if pack.size() >= MAX_PACK:
			break
	return pack


func _load_enemy(path: String) -> EnemyData:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as EnemyData


func _on_combat_ended(_victory: bool) -> void:
	_sequence_running = false
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if is_instance_valid(player) and player.has_method("set_movement_locked"):
		player.call("set_movement_locked", false)


func _fade_to(alpha: float) -> void:
	if not is_instance_valid(_fade_rect):
		var layer := CanvasLayer.new()
		layer.layer = 110
		add_child(layer)
		_fade_rect = ColorRect.new()
		_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
		layer.add_child(_fade_rect)
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", alpha, maxf(0.01, fade_time))
	await tween.finished
