extends Control

## Step distance mapping in meters matching your CSG map block profiles
const TILE_SIZE: float = 3.0
const MOVE_DURATION: float = 0.22

# Clean, modern declarations for the top of main_gameplay.gd:
@onready var party_hud: HBoxContainer = %PartyHUD
@onready var game_log: RichTextLabel = %GameLog
@onready var compass_label: Label = %CompassLabel

# Bypasses the deep layout hierarchy completely!
@onready var player_node: Player = %GridPlayer
@onready var wall_ray: RayCast3D = %WallCheck
@onready var world_space: Node3D = %WorldSpace # Reference to the Node3D where the world will be instantiated

# Tactical Orientation variables
var current_heading: Vector3 = Vector3.FORWARD
var action_locked: bool = false

func _ready() -> void:
	# 1. Wire event system listeners
	SignalBus.party_member_stats_changed.connect(_on_roster_slot_mutated)
	SignalBus.game_log_emitted.connect(_on_narrative_log_received)
	
	# 2. Build the bottom party frames
	_build_hud_displays()
	
	# 3. Load and setup the world, player, and minimap
	_load_and_setup_world()
	
	# 4. Synchronize player 3D transform mappings (after world setup)
	# These now run after _load_and_setup_world to ensure player_node has its final transform
	_sync_ray_heading()
	_update_compass_hud()
	
	# 5. Print initial deployment text
	_write_terminal_line("[color=#36ffcf]SYSTEM: Starship vault depressurized. Recon squad deployed.[/color]")
	var active_cats: Array[CatCharacter] = GameState.get_living_party()
	_write_terminal_line("Active Felines: %d ready for extraction duty." % active_cats.size())

func _load_and_setup_world() -> void:
	# Step 1: Level Injection Architecture
	var world_scene_path: String = "res://scenes/world/main.tscn"
	var world_scene_resource: Resource = ResourceLoader.load(world_scene_path)
	
	if world_scene_resource == null:
		push_error("Failed to load world scene: %s" % world_scene_path)
		SignalBus.game_log_emitted.emit("[color=red]ERROR: Failed to load world scene. Check path: %s[/color]" % world_scene_path)
		return
		
	if not world_scene_resource is PackedScene:
		push_error("Loaded resource is not a PackedScene: %s" % world_scene_path)
		SignalBus.game_log_emitted.emit("[color=red]ERROR: World scene is not a PackedScene: %s[/color]" % world_scene_path)
		return

	# Clear out any placeholder content in WorldSpace (e.g., the old TestingArena)
	for child in world_space.get_children():
		child.queue_free()

	var world_instance: Node3D = (world_scene_resource as PackedScene).instantiate()
	world_space.add_child(world_instance)
	
	# Pass the GridPlayer to the world instance
	if world_instance.has_method("set_external_player"):
		world_instance.set_external_player(player_node as Player)
	else:
		push_warning("World scene lacks 'set_external_player' method. Player may not be fully integrated.")

	# Step 2: Player Spawn Handling
	var spawn_point: Marker3D = world_instance.find_child("SpawnPoint", true, false) as Marker3D
	if spawn_point:
		player_node.global_transform = spawn_point.global_transform
		current_heading = -player_node.transform.basis.z.normalized()
		
		# Update global GameState with player's initial position and direction
		GameState.party_position = Vector3i(player_node.global_position / TILE_SIZE)
		GameState.party_direction = Vector3i(current_heading.round())
		
		_write_terminal_line("Player spawned at %s with heading %s" % [str(GameState.party_position), str(GameState.party_direction)])
	else:
		push_warning("SpawnPoint not found in world scene: %s. Player may be at default position." % world_scene_path)
		SignalBus.game_log_emitted.emit("[color=yellow]WARNING: SpawnPoint not found in world. Player may be at default.[/color]")

	# Step 3: Hook up the Minimap
	if minimap_overlay and world_instance.has_method("get_grid_occupancy"):
		var world_occupancy = world_instance.call("get_grid_occupancy")
		if world_occupancy != null:
			if minimap_overlay.has_method("set_occupancy"):
				minimap_overlay.call("set_occupancy", world_occupancy)
			_trigger_minimap_refresh()
		else:
			push_warning("World scene did not return valid grid occupancy for minimap.")
			SignalBus.game_log_emitted.emit("[color=yellow]WARNING: Minimap could not get world occupancy data.[/color]")
	else:
		push_warning("MinimapOverlay not available or world scene lacks 'get_grid_occupancy' method.")
		SignalBus.game_log_emitted.emit("[color=yellow]WARNING: Minimap setup incomplete. Check 'get_grid_occupancy' in world scene.[/color]")


## Loops through active slots to generate internal indicators (Name/HP labels)
func _build_hud_displays() -> void:
	var slot_nodes: Array[Node] = party_hud.get_children()
	
	for i in range(6):
		var container: PanelContainer = slot_nodes[i] as PanelContainer
		
		# Clear out fallback test nodes
		for child in container.get_children():
			child.queue_free()
			
		# Construct standard status typography layout stack
		var vbox := VBoxContainer.new()
		vbox.name = "StatVBox"
		
		var name_lbl := Label.new()
		name_lbl.name = "NameLabel"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)
		
		var hp_lbl := Label.new()
		hp_lbl.name = "HPLabel"
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(hp_lbl)
		
		var row_lbl := Label.new()
		row_lbl.name = "RowLabel"
		row_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Enforce Front (0-2) and Back (3-5) row boundaries
		if i <= 2:
			row_lbl.text = "[ FRONT ]"
			row_lbl.add_theme_color_override("font_color", Color.CRIMSON)
		else:
			row_lbl.text = "[ BACK ]"
			row_lbl.add_theme_color_override("font_color", Color.MEDIUM_AQUAMARINE)
		vbox.add_child(row_lbl)
		
		container.add_child(vbox)
		
		# Draw the current space cat details if the slot is populated
		_on_roster_slot_mutated(i, GameState.party[i])

## Triggers when a character changes or is initialized
func _on_roster_slot_mutated(slot_index: int, cat: CatCharacter) -> void:
	if slot_index < 0 or slot_index >= 6: 
		return
		
	var slot_nodes: Array[Node] = party_hud.get_children()
	var container: PanelContainer = slot_nodes[slot_index] as PanelContainer
	var vbox: VBoxContainer = container.get_node_or_null("StatVBox") as VBoxContainer
	
	if not vbox: return
	
	if cat == null:
		vbox.get_node("NameLabel").text = "- EMPTY -"
		vbox.get_node("HPLabel").text = "HP: 0/0"
		container.modulate = Color(1, 1, 1, 0.35)
	else:
		vbox.get_node("NameLabel").text = cat.name
		vbox.get_node("HPLabel").text = "HP: %d/%d" % [cat.current_hp, cat.max_hp]
		container.modulate = Color.WHITE

# =============================================================================
# 🗺️ GRID INPUT INTERPOLATION HANDLING
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if action_locked: 
		return
		
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		_execute_grid_step(current_heading)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_backward"):
		_execute_grid_step(-current_heading)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("turn_left"):
		_execute_grid_rotation(90.0)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("turn_right"):
		_execute_grid_rotation(-90.0)

# Add your overlay hook alongside your unique UI node links:
@onready var minimap_overlay: Control = %MinimapOverlay

# Update your movement block to pass position vectors to the global state and radar:
func _execute_grid_step(step_vector: Vector3) -> void:
	wall_ray.target_position = step_vector.normalized() * TILE_SIZE
	wall_ray.force_raycast_update()
	
	if wall_ray.is_colliding():
		SignalBus.game_log_emitted.emit("Hiss! Bulkhead wall blocked navigation.")
		return
		
	action_locked = true
	var target_destination: Vector3 = player_node.position + (step_vector * TILE_SIZE)
	
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player_node, "position", target_destination, MOVE_DURATION)
	tween.finished.connect(func(): 
		action_locked = false
		
		# 1. Update global coordinates for downstream battle engines
		GameState.party_position = Vector3i(player_node.position / TILE_SIZE)
		
		SignalBus.game_log_emitted.emit("Step taken. Coordinates: %d, %d" % [GameState.party_position.x, GameState.party_position.z])
		
		# 2. Fire update on your specific minimap overlay script
		_trigger_minimap_refresh()
	)

# Update your rotation block to sync turning updates:
func _execute_grid_rotation(degrees: float) -> void:
	action_locked = true
	var target_radians: float = player_node.rotation.y + deg_to_rad(degrees)
	
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player_node, "rotation:y", target_radians, MOVE_DURATION)
	tween.finished.connect(func():
		action_locked = false
		current_heading = -player_node.transform.basis.z.normalized()
		
		# Update global heading configurations
		GameState.party_direction = Vector3i(current_heading.round())
		
		_sync_ray_heading()
		_update_compass_hud()
		_trigger_minimap_refresh()
	)

## Defensive pipeline execution to refresh your overlay component safely
func _trigger_minimap_refresh() -> void:
	if not minimap_overlay: 
		return
		
	# Adapts to whatever update signature your custom overlay script expects
	if minimap_overlay.has_method("refresh_map"):
		minimap_overlay.refresh_map()
	elif minimap_overlay.has_method("update_position"):
		minimap_overlay.update_position(GameState.party_position, GameState.party_direction)

func _sync_ray_heading() -> void:
	wall_ray.target_position = Vector3.FORWARD * TILE_SIZE

# =============================================================================
# 🛠️ TERMINAL LOG & NARRATIVE HELPERS
# =============================================================================

func _on_narrative_log_received(message: String) -> void:
	_write_terminal_line(message)

func _write_terminal_line(text_line: String) -> void:
	if game_log:
		game_log.append_text("\n" + text_line)

func _update_compass_hud() -> void:
	if not compass_label: return
	
	var heading_text: String = "UNKNOWN"
	
	# Round to avoid decimal tracking noise from vector conversions
	var forward_dir: Vector3 = current_heading.round()
	
	# Godot 3D Space Coordinates: -Z is North, +Z is South, +X is East, -X is West
	if forward_dir.is_equal_approx(Vector3.FORWARD):
		heading_text = "NORTH"
	elif forward_dir.is_equal_approx(Vector3.BACK):
		heading_text = "SOUTH"
	elif forward_dir.is_equal_approx(Vector3.RIGHT):
		heading_text = "EAST"
	elif forward_dir.is_equal_approx(Vector3.LEFT):
		heading_text = "WEST"
		
	compass_label.text = "HEADING: " + heading_text

# Inside your res://scenes/overlays/minimap_overlay.gd script:
func refresh_map() -> void:
	var _current_pos: Vector3i = GameState.party_position
	var _current_dir: Vector3i = GameState.party_direction
	# Paint your radar steps or grids here based on these persistent metrics!
