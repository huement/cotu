# HUD.gd (attached to your HUD CanvasLayer)
extends CanvasLayer
class_name DungeonHUD

# References to UI elements using preferred SceneUniqueNodes format
@onready var minimap_indicator: TextureRect = %MinimapIndicator as TextureRect
@onready var minimap_container: SubViewportContainer = %SubViewportContainer as SubViewportContainer
@onready var compass_label: Label = %CompassLabel as Label

# Strongly-typed reference to the player grid-walker
@onready var player: Node3D = get_node("../Player") as Node3D

# 🎯 PORTRAIT MATRIX MAP: Gather your UI slots safely on launch
@onready var portrait_slots: Array[TextureRect] = [
	%Slot0_Portrait as TextureRect,
	%Slot1_Portrait as TextureRect,
	%Slot2_Portrait as TextureRect,
	%Slot3_Portrait as TextureRect,
	%Slot4_Portrait as TextureRect,
	%Slot5_Portrait as TextureRect
]

func _ready() -> void:
	_verify_ui_nodes()
	
	# Connect to event router for tile-by-tile coordinate changes
	if get_tree().root.has_node("SignalBus"):
		var signal_bus: Node = get_tree().root.get_node("SignalBus")
		signal_bus.party_moved.connect(_on_party_coordinates_changed)
		# LINK: Listen to the global event router for roster updates
		signal_bus.party_roster_updated.connect(_update_party_portraits)
		
	# Connect to the global singleton instance directly
	GameState.core_state_changed.connect(_on_game_state_changed)
	_on_game_state_changed(GameState.current_mode)
	
	# DIRECT SYNC: Pull active roster status immediately if GameState has booted up
	if GameState.current_party:
		_update_party_portraits(GameState.current_party.slots)

func _on_party_coordinates_changed(_grid_pos: Vector3i, facing_direction: String) -> void:
	_update_compass_text(facing_direction)
	_update_minimap_pointer(facing_direction)

## Reads incoming roster resources and draws textures into available HUD panels
func _update_party_portraits(active_slots: Array) -> void:
	var fallback_image_path: String = "res://ui/portrait.png"
	
	# Loop through our 6 UI boxes
	for i in range(6):
		if i >= active_slots.size() or active_slots[i] == null:
			# If a slot is mathematically empty, make it a blank box
			portrait_slots[i].texture = null
			continue
			
		var cat: CatCharacter = active_slots[i] as CatCharacter
		
		# 🎯 ASSET VERIFICATION CHECK: Fall back cleanly to your custom blank placeholder frame
		if cat.portrait_path.is_empty() or not ResourceLoader.exists(cat.portrait_path):
			portrait_slots[i].texture = load(fallback_image_path) as Texture
		else:
			portrait_slots[i].texture = load(cat.portrait_path) as Texture

## Ensures the UI doesn't crash silently if nodes are moved or missing
func _verify_ui_nodes() -> void:
	if not minimap_container:
		push_error("HUD: Unique Node %SubViewportContainer missing from scene tree!")
	if not compass_label:
		push_error("HUD: Unique Node %CompassLabel missing from scene tree!")
	if not player:
		push_warning("HUD: Player reference could not be resolved from relative path.")

## Modifies the global singleton state directly
func switch_state(new_state: int) -> void:
	GameState.current_mode = new_state as GameState.Mode

## Responds to the global singleton broadcast to alter interface rendering
func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		GameState.Mode.EXPLORING:
			if minimap_container: minimap_container.visible = true
			if compass_label: compass_label.visible = true
		GameState.Mode.BATTLE:
			if minimap_container: minimap_container.visible = false
			# This is where your phased initiative choice panels will overlay
		GameState.Mode.MANAGEMENT:
			if minimap_container: minimap_container.visible = false
		_:
			push_warning("HUD: Unhandled game state transition occurred.")

func _update_compass_text(direction: String) -> void:
	if not compass_label:
		return
		
	match direction.to_upper():
		"NORTH": compass_label.text = "NORTH"
		"WEST":  compass_label.text = "WEST"
		"SOUTH": compass_label.text = "SOUTH"
		"EAST":  compass_label.text = "EAST"
		_:       compass_label.text = "UNKWN"

func _update_minimap_pointer(direction: String) -> void:
	if not minimap_indicator:
		return
		
	var target_2d_angle: float = 0.0
	
	match direction.to_upper():
		"NORTH": target_2d_angle = 0.0
		"WEST":  target_2d_angle = -90.0
		"SOUTH": target_2d_angle = 180.0
		"EAST":  target_2d_angle = 90.0
		
	var tween: Tween = create_tween()
	tween.tween_property(minimap_indicator, "rotation_degrees", target_2d_angle, 0.15)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
