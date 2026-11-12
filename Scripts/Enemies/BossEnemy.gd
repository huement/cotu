# res://Scripts/Enemies/BossEnemy.gd
class_name BossEnemy
extends WorldEnemy

## Specialized stationary boss enemy with model scaling, fixed facing alignment,
## and automatic minion party layout for combat.
## Inside a BossChamber it plays the chamber's boss: beating it opens the reward room and
## unlocks the exit gate (BossChamber listens to `boss_defeated`).

const _Formation = preload("res://Scripts/3D/CombatFormation.gd")

## Emitted when the party wins the fight against this boss (just before it is removed).
signal boss_defeated(boss: BossEnemy)

# ==============================================================================
# 1. EXPORTED BOSS CONFIGURATION
# ==============================================================================
## Facing direction in the room (lets you align the boss with its back to the wall)
@export var default_facing: Facing = Facing.SOUTH

## Model scale multiplier applied to the standard overworld model size
@export var model_scale_multiplier: float = 1.5

## Optional minion resource to flank the boss in combat
@export var minion_data: Resource

## Total number of minions accompanying the boss (e.g., 2 places 1 minion on each side)
@export_range(0, 4) var minion_count: int = 2


# ==============================================================================
# 2. LIFECYCLE & COMBAT PARTY SETUP
# ==============================================================================
@export_group("Boss Rewards")
## Spell Books / Skill Crystals added to the loot when this boss is beaten (shown on the victory screen).
@export_range(0, 10) var reward_spell_books: int = 1
@export_range(0, 10) var reward_skill_crystals: int = 1
@export_group("")

@export_group("Rush Ambush")
## The moment the party steps into the boss's room: freeze the party, yell, sprint at them and
## start the fight (like the Enraged Azurian). Off = the boss waits to be walked up to.
@export var rush_on_room_enter: bool = false
## Used only when the boss is NOT inside a BossChamber: rush when the party is this many tiles away.
@export_range(1, 12) var rush_trigger_tiles: int = 5
## Yell played as the rush starts.
@export_file("*.mp3", "*.ogg", "*.wav") var rush_yell_path: String = "res://Audio/Enemies/azure_yell.mp3"
## Footsteps looped while it runs (empty = silent run).
@export var rush_run_sound: AudioStream = preload("res://Audio/Enemies/gravel_run.mp3")
## Seconds the boss stands yelling before it starts to run.
@export var rush_taunt_time: float = 1.0
## Sprint speed in metres per second.
@export var rush_speed: float = 9.0
## The boss stops this far in front of the camera.
@export var rush_stop_distance: float = 2.5
@export var rush_impact_shake: float = 0.6
@export_group("")

var _rush_active: bool = false
## False after a lost / fled fight until the party has left the room, so it can't loop instantly.
var _rush_armed: bool = true
var _rush_audio: AudioStreamPlayer = null


func _ready() -> void:
	_current_facing = default_facing
	# Apply scale multiplier before base script instantiates the 3D mesh
	model_scale *= model_scale_multiplier
	super._ready()


func _setup_enemy_group() -> void:
	# If enemy_group was manually populated in the Inspector, preserve it and mark the boss.
	if not enemy_group.is_empty():
		_mark_boss_in_group()
		return

	var primary_boss_resource: Resource = data if data != null else enemy_data
	if not is_instance_valid(primary_boss_resource):
		super._setup_enemy_group()
		return

	enemy_group.clear()

	# Build party array: Minions on left, Boss in center, Minions on right.
	# Combat model_scale stays on EnemyData (CSV); model_scale_multiplier is overworld-only.
	if is_instance_valid(minion_data) and minion_count > 0:
		var left_count: int = minion_count / 2
		var right_count: int = minion_count - left_count

		for i in range(left_count):
			enemy_group.append(minion_data.duplicate())

		var boss_dup: Resource = primary_boss_resource.duplicate()
		_Formation.mark_boss(boss_dup)
		enemy_group.append(boss_dup)

		for i in range(right_count):
			enemy_group.append(minion_data.duplicate())
	else:
		var solo: Resource = primary_boss_resource.duplicate()
		_Formation.mark_boss(solo)
		enemy_group.append(solo)


## Marks the center (or only) pack member as the formation boss when the group was hand-authored.
func _mark_boss_in_group() -> void:
	if enemy_group.is_empty():
		return
	for entry: Resource in enemy_group:
		if _Formation.is_boss(entry):
			return
	var mid: int = enemy_group.size() / 2
	_Formation.mark_boss(enemy_group[mid])


# ==============================================================================
# 3. STATIONARY OVERRIDE
# ==============================================================================
## Overrides movement logic so the boss remains locked in place
func _check_pursuit_range() -> void:
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var player_cell: Vector2i = player.current_grid_pos if is_instance_valid(player) and ("current_grid_pos" in player) else Vector2i(-9999, -9999)

	var dist_to_player: int = absi(_grid_position.x - player_cell.x) + absi(_grid_position.y - player_cell.y)

	# Trigger combat when player walks into adjacent tile without moving boss from tile
	if dist_to_player <= 1:
		trigger_combat_encounter()


# ==============================================================================
# 3b. RUSH AMBUSH (rush_on_room_enter)
# ==============================================================================
func _process(delta: float) -> void:
	if rush_on_room_enter and _is_initialized and not _rush_active and not _is_in_active_combat and visible:
		var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
		if is_instance_valid(player):
			var in_zone: bool = _is_party_in_rush_zone(player)
			if not in_zone:
				_rush_armed = true
			elif _rush_armed and GameState.can_begin_encounter():
				_run_rush_ambush(player)
				return
	super._process(delta)


## In a BossChamber: the party is standing on the chamber's floor. Elsewhere: within rush_trigger_tiles.
func _is_party_in_rush_zone(player: Node3D) -> bool:
	var chamber: Node = get_parent()
	if chamber is BossChamber:
		var floor_grid: GridMap = chamber.get_node_or_null("BossFloor") as GridMap
		if floor_grid != null:
			var cell: Vector3i = floor_grid.local_to_map(floor_grid.to_local(player.global_position))
			return floor_grid.get_cell_item(Vector3i(cell.x, 0, cell.z)) != GridMap.INVALID_CELL_ITEM
	if not ("current_grid_pos" in player):
		return false
	var player_cell: Vector2i = player.get("current_grid_pos") as Vector2i
	return absi(_grid_position.x - player_cell.x) + absi(_grid_position.y - player_cell.y) <= rush_trigger_tiles


func _run_rush_ambush(player: Node3D) -> void:
	_rush_active = true
	_rush_armed = false
	_is_moving = true # stops the normal patrol / adjacent-tile check while we run
	var home: Vector3 = global_position

	# Freeze the party and keep other enemies from starting a fight mid-rush.
	_set_party_locked(player, true)
	GameState.lock_encounters(30.0)

	# Let the step that carried the party into the room finish, then turn them to face the boss.
	while is_instance_valid(player) and bool(player.get("is_moving")):
		await get_tree().process_frame
	if not _rush_still_valid(player):
		return
	await BattleFacing.orient_party(get_tree(), global_position)
	if not _rush_still_valid(player):
		return
	_set_party_locked(player, true) # orient_party hands movement back when it finishes

	# Yell.
	GameLogger.combat("%s spots the party and charges!" % name)
	_face_model_toward(player.global_position)
	if not rush_yell_path.is_empty():
		AudioManager.play_audio_path(rush_yell_path)
	SignalBus.camera_shake_requested.emit(0.35)
	await get_tree().create_timer(maxf(0.0, rush_taunt_time)).timeout
	if not _rush_still_valid(player):
		return

	# Sprint to just in front of the camera.
	var target: Vector3 = _rush_target(player)
	var run_time: float = maxf(0.25, global_position.distance_to(target) / maxf(0.5, rush_speed))
	_face_model_toward(target)
	_play_rush_anim([&"sprint", &"Sprint", &"run", &"Run"], &"walk", true)
	_play_run_loop(true)
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", target, run_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	_play_run_loop(false)
	if not _rush_still_valid(player):
		return

	# Impact, then the fight.
	SignalBus.camera_shake_requested.emit(rush_impact_shake)
	_play_rush_anim([&"attack-melee-right", &"Attack", &"attack"], &"idle", false)
	await get_tree().create_timer(0.25).timeout
	if not _rush_still_valid(player):
		return

	GameState.clear_encounter_lock()
	_set_party_locked(player, false) # the battle takes over the lock from here
	_is_moving = false
	_rush_active = false
	trigger_combat_encounter()
	# Wait until the battle has actually taken over (the boss is hidden) or was refused.
	while is_inside_tree() and visible and _is_in_active_combat:
		await get_tree().process_frame
	if not is_inside_tree():
		return
	# Back to its spot (hidden during the fight), so a reward left "where the boss stood" and a
	# boss that survives a fled fight are both in the middle of the room, not at the doorway.
	global_position = home
	if is_instance_valid(model_holder):
		model_holder.rotation_degrees.y = _facing_to_angle(default_facing)
	_play_animation(&"idle", true)


func _rush_still_valid(player: Node3D) -> bool:
	if is_inside_tree() and is_instance_valid(player):
		return true
	_abort_rush(player)
	return false


func _abort_rush(player: Node3D) -> void:
	_play_run_loop(false)
	_rush_active = false
	_is_moving = false
	if is_instance_valid(player):
		_set_party_locked(player, false)


func _set_party_locked(player: Node3D, locked: bool) -> void:
	if is_instance_valid(player) and player.has_method("set_movement_locked"):
		player.call("set_movement_locked", locked)


func _rush_target(player: Node3D) -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var origin: Vector3 = player.global_position
	var forward: Vector3 = -player.global_basis.z
	if is_instance_valid(camera):
		origin = camera.global_position
		forward = -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var target: Vector3 = origin + forward * rush_stop_distance
	target.y = global_position.y
	return target


## Turns the overworld model to look at a point (same angle convention as _facing_to_angle).
func _face_model_toward(world_point: Vector3) -> void:
	if not is_instance_valid(model_holder):
		return
	var dir: Vector3 = world_point - global_position
	if Vector2(dir.x, dir.z).length_squared() < 0.0004:
		return
	model_holder.rotation_degrees.y = rad_to_deg(atan2(dir.x, dir.z))


## Plays the first clip the model has from `names`, else the standard `fallback` action.
func _play_rush_anim(names: Array[StringName], fallback: StringName, loop: bool) -> void:
	var anim_player: AnimationPlayer = model_holder.find_child("AnimationPlayer", true, false) as AnimationPlayer if is_instance_valid(model_holder) else null
	if is_instance_valid(anim_player):
		for anim_name: StringName in names:
			if anim_player.has_animation(anim_name):
				var anim: Animation = anim_player.get_animation(anim_name)
				if is_instance_valid(anim):
					anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
				anim_player.play(anim_name)
				return
	_play_animation(fallback, true)


func _play_run_loop(on: bool) -> void:
	if not on:
		if is_instance_valid(_rush_audio):
			_rush_audio.stop()
		return
	if rush_run_sound == null:
		return
	if not is_instance_valid(_rush_audio):
		_rush_audio = AudioStreamPlayer.new()
		_rush_audio.bus = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
		add_child(_rush_audio)
	var stream: AudioStream = rush_run_sound.duplicate() as AudioStream
	if "loop" in stream:
		stream.set("loop", true)
	_rush_audio.stream = stream
	_rush_audio.play()


func _exit_tree() -> void:
	# Never leave the party frozen if the map is swapped mid-rush.
	if _rush_active:
		_set_party_locked(get_tree().get_first_node_in_group(&"player") as Node3D, false)
		GameState.clear_encounter_lock()


# ==============================================================================
# 4. DEFEAT
# ==============================================================================
func _on_combat_ended(victory: bool) -> void:
	if victory and _is_in_active_combat:
		boss_defeated.emit(self)
	super._on_combat_ended(victory)


## Boss fights also pay out Spell Books / Skill Crystals (see reward_* exports).
func trigger_combat_encounter() -> void:
	GameState.register_boss_rewards(reward_spell_books, reward_skill_crystals)
	super.trigger_combat_encounter()
