class_name DungeonGenerator
extends RefCounted
## Layout logic for room-based dungeon levels (used by GenerateDungeonLevel.gd).
## Port of the Python reference used to build DungeonLevel1.
##
## Grid conventions
##  * 4 m modules. Module (i, j) centre = world (4i + 3, 0, 4j + 3): always a 2 m movement-cell centre.
##  * Room scenes (DungeonRoom) have their origin on a module centre and are rotated 0/90/180/270.
##  * Directions: N = (0, -1), E = (1, 0), S = (0, 1), W = (-1, 0) on (x, z).
##  * Rotating by +90 turns S -> E (same as Basis(Vector3.UP, deg_to_rad(90))).

const MODULE: float = 4.0
const LETTERS: String = "NESW"
const DIR_VECTORS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const ANGLES: Array[int] = [0, 90, 180, 270]
const STRUCTURE_NODES: Array[String] = ["RoomModel", "Walls", "Doors", "Caps"]

## Corridor model files (resources/tile_sets/dungeon) and their openings in default orientation.
const PIECE_FILES: Array[String] = ["corridor-end", "corridor", "corridor-corner-square", "corridor-junction", "corridor-intersection"]
const PIECE_OPENINGS: Array[String] = ["E", "EW", "NW", "NWE", "NESW"]
## Prop scenes that block the 2 m cell they stand in (barrels/columns/bones/stones have collision,
## chests block as interactables). Used to check every room stays reachable.
const BLOCKING_PROP_SCENES: Array[String] = ["Barrel.tscn", "Column.tscn", "Bones.tscn", "Stones.tscn", "chest.tscn", "HypeChest.tscn"]


## A doorway of a room scene, in the room's own (unrotated) space.
class DoorInfo extends RefCounted:
	var letter: String = "N"
	var bit: int = 1
	var dir: Vector2i = Vector2i(0, -1)
	var out_module: Vector2i = Vector2i.ZERO # module just outside the doorway
	var cell: Vector2 = Vector2.ZERO # doorway cell centre (metres)


## A collision box of a room (axis aligned, room space). cap_letter != "" for door caps.
class BoxInfo extends RefCounted:
	var center: Vector2 = Vector2.ZERO
	var half: Vector2 = Vector2.ZERO
	var cap_letter: String = ""


## Everything the generator needs to know about one room scene.
class RoomTemplate extends RefCounted:
	var scene_path: String = ""
	var scene: PackedScene = null
	var modules: Array[Vector2i] = []
	var doors: Array[DoorInfo] = []
	var boxes: Array[BoxInfo] = []
	var prop_cells: Array[Vector2] = [] # positions of props that block their cell (room space, metres)
	var prop_paths: Array[String] = [] # node path of each prop (to skip removed ones)
	var dressing: Array[String] = [] # removable node paths
	var dressing_chance: Array[float] = [] # survival chance of each
	var decor_chance: float = 0.6
	var torch_chance: float = 1.0
	var is_boss: bool = false


## One placed room.
class Placement extends RefCounted:
	var template: RoomTemplate = null
	var origin: Vector2i = Vector2i.ZERO
	var deg: int = 0
	var used: int = 0 # door bits that are connected
	var depth: int = 0
	var index: int = 0
	var removed: PackedStringArray = PackedStringArray()


## An open doorway (or the entrance) waiting for something to be attached.
class Frontier extends RefCounted:
	var out_module: Vector2i = Vector2i.ZERO
	var dir: Vector2i = Vector2i.ZERO
	var depth: int = 0
	var owner: int = -1 # room index, -1 = entrance
	var bit: int = 0


class Attachment extends RefCounted:
	var path_modules: Array[Vector2i] = []
	var path_openings: Array[String] = []
	var door: DoorInfo = null
	var deg: int = 0
	var origin: Vector2i = Vector2i.ZERO
	var modules: Array[Vector2i] = []


## The finished layout.
class Layout extends RefCounted:
	var seed_used: int = 0
	var occupied: Dictionary[Vector2i, int] = {} # module -> room index, -1 corridor, -2 entrance
	var corridors: Dictionary[Vector2i, String] = {} # module -> opening letters
	var rooms: Array[Placement] = []
	var entry_module: Vector2i = Vector2i.ZERO
	var spawn_cell: Vector2i = Vector2i.ZERO # world metres (odd numbers)
	var stairs_cell: Vector2i = Vector2i.ZERO
	var blocked_cells: Dictionary[Vector2i, bool] = {} # corridor walls (world metres)
	var walkable: Dictionary[Vector2i, bool] = {} # cells the party can stand in (ignores enemies)
	var reachable: Dictionary[Vector2i, bool] = {}
	var enemies: Array[Vector2i] = []
	var has_exit: bool = false # floors without a boss end in a dead-end corridor with the way down
	var exit_module: Vector2i = Vector2i.ZERO
	var exit_dir: Vector2i = Vector2i.ZERO # direction the dead end points (away from the level)


# ==============================================================================
# Templates
# ==============================================================================

## Reads a room scene: doors (Doors/Door_X markers), collision boxes (Walls + Caps), footprint
## modules (wall boxes, plus GridMap tiles for hand-built rooms) and removable dressing.
static func load_template(scene_path: String, is_boss: bool) -> RoomTemplate:
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		push_error("DungeonGenerator: cannot load %s" % scene_path)
		return null
	var root: Node3D = scene.instantiate() as Node3D
	var t := RoomTemplate.new()
	t.scene_path = scene_path
	t.scene = scene
	t.is_boss = is_boss
	t.decor_chance = _float_or(root.get("decor_chance"), 0.6)
	t.torch_chance = _float_or(root.get("torch_chance"), 1.0)

	# Doors
	var doors_node: Node = root.get_node_or_null("Doors")
	if doors_node != null:
		for child: Node in doors_node.get_children():
			var marker: Node3D = child as Node3D
			if marker == null or not String(marker.name).begins_with("Door_"):
				continue
			var xf: Transform3D = _local_xform(marker, root)
			var fwd: Vector3 = -xf.basis.z
			var door := DoorInfo.new()
			door.letter = String(marker.name).substr(5, 1)
			door.bit = 1 << LETTERS.find(door.letter)
			door.dir = Vector2i(roundi(fwd.x), roundi(fwd.z))
			door.cell = Vector2(xf.origin.x, xf.origin.z)
			door.out_module = Vector2i(roundi((xf.origin.x + 2.0 * door.dir.x) / MODULE), roundi((xf.origin.z + 2.0 * door.dir.y) / MODULE))
			t.doors.append(door)

	# Collision boxes
	for group_name: String in ["Walls", "Caps"]:
		var group_node: Node = root.get_node_or_null(group_name)
		if group_node != null:
			_collect_boxes(group_node, group_node, root, t, group_name == "Caps")

	# Footprint
	var mods: Dictionary[Vector2i, bool] = {}
	for box: BoxInfo in t.boxes:
		if box.cap_letter != "":
			continue
		for i: int in range(floori((box.center.x - box.half.x) / MODULE + 0.5), floori((box.center.x + box.half.x) / MODULE + 0.5) + 1):
			for j: int in range(floori((box.center.y - box.half.y) / MODULE + 0.5), floori((box.center.y + box.half.y) / MODULE + 0.5) + 1):
				var ox: float = minf(box.center.x + box.half.x, i * MODULE + 2.0) - maxf(box.center.x - box.half.x, i * MODULE - 2.0)
				var oz: float = minf(box.center.y + box.half.y, j * MODULE + 2.0) - maxf(box.center.y - box.half.y, j * MODULE - 2.0)
				if ox > 1.05 and oz > 1.05: # edge boxes poke 1 m past the room - not the next module
					mods[Vector2i(i, j)] = true
	var has_gridmap: bool = false
	for child: Node in root.get_children():
		var gm: GridMap = child as GridMap
		if gm == null:
			continue
		has_gridmap = true
		for cell: Vector3i in gm.get_used_cells():
			var p: Vector3 = gm.transform * gm.map_to_local(cell)
			mods[Vector2i(roundi(p.x / MODULE), roundi(p.z / MODULE))] = true
	if has_gridmap:
		for m: Vector2i in mods:
			t.modules.append(m)
	elif not mods.is_empty():
		var lo := Vector2i(1 << 20, 1 << 20)
		var hi := Vector2i(-(1 << 20), -(1 << 20))
		for m: Vector2i in mods:
			lo = Vector2i(mini(lo.x, m.x), mini(lo.y, m.y))
			hi = Vector2i(maxi(hi.x, m.x), maxi(hi.y, m.y))
		for i: int in range(lo.x, hi.x + 1):
			for j: int in range(lo.y, hi.y + 1):
				t.modules.append(Vector2i(i, j))

	# Dressing (same rules as DungeonRoom.find_dressing / roll_removed_nodes)
	for node: Node in DungeonRoom.find_dressing(root):
		var default_chance: float = t.torch_chance if DungeonRoom.is_torch(node) else t.decor_chance
		t.dressing.append(String(root.get_path_to(node)))
		t.dressing_chance.append(_float_or(node.get_meta("spawn_chance", default_chance), default_chance))

	# Props that block their cell
	_collect_props(root, root, t)
	root.free()

	if t.modules.is_empty():
		push_error("DungeonGenerator: %s has no Walls collision or GridMap tiles - can't work out its size." % scene_path)
		return null
	if t.doors.is_empty():
		push_error("DungeonGenerator: %s has no Doors/Door_X markers." % scene_path)
		return null
	return t


## `group` is the Walls/Caps node; for caps the box belongs to the Cap_X child of `group` it sits under.
static func _collect_boxes(node: Node, group: Node, root: Node, t: RoomTemplate, is_cap: bool) -> void:
	for child: Node in node.get_children():
		var cs: CollisionShape3D = child as CollisionShape3D
		if cs != null and cs.shape is BoxShape3D:
			var xf: Transform3D = _local_xform(cs, root)
			var size: Vector3 = (cs.shape as BoxShape3D).size * 0.5
			var b := BoxInfo.new()
			b.center = Vector2(xf.origin.x, xf.origin.z)
			var ax: Vector3 = xf.basis.x.abs() * size.x + xf.basis.y.abs() * size.y + xf.basis.z.abs() * size.z
			b.half = Vector2(ax.x, ax.z)
			if is_cap:
				var cap_node: Node = cs
				while cap_node != null and cap_node.get_parent() != group:
					cap_node = cap_node.get_parent()
				var cap_name: String = String(cap_node.name) if cap_node != null else String(child.name)
				b.cap_letter = cap_name.right(1) if cap_name.begins_with("Cap_") else "?"
			t.boxes.append(b)
		_collect_boxes(child, group, root, t, is_cap)


static func _collect_props(node: Node, root: Node, t: RoomTemplate) -> void:
	for child: Node in node.get_children():
		if node == root and STRUCTURE_NODES.has(String(child.name)):
			continue
		var c3: Node3D = child as Node3D
		if c3 != null and BLOCKING_PROP_SCENES.has(child.scene_file_path.get_file()):
			var xf: Transform3D = _local_xform(c3, root)
			t.prop_cells.append(Vector2(xf.origin.x, xf.origin.z))
			t.prop_paths.append(String(root.get_path_to(child)))
			continue
		_collect_props(child, root, t)


# ==============================================================================
# Layout
# ==============================================================================

## Tries up to `max_attempts` seeds derived from `seed_value`. Returns null if nothing fits.
## `boss` = null builds an upper floor: it ends in a dead-end corridor (exit_module) for the way down.
static func generate(seed_value: int, room_count: int, room_templates: Array[RoomTemplate], room_weights: Array[int], boss: RoomTemplate, enemy_count: int, max_attempts: int = 40) -> Layout:
	for attempt: int in range(max_attempts):
		var layout: Layout = _try(seed_value * 1000 + attempt, room_count, room_templates, room_weights, boss)
		if layout != null:
			layout.seed_used = seed_value * 1000 + attempt
			_finish(layout, enemy_count)
			return layout
	push_error("DungeonGenerator: no layout fitted after %d attempts - try fewer rooms or another seed." % max_attempts)
	return null


static func _try(seed_value: int, room_count: int, room_templates: Array[RoomTemplate], room_weights: Array[int], boss: RoomTemplate) -> Layout:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var lv := Layout.new()
	var frontier: Array[Frontier] = []

	lv.entry_module = Vector2i.ZERO
	lv.occupied[lv.entry_module] = -2
	lv.corridors[lv.entry_module] = "E"
	var first := Frontier.new()
	first.out_module = Vector2i(1, 0)
	first.dir = Vector2i(1, 0)
	frontier.append(first)

	var stalls: int = 0
	while lv.rooms.size() < room_count and not frontier.is_empty() and stalls < 200:
		var i: int = rng.randi_range(0, frontier.size() - 1)
		var src: Frontier = frontier[i]
		var lengths: Array[int] = [1, 2, 2, 3] # the entrance needs a corridor
		if src.owner >= 0:
			lengths = [0, 1, 1, 2, 2, 3, 3]
		_shuffle_int(lengths, rng)
		var t: RoomTemplate = room_templates[_weighted_pick(room_weights, rng)]
		var att: Attachment = _attach(lv, src, t, rng, lengths)
		if att == null:
			stalls += 1
			if stalls % 4 == 0:
				frontier.remove_at(i) # hopeless doorway - stays capped
			continue
		frontier.remove_at(i)
		_place(lv, frontier, src, t, att)
	if lv.rooms.size() < room_count:
		return null

	# Boss chamber (or the way down) off the deepest open doorway.
	var order: Array[int] = []
	for k: int in range(frontier.size()):
		order.append(k)
	order.sort_custom(func(a: int, b: int) -> bool: return frontier[a].depth > frontier[b].depth)
	if boss == null:
		for k: int in order:
			if _add_exit(lv, frontier[k]):
				frontier.remove_at(k)
				for room: Placement in lv.rooms:
					room.removed = _roll_dressing(room.template, rng)
				return lv
		return null
	var boss_lengths: Array[int] = [2, 3, 1, 4, 5]
	for k: int in order:
		var src: Frontier = frontier[k]
		var att: Attachment = _attach(lv, src, boss, rng, boss_lengths)
		if att != null:
			frontier.remove_at(k)
			_place(lv, frontier, src, boss, att)
			# dressing rolls (after layout, deterministic)
			for room: Placement in lv.rooms:
				room.removed = _roll_dressing(room.template, rng)
			return lv
	return null


## Straight dead-end corridor from an open doorway; the last module holds the way down.
static func _add_exit(lv: Layout, src: Frontier) -> bool:
	for corridor_len: int in [2, 3, 1, 4]:
		var path: Array[Vector2i] = []
		for k: int in range(corridor_len):
			path.append(src.out_module + src.dir * k)
		if not _all_free(lv, path):
			continue
		for k: int in range(path.size()):
			lv.occupied[path[k]] = -1
			lv.corridors[path[k]] = _letter(-src.dir) if k == path.size() - 1 else _letter(src.dir) + _letter(-src.dir)
		if src.owner >= 0:
			lv.rooms[src.owner].used |= src.bit
		lv.has_exit = true
		lv.exit_module = path[path.size() - 1]
		lv.exit_dir = src.dir
		return true
	return false


static func _attach(lv: Layout, src: Frontier, t: RoomTemplate, rng: RandomNumberGenerator, lengths: Array[int]) -> Attachment:
	for corridor_len: int in lengths:
		var turns: Array[String] = [""]
		if corridor_len >= 2:
			if rng.randf() < 0.5:
				turns = ["", "L", "R"]
			else:
				turns = ["L", "R", ""]
		for turn: String in turns:
			var path_modules: Array[Vector2i] = []
			var path_openings: Array[String] = []
			var d: Vector2i = src.dir
			var end_dir: Vector2i = d
			var target: Vector2i
			if turn == "":
				for k: int in range(corridor_len):
					path_modules.append(src.out_module + d * k)
					path_openings.append(_letter(d) + _letter(-d))
				target = src.out_module + d * (corridor_len - 1)
			else:
				var k1: int = rng.randi_range(0, corridor_len - 2)
				var d2: Vector2i = rot(d, 90 if turn == "L" else 270)
				for k: int in range(k1):
					path_modules.append(src.out_module + d * k)
					path_openings.append(_letter(d) + _letter(-d))
				var corner: Vector2i = src.out_module + d * k1
				path_modules.append(corner)
				path_openings.append(_letter(-d) + _letter(d2))
				for k: int in range(corridor_len - k1 - 1):
					path_modules.append(corner + d2 * (k + 1))
					path_openings.append(_letter(d2) + _letter(-d2))
				end_dir = d2
				target = path_modules[path_modules.size() - 1]
			if corridor_len == 0:
				target = src.out_module - d
			if not _all_free(lv, path_modules):
				continue
			var options: Array[Attachment] = []
			for door: DoorInfo in t.doors:
				for deg: int in ANGLES:
					if rot(door.dir, deg) != -end_dir:
						continue
					var origin: Vector2i = target - rot(door.out_module, deg)
					var mods: Array[Vector2i] = []
					for m: Vector2i in t.modules:
						mods.append(origin + rot(m, deg))
					if not _all_free(lv, mods):
						continue
					var overlap: bool = false
					for m: Vector2i in mods:
						if path_modules.has(m):
							overlap = true
							break
					if overlap:
						continue
					var opt := Attachment.new()
					opt.path_modules = path_modules
					opt.path_openings = path_openings
					opt.door = door
					opt.deg = deg
					opt.origin = origin
					opt.modules = mods
					options.append(opt)
			if not options.is_empty():
				return options[rng.randi_range(0, options.size() - 1)]
	return null


static func _place(lv: Layout, frontier: Array[Frontier], src: Frontier, t: RoomTemplate, att: Attachment) -> void:
	for k: int in range(att.path_modules.size()):
		lv.occupied[att.path_modules[k]] = -1
		lv.corridors[att.path_modules[k]] = att.path_openings[k]
	var p := Placement.new()
	p.template = t
	p.origin = att.origin
	p.deg = att.deg
	p.used = att.door.bit
	p.depth = src.depth + 1
	p.index = lv.rooms.size()
	for m: Vector2i in att.modules:
		lv.occupied[m] = p.index
	lv.rooms.append(p)
	if src.owner >= 0:
		lv.rooms[src.owner].used |= src.bit
	for door: DoorInfo in t.doors:
		if door == att.door:
			continue
		var f := Frontier.new()
		f.out_module = att.origin + rot(door.out_module, att.deg)
		f.dir = rot(door.dir, att.deg)
		f.depth = src.depth + 1
		f.owner = p.index
		f.bit = door.bit
		frontier.append(f)


static func _roll_dressing(t: RoomTemplate, rng: RandomNumberGenerator) -> PackedStringArray:
	var removed := PackedStringArray()
	for k: int in range(t.dressing.size()):
		if rng.randf() >= t.dressing_chance[k]:
			removed.append(t.dressing[k])
	return removed


# ==============================================================================
# Movement model: corridor-wall blockers, reachability and enemy spots
# ==============================================================================

static func _finish(lv: Layout, enemy_count: int) -> void:
	var c: Vector2i = module_center(lv.entry_module)
	lv.stairs_cell = c
	lv.spawn_cell = c + Vector2i(2, 0)
	# corridor walls on the 2 m grid: module corners + every closed side
	for m: Vector2i in lv.corridors:
		var mc: Vector2i = module_center(m)
		var open: String = lv.corridors[m]
		for dx: int in [-2, 0, 2]:
			for dz: int in [-2, 0, 2]:
				if dx == 0 and dz == 0:
					continue
				if dx != 0 and dz != 0:
					lv.blocked_cells[mc + Vector2i(dx, dz)] = true
				elif not open.contains(_letter(Vector2i(signi(dx), signi(dz)))):
					lv.blocked_cells[mc + Vector2i(dx, dz)] = true
	lv.walkable = _walkable(lv)
	var none: Dictionary[Vector2i, bool] = {}
	lv.reachable = _flood(lv, none)
	_place_enemies(lv, enemy_count)


## Every 2 m cell inside the level the party can stand in: same test as the player's 1.6 m box
## query against room collision, corridor blockers and props.
static func _walkable(lv: Layout) -> Dictionary[Vector2i, bool]:
	var boxes: Array[Rect2] = []
	var props: Dictionary[Vector2i, bool] = {}
	for room: Placement in lv.rooms:
		var oc := Vector2(module_center(room.origin))
		for b: BoxInfo in room.template.boxes:
			if b.cap_letter != "" and b.cap_letter != "?" and (room.used & (1 << LETTERS.find(b.cap_letter))) != 0:
				continue # this doorway is open, its cap is removed at runtime
			var h: Vector2 = b.half if room.deg % 180 == 0 else Vector2(b.half.y, b.half.x)
			boxes.append(Rect2(oc + rotf(b.center, room.deg) - h, h * 2.0))
		for k: int in range(room.template.prop_cells.size()):
			if not _is_removed(room.removed, room.template.prop_paths[k]):
				props[cell_of(oc + rotf(room.template.prop_cells[k], room.deg))] = true
	var cells: Dictionary[Vector2i, bool] = {}
	for m: Vector2i in lv.occupied:
		var mc: Vector2i = module_center(m)
		for dx: int in [-2, 0, 2]:
			for dz: int in [-2, 0, 2]:
				var c: Vector2i = mc + Vector2i(dx, dz)
				if lv.blocked_cells.has(c) or props.has(c) or c == lv.stairs_cell:
					continue
				var hit: bool = false
				for r: Rect2 in boxes:
					var rc: Vector2 = r.get_center()
					if absf(rc.x - c.x) < r.size.x * 0.5 + 0.8 and absf(rc.y - c.y) < r.size.y * 0.5 + 0.8:
						hit = true
						break
				if not hit:
					cells[c] = true
	return cells


## Cells reachable from the spawn without walking through `extra_blocked`.
static func _flood(lv: Layout, extra_blocked: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, bool]:
	var seen: Dictionary[Vector2i, bool] = {}
	seen[lv.spawn_cell] = true
	var queue: Array[Vector2i] = [lv.spawn_cell]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for step: Vector2i in DIR_VECTORS:
			var n: Vector2i = cur + step * 2
			if seen.has(n) or not lv.walkable.has(n) or extra_blocked.has(n):
				continue
			seen[n] = true
			queue.append(n)
	return seen


static func _is_removed(removed: PackedStringArray, path: String) -> bool:
	for r: String in removed:
		if path == r or path.begins_with(r + "/"):
			return true
	return false


static func _place_enemies(lv: Layout, enemy_count: int) -> void:
	if enemy_count <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = lv.seed_used + 77
	var door_cells: Array[Vector2i] = []
	for room: Placement in lv.rooms:
		for door: DoorInfo in room.template.doors:
			door_cells.append(cell_of(Vector2(module_center(room.origin)) + rotf(door.cell, room.deg)))
	var candidates: Array[Vector3i] = [] # (x, z, room index)
	for room: Placement in lv.rooms:
		if room.template.is_boss:
			continue
		for m: Vector2i in room.template.modules:
			var mc: Vector2i = module_center(room.origin + rot(m, room.deg))
			for dx: int in [-2, 0, 2]:
				for dz: int in [-2, 0, 2]:
					var c: Vector2i = mc + Vector2i(dx, dz)
					if not lv.reachable.has(c) or _manhattan(c, lv.spawn_cell) <= 12:
						continue
					var near_door: bool = false
					for d: Vector2i in door_cells:
						if _manhattan(c, d) <= 2:
							near_door = true
							break
					if not near_door:
						candidates.append(Vector3i(c.x, c.y, room.index))
	candidates.sort()
	for i: int in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector3i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var per_room: Dictionary[int, int] = {}
	var taken: Dictionary[Vector2i, bool] = {}
	for cand: Vector3i in candidates:
		if lv.enemies.size() >= enemy_count:
			break
		var c := Vector2i(cand.x, cand.y)
		if int(per_room.get(cand.z, 0)) >= 2 or taken.has(c):
			continue
		var spaced: bool = true
		for e: Vector2i in lv.enemies:
			if _manhattan(c, e) < 6:
				spaced = false
				break
		if not spaced:
			continue
		# everything must stay reachable with this enemy standing here
		var test: Dictionary[Vector2i, bool] = {}
		for e: Vector2i in taken:
			test[e] = true
		test[c] = true
		if _flood(lv, test).size() < lv.reachable.size() - test.size():
			continue
		taken[c] = true
		lv.enemies.append(c)
		per_room[cand.z] = int(per_room.get(cand.z, 0)) + 1


# ==============================================================================
# Helpers
# ==============================================================================

static func module_center(m: Vector2i) -> Vector2i:
	return Vector2i(4 * m.x + 3, 4 * m.y + 3)


## 2 m movement cell (odd world coordinates) containing a point.
static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(2 * floori((p.x - 1.0) / 2.0 + 0.5) + 1, 2 * floori((p.y - 1.0) / 2.0 + 0.5) + 1)


static func rot(v: Vector2i, deg: int) -> Vector2i:
	match posmod(deg, 360):
		90:
			return Vector2i(v.y, -v.x)
		180:
			return Vector2i(-v.x, -v.y)
		270:
			return Vector2i(-v.y, v.x)
	return v


static func rotf(v: Vector2, deg: int) -> Vector2:
	match posmod(deg, 360):
		90:
			return Vector2(v.y, -v.x)
		180:
			return Vector2(-v.x, -v.y)
		270:
			return Vector2(-v.y, v.x)
	return v


## Corridor model + Y rotation whose openings match `openings` (letters, any order).
static func piece_for(openings: String) -> Vector2i: # (piece index, degrees)
	for p: int in range(PIECE_FILES.size()):
		if PIECE_OPENINGS[p].length() != openings.length():
			continue
		for deg: int in ANGLES:
			var ok: bool = true
			for ch: String in PIECE_OPENINGS[p]:
				if not openings.contains(_letter(rot(DIR_VECTORS[LETTERS.find(ch)], deg))):
					ok = false
					break
			if ok:
				return Vector2i(p, deg)
	return Vector2i(-1, 0)


static func _letter(d: Vector2i) -> String:
	var i: int = DIR_VECTORS.find(d)
	return LETTERS[i] if i >= 0 else "?"


static func _all_free(lv: Layout, mods: Array[Vector2i]) -> bool:
	for m: Vector2i in mods:
		if lv.occupied.has(m):
			return false
	return true


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _weighted_pick(weights: Array[int], rng: RandomNumberGenerator) -> int:
	var total: int = 0
	for w: int in weights:
		total += w
	var r: int = rng.randi_range(0, total - 1)
	for i: int in range(weights.size()):
		r -= weights[i]
		if r < 0:
			return i
	return weights.size() - 1


static func _shuffle_int(items: Array[int], rng: RandomNumberGenerator) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = items[i]
		items[i] = items[j]
		items[j] = tmp


static func _local_xform(node: Node3D, root: Node) -> Transform3D:
	var xf: Transform3D = node.transform
	var p: Node = node.get_parent()
	while p != null and p != root:
		var p3: Node3D = p as Node3D
		if p3 != null:
			xf = p3.transform * xf
		p = p.get_parent()
	return xf


static func _float_or(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		return float(value)
	return fallback
