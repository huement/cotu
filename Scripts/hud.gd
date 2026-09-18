# res://Scripts/hud.gd
class_name DungeonHUD
extends CanvasLayer

# ==============================================================================
# 1. SCENE UNIQUE NODE REFERENCES (% Prefix)
# ==============================================================================
@onready var minimap_indicator: TextureRect = %MinimapIndicator as TextureRect
@onready var minimap_container: SubViewportContainer = %SubViewportContainer as SubViewportContainer
@onready var compass_label: Label = %CompassLabel as Label
@onready var minimap_anchor: Control = %MinimapAnchor as Control

@onready var main_hud_layout: Control = %MainHUDLayout as Control
@onready var cockpit_background: TextureRect = %CockpitBackground as TextureRect
@onready var top_bar: TextureRect = $MainHUDLayout/TopBar as TextureRect
@onready var right_sidebar_anchor: Control = %RightSidebarAnchor as Control

# Battle HUD Overlay Reference
@onready var battle_hud: Control = %BattleHUD as Control
@onready var action_bar_anchor: Control = %ActionBarAnchor as Control
@onready var edge_flash: TextureRect = %EdgeFlash as TextureRect
@onready var enemy_in_range: ColorRect = %EnemyInRange as ColorRect

# Strongly-typed reference to the player grid-walker
@onready var player: Node3D = get_node("../Player") as Node3D

# 🎯 PORTRAIT MATRIX MAP: 6-Slot Exploration Party Portraits
@onready var portrait_slots: Array[PartySlotPortrait] = [
	%Slot0_Portrait as PartySlotPortrait,
	%Slot1_Portrait as PartySlotPortrait,
	%Slot2_Portrait as PartySlotPortrait,
	%Slot3_Portrait as PartySlotPortrait,
	%Slot4_Portrait as PartySlotPortrait,
	%Slot5_Portrait as PartySlotPortrait,
]

var _proximity_step_count: int = 0

# ==============================================================================
# 2. LIFECYCLE & INITIALIZATION
# ==============================================================================
func _ready() -> void:
	_verify_ui_nodes()
	_initialize_ui_state()
	_setup_portrait_click_listeners()
	_connect_signal_bus()
	_connect_game_state()


## Initial visual defaults for HUD components
func _initialize_ui_state() -> void:
	if is_instance_valid(battle_hud):
		battle_hud.hide()

	if is_instance_valid(edge_flash):
		edge_flash.hide()

	_update_enemy_in_range_indicator(0)


## Single, safe entry point for all central SignalBus subscriptions
func _connect_signal_bus() -> void:
	var sb: Node = SignalBus if is_instance_valid(SignalBus) else get_tree().root.get_node_or_null("SignalBus")
	if not is_instance_valid(sb):
		return

	_connect_signal_safe(sb, &"party_moved", _on_party_coordinates_changed)
	_connect_signal_safe(sb, &"party_roster_updated", _update_party_portraits)
	_connect_signal_safe(sb, &"combat_started", on_combat_started)
	_connect_signal_safe(sb, &"combat_ended", _on_combat_ended)
	_connect_signal_safe(sb, &"edge_flash_requested", _on_edge_flash_requested)
	_connect_signal_safe(sb, &"enemy_proximity_changed", _on_enemy_proximity_changed)


## Binds global GameState events and synchronizes initial party/mode state
func _connect_game_state() -> void:
	var gs: Node = GameState if is_instance_valid(GameState) else get_tree().root.get_node_or_null("GameState")
	if not is_instance_valid(gs):
		return

	_connect_signal_safe(gs, &"core_state_changed", _on_game_state_changed)

	if "current_mode" in gs:
		_on_game_state_changed(gs.current_mode)

	if "current_party" in gs and is_instance_valid(gs.current_party) and "slots" in gs.current_party:
		_update_party_portraits(gs.current_party.slots)


## Helper utility to check signal presence and guard against duplicate connections
func _connect_signal_safe(target: Node, signal_name: StringName, callback: Callable) -> void:
	if target.has_signal(signal_name):
		var sig: Signal = target.get(signal_name)
		if not sig.is_connected(callback):
			sig.connect(callback)


## Cleanly toggles exploration overlays (renamed parameter prevents shadowing base CanvasLayer method)
func _set_exploration_ui_visible(show_ui: bool) -> void:
	if minimap_anchor:
		minimap_anchor.visible = show_ui
	if compass_label:
		compass_label.visible = show_ui
	if cockpit_background:
		cockpit_background.visible = show_ui
	if top_bar:
		top_bar.visible = show_ui
	if right_sidebar_anchor:
		right_sidebar_anchor.visible = show_ui
	if action_bar_anchor:
		action_bar_anchor.visible = show_ui


# ==============================================================================
# 4. COMPASS & MINIMAP LOGIC
# ==============================================================================
func _on_party_coordinates_changed(_grid_pos: Vector3i, facing_direction: String) -> void:
	_update_compass_text(facing_direction)
	_update_minimap_pointer(facing_direction)


func _update_compass_text(direction: String) -> void:
	if not compass_label:
		return

	match direction.to_upper():
		"NORTH":
			compass_label.text = "NORTH"
		"WEST":
			compass_label.text = "WEST"
		"SOUTH":
			compass_label.text = "SOUTH"
		"EAST":
			compass_label.text = "EAST"
		_:
			compass_label.text = "UNKWN"


func _update_minimap_pointer(direction: String) -> void:
	if not minimap_indicator:
		return

	var target_2d_angle: float = 0.0
	match direction.to_upper():
		"NORTH":
			target_2d_angle = 0.0
		"WEST":
			target_2d_angle = -90.0
		"SOUTH":
			target_2d_angle = 180.0
		"EAST":
			target_2d_angle = 90.0

	var tween: Tween = create_tween()
	tween.tween_property(minimap_indicator, "rotation_degrees", target_2d_angle, 0.15) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)


# ==============================================================================
# 5. PARTY ROSTER & PORTRAIT MANAGEMENT
# ==============================================================================
## Binds GUI input events directly to each PartySlotPortrait component
func _setup_portrait_click_listeners() -> void:
	for i in range(portrait_slots.size()):
		# Updated type from TextureRect to PartySlotPortrait (Control)
		var slot_component: PartySlotPortrait = portrait_slots[i]

		if slot_component:
			# Ensure the slot container catches mouse clicks
			slot_component.mouse_filter = Control.MOUSE_FILTER_STOP

			# Cleanly bind the slot index `i` to our handler method
			var click_callable: Callable = _on_portrait_gui_input.bind(i)

			if not slot_component.gui_input.is_connected(click_callable):
				slot_component.gui_input.connect(click_callable)


func _on_portrait_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if GameState.current_party and slot_index < GameState.current_party.slots.size():
			if GameState.current_party.slots[slot_index] != null:
				var sb: Node = get_tree().root.get_node_or_null("SignalBus")
				if sb and sb.has_signal("portrait_clicked"):
					sb.portrait_clicked.emit(slot_index)
					if is_instance_valid(AudioManager):
						AudioManager.play_button_press()


## Reads incoming roster resources and delegates rendering directly to component slots
func _update_party_portraits(active_slots: Array) -> void:
	for i in range(6):
		# 1. Null Guard: Verify the UI slot component exists in the scene tree
		if i >= portrait_slots.size() or portrait_slots[i] == null:
			continue

		# 2. Safely resolve the CatCharacter resource
		var cat: CatCharacter = null
		if i < active_slots.size() and active_slots[i] is CatCharacter:
			cat = active_slots[i] as CatCharacter

		# 3. Delegate to the PartySlotPortrait component
		if portrait_slots[i].has_method("setup_slot"):
			portrait_slots[i].setup_slot(cat)


# ==============================================================================
# 6. HELPER & DEBUG TESTING
# ==============================================================================
func _verify_ui_nodes() -> void:
	if not minimap_container:
		push_error("HUD: Unique Node %SubViewportContainer missing from scene tree!")
	if not compass_label:
		push_error("HUD: Unique Node %CompassLabel missing from scene tree!")


func switch_state(new_state: int) -> void:
	GameState.current_mode = new_state as GameState.Mode


func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		GameState.Mode.EXPLORING:
			_set_exploration_ui_visible(true)
			if battle_hud:
				battle_hud.hide()
		GameState.Mode.BATTLE:
			_set_exploration_ui_visible(false)
			if battle_hud:
				battle_hud.show()
		GameState.Mode.MANAGEMENT:
			_set_exploration_ui_visible(false)


# ==============================================================================
# 7. Combat Functions
# ==============================================================================
func on_combat_started(enemy_data_or_group: Variant = null, player_party: Array = []) -> void:
	_set_exploration_ui_visible(false)

	var active_party: Array = player_party
	if active_party.is_empty() and (Engine.has_singleton("GameState") or get_tree().root.has_node("GameState")):
		if GameState.current_party:
			active_party = GameState.current_party.slots

	if battle_hud:
		battle_hud.show()
		if battle_hud.has_method("on_combat_started"):
			battle_hud.on_combat_started(enemy_data_or_group, active_party)


func _on_combat_ended(_victory: bool) -> void:
	if battle_hud:
		battle_hud.hide()
	_set_exploration_ui_visible(true)


## Tweens EnemyInRange indicator width, position, and color based on threat tier
func _update_enemy_in_range_indicator(tier: int) -> void:
	if not is_instance_valid(enemy_in_range):
		return

	var target_width: float = 10.0
	var target_x: float = 865.0
	var target_color := Color("46e689") # Green (#46e689)

	match tier:
		1: # Nearby (3 to 5 tiles)
			target_width = 50.0
			target_x = 845.0
			target_color = Color("ffff53") # Yellow (#ffff53)
		2: # Close (1 to 2 tiles)
			target_width = 100.0
			target_x = 820.0
			target_color = Color("ff3366") # Red (#ff3366)

	target_color.a = 0.4 # 40% Opacity

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(enemy_in_range, "size:x", target_width, 0.2) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy_in_range, "position:x", target_x, 0.2) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy_in_range, "color", target_color, 0.2) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)


func _on_edge_flash_requested(color: Color, duration: float = 0.4) -> void:
	var alpha: float = color.a if color.a > 0.0 else 0.8
	_trigger_edge_flash(color, duration, alpha)


func _on_enemy_proximity_changed(_min_dist: int, current_tier: int) -> void:
	_update_enemy_in_range_indicator(current_tier)
	_handle_proximity_edge_flash(current_tier)


## Triggers proportional edge vignette flashes based on current threat tier
func _handle_proximity_edge_flash(tier: int) -> void:
	_proximity_step_count += 1

	match tier:
		1: # Yellow alert: Flashes every 2 steps at soft 35% opacity
			if _proximity_step_count % 2 == 1:
				_trigger_edge_flash(Color("ffff53"), 0.35, 0.35)
		2: # Red alert: Flashes every step at intense 75% opacity
			_trigger_edge_flash(Color("ff3366"), 0.3, 0.75)
		_: # Safe tier: Reset counter
			_proximity_step_count = 0


## Helper to cleanly animate the edge flash vignette without overlapping tweens
func _trigger_edge_flash(color: Color, duration: float = 0.4, max_alpha: float = 0.8) -> void:
	if not is_instance_valid(edge_flash):
		return

	var flash_color: Color = color
	flash_color.a = max_alpha

	edge_flash.modulate = flash_color
	edge_flash.show()

	var tween: Tween = create_tween()
	tween.tween_property(edge_flash, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_callback(edge_flash.hide)
