# res://Scripts/Managers/BattleArena.gd
class_name BattleArena
extends Node3D
## "Battle mode": fights in a dungeon or a cave happen in a big open room instead of the corridor.
##
## Corridors and tunnels are too tight to know whether a whole enemy pack fits in front of the party.
## So before the battle the screen fades to black, the party's VIEW is moved into the battle room
## (dungeons: Scenes/Dungeons/DungeonBattle.tscn, caves: Scenes/Caves/CaveBattle.tscn), and when
## the battle ends it jumps straight back.
##
## The party never leaves its grid cell: only the Player node's transform moves
## (DungeonPlayer.enter_battle_view / leave_battle_view). Saves, the encounter logic and the
## enemies left in the dungeon all still see the party on the cell where the fight started.
##
## Fights that start inside a BossChamber stay there - that room is big enough. A boss met
## anywhere else is moved to the battle room like any other enemy.
##
## Which maps use it: any map whose root is a DungeonLevel or a CaveLevel. Override per map with
## the root metadata "use_battle_room" (true / false). A map can also name its own room scene
## with the root metadata "battle_room_scene" (a res:// path).
##
## Usage (before emitting combat_started, instead of BattleFacing.orient_party):
##     await BattleArena.prepare_party(get_tree(), global_position)
##
## The room is added once per map as a hidden child called "BattleArena", far away from the level.
## Edit the room itself in DungeonBattle.tscn / CaveBattle.tscn: the party stands on its
## "SpawnPoint" marker and looks along the marker's -Z.

const ROOM_SCENE_PATH: String = "res://Scenes/Dungeons/DungeonBattle.tscn"
const CAVE_ROOM_SCENE_PATH: String = "res://Scenes/Caves/CaveBattle.tscn"
const NODE_NAME: String = "BattleArena"
## Where the room sits relative to the level (far outside any generated dungeon).
const ROOM_OFFSET: Vector3 = Vector3(2000.0, 0.0, 2000.0)
const MAP_META: StringName = &"use_battle_room"
## Optional root metadata: res:// path of the room scene this map fights in.
const ROOM_SCENE_META: StringName = &"battle_room_scene"
const FADE_OUT_SECONDS: float = 0.25
const FADE_IN_SECONDS: float = 0.35

var _room: Node3D = null
var _fade_rect: ColorRect = null
var _fade_tween: Tween = null
var _party_is_here: bool = false


## Gets the party ready for a battle against the enemy at `enemy_world_pos`.
## Dungeon / cave: fade to black and move the view to the battle room.
## Everywhere else (and inside a boss chamber): turn the party to face the enemy,
## then shove nearby trees/walls aside so combat models have room (BattleSpaceClearance).
static func prepare_party(tree: SceneTree, enemy_world_pos: Vector3) -> void:
	if tree == null:
		return
	var player: DungeonPlayer = tree.get_first_node_in_group(&"player") as DungeonPlayer
	if is_instance_valid(player):
		var arena: BattleArena = _find_or_create(tree)
		if arena != null and not arena.is_party_in_boss_chamber(player):
			await arena.enter(player)
			return
	await BattleFacing.orient_party(tree, enemy_world_pos)
	BattleSpaceClearance.ensure_space(tree)


## True when this map sends its fights to the battle room.
static func map_uses_battle_room(map: Node) -> bool:
	if not is_instance_valid(map):
		return false
	if map.has_meta(MAP_META):
		return bool(map.get_meta(MAP_META))
	return map is DungeonLevel or map is CaveLevel


## The room scene this map fights in: its own "battle_room_scene" metadata, else the cave room
## for cave levels, else the dungeon room.
static func room_scene_path_for(map: Node) -> String:
	if is_instance_valid(map) and map.has_meta(ROOM_SCENE_META):
		var custom: String = str(map.get_meta(ROOM_SCENE_META))
		if not custom.is_empty():
			return custom
	if map is CaveLevel:
		return CAVE_ROOM_SCENE_PATH
	return ROOM_SCENE_PATH


static func _find_or_create(tree: SceneTree) -> BattleArena:
	var map_mgr: MapManager = tree.root.find_child("MapManager", true, false) as MapManager
	if map_mgr == null:
		return null
	var map: Node3D = map_mgr.active_map_instance
	if not map_uses_battle_room(map):
		return null
	var existing: BattleArena = map.get_node_or_null(NODE_NAME) as BattleArena
	if existing != null:
		return existing

	var room_path: String = room_scene_path_for(map)
	var packed: PackedScene = load(room_path) as PackedScene if ResourceLoader.exists(room_path) else null
	if packed == null:
		push_warning("BattleArena: %s is missing - fighting in place." % room_path)
		return null
	var room: Node3D = packed.instantiate() as Node3D
	if room == null:
		return null
	room.visible = false

	var arena := BattleArena.new()
	arena.name = NODE_NAME
	arena.position = ROOM_OFFSET
	arena._room = room
	arena.add_child(room)
	map.add_child(arena)
	return arena


func _ready() -> void:
	# The victory screen may pause the game while the view is still fading back in.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not SignalBus.combat_ended.is_connected(_on_combat_ended):
		SignalBus.combat_ended.connect(_on_combat_ended)


func _exit_tree() -> void:
	# Map unloaded mid-fight: never leave the player stuck off the grid.
	if not _party_is_here:
		return
	_party_is_here = false
	var player: DungeonPlayer = get_tree().get_first_node_in_group(&"player") as DungeonPlayer
	if is_instance_valid(player):
		player.battle_position_override = false


## Fades out, moves the party's view into the room and starts fading back in.
## Returns as soon as the party is in place, so the battle opens while the screen fades in.
func enter(player: DungeonPlayer) -> void:
	if _party_is_here or not is_instance_valid(_room):
		return
	var was_locked: bool = player.is_movement_locked
	player.set_movement_locked(true)
	if is_instance_valid(GameState) and GameState.has_method("lock_encounters"):
		GameState.lock_encounters(2.0) # nobody else may start a fight during the fade
	if is_instance_valid(GameLogger):
		GameLogger.combat("Moving the fight to the battle room (%s)." % _room.name)

	await _fade(1.0, FADE_OUT_SECONDS).finished

	# Let a step or turn that was in progress finish, so its tween can't drag the party back.
	var waited: float = 0.0
	while is_instance_valid(player) and _is_player_moving(player) and waited < 1.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not is_instance_valid(player):
		return

	var stand_pos: Vector3 = _room.global_position
	var yaw: float = 0.0
	var spot: Node3D = _room.get_node_or_null("SpawnPoint") as Node3D
	if spot != null:
		stand_pos = Vector3(spot.global_position.x, _room.global_position.y, spot.global_position.z)
		yaw = spot.global_rotation.y

	_room.visible = true
	_party_is_here = true
	player.enter_battle_view(stand_pos, yaw)
	player.set_movement_locked(was_locked)
	_fade(0.0, FADE_IN_SECONDS)


## Jumps the view back to the party's real cell (cut to black, then fade in).
func leave() -> void:
	if not _party_is_here:
		return
	_party_is_here = false
	_fade(1.0, 0.0)
	_fade_rect.color.a = 1.0
	var player: DungeonPlayer = get_tree().get_first_node_in_group(&"player") as DungeonPlayer
	if is_instance_valid(player):
		player.leave_battle_view()
	if is_instance_valid(_room):
		_room.visible = false
	_fade(0.0, FADE_IN_SECONDS)


## True when the party stands on a BossChamber's floor (BossFloor GridMap).
func is_party_in_boss_chamber(player: DungeonPlayer) -> bool:
	var map: Node = get_parent()
	return map != null and _has_chamber_at(map, player.global_position, 3)


func _on_combat_ended(_victory: bool) -> void:
	leave()


func _has_chamber_at(node: Node, world_pos: Vector3, depth: int) -> bool:
	if node is BossChamber:
		return _chamber_contains(node as BossChamber, world_pos)
	if depth <= 0 or node == self:
		return false
	for child: Node in node.get_children():
		if _has_chamber_at(child, world_pos, depth - 1):
			return true
	return false


func _chamber_contains(chamber: BossChamber, world_pos: Vector3) -> bool:
	var floor_grid: GridMap = chamber.get_node_or_null("BossFloor") as GridMap
	if floor_grid == null:
		return false
	var cell: Vector3i = floor_grid.local_to_map(floor_grid.to_local(world_pos))
	return floor_grid.get_cell_item(Vector3i(cell.x, 0, cell.z)) != GridMap.INVALID_CELL_ITEM


func _is_player_moving(player: DungeonPlayer) -> bool:
	if player.is_moving:
		return true
	var mover: Node = player.get_node_or_null("%GridMovementComponent")
	return mover != null and bool(mover.get("is_moving"))


func _fade(alpha: float, seconds: float) -> Tween:
	if not is_instance_valid(_fade_rect):
		var layer := CanvasLayer.new()
		layer.layer = 95 # over the HUD, under popups (the victory screen is 100)
		add_child(layer)
		_fade_rect = ColorRect.new()
		_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
		layer.add_child(_fade_rect)
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "color:a", alpha, maxf(0.01, seconds))
	return _fade_tween
