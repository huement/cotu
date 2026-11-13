# res://Scripts/Utilities/generate_castle_hollow.gd
# One-shot: godot --path . --headless -s Scripts/Utilities/generate_castle_hollow.gd
extends SceneTree

## Castle Hollow, the woods west of VeroWood (the old Witch's Hollow slot).
## Traced from the hand-drawn map: grass clearings, magenta tree lines split
## across the three marsh wall maps, and an east-west river crossed by a wood bridge.
## The sunken castle is an empty anchor. North gate and the cave mouth stay locked.

const SAVE_PATH: String = "res://Scenes/CastleHollow.tscn"
const PIXEL_SKY_MATERIAL: String = "res://resources/Environment/pixel_sky_overcast.tres"
const FLOOR_LIB: String = "res://resources/mesh_library/blackmarsh_mesh_library.tres"
const WALL_LIB: String = "res://resources/mesh_library/forestwall_mesh_library.tres"
const WALL_SCRIPT: String = "res://Scripts/Environment/forest_grid_map_replacer.gd"
const THICK_CHUNK: String = "res://Scenes/Environment/forest_wall_chunk_thick.tscn"

const FLOOR_GRASS_ID: int = 1
const RIVER_OPEN_ID: int = 22
const RIVER_SIDE_ID: int = 24
const RIVER_STRAIGHT_ID: int = 27
const BRIDGE_WOOD_ID: int = 41
const WALL_TREE_ID: int = 0

## Gray dot in the lower-left clearing, and the east half of the north court.
const CAVE_CELL: Vector2i = Vector2i(10, 37)
const CASTLE_CELL: Vector2i = Vector2i(40, 8)

const KIND_GRASS: String = "G"
const KIND_TREE: String = "#"
const KIND_WATER: String = "~"
const KIND_BRIDGE: String = "B"
const KIND_OUT: String = "."

## North is row 0. Godot -Z is north, so row index is the floor Z cell.
const MAP: PackedStringArray = [
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###",
	"...............##############GGGGG######################",
	"...............##############GGGGG######################",
	"...............##############GGGGG######################",
	".........................####GGGGG###...................",
	".........................####GGGGG###...................",
	".........................####GGGGG###...................",
	".........................####GGGGG###...................",
	".........................####GGGGG###...................",
	"...................~~~~~~~~~~~~G~~~~~~~~~~~~~~~~~~~~~~~~",
	"...................~~~~~~~~~~~~G~~~~~~~~~~~~~~~~~~~~~~~~",
	"............~......~~~~~~~~~~~~G~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~G~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~..##GGGGGG###...................",
	"~~~~~~~~~~~~~~~~~~~~~~~~..###GGGGG###...................",
	"~~~~~~~~~~~~~~~~~~~~~~~...###GGGGG###...................",
	"..####GGGGGGGGG###........###GGGGG###...................",
	"..####GGGGGGGGG###........###GGGGG###...................",
	"..####GGGGGGGGG###........###GGGGG###...................",
	"..####GGGGGGGGG###........###GGGGG###...................",
	"..####GGGGGGGGG###........###GGGGG###...................",
	"..####GGGGGGGGG###........###GGGGG###...................",
	"..####GGGGGGGGG###........###GGGGG###...................",
	"..####GGGGGGGGG###........###GGGGG#########.............",
	"..####GGGGGGGGG##############GGGGG#########.............",
	"..#######GGG#################GGGGG#########.............",
	"..#######GGG################GGGGGG#########.............",
	"..#######GGG###GGGGGGGGGGGGGGGGGGGGGGGGG###.............",
	"..#######GGG###GGGGGGGGGGGGGGGGGGGGGGGGG###.............",
	"..#######GGG###GGGGGGGGGGGGGGGGGGGGGGGGG###.............",
	"..#######GGG###GGGGGGGGGGGGGGGGGGGGGGGGG###.............",
	"..####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###.............",
	"..####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###.............",
	"..####GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG###.............",
	"..#############GGGGGGGGGGGGGGGGGGGGGGGGG###.............",
	"..#############GGGGGGGGGGGGGGGGGGGGGGGGG###.............",
	"..#############GGGGGGGGGGGGGGGGGGGGGGGGG###.............",
	"....###########GGGGGGGGGGGGGGGGGGGGGGGGG###.............",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var layout: Dictionary[Vector2i, String] = _build_layout()
	var root := Node3D.new()
	root.name = "CastleHollow"

	_add_environment(root)
	var floor_map: GridMap = _add_floor_map(root, "FloorMap")
	var bridges: GridMap = _add_floor_map(root, "Bridges")
	var wall_map: GridMap = _add_wall_map(root, "WallMap", 2.6, "")
	var wall_map2: GridMap = _add_wall_map(root, "WallMap2", 2.0, THICK_CHUNK)
	var wall_map3: GridMap = _add_wall_map(root, "WallMap3", 1.6, THICK_CHUNK)
	var walls: Array[GridMap] = [wall_map, wall_map2, wall_map3]

	var counts: Dictionary = _paint(layout, floor_map, bridges, walls)
	_add_markers_and_gates(root, floor_map, layout)
	_add_shell(root, floor_map, layout)

	_set_owner_recursive(root, root)
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("CastleHollow: failed to pack scene.")
		root.queue_free()
		quit(1)
		return

	var err: Error = ResourceSaver.save(packed, SAVE_PATH)
	root.queue_free()
	if err != OK:
		push_error("CastleHollow: failed to save %s (err %d)" % [SAVE_PATH, err])
		quit(1)
		return

	print("CastleHollow written to %s" % SAVE_PATH)
	print("  grass %d  river %d  bridge %d  trees %d" % [
		int(counts["grass"]), int(counts["river"]), int(counts["bridge"]), int(counts["tree"])
	])
	print("  WallMap %d  WallMap2 %d  WallMap3 %d" % [
		int(counts["w0"]), int(counts["w1"]), int(counts["w2"])
	])
	if int(counts["bridge_miss"]) > 0:
		push_error("CastleHollow: %d bridge cells are not on a river tile." % int(counts["bridge_miss"]))
		quit(1)
		return
	quit(0)


func _build_layout() -> Dictionary[Vector2i, String]:
	var layout: Dictionary[Vector2i, String] = {}
	var width: int = MAP[0].length()
	for z: int in range(MAP.size()):
		var row: String = MAP[z]
		if row.length() != width:
			push_error("CastleHollow: map row %d has width %d, expected %d." % [z, row.length(), width])
		for x: int in range(row.length()):
			layout[Vector2i(x, z)] = row.substr(x, 1)

	var bridge_xs: Dictionary[int, bool] = {}
	for cell: Vector2i in layout.keys():
		if layout[cell] != KIND_GRASS:
			continue
		if _raw(layout, cell.x - 1, cell.y) == KIND_WATER and _raw(layout, cell.x + 1, cell.y) == KIND_WATER:
			bridge_xs[cell.x] = true

	if bridge_xs.is_empty():
		push_error("CastleHollow: no bridge column where grass crosses the river.")

	for x: int in bridge_xs.keys():
		for z: int in range(MAP.size()):
			var at: Vector2i = Vector2i(x, z)
			var kind: String = str(layout.get(at, KIND_OUT))
			if kind == KIND_WATER:
				layout[at] = KIND_BRIDGE
			elif kind == KIND_GRASS and _raw(layout, x - 1, z) == KIND_WATER and _raw(layout, x + 1, z) == KIND_WATER:
				layout[at] = KIND_BRIDGE

	_seal_edges(layout)
	return layout


func _raw(layout: Dictionary[Vector2i, String], x: int, z: int) -> String:
	return str(layout.get(Vector2i(x, z), KIND_OUT))


func _seal_edges(layout: Dictionary[Vector2i, String]) -> void:
	var grass_cells: Array[Vector2i] = []
	for cell: Vector2i in layout.keys():
		if layout[cell] == KIND_GRASS:
			grass_cells.append(cell)

	for cell: Vector2i in grass_cells:
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := Vector2i(cell.x + step.x, cell.y + step.y)
			var kind: String = str(layout.get(next, KIND_OUT))
			if kind != KIND_OUT:
				continue
			layout[next] = KIND_TREE


func _gate_gap(layout: Dictionary[Vector2i, String], z: int) -> Dictionary[int, bool]:
	var xs: Array[int] = []
	var width: int = MAP[0].length()
	for x: int in range(width):
		if str(layout.get(Vector2i(x, z), KIND_OUT)) == KIND_GRASS:
			xs.append(x)
	var gap: Dictionary[int, bool] = {}
	if xs.is_empty():
		push_error("CastleHollow: no grass on row %d for a gate." % z)
		return gap
	var mid: int = xs[xs.size() >> 1]
	for x: int in [mid - 1, mid, mid + 1]:
		if xs.has(x):
			gap[x] = true
	return gap


func _paint(layout: Dictionary[Vector2i, String], floor_map: GridMap, bridges: GridMap, walls: Array[GridMap]) -> Dictionary:
	var yaw: Dictionary[int, int] = {
		0: floor_map.get_orthogonal_index_from_basis(Basis(Vector3.UP, 0.0)),
		2: floor_map.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI)),
	}
	var grass_n: int = 0
	var river_n: int = 0
	var bridge_n: int = 0
	var tree_n: int = 0
	var wall_hits: Array[int] = [0, 0, 0]
	var bridge_miss: int = 0
	var lib: MeshLibrary = floor_map.mesh_library

	for cell: Vector2i in layout.keys():
		var kind: String = layout[cell]
		var grid := Vector3i(cell.x, 0, cell.y)
		if kind == KIND_GRASS:
			floor_map.set_cell_item(grid, FLOOR_GRASS_ID)
			grass_n += 1
		elif kind == KIND_WATER or kind == KIND_BRIDGE:
			var painted: Vector2i = _paint_river(layout, floor_map, grid, int(yaw[0]), int(yaw[2]))
			river_n += 1
			if kind == KIND_BRIDGE:
				# bridge_wood rails run along Z, which is the north-south crossing.
				bridges.set_cell_item(grid, BRIDGE_WOOD_ID, int(yaw[0]))
				bridge_n += 1
				var item_name: String = lib.get_item_name(painted.x).to_lower() if painted.x >= 0 else ""
				if not item_name.contains("river"):
					bridge_miss += 1
		elif kind == KIND_TREE:
			var which: int = posmod(cell.x + cell.y, 3)
			var center: Vector3 = floor_map.map_to_local(grid)
			var wall_cell: Vector3i = walls[which].local_to_map(center)
			walls[which].set_cell_item(wall_cell, WALL_TREE_ID)
			wall_hits[which] = int(wall_hits[which]) + 1
			tree_n += 1

	return {
		"grass": grass_n,
		"river": river_n,
		"bridge": bridge_n,
		"tree": tree_n,
		"w0": int(wall_hits[0]),
		"w1": int(wall_hits[1]),
		"w2": int(wall_hits[2]),
		"bridge_miss": bridge_miss,
	}


## Wide river: side banks where grass meets water, a single straight channel
## where the river is one cell thick, open water (the marsh fill) in the middle.
## ground_riverSide's bank geometry faces -Z at yaw 0, so the north bank stays
## at yaw 0 and the south bank turns 180 degrees.
func _paint_river(layout: Dictionary[Vector2i, String], floor_map: GridMap, grid: Vector3i, yaw_east: int, yaw_south: int) -> Vector2i:
	var north_wet: bool = _is_wet(layout, grid.x, grid.z - 1)
	var south_wet: bool = _is_wet(layout, grid.x, grid.z + 1)
	if north_wet and not south_wet:
		floor_map.set_cell_item(grid, RIVER_SIDE_ID, yaw_south)
		return Vector2i(RIVER_SIDE_ID, yaw_south)
	if south_wet and not north_wet:
		floor_map.set_cell_item(grid, RIVER_SIDE_ID, yaw_east)
		return Vector2i(RIVER_SIDE_ID, yaw_east)
	if not north_wet and not south_wet:
		floor_map.set_cell_item(grid, RIVER_STRAIGHT_ID, yaw_east)
		return Vector2i(RIVER_STRAIGHT_ID, yaw_east)
	floor_map.set_cell_item(grid, RIVER_OPEN_ID, yaw_east)
	return Vector2i(RIVER_OPEN_ID, yaw_east)


func _is_wet(layout: Dictionary[Vector2i, String], x: int, z: int) -> bool:
	var kind: String = str(layout.get(Vector2i(x, z), KIND_OUT))
	return kind == KIND_WATER or kind == KIND_BRIDGE


func _add_markers_and_gates(root: Node3D, floor_map: GridMap, layout: Dictionary[Vector2i, String]) -> void:
	var south_z: int = MAP.size() - 1
	var north_gap: Dictionary[int, bool] = _gate_gap(layout, 0)
	var south_gap: Dictionary[int, bool] = _gate_gap(layout, south_z)
	var north_x: int = _gap_center(north_gap)
	var south_x: int = _gap_center(south_gap)

	# Gate meshes are scaled 2x, so their collision reaches about two cells in.
	# Stand three cells inside the clearing, facing into the hollow.
	_add_marker(root, "SpawnPoint", floor_map, south_x, south_z - 3, 0.0)
	_add_marker(root, "SpawnPoint_North", floor_map, north_x, 3, PI)

	_add_gate(root, floor_map, "StoneGate", south_x, south_z, PI, {
		"target_dungeon_scene": "res://Scenes/VeroWood.tscn",
		"arrival_point_name": "SpawnPointWest",
		"prompt_text": "The trees open back toward VeroWood. Leave Castle Hollow?",
		"object_id": "castlehollow_gate_verowood",
		"locked_message": "",
		"locked_title": "",
	})
	_add_gate(root, floor_map, "StoneGate_North", north_x, 0, 0.0, {
		"target_dungeon_scene": "",
		"arrival_point_name": "SpawnPoint",
		"prompt_text": "A drowned road leads north toward the ruins. Leave Castle Hollow?",
		"object_id": "castlehollow_gate_north",
		"locked_message": "The north bank is drowned. The ruins beyond are not part of the current demo.",
		"locked_title": "Not In The Demo",
	})

	if str(layout.get(CAVE_CELL, KIND_OUT)) != KIND_GRASS:
		push_error("CastleHollow: cave cell %s is '%s', expected grass." % [CAVE_CELL, str(layout.get(CAVE_CELL, KIND_OUT))])
	_add_crypt(root, floor_map, CAVE_CELL)

	if str(layout.get(CASTLE_CELL, KIND_OUT)) != KIND_GRASS:
		push_error("CastleHollow: castle anchor %s is '%s', expected grass." % [CASTLE_CELL, str(layout.get(CASTLE_CELL, KIND_OUT))])
	_add_marker(root, "SunkenCastleAnchor", floor_map, CASTLE_CELL.x, CASTLE_CELL.y, 0.0)


func _gap_center(gap: Dictionary[int, bool]) -> int:
	var xs: Array[int] = []
	for x: int in gap.keys():
		xs.append(x)
	xs.sort()
	if xs.is_empty():
		return 0
	return xs[xs.size() >> 1]


func _add_marker(root: Node3D, marker_name: String, floor_map: GridMap, x: int, z: int, yaw: float) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.unique_name_in_owner = true
	marker.position = _cell_pos(floor_map, x, z)
	marker.rotation.y = yaw
	marker.set_meta("eye_height", 1.0)
	root.add_child(marker)


func _cell_pos(floor_map: GridMap, x: int, z: int) -> Vector3:
	var local: Vector3 = floor_map.map_to_local(Vector3i(x, 0, z))
	return Vector3(local.x, 0.0, local.z)


func _add_gate(root: Node3D, floor_map: GridMap, gate_name: String, x: int, z: int, yaw: float, props: Dictionary) -> void:
	if not ResourceLoader.exists("res://Scenes/Environment/StoneGate.tscn"):
		push_error("CastleHollow: StoneGate.tscn is missing.")
		return
	var gate: Node3D = load("res://Scenes/Environment/StoneGate.tscn").instantiate() as Node3D
	gate.name = gate_name
	gate.set_script(load("res://Scripts/Environment/StoneGate.gd"))
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(2.0, 2.0, 2.0))
	gate.transform = Transform3D(basis, _cell_pos(floor_map, x, z))
	for key: Variant in props.keys():
		gate.set(str(key), props[key])
	root.add_child(gate)


func _add_crypt(root: Node3D, floor_map: GridMap, cell: Vector2i) -> void:
	if not ResourceLoader.exists("res://Scenes/Environment/CryptHole.tscn"):
		push_error("CastleHollow: CryptHole.tscn is missing.")
		return
	var crypt: Node3D = load("res://Scenes/Environment/CryptHole.tscn").instantiate() as Node3D
	crypt.name = "CryptHole"
	# StoneGate knows how to show a locked message. CryptHole would try to travel.
	crypt.set_script(load("res://Scripts/Environment/StoneGate.gd"))
	crypt.position = _cell_pos(floor_map, cell.x, cell.y)
	crypt.scale = Vector3(0.2, 0.2, 0.2)
	crypt.set("target_dungeon_scene", "")
	crypt.set("prompt_text", "A crypt mouth sinks into the bank. Climb down?")
	crypt.set("locked_message", "The caves under Castle Hollow are not open yet.")
	crypt.set("locked_title", "Not In The Demo")
	crypt.set("object_id", "castlehollow_crypt")
	crypt.set("snap_to_floor_center", true)
	root.add_child(crypt)


func _add_shell(root: Node3D, floor_map: GridMap, layout: Dictionary[Vector2i, String]) -> void:
	for node_name: String in ["WoodPaths", "BigTimbers", "Shrooms"]:
		var holder := Node3D.new()
		holder.name = node_name
		root.add_child(holder)

	var initializer := Node3D.new()
	initializer.name = "WorldSceneInitializer"
	if ResourceLoader.exists("res://Scripts/WorldSceneInitializerModule.gd"):
		initializer.set_script(load("res://Scripts/WorldSceneInitializerModule.gd"))
		initializer.set("create_floor", false)
		initializer.set("create_ceiling", false)
		initializer.set("setup_dark_retro_environment", false)
		initializer.set("attach_torch_to_player", false)
		initializer.set("particle_color", Color(0.94, 1.01, 0.77, 0.4))
	root.add_child(initializer)

	var min_x: int = 999
	var max_x: int = -999
	var min_z: int = 999
	var max_z: int = -999
	for cell: Vector2i in layout.keys():
		if layout[cell] == KIND_OUT:
			continue
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_z = mini(min_z, cell.y)
		max_z = maxi(max_z, cell.y)
	var center: Vector3 = _cell_pos(floor_map, (min_x + max_x) >> 1, (min_z + max_z) >> 1)
	var mist := CPUParticles3D.new()
	mist.name = "GroundMist"
	mist.position = Vector3(center.x, 0.4, center.z)
	mist.amount = 60
	mist.lifetime = 8.0
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(float(max_x - min_x), 0.3, float(max_z - min_z))
	mist.gravity = Vector3(0.0, -0.02, 0.0)
	mist.scale_amount_min = 0.8
	mist.scale_amount_max = 1.6
	mist.color = Color(0.7, 0.8, 0.75, 0.3)
	var quad := QuadMesh.new()
	quad.size = Vector2(6, 6)
	var mist_mat := StandardMaterial3D.new()
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_mat.vertex_color_use_as_albedo = true
	mist_mat.albedo_color = Color(0.45, 0.55, 0.5, 0.18)
	mist_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mist_mat
	mist.mesh = quad
	root.add_child(mist)

	_add_day_night(root)
	_add_grass(root, floor_map)
	_add_level_title(root)


func _add_environment(root: Node3D) -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = load(PIXEL_SKY_MATERIAL) if ResourceLoader.exists(PIXEL_SKY_MATERIAL) else ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.62, 1.0, 0.85, 1.0)
	world_env.environment = env
	root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.transform = Transform3D(Basis.from_euler(Vector3(-0.8, -0.5, 0.0)), Vector3.ZERO)
	root.add_child(sun)


func _add_floor_map(root: Node3D, map_name: String) -> GridMap:
	var grid := GridMap.new()
	grid.name = map_name
	grid.unique_name_in_owner = true
	grid.mesh_library = load(FLOOR_LIB)
	grid.cell_scale = 2.0
	grid.cell_center_y = false
	root.add_child(grid)
	return grid


func _add_wall_map(root: Node3D, map_name: String, cell_scale: float, chunk_path: String) -> GridMap:
	var wall := GridMap.new()
	wall.name = map_name
	if map_name == "WallMap":
		wall.unique_name_in_owner = true
	wall.mesh_library = load(WALL_LIB)
	wall.cell_scale = cell_scale
	wall.set_script(load(WALL_SCRIPT))
	if not chunk_path.is_empty() and ResourceLoader.exists(chunk_path):
		wall.set("forest_chunk_scene", load(chunk_path))
	root.add_child(wall)
	return wall


func _add_day_night(root: Node3D) -> void:
	var sun: DirectionalLight3D = root.get_node("SunLight") as DirectionalLight3D
	var world_env: WorldEnvironment = root.get_node("WorldEnvironment") as WorldEnvironment
	var day := Node3D.new()
	day.name = "DayLightCycle"
	if ResourceLoader.exists("res://Scripts/Environment/day_night_cycle.gd"):
		day.set_script(load("res://Scripts/Environment/day_night_cycle.gd"))
	var moon := DirectionalLight3D.new()
	moon.name = "MoonLight"
	moon.light_color = Color(0.665, 0.798, 1.0, 1.0)
	day.add_child(moon)
	if ResourceLoader.exists("res://resources/OutdoorParts/moon.glb"):
		var moon_mesh: Node3D = load("res://resources/OutdoorParts/moon.glb").instantiate() as Node3D
		moon_mesh.name = "moon"
		moon_mesh.position = Vector3(0, 0, -200)
		moon_mesh.rotation_degrees = Vector3(0, 180, 0)
		moon.add_child(moon_mesh)
	root.add_child(day)
	day.set("sun_light", sun)
	day.set("moon_light", moon)
	day.set("world_environment", world_env)
	if moon.has_node("moon"):
		day.set("moon_mesh_node", moon.get_node("moon"))
	day.set("moon_rotation_degrees", Vector3(0, 180, 0))


func _add_grass(root: Node3D, floor_map: GridMap) -> void:
	var grass := Node3D.new()
	grass.name = "GrassScatter"
	if ResourceLoader.exists("res://Scripts/Environment/grass_scatter.gd"):
		grass.set_script(load("res://Scripts/Environment/grass_scatter.gd"))
		grass.set("floor_map", floor_map)
		if ResourceLoader.exists("res://resources/meshes/grass_tuft.tres"):
			grass.set("grass_mesh", load("res://resources/meshes/grass_tuft.tres"))
		grass.set("tufts_per_tile", 3)
	root.add_child(grass)
	if grass.get_script() != null:
		var grass_ids: Array[int] = [1, 46]
		grass.set("valid_floor_item_ids", grass_ids)


func _add_level_title(root: Node3D) -> void:
	if not ResourceLoader.exists("res://Scenes/UI/LevelTitleTrigger.tscn"):
		return
	var title: Node3D = load("res://Scenes/UI/LevelTitleTrigger.tscn").instantiate() as Node3D
	title.name = "LevelTitle"
	title.set("level_title", "Castle Hollow")
	title.set("play_new_area_sound", true)
	root.add_child(title)


func _set_owner_recursive(node: Node, root_node: Node) -> void:
	for child: Node in node.get_children():
		if child == root_node:
			continue
		child.owner = root_node
		if child.scene_file_path.is_empty():
			_set_owner_recursive(child, root_node)
