# res://Scripts/Managers/BattleSpaceClearance.gd
class_name BattleSpaceClearance
extends Node
## Temporarily moves trees / wall props / StaticBody clutter out of the party's battle view.
##
## Outdoor and cave fights happen in place (see BattleFacing). When trees or walls sit right
## in front of the camera the combat models clip into them. This helper:
##   1. Finds Node3D obstacles in a forward box ahead of the party
##   2. Shoves them sideways out of the view cone (keeps them in the world, easy to restore)
##   3. Clears leftover GridMap wall cells in that same box
##   4. Puts everything back on combat_ended
##
## Dungeon battle-room fights skip this (the room is already empty). Opt out per map with root
## metadata "use_battle_clearance" = false.
##
## Usage (after BattleFacing.orient_party, before combat_started):
##     BattleSpaceClearance.ensure_space(get_tree())

const NODE_NAME: String = "BattleSpaceClearance"
const MAP_META: StringName = &"use_battle_clearance"
## How far ahead of the party (meters) to clear.
const FORWARD_METERS: float = 8.0
## Half-width of the clear box (meters).
const SIDE_METERS: float = 4.0
## Vertical half-extent of the clear box (meters).
const HEIGHT_METERS: float = 6.0
## How far sideways to shove a node so it leaves the view cone.
const SHOVE_METERS: float = 10.0
## Names / path fragments that must never be moved (floor, player, HUD, combat).
const SKIP_NAME_FRAGMENTS: Array[String] = [
	"FloorMap", "Bridges", "Player", "EnemyVisual", "BattleHUD", "HUD", "Camera",
	"SpawnPoint", "DayNight", "Cloud", "Sun", "Moon", "DirectionalLight",
]

## Original global_position of each shoved Node3D.
var _moved_nodes: Dictionary = {} # Node3D -> Vector3
## Cleared GridMap cells: { "grid": GridMap, "cell": Vector3i, "item": int, "orient": int }
var _cleared_cells: Array[Dictionary] = []
var _is_active: bool = false


## Clears space in front of the party for an in-place battle. No-op for dungeon battle rooms.
static func ensure_space(tree: SceneTree) -> void:
	if tree == null:
		return
	var map_mgr: MapManager = tree.root.find_child("MapManager", true, false) as MapManager
	if map_mgr == null or not is_instance_valid(map_mgr.active_map_instance):
		return
	var map: Node3D = map_mgr.active_map_instance
	# Soft check (avoid class_name cycle with BattleArena): dungeon battle rooms are already empty.
	if map is DungeonLevel:
		return
	if map.has_meta(&"use_battle_room") and bool(map.get_meta(&"use_battle_room")):
		return
	if map.has_meta(MAP_META) and not bool(map.get_meta(MAP_META)):
		return

	var clearance: BattleSpaceClearance = map.get_node_or_null(NODE_NAME) as BattleSpaceClearance
	if clearance == null:
		clearance = BattleSpaceClearance.new()
		clearance.name = NODE_NAME
		map.add_child(clearance)

	var player: DungeonPlayer = tree.get_first_node_in_group(&"player") as DungeonPlayer
	if not is_instance_valid(player):
		return
	clearance.clear_in_front_of(player)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not SignalBus.combat_ended.is_connected(_on_combat_ended):
		SignalBus.combat_ended.connect(_on_combat_ended)


func _exit_tree() -> void:
	_restore_all()


## Shoves / clears obstacles in the box ahead of `player`'s current facing.
func clear_in_front_of(player: DungeonPlayer) -> void:
	_restore_all()
	if not is_instance_valid(player):
		return

	var origin: Vector3 = player.global_position
	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3(0.0, 0.0, -1.0)
	else:
		forward = forward.normalized()
	var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)

	var box_center: Vector3 = origin + forward * (FORWARD_METERS * 0.5) + Vector3(0.0, HEIGHT_METERS * 0.35, 0.0)
	var half_extents: Vector3 = Vector3(SIDE_METERS, HEIGHT_METERS * 0.5, FORWARD_METERS * 0.5)

	_shove_nodes_in_box(box_center, half_extents, forward, right)
	_clear_wall_grid_cells(origin, forward, right)

	_is_active = not _moved_nodes.is_empty() or not _cleared_cells.is_empty()
	if _is_active and is_instance_valid(GameLogger):
		GameLogger.combat(
			"BattleSpaceClearance moved %d props, cleared %d wall cells." % [
				_moved_nodes.size(), _cleared_cells.size()
			]
		)


func _shove_nodes_in_box(
	box_center: Vector3,
	half_extents: Vector3,
	forward: Vector3,
	right: Vector3
) -> void:
	var map: Node = get_parent()
	if not is_instance_valid(map):
		return

	var candidates: Array[Node3D] = []
	_collect_clearable_nodes(map, candidates)

	for node: Node3D in candidates:
		if not is_instance_valid(node) or _moved_nodes.has(node):
			continue
		if _should_skip_node(node):
			continue
		var local: Vector3 = _to_box_local(node.global_position, box_center, forward, right)
		if absf(local.x) > half_extents.x:
			continue
		if absf(local.y) > half_extents.y:
			continue
		if absf(local.z) > half_extents.z:
			continue

		var side_sign: float = 1.0 if local.x >= 0.0 else -1.0
		# Prefer the side the prop already leans toward so motion is shorter.
		var shove: Vector3 = right * (side_sign * SHOVE_METERS)
		_moved_nodes[node] = node.global_position
		node.global_position = node.global_position + shove


func _collect_clearable_nodes(root: Node, out: Array[Node3D]) -> void:
	# Forest wall replacers parent MultiMesh tree chunks under WallMap*.
	# BigTimbers / MarshTimber / barrels sit as sibling props with StaticBody3D.
	for child: Node in root.get_children():
		if child == self or child.name == "BattleArena" or child.name == NODE_NAME:
			continue
		if child is GridMap:
			for grid_child: Node in child.get_children():
				var as_3d: Node3D = grid_child as Node3D
				if is_instance_valid(as_3d):
					out.append(as_3d)
			continue
		if child.name == "BigTimbers" or child.name == "MarshTimbers" or child.name == "Props":
			for prop: Node in child.get_children():
				var prop_3d: Node3D = prop as Node3D
				if is_instance_valid(prop_3d):
					out.append(prop_3d)
			continue
		# Direct StaticBody3D / CharacterBody3D props under the map root.
		if child is StaticBody3D or child is AnimatableBody3D:
			var body_3d: Node3D = child as Node3D
			if is_instance_valid(body_3d):
				out.append(body_3d)


func _clear_wall_grid_cells(origin: Vector3, forward: Vector3, right: Vector3) -> void:
	var map: Node = get_parent()
	if not is_instance_valid(map):
		return

	var wall_maps: Array[GridMap] = []
	for child: Node in map.get_children():
		if child is GridMap and str(child.name).begins_with("WallMap"):
			wall_maps.append(child as GridMap)

	# Sample a coarse grid of world points in the clear box and clear any wall cell hit.
	var step: float = 2.0
	var z: float = 0.5
	while z <= FORWARD_METERS:
		var x: float = -SIDE_METERS
		while x <= SIDE_METERS:
			var world: Vector3 = origin + forward * z + right * x
			for grid: GridMap in wall_maps:
				if not is_instance_valid(grid):
					continue
				var cell: Vector3i = grid.local_to_map(grid.to_local(world))
				cell.y = 0
				var item: int = grid.get_cell_item(cell)
				if item == GridMap.INVALID_CELL_ITEM:
					continue
				var already: bool = false
				for entry: Dictionary in _cleared_cells:
					if entry.get("grid") == grid and entry.get("cell") == cell:
						already = true
						break
				if already:
					continue
				_cleared_cells.append({
					"grid": grid,
					"cell": cell,
					"item": item,
					"orient": grid.get_cell_item_orientation(cell),
				})
				grid.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)
			x += step
		z += step


func _to_box_local(world: Vector3, center: Vector3, forward: Vector3, right: Vector3) -> Vector3:
	var delta: Vector3 = world - center
	return Vector3(delta.dot(right), delta.y, delta.dot(forward))


func _should_skip_node(node: Node) -> bool:
	if node.is_in_group(&"player") or node.is_in_group(&"world_enemies") or node.is_in_group(&"enemies"):
		return true
	var path_str: String = str(node.get_path())
	for frag: String in SKIP_NAME_FRAGMENTS:
		if frag in path_str or frag in node.name:
			return true
	# Don't shove the combat models EnemyVisualManager just spawned.
	var parent_n: Node = node.get_parent()
	if is_instance_valid(parent_n) and parent_n.name == "EnemyVisualManager":
		return true
	return false


func _on_combat_ended(_victory: bool) -> void:
	_restore_all()


func _restore_all() -> void:
	for node_v: Variant in _moved_nodes.keys():
		var node: Node3D = node_v as Node3D
		if is_instance_valid(node):
			node.global_position = _moved_nodes[node] as Vector3
	_moved_nodes.clear()

	for entry: Dictionary in _cleared_cells:
		var grid: GridMap = entry.get("grid") as GridMap
		if not is_instance_valid(grid):
			continue
		var cell: Vector3i = entry.get("cell") as Vector3i
		var item: int = int(entry.get("item", GridMap.INVALID_CELL_ITEM))
		var orient: int = int(entry.get("orient", 0))
		grid.set_cell_item(cell, item, orient)
	_cleared_cells.clear()
	_is_active = false
