# res://Scripts/Managers/BattleFacing.gd
class_name BattleFacing
extends RefCounted
## Makes sure the party is looking at the enemy before a battle starts.
## Battle models are placed in front of the camera, so if the party faces a wall when an enemy
## bumps into them from the side or behind, the fight would happen inside the wall.
##
## The enemy is never moved (it could end up out of bounds). Instead the party turns on the spot to
## face the enemy's cell - that cell is always open floor, because the enemy is standing on it.
## If the enemy shares the party's cell, the party turns to the nearest open direction instead.
##
## Usage (before emitting combat_started):
##     await BattleFacing.orient_party(get_tree(), global_position)

## Turn time for 90 degrees; a full about-face takes about twice as long.
const TURN_SECONDS_PER_90: float = 0.18
## A quick dip to black when the party has to spin all the way round.
const ABOUT_FACE_FADE: float = 0.12
const ABOUT_FACE_FADE_ALPHA: float = 0.55

const DIRECTIONS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


## Turns the party toward `enemy_world_pos` if it isn't already facing it. Returns once the turn is done.
static func orient_party(tree: SceneTree, enemy_world_pos: Vector3) -> void:
	if tree == null:
		return
	var player: DungeonPlayer = tree.get_first_node_in_group(&"player") as DungeonPlayer
	if not is_instance_valid(player):
		return

	var party_cell: Vector2i = player.current_grid_pos
	var enemy_cell: Vector2i = player.call("_world_to_cell", enemy_world_pos) as Vector2i
	var target_dir: Vector2i = _direction_to(enemy_cell - party_cell)
	var current_dir: Vector2i = _facing_dir(player)

	if target_dir == Vector2i.ZERO:
		# Enemy is on our cell: keep facing if the view ahead is open, else turn to open floor.
		if not _is_cell_blocked(tree, party_cell + current_dir):
			return
		target_dir = _first_open_dir(tree, party_cell, current_dir)
		if target_dir == Vector2i.ZERO:
			return
	if target_dir == current_dir:
		return

	if is_instance_valid(GameLogger):
		GameLogger.combat("Turning the party to face the enemy before battle.")
	player.set_movement_locked(true)
	if is_instance_valid(GameState) and GameState.has_method("lock_encounters"):
		GameState.lock_encounters(2.0) # nobody else may start a fight mid-turn

	var is_about_face: bool = target_dir == -current_dir
	var fade_rect: ColorRect = null
	if is_about_face:
		fade_rect = _make_fade(player)
	var turn_time: float = TURN_SECONDS_PER_90 * (2.0 if is_about_face else 1.0)

	# Shortest spin from the current yaw to the yaw that looks along target_dir (-Z forward).
	var target_yaw: float = rad_to_deg(atan2(-float(target_dir.x), -float(target_dir.y)))
	var delta_yaw: float = wrapf(target_yaw - player.rotation_degrees.y, -180.0, 180.0)
	var tween: Tween = player.create_tween()
	if fade_rect != null:
		tween.tween_property(fade_rect, "color:a", ABOUT_FACE_FADE_ALPHA, ABOUT_FACE_FADE)
	tween.tween_property(player, "rotation_degrees:y", player.rotation_degrees.y + delta_yaw, turn_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if fade_rect != null:
		tween.tween_property(fade_rect, "color:a", 0.0, ABOUT_FACE_FADE)
	await tween.finished
	if fade_rect != null and is_instance_valid(fade_rect):
		fade_rect.get_parent().queue_free()

	if is_instance_valid(player):
		# Snap to the exact grid facing and sync the grid component / minimap.
		var here: Vector3 = player.call("_cell_to_world", party_cell) as Vector3
		player.teleport_to(here, here + Vector3(target_dir.x, 0.0, target_dir.y))
		player.set_movement_locked(false)


## Cardinal step that points from the party toward an offset (dominant axis for longer offsets).
static func _direction_to(offset: Vector2i) -> Vector2i:
	if offset == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(offset.x) >= absi(offset.y):
		return Vector2i(signi(offset.x), 0)
	return Vector2i(0, signi(offset.y))


static func _facing_dir(player: DungeonPlayer) -> Vector2i:
	var forward: Vector3 = -player.global_transform.basis.z
	return _direction_to(Vector2i(roundi(forward.x * 10.0), roundi(forward.z * 10.0)))


static func _first_open_dir(tree: SceneTree, cell: Vector2i, current_dir: Vector2i) -> Vector2i:
	# Prefer a quarter turn over an about-face.
	var order: Array[Vector2i] = [Vector2i(current_dir.y, -current_dir.x), Vector2i(-current_dir.y, current_dir.x), -current_dir]
	for dir: Vector2i in order:
		if dir != Vector2i.ZERO and not _is_cell_blocked(tree, cell + dir):
			return dir
	return Vector2i.ZERO


static func _is_cell_blocked(tree: SceneTree, cell: Vector2i) -> bool:
	var map_mgr: Node = tree.root.find_child("MapManager", true, false)
	if map_mgr == null or not map_mgr.has_method("is_tile_blocked"):
		return false
	return bool(map_mgr.call("is_tile_blocked", Vector3i(cell.x, 0, cell.y)))


static func _make_fade(owner_node: Node) -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 95
	owner_node.add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0.0, 0.0, 0.0, 0.0)
	layer.add_child(rect)
	return rect
