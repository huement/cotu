class_name CaveGenerator
extends RefCounted
## Pure layout logic for cave levels: rooms, tunnels, the entrance/exit, props and
## the wall piece for every rock cell. No scene access, so it is safe to call from
## EditorScripts (GenerateCaveLevel.gd, RebuildCaveWalls.gd) or at runtime.
##
## Grid conventions (match cave_floor/cave_wall mesh libraries, 2 m cells):
##  * A cell is Vector2i(x, z) -> GridMap cell Vector3i(x, 0, z).
##  * Wall pieces are painted in ROCK cells; their rock face points +Z by default.
##  * Angles are Y rotations: 0 = faces +Z (south), 90 = +X (east), 180 = -Z, 270 = -X.

# --- cave_floor_mesh_library item ids ---
const FLOOR_PLAIN: int = 0
const FLOOR_DETAIL: int = 1

# --- cave_wall_mesh_library item ids ---
const WALL: int = 0
const WALL_B: int = 1
const WALL_C: int = 2
const WALL_DOUBLE: int = 3
const WALL_CORNER: int = 4
const WALL_END: int = 5
const WALL_PILLAR: int = 6
const CRYSTAL: int = 7

## GridMap orthogonal index for each Y angle, and back.
const ORIENT_BY_ANGLE: Dictionary = {0: 0, 90: 16, 180: 10, 270: 22}
const ANGLE_BY_ORIENT: Dictionary = {0: 0, 16: 90, 10: 180, 22: 270}

## Cardinal steps (S, E, N, W) and the angle that turns a +Z-facing piece toward each.
const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
const DIR_ANGLES: Array[int] = [0, 90, 180, 270]

const MIN_GRID_SIZE: int = 12


## Everything GenerateCaveLevel needs to build a scene.
class CaveLayout extends RefCounted:
	var size: Vector2i = Vector2i.ZERO
	var open_cells: Dictionary[Vector2i, bool] = {}
	var blocked: Dictionary[Vector2i, bool] = {}
	var rooms: Array[Vector4i] = [] # (center_x, center_z, radius_x, radius_z)
	var stairs_cell: Vector2i = Vector2i.ZERO
	var stairs_angle: int = 0
	var spawn_cell: Vector2i = Vector2i.ZERO
	var spawn_angle: int = 0
	var exit_in_alcove: bool = false
	var exit_cell: Vector2i = Vector2i.ZERO
	var exit_angle: int = 0
	var arrival_cell: Vector2i = Vector2i.ZERO
	var arrival_angle: int = 0
	var crystals: Array[Vector2i] = []
	var crystal_angles: Array[int] = []
	var enemies: Array[Vector2i] = []
	var floor_cells: Array[Vector4i] = [] # (x, z, item, orientation)
	var wall_cells: Array[Vector4i] = [] # (x, z, item, orientation)


## A stairs alcove: `cell` holds the stairs, `stand` is the room cell in front of it.
## `angle` points from the stairs back into the room (stairs low end and party facing).
class Alcove extends RefCounted:
	var cell: Vector2i = Vector2i.ZERO
	var stand: Vector2i = Vector2i.ZERO
	var angle: int = 0


## Builds a full layout. Returns null (with an error) if the grid is too small or no
## entrance/exit could be placed; try another seed in that case.
## start_at_west_end: rooms are chained west -> east and the entrance is the westernmost room,
## so a long, wide grid becomes one long walk (the exit lands at the far east end).
static func generate(seed_value: int, size: Vector2i, room_count: int, enemy_count: int, exit_in_alcove: bool, start_at_west_end: bool = false) -> CaveLayout:
	if size.x < MIN_GRID_SIZE or size.y < MIN_GRID_SIZE:
		push_error("CaveGenerator: grid_size must be at least %d x %d." % [MIN_GRID_SIZE, MIN_GRID_SIZE])
		return null

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var layout := CaveLayout.new()
	layout.size = size
	layout.exit_in_alcove = exit_in_alcove
	var bounds := Rect2i(2, 2, size.x - 4, size.y - 4) # open cells stay inside this

	# 1. Rooms: jittered ellipses with a 2-cell gap between them.
	var tries: int = 0
	while layout.rooms.size() < room_count and tries < 600:
		tries += 1
		var rx: int = rng.randi_range(1, 3)
		var rz: int = rng.randi_range(1, 3)
		var cx: int = rng.randi_range(2 + rx, size.x - 3 - rx)
		var cz: int = rng.randi_range(2 + rz, size.y - 3 - rz)
		var overlaps: bool = false
		for room: Vector4i in layout.rooms:
			if absi(cx - room.x) <= rx + room.z + 2 and absi(cz - room.y) <= rz + room.w + 2:
				overlaps = true
				break
		if overlaps:
			continue
		layout.rooms.append(Vector4i(cx, cz, rx, rz))
		for z: int in range(cz - rz - 1, cz + rz + 2):
			for x: int in range(cx - rx - 1, cx + rx + 2):
				var ex: float = float(x - cx) / (float(rx) + 0.5)
				var ez: float = float(z - cz) / (float(rz) + 0.5)
				if ex * ex + ez * ez <= 1.0 + rng.randf_range(-0.3, 0.35):
					_carve(layout.open_cells, bounds, Vector2i(x, z))
		_carve(layout.open_cells, bounds, Vector2i(cx, cz))

	if start_at_west_end:
		layout.rooms.sort_custom(func(a: Vector4i, b: Vector4i) -> bool: return a.x < b.x)

	if layout.rooms.size() < 2:
		push_error("CaveGenerator: could only fit %d room(s); use a bigger grid_size." % layout.rooms.size())
		return null

	# 2. Tunnels: nearest-neighbour chain through every room, plus a few loops.
	var centers: Array[Vector2i] = []
	for room: Vector4i in layout.rooms:
		centers.append(Vector2i(room.x, room.y))
	var order: Array[int] = [0]
	var left: Array[int] = []
	for i: int in range(1, centers.size()):
		left.append(i)
	while not left.is_empty():
		var last: Vector2i = centers[order[order.size() - 1]]
		var best: int = left[0]
		var best_d: int = _manhattan(centers[best], last)
		for i: int in left:
			var d: int = _manhattan(centers[i], last)
			if d < best_d:
				best = i
				best_d = d
		left.erase(best)
		_tunnel(layout.open_cells, bounds, rng, last, centers[best])
		order.append(best)
	for _loop: int in range(maxi(1, floori(room_count / 4.0))):
		var a: int = rng.randi_range(0, centers.size() - 1)
		var b: int = rng.randi_range(0, centers.size() - 2)
		if b >= a:
			b += 1
		_tunnel(layout.open_cells, bounds, rng, centers[a], centers[b])

	# 3. Keep only what is reachable from the first room.
	var empty_blocked: Dictionary[Vector2i, bool] = {}
	var reach: Dictionary[Vector2i, int] = bfs(layout.open_cells, centers[0], empty_blocked)
	var reachable: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in reach:
		reachable[cell] = true
	layout.open_cells = reachable

	# 4. Rock pillars inside big rooms (a cell whose 8 neighbours are open never cuts a path).
	for room: Vector4i in layout.rooms:
		if room.z >= 2 and room.w >= 2 and rng.randf() < 0.6:
			var candidates: Array[Vector2i] = []
			for z: int in range(room.y - room.w, room.y + room.w + 1):
				for x: int in range(room.x - room.z, room.x + room.z + 1):
					var c := Vector2i(x, z)
					if c != Vector2i(room.x, room.y) and _all8_open(layout.open_cells, c):
						candidates.append(c)
			if not candidates.is_empty():
				layout.open_cells.erase(candidates[rng.randi_range(0, candidates.size() - 1)])

	# 5. Entrance: stairs in an alcove off the first room.
	var entrance: Alcove = find_alcove(layout.open_cells, layout.rooms[0], rng, size, empty_blocked)
	if entrance == null:
		push_error("CaveGenerator: no room for the entrance stairs with this seed; try another seed.")
		return null
	layout.stairs_cell = entrance.cell
	layout.stairs_angle = entrance.angle
	layout.spawn_cell = entrance.stand
	layout.spawn_angle = entrance.angle
	layout.open_cells[entrance.cell] = true
	layout.blocked[entrance.cell] = true

	# 6. Exit at the far end.
	var dist: Dictionary[Vector2i, int] = bfs(layout.open_cells, layout.spawn_cell, layout.blocked)
	if exit_in_alcove:
		var ranked: Array[int] = []
		for i: int in range(layout.rooms.size()):
			ranked.append(i)
		ranked.sort_custom(func(a: int, b: int) -> bool:
			return int(dist.get(centers[a], -1)) > int(dist.get(centers[b], -1)))
		var exit_alcove: Alcove = null
		for k: int in range(ranked.size() - 1):
			var room_index: int = ranked[k]
			if dist.has(centers[room_index]):
				exit_alcove = find_alcove(layout.open_cells, layout.rooms[room_index], rng, size, layout.blocked)
				if exit_alcove != null:
					break
		if exit_alcove == null:
			push_error("CaveGenerator: no room for the exit stairs with this seed; try another seed.")
			return null
		layout.exit_cell = exit_alcove.cell
		layout.exit_angle = exit_alcove.angle
		layout.arrival_cell = exit_alcove.stand
		layout.arrival_angle = exit_alcove.angle
		layout.open_cells[exit_alcove.cell] = true
	else:
		var candidates: Array[Vector2i] = []
		for c: Vector2i in dist:
			if c != layout.spawn_cell and _all8_open(layout.open_cells, c):
				candidates.append(c)
		if candidates.is_empty():
			push_error("CaveGenerator: no open spot for the crypt hole; try another seed.")
			return null
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return dist[a] > dist[b])
		layout.exit_cell = candidates[0]
		layout.exit_angle = 0
		# Arrival = the hole's neighbour closest to the way in, facing away from the hole.
		var best_dist: int = -1
		for i: int in range(DIRS.size()):
			var n: Vector2i = layout.exit_cell + DIRS[i]
			if dist.has(n) and (best_dist < 0 or dist[n] < best_dist):
				best_dist = dist[n]
				layout.arrival_cell = n
				layout.arrival_angle = DIR_ANGLES[i]
	layout.blocked[layout.exit_cell] = true
	var specials: Array[Vector2i] = [layout.stairs_cell, layout.spawn_cell, layout.exit_cell, layout.arrival_cell]

	# 7. Crystal rocks: props that block their cell, never on a cell that cuts a path.
	for _n: int in range(maxi(1, floori(room_count / 2.0))):
		var candidates: Array[Vector2i] = []
		var sorted_open: Array[Vector2i] = []
		sorted_open.assign(layout.open_cells.keys())
		sorted_open.sort()
		for c: Vector2i in sorted_open:
			if layout.blocked.has(c) or _near_any(c, specials, 2):
				continue
			var ok: bool = true
			for dz: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var n := Vector2i(c.x + dx, c.y + dz)
					if n != c and (not layout.open_cells.has(n) or layout.blocked.has(n)):
						ok = false
			if ok:
				candidates.append(c)
		if candidates.is_empty():
			break
		var crystal: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		layout.crystals.append(crystal)
		layout.crystal_angles.append(DIR_ANGLES[rng.randi_range(0, 3)])
		layout.blocked[crystal] = true

	# 8. Enemies: well away from the entrance and spread out.
	dist = bfs(layout.open_cells, layout.spawn_cell, layout.blocked)
	var enemy_spots: Array[Vector2i] = []
	for c: Vector2i in dist:
		if dist[c] >= 6 and not _near_any(c, specials, 1):
			enemy_spots.append(c)
	enemy_spots.sort()
	_shuffle(enemy_spots, rng)
	for c: Vector2i in enemy_spots:
		if layout.enemies.size() >= enemy_count:
			break
		var spaced: bool = true
		for e: Vector2i in layout.enemies:
			if _manhattan(c, e) < 5:
				spaced = false
				break
		if spaced:
			layout.enemies.append(c)

	# 9. Paint lists.
	var floor_order: Array[Vector2i] = []
	floor_order.assign(layout.open_cells.keys())
	floor_order.sort()
	for c: Vector2i in floor_order:
		var item: int = FLOOR_DETAIL if rng.randf() < 0.35 else FLOOR_PLAIN
		var orient: int = ORIENT_BY_ANGLE[DIR_ANGLES[rng.randi_range(0, 3)]]
		layout.floor_cells.append(Vector4i(c.x, c.y, item, orient))
	layout.wall_cells = autowall(layout.open_cells, Rect2i(Vector2i.ZERO, size), rng)
	for i: int in range(layout.crystals.size()):
		var c: Vector2i = layout.crystals[i]
		layout.wall_cells.append(Vector4i(c.x, c.y, CRYSTAL, ORIENT_BY_ANGLE[layout.crystal_angles[i]]))
	return layout


## Picks the wall piece for every rock cell inside `region` that touches an open cell.
## Returns (x, z, item, orientation) entries for the WallMap.
static func autowall(open_cells: Dictionary[Vector2i, bool], region: Rect2i, rng: RandomNumberGenerator) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	for z: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var c := Vector2i(x, z)
			if open_cells.has(c):
				continue
			var faces: Array[int] = []
			for i: int in range(DIRS.size()):
				if open_cells.has(c + DIRS[i]):
					faces.append(DIR_ANGLES[i])
			if faces.is_empty():
				continue
			var piece: Vector2i = piece_for(faces, rng)
			out.append(Vector4i(x, z, piece.x, ORIENT_BY_ANGLE[piece.y]))
	return out


## Wall item + Y angle for a rock cell whose open sides are `faces` (angles).
static func piece_for(faces: Array[int], rng: RandomNumberGenerator) -> Vector2i:
	if faces.size() == 1:
		var r: float = rng.randf()
		var item: int = WALL if r < 0.45 else (WALL_B if r < 0.8 else WALL_C)
		return Vector2i(item, faces[0])
	if faces.size() == 4:
		return Vector2i(WALL_PILLAR, 0)
	if faces.size() == 3:
		var missing: int = 0
		for a: int in DIR_ANGLES:
			if not faces.has(a):
				missing = a
		return Vector2i(WALL_END, posmod(missing - 180, 360))
	# Two faces: opposite -> double wall, adjacent -> corner (faces a and a + 90).
	if posmod(faces[1] - faces[0], 360) == 180:
		return Vector2i(WALL_DOUBLE, mini(faces[0], faces[1]))
	for a: int in faces:
		if faces.has(posmod(a + 90, 360)):
			return Vector2i(WALL_CORNER, a)
	return Vector2i(WALL, faces[0])


## Breadth-first step distances from `start` over open, unblocked cells.
static func bfs(open_cells: Dictionary[Vector2i, bool], start: Vector2i, blocked: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, int]:
	var dist: Dictionary[Vector2i, int] = {start: 0}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for step: Vector2i in DIRS:
			var n: Vector2i = c + step
			if open_cells.has(n) and not blocked.has(n) and not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	return dist


## Walks out from a room centre; the first rock cell becomes a stairs alcove if it is
## enclosed on its other three sides. Returns null if no direction works.
static func find_alcove(open_cells: Dictionary[Vector2i, bool], room: Vector4i, rng: RandomNumberGenerator, size: Vector2i, avoid: Dictionary[Vector2i, bool]) -> Alcove:
	var order: Array[int] = [0, 1, 2, 3]
	_shuffle_int(order, rng)
	var center := Vector2i(room.x, room.y)
	if not open_cells.has(center):
		return null
	for i: int in order:
		var step: Vector2i = DIRS[i]
		var stand: Vector2i = center
		while open_cells.has(stand + step):
			stand += step
		var cell: Vector2i = stand + step
		if cell.x < 1 or cell.y < 1 or cell.x > size.x - 2 or cell.y > size.y - 2:
			continue
		var side_a := Vector2i(cell.x + step.y, cell.y + step.x)
		var side_b := Vector2i(cell.x - step.y, cell.y - step.x)
		var back: Vector2i = cell + step
		if open_cells.has(side_a) or open_cells.has(side_b) or open_cells.has(back):
			continue
		if avoid.has(stand):
			continue
		var alcove := Alcove.new()
		alcove.cell = cell
		alcove.stand = stand
		alcove.angle = posmod(DIR_ANGLES[i] + 180, 360)
		return alcove
	return null


# --- helpers -----------------------------------------------------------------

static func _carve(open_cells: Dictionary[Vector2i, bool], bounds: Rect2i, cell: Vector2i) -> void:
	if bounds.has_point(cell):
		open_cells[cell] = true


static func _tunnel(open_cells: Dictionary[Vector2i, bool], bounds: Rect2i, rng: RandomNumberGenerator, from: Vector2i, to: Vector2i) -> void:
	var p: Vector2i = from
	var guard: int = 0
	while p != to and guard < 2000:
		guard += 1
		_carve(open_cells, bounds, p)
		if rng.randf() < 0.15: # occasional wide spot
			if rng.randf() < 0.5:
				_carve(open_cells, bounds, Vector2i(p.x + _pick_sign(rng), p.y))
			else:
				_carve(open_cells, bounds, Vector2i(p.x, p.y + _pick_sign(rng)))
		var dx: int = to.x - p.x
		var dz: int = to.y - p.y
		if rng.randf() < 0.2: # wiggle
			if rng.randf() < 0.5:
				p.x += _pick_sign(rng)
			else:
				p.y += _pick_sign(rng)
		elif dx != 0 and (dz == 0 or rng.randf() < float(absi(dx)) / float(absi(dx) + absi(dz))):
			p.x += signi(dx)
		else:
			p.y += signi(dz)
		p.x = clampi(p.x, bounds.position.x, bounds.end.x - 1)
		p.y = clampi(p.y, bounds.position.y, bounds.end.y - 1)
	_carve(open_cells, bounds, to)


static func _all8_open(open_cells: Dictionary[Vector2i, bool], c: Vector2i) -> bool:
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if not open_cells.has(Vector2i(c.x + dx, c.y + dz)):
				return false
	return true


static func _near_any(c: Vector2i, points: Array[Vector2i], radius: int) -> bool:
	for p: Vector2i in points:
		if absi(c.x - p.x) <= radius and absi(c.y - p.y) <= radius:
			return true
	return false


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _pick_sign(rng: RandomNumberGenerator) -> int:
	return -1 if rng.randf() < 0.5 else 1


## Seeded Fisher-Yates (Array.shuffle() ignores our RandomNumberGenerator).
static func _shuffle(items: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = items[i]
		items[i] = items[j]
		items[j] = tmp


static func _shuffle_int(items: Array[int], rng: RandomNumberGenerator) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = items[i]
		items[i] = items[j]
		items[j] = tmp
