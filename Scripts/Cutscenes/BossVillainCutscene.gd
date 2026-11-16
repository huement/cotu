# res://Scripts/Cutscenes/BossVillainCutscene.gd
class_name BossVillainCutscene
extends Node
## The main villain's "taunt" cutscene. One of these lives in world.tscn (it survives map swaps);
## bosses ask for it with SignalBus.boss_cutscene_requested and never touch it directly.
##
## What the player sees:
##   1. Party frozen and turned to face the boss. The boss appears (screen quake + red/black strobe).
##   2. A dark red vignette closes in while the camera backs away, step by step.
##   3. Halfway back: the cube flash (LoreScareFX) and the scary voice.
##   4. The boss's dialog box (avatar in the corner). Waits for the player.
##   5. Fade to black. While black: the boss is gone, the party is drained / moved (the ending).
##   6. The party "wakes up" (camera lifts off the floor), then the forced fight starts if one is set.
##
## The ending (dialog text, drain, fight or travel) comes with the request as a BossCutsceneEnding,
## so each boss placed in a level carries its own - see MalviathanController.

## Camera stops this far short of anything behind it.
const WALL_MARGIN: float = 0.6
## Retreat allowed when the cell behind the party is a wall (GridMap walls may have no collision).
const BLOCKED_CELL_RETREAT: float = 0.35
const BLACK_LAYER: int = 130

@export_group("Filter")
## Only answer requests with this id. Empty = play for every boss that asks.
@export var only_cutscene_id: String = ""

@export_group("Villain")
## Optional. A scene to spawn in front of the party as the villain. Leave empty when the boss is
## already placed in the level (Malviathan shows / hides itself).
@export var villain_scene: PackedScene
## How far in front of the party the spawned villain stands (metres).
@export var villain_spawn_distance: float = 3.6

@export_group("Scare")
## Image that strobes across the screen halfway through the retreat. Empty = the cube.
@export var lore_flash_texture: Texture2D
@export var scary_voice_stream: AudioStream = preload("res://Audio/Enemies_Boss/die-die-die.mp3")
@export_range(-40.0, 12.0, 0.5) var scary_voice_volume_db: float = 0.0
## Quake when the villain appears (0-1).
@export_range(0.0, 1.0, 0.05) var impact_shake: float = 0.9

@export_group("Camera Retreat")
## How far the camera backs away (metres). Shortened automatically next to a wall.
@export var max_retreat_distance: float = 1.8
@export var retreat_duration: float = 2.4
## Footstep bobs during the retreat, and how high each one is.
@export_range(0, 8) var retreat_steps: int = 3
@export var retreat_bob_height: float = 0.05

@export_group("Timing")
## Pause between the end of the retreat and the dialog box.
@export var dialog_delay: float = 0.6
@export var fade_to_black_seconds: float = 0.9
## Seconds spent in the dark before waking up.
@export var black_hold_seconds: float = 0.8
@export var wake_up_seconds: float = 1.6
## How far the camera looks down at the floor when the party wakes (degrees).
@export var wake_up_tilt_degrees: float = 12.0

var _running: bool = false
var _player: DungeonPlayer = null
var _camera: Camera3D = null
var _camera_home_position: Vector3 = Vector3.ZERO
var _camera_home_rotation: Vector3 = Vector3.ZERO
var _camera_moved: bool = false
var _vignette: GhostScareFX = null
var _black_layer: CanvasLayer = null
var _spawned_villain: Node3D = null
var _voice_player: AudioStreamPlayer = null
var _dialog_token: String = ""
var _dialog_closed: bool = false


func _ready() -> void:
	set_process(false)
	SignalBus.boss_cutscene_requested.connect(_on_cutscene_requested)
	SignalBus.popup_confirmed.connect(_on_popup_confirmed)


func is_running() -> bool:
	return _running


func _on_cutscene_requested(cutscene_id: String, anchor_position: Vector3, ending: Resource) -> void:
	if _running:
		return
	if not only_cutscene_id.is_empty() and cutscene_id != only_cutscene_id:
		return
	_run_cutscene(cutscene_id, anchor_position, ending as BossCutsceneEnding)


## Keeps wandering enemies from starting a fight for as long as the cutscene runs (the dialog
## waits for the player, so a fixed timer could run out).
func _process(_delta: float) -> void:
	if _running:
		GameState.lock_encounters(5.0)


# ==============================================================================
# The sequence
# ==============================================================================

func _run_cutscene(cutscene_id: String, anchor_position: Vector3, ending: BossCutsceneEnding) -> void:
	_player = get_tree().get_first_node_in_group(&"player") as DungeonPlayer
	if not is_instance_valid(_player):
		push_warning("BossVillainCutscene: no player in group 'player' - cutscene '%s' skipped." % cutscene_id)
		SignalBus.boss_cutscene_finished.emit(cutscene_id)
		return
	if ending == null:
		ending = BossCutsceneEnding.new()
	_running = true
	set_process(true)
	GameLogger.info("BossVillainCutscene: '%s' started." % cutscene_id)

	# 1. Lock state. Let the step that carried the party in finish, then face the boss.
	_player.set_movement_locked(true)
	GameState.lock_encounters(30.0)
	while _alive() and _player.is_moving:
		await get_tree().process_frame
	if not _alive():
		return
	await BattleFacing.orient_party(get_tree(), anchor_position)
	if not _alive():
		return
	_player.set_movement_locked(true) # orient_party hands movement back when it finishes
	_camera = _player.camera
	_camera_home_position = _camera.position
	_camera_home_rotation = _camera.rotation
	_camera_moved = true

	# 2. The villain appears.
	SignalBus.boss_cutscene_villain_visible.emit(cutscene_id, true)
	_spawn_villain()

	# 3. Initial impact.
	SignalBus.camera_shake_requested.emit(impact_shake)
	GhostScareFX.play_blood(get_tree(), 2, 0.95, 0.07)

	# 4. Sustained vignette.
	_vignette = GhostScareFX.start_red_vignette(get_tree())

	# 5 + 6. Back away; halfway through: cube flash + voice.
	await get_tree().physics_frame # ray queries want the physics state
	if not _alive():
		return
	var distance: float = _safe_retreat_distance()
	var retreat: Tween = create_tween()
	retreat.tween_method(_apply_retreat.bind(distance), 0.0, 1.0, maxf(0.1, retreat_duration)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(maxf(0.05, retreat_duration * 0.5)).timeout
	if not _alive():
		return
	_play_scare()
	if retreat.is_running():
		await retreat.finished
	if not _alive():
		return

	# 7. The boss speaks. Waits for the player to close the box.
	if ending.has_dialog():
		await get_tree().create_timer(maxf(0.0, dialog_delay)).timeout
		if not _alive():
			return
		await _show_dialog(cutscene_id, ending)
		if not _alive():
			return

	# 8. Fade to black.
	var black: ColorRect = _make_black_screen()
	var fade_in: Tween = create_tween()
	fade_in.tween_property(black, "modulate:a", 1.0, maxf(0.05, fade_to_black_seconds))
	await fade_in.finished
	if not _alive():
		return

	# 9. While black: villain gone, camera back on its cell, the ending applied, game saved.
	SignalBus.boss_cutscene_villain_visible.emit(cutscene_id, false)
	_free_villain()
	_end_vignette()
	_restore_camera()
	_apply_drain(ending)
	var travelled: bool = false
	if ending.after == BossCutsceneEnding.After.TRAVEL:
		travelled = _travel(ending) # autosaves on arrival
	if not travelled:
		GameState.save_game()
	await get_tree().create_timer(maxf(0.0, black_hold_seconds)).timeout
	if not _alive():
		return

	# 10. Wake up on the floor.
	_camera = _player.camera
	var rest_x: float = _camera.rotation_degrees.x
	_camera.rotation_degrees.x = rest_x - wake_up_tilt_degrees
	var wake: Tween = create_tween().set_parallel(true)
	wake.tween_property(black, "modulate:a", 0.0, maxf(0.05, wake_up_seconds)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	wake.tween_property(_camera, "rotation_degrees:x", rest_x, maxf(0.05, wake_up_seconds)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await wake.finished
	if not _alive():
		return

	# 11. Hand the game back.
	var fight_group: Array[Resource] = []
	if ending.after == BossCutsceneEnding.After.FIGHT:
		fight_group = ending.build_fight_group()
		if fight_group.is_empty():
			push_warning("BossVillainCutscene: ending is 'Fight' but no enemies are set - skipping the fight.")
	_finish(cutscene_id)
	if not fight_group.is_empty():
		_start_forced_fight(fight_group)


func _finish(cutscene_id: String) -> void:
	_free_black_screen()
	_running = false
	set_process(false)
	GameState.clear_encounter_lock()
	GameState.lock_encounters(2.0)
	if is_instance_valid(_player):
		_player.set_movement_locked(false)
	GameLogger.info("BossVillainCutscene: '%s' finished." % cutscene_id)
	SignalBus.boss_cutscene_finished.emit(cutscene_id)


## False when the cutscene can't go on (world torn down / player gone). Cleans up once.
func _alive() -> bool:
	if is_inside_tree() and is_instance_valid(_player) and _player.is_inside_tree():
		return true
	_abort()
	return false


func _abort() -> void:
	if not _running:
		return
	_running = false
	set_process(false)
	_free_villain()
	_end_vignette()
	_free_black_screen()
	_restore_camera()
	if is_instance_valid(_player):
		_player.set_movement_locked(false)
	GameState.clear_encounter_lock()


func _exit_tree() -> void:
	# Never leave the party frozen or the screen black if the world is torn down mid-cutscene.
	_abort()


# ==============================================================================
# Villain (optional spawned scene)
# ==============================================================================

func _spawn_villain() -> void:
	if villain_scene == null:
		return
	_spawned_villain = villain_scene.instantiate() as Node3D
	if not is_instance_valid(_spawned_villain):
		return
	var forward: Vector3 = -_player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	_player.get_parent().add_child(_spawned_villain)
	_spawned_villain.global_position = _player.global_position + forward * villain_spawn_distance
	_spawned_villain.look_at(Vector3(_player.global_position.x, _spawned_villain.global_position.y, _player.global_position.z), Vector3.UP)


func _free_villain() -> void:
	if is_instance_valid(_spawned_villain):
		_spawned_villain.queue_free()
	_spawned_villain = null


# ==============================================================================
# Camera
# ==============================================================================

## How far the camera may back away without going through whatever is behind the party.
func _safe_retreat_distance() -> float:
	var limit: float = maxf(0.0, max_retreat_distance)
	var back: Vector3 = _camera.global_basis.z
	back.y = 0.0
	if back.length_squared() < 0.0001:
		return 0.0
	back = back.normalized()

	# Grid check: a wall cell behind the party (GridMap walls don't always have collision).
	var map_mgr: MapManager = _player.map_manager
	if is_instance_valid(map_mgr) and is_instance_valid(_player.grid_movement):
		var behind: Vector3 = _player.global_position + back * _player.grid_movement.tile_size
		if map_mgr.is_tile_blocked(map_mgr.world_to_grid(behind)):
			limit = minf(limit, BLOCKED_CELL_RETREAT)

	# Physics check: anything solid behind the camera.
	var from: Vector3 = _camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + back * (limit + WALL_MARGIN))
	var player_node: Node = _player # the Player node is a CharacterBody3D under the DungeonPlayer script
	var player_body: CollisionObject3D = player_node as CollisionObject3D
	if player_body != null:
		query.exclude = [player_body.get_rid()]
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_distance: float = from.distance_to(hit["position"] as Vector3)
		limit = clampf(hit_distance - WALL_MARGIN, 0.0, limit)
	return limit


## t 0..1 along the retreat: slides the camera back (local +Z) with a small bob per footstep.
func _apply_retreat(t: float, distance: float) -> void:
	if not is_instance_valid(_camera):
		return
	var bob: float = absf(sin(t * PI * float(retreat_steps))) * retreat_bob_height
	_camera.position = _camera_home_position + Vector3(0.0, -bob, distance * t)


## Puts the camera back exactly where the player controller keeps it, so the party stays aligned
## to its grid cell.
func _restore_camera() -> void:
	if not _camera_moved:
		return
	_camera_moved = false
	if is_instance_valid(_camera):
		_camera.position = _camera_home_position
		_camera.rotation = _camera_home_rotation


# ==============================================================================
# Scare, dialog, screen
# ==============================================================================

func _play_scare() -> void:
	var data: Dictionary = { "aura_type": "bad", "shake_trauma": 0.6, "aura_hold": 2.0 }
	if lore_flash_texture != null:
		data["flash_texture"] = lore_flash_texture
	SignalBus.lore_scare_requested.emit(data)
	if scary_voice_stream == null:
		return
	if not is_instance_valid(_voice_player):
		_voice_player = AudioStreamPlayer.new()
		_voice_player.bus = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
		add_child(_voice_player)
	_voice_player.stream = scary_voice_stream
	_voice_player.volume_db = scary_voice_volume_db
	_voice_player.play()


func _show_dialog(cutscene_id: String, ending: BossCutsceneEnding) -> void:
	_dialog_token = "%s_%d" % [cutscene_id, Time.get_ticks_msec()]
	_dialog_closed = false
	SignalBus.popup_requested.emit(&"BOSS_DIALOG", {
		"speaker": ending.speaker_name,
		"body": ending.dialog_text,
		"avatar": ending.avatar,
		"dialog_id": _dialog_token,
	})
	while not _dialog_closed and is_inside_tree():
		await get_tree().process_frame


func _on_popup_confirmed(action_type: StringName, extra_data: Dictionary) -> void:
	if action_type == &"BOSS_DIALOG" and str(extra_data.get("dialog_id", "")) == _dialog_token:
		_dialog_closed = true


func _make_black_screen() -> ColorRect:
	_free_black_screen()
	_black_layer = CanvasLayer.new()
	_black_layer.layer = BLACK_LAYER
	add_child(_black_layer)
	var rect := ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP # no clicking the HUD through the dark
	rect.modulate.a = 0.0
	_black_layer.add_child(rect)
	return rect


func _free_black_screen() -> void:
	if is_instance_valid(_black_layer):
		_black_layer.queue_free()
	_black_layer = null


func _end_vignette() -> void:
	if is_instance_valid(_vignette):
		_vignette.fade_out_and_free()
	_vignette = null


# ==============================================================================
# Ending
# ==============================================================================

func _apply_drain(ending: BossCutsceneEnding) -> void:
	if GameState.current_party == null:
		return
	var slots: Array = GameState.current_party.slots
	for slot: int in ending.apply_drain(slots):
		var member: CatCharacter = slots[slot] as CatCharacter
		SignalBus.character_health_changed.emit(slot, member.current_hp)
		SignalBus.character_mana_changed.emit(slot, member.current_mana, member.max_mana)


func _travel(ending: BossCutsceneEnding) -> bool:
	if ending.travel_scene.is_empty() or not ResourceLoader.exists(ending.travel_scene):
		push_warning("BossVillainCutscene: ending is 'Travel' but the scene '%s' does not exist - staying here." % ending.travel_scene)
		return false
	return MapTransition.travel(get_tree(), ending.travel_scene, ending.travel_arrival_point)


## Starts a battle the same way a WorldEnemy does, against a pack that has no model in the level.
func _start_forced_fight(group: Array[Resource]) -> void:
	GameState.clear_encounter_lock()
	# "Enemy" spot = straight ahead, so the party doesn't spin round before the fight.
	var ahead: Vector3 = _player.global_position - _player.global_basis.z * 2.0
	await BattleArena.prepare_party(get_tree(), ahead)
	if not is_inside_tree():
		return
	var combat_manager: Node = get_tree().root.get_node_or_null("CombatManager")
	if is_instance_valid(combat_manager) and bool(combat_manager.get("is_combat_active")):
		return # another fight started while we turned
	var party_slots: Array = GameState.current_party.slots if GameState.current_party != null else []
	GameLogger.combat("The party is forced into battle (%d hostiles)." % group.size())
	SignalBus.combat_started.emit(group, party_slots, "SOUTH")
