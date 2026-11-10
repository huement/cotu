extends Node2D
## Tiny game used to show the kit: fly through three zones of Sector 7 and pick up
## the data shards. Esc goes back to the main menu.

const DemoSetup := preload("res://addons/game_menu_kit/demo/demo_setup.gd")
const ORBITRON: FontFile = preload("res://addons/game_menu_kit/fonts/Orbitron-Variable.ttf")
const RAJDHANI: FontFile = preload("res://addons/game_menu_kit/fonts/Rajdhani-SemiBold.ttf")

const ZONE_WIDTH: float = 1600.0
const WORLD_SIZE: Vector2 = Vector2(4800.0, 1400.0)
const ZONES: Array[Dictionary] = [
	{"name": "Sector 7 · Orbital Dock", "color": Color("35f0ff")},
	{"name": "Sector 7 · Neon Market", "color": Color("ff3fb4")},
	{"name": "Sector 7 · Data Core", "color": Color("ffd36b")},
]
const SHARDS: Array[Vector2] = [
	Vector2(620, 380), Vector2(980, 1040), Vector2(1320, 560), Vector2(1450, 250),
	Vector2(1880, 900), Vector2(2240, 420), Vector2(2650, 1120), Vector2(3010, 610),
	Vector2(3420, 300), Vector2(3760, 980), Vector2(4150, 520), Vector2(4520, 1050),
]
const SPEED: float = 380.0

var player: Node2D
var camera: Camera2D
var collected: Array[int] = []

var _world: _World
var _place_label: Label
var _count_label: Label
var _shake: float = 0.0
var _zone: int = -1


func _enter_tree() -> void:
	DemoSetup.run()


func _ready() -> void:
	_world = _World.new()
	_world.level = self
	add_child(_world)
	player = _Ship.new()
	player.position = Vector2(300, 700)
	add_child(player)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	player.add_child(camera)
	_build_hud()
	_update_zone()


func _process(delta: float) -> void:
	var direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var boost: float = 2.0 if Input.is_action_pressed(&"jump") else 1.0
	player.position = (player.position + direction * SPEED * boost * delta).clamp(Vector2(40, 40), WORLD_SIZE - Vector2(40, 40))
	if direction.length() > 0.1:
		player.rotation = lerp_angle(player.rotation, direction.angle(), minf(1.0, delta * 12.0))
	player.set(&"thrust", direction.length() * boost)
	for i: int in SHARDS.size():
		if not collected.has(i) and player.position.distance_to(SHARDS[i]) < 46.0:
			_collect(i)
	_update_zone()
	# Camera shake follows the "Camera shake" setting.
	_shake = maxf(0.0, _shake - delta * 3.0)
	var amount: float = _shake * float(MenuKit.settings.get_value("camera/shake", 100.0)) / 100.0
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * amount
	_world.queue_redraw()


func _collect(index: int) -> void:
	collected.append(index)
	_shake = 0.6
	MenuKit.sounds.play(&"done")
	MenuKit.vibrate(0, 0.3, 0.1, 0.15)
	_update_count()


## Called by the kit when saving.
func menu_kit_save() -> Dictionary:
	return {"player": player.position, "collected": collected}


## Called by the kit after loading a save.
func menu_kit_load(data: Dictionary) -> void:
	player.position = data.get("player", player.position)
	camera.reset_smoothing.call_deferred()
	collected.clear()
	for index: Variant in data.get("collected", []):
		collected.append(int(index))
	_update_count()
	_update_zone()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		MenuKit.go_to_main_menu()


func _update_zone() -> void:
	var zone: int = clampi(int(player.position.x / ZONE_WIDTH), 0, ZONES.size() - 1)
	if zone == _zone:
		return
	_zone = zone
	_place_label.text = tr(String(ZONES[zone]["name"]))
	_place_label.add_theme_color_override("font_color", ZONES[zone]["color"] as Color)


func _update_count() -> void:
	if collected.size() >= SHARDS.size():
		_count_label.text = tr("All shards recovered")
	else:
		_count_label.text = "%s  %d / %d" % [tr("Data shards"), collected.size(), SHARDS.size()]


func _build_hud() -> void:
	var hud: CanvasLayer = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	_place_label = _label(RAJDHANI, 22, 5)
	_place_label.position = Vector2(40, 30)
	root.add_child(_place_label)
	_count_label = _label(ORBITRON, 20, 2)
	_count_label.position = Vector2(40, 62)
	_count_label.add_theme_color_override("font_color", Color("f4fdff"))
	root.add_child(_count_label)
	var hint: Label = _label(RAJDHANI, 17, 3)
	hint.text = "WASD / %s   ·   %s: %s   ·   Esc: %s" % [tr("Move"), "Space", tr("Boost"), tr("Main Menu")]
	hint.add_theme_color_override("font_color", Color(0.54, 0.61, 0.76, 0.9))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE, 40)
	hint.position.y -= 10
	root.add_child(hint)
	_update_count()


func _label(font: Font, size: int, spacing: int) -> Label:
	var label: Label = Label.new()
	var variation: FontVariation = FontVariation.new()
	variation.base_font = font
	variation.spacing_glyph = spacing
	if font == ORBITRON:
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	label.add_theme_font_override("font", variation)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.uppercase = true
	return label


## Grid floor, zone borders, buildings and shards.
class _World:
	extends Node2D

	var level: Node2D
	var _blocks: Array[Rect2] = []

	func _ready() -> void:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 7
		for i: int in 34:
			var size: Vector2 = Vector2(rng.randf_range(90, 260), rng.randf_range(60, 200))
			var at: Vector2 = Vector2(rng.randf_range(0, WORLD_SIZE.x - size.x), rng.randf_range(0, WORLD_SIZE.y - size.y))
			var rect: Rect2 = Rect2(at, size)
			var free: bool = true
			for shard: Vector2 in SHARDS:
				if rect.grow(70).has_point(shard):
					free = false
			if free and not rect.grow(120).has_point(Vector2(300, 700)):
				_blocks.append(rect)

	func _draw() -> void:
		var time: float = Time.get_ticks_msec() / 1000.0
		draw_rect(Rect2(Vector2(-400, -400), WORLD_SIZE + Vector2(800, 800)), Color("05030d"))
		for z: int in ZONES.size():
			var color: Color = ZONES[z]["color"]
			var zone: Rect2 = Rect2(z * ZONE_WIDTH, 0, ZONE_WIDTH, WORLD_SIZE.y)
			draw_rect(zone, Color(color, 0.025))
			var x: float = zone.position.x
			while x <= zone.end.x:
				var major: bool = int(x) % 400 == 0
				draw_line(Vector2(x, 0), Vector2(x, WORLD_SIZE.y), Color(color, 0.16 if major else 0.06), 2.0 if major else 1.0)
				x += 80.0
			var y: float = 0.0
			while y <= WORLD_SIZE.y:
				var major_row: bool = int(y) % 400 == 0
				draw_line(Vector2(zone.position.x, y), Vector2(zone.end.x, y), Color(color, 0.16 if major_row else 0.06),
					2.0 if major_row else 1.0)
				y += 80.0
			var zone_name: String = tr(String(ZONES[z]["name"])).get_slice("· ", 1).to_upper()
			draw_string(ORBITRON, Vector2(zone.position.x + 80, WORLD_SIZE.y - 90), zone_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(color, 0.12))
		for z: int in range(1, ZONES.size()):
			var x_border: float = z * ZONE_WIDTH
			for k: int in 4:
				draw_line(Vector2(x_border, 0), Vector2(x_border, WORLD_SIZE.y), Color("ff3fb4", 0.08), 6.0 + k * 6.0)
			draw_line(Vector2(x_border, 0), Vector2(x_border, WORLD_SIZE.y), Color("ff3fb4", 0.8), 2.0)
		for i: int in _blocks.size():
			var block: Rect2 = _blocks[i]
			var color: Color = ZONES[clampi(int(block.get_center().x / ZONE_WIDTH), 0, 2)]["color"]
			draw_rect(block, Color(color, 0.05))
			for k: int in 3:
				draw_rect(block.grow(2 + k * 3), Color(color, 0.05), false, 3.0)
			draw_rect(block, Color(color, 0.7), false, 2.0)
			var windows: int = int(block.size.x / 30)
			for w: int in windows:
				if (i * 7 + w * 3) % 5 < 2:
					draw_rect(Rect2(block.position + Vector2(12 + w * 30, 14), Vector2(12, 6)), Color(color, 0.5))
		var shards: Array = SHARDS
		var collected: Array = level.get(&"collected")
		for i: int in shards.size():
			if collected.has(i):
				continue
			var at: Vector2 = shards[i]
			var pulse: float = 0.5 + 0.5 * sin(time * 3.0 + i)
			draw_set_transform(at, time * 1.4 + i, Vector2.ONE)
			for k: int in 4:
				var s: float = 26.0 + k * 9.0 + pulse * 6.0
				draw_colored_polygon(PackedVector2Array([Vector2(0, -s), Vector2(s * 0.62, 0), Vector2(0, s), Vector2(-s * 0.62, 0)]),
					Color("35f0ff", 0.06))
			var p: float = 18.0
			draw_colored_polygon(PackedVector2Array([Vector2(0, -p), Vector2(p * 0.62, 0), Vector2(0, p), Vector2(-p * 0.62, 0)]),
				Color("bff9ff"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The player's ship: a glowing arrow with an engine flame.
class _Ship:
	extends Node2D

	var thrust: float = 0.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var flame: float = (14.0 + 26.0 * thrust) * (0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.05))
		var body: PackedVector2Array = PackedVector2Array([Vector2(30, 0), Vector2(-20, -20), Vector2(-10, 0), Vector2(-20, 20)])
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -7), Vector2(-12 - flame, 0), Vector2(-12, 7)]), Color("ff3fb4", 0.9))
		for k: int in 5:
			var grow: float = 1.0 + 0.22 * (k + 1)
			var scaled: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in body:
				scaled.append(point * grow)
			draw_colored_polygon(scaled, Color("35f0ff", 0.07))
		draw_colored_polygon(body, Color("0b1a2e"))
		var outline: PackedVector2Array = body.duplicate()
		outline.append(body[0])
		draw_polyline(outline, Color("35f0ff"), 3.0, true)
