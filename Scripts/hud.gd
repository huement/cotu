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
@onready var action_bar_anchor: Control = %ActionBarAnchor as Control
@onready var right_sidebar_anchor: Control = %RightSidebarAnchor as Control

# Battle HUD Overlay Reference
@onready var battle_hud: Control = %BattleHUD as Control

# Strongly-typed reference to the player grid-walker
@onready var player: Node3D = get_node("../Player") as Node3D

# 🎯 PORTRAIT MATRIX MAP: 6-Slot Exploration Party Portraits
@onready var portrait_slots: Array[TextureRect] = [
	%Slot0_Portrait as TextureRect,
	%Slot1_Portrait as TextureRect,
	%Slot2_Portrait as TextureRect,
	%Slot3_Portrait as TextureRect,
	%Slot4_Portrait as TextureRect,
	%Slot5_Portrait as TextureRect
]


# ==============================================================================
# 2. LIFECYCLE & INITIALIZATION
# ==============================================================================
func _ready() -> void:
	_verify_ui_nodes()
	
	if battle_hud:
		battle_hud.hide()
		
	# Connect to Autoload SignalBus events
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb:
		if sb.has_signal("party_moved"):
			sb.party_moved.connect(_on_party_coordinates_changed)
		if sb.has_signal("party_roster_updated"):
			sb.party_roster_updated.connect(_update_party_portraits)
		if sb.has_signal("combat_started"):
			sb.combat_started.connect(_on_combat_started)
		if sb.has_signal("combat_ended"):
			sb.combat_ended.connect(_on_combat_ended)
	
	_setup_portrait_click_listeners()
		
	# Connect to global GameState manager
	if Engine.has_singleton("GameState") or get_tree().root.has_node("GameState"):
		GameState.core_state_changed.connect(_on_game_state_changed)
		_on_game_state_changed(GameState.current_mode)
		
		if GameState.current_party:
			_update_party_portraits(GameState.current_party.slots)


# ==============================================================================
# 3. HUD STATE & VISIBILITY TOGGLING
# ==============================================================================
func _on_combat_started(enemy_data: EnemyData = null, player_party: Array = []) -> void:
	_set_exploration_ui_visible(false)
	
	# Fetch live party from GameState if an empty array was provided
	var active_party: Array = player_party
	if active_party.is_empty() and (Engine.has_singleton("GameState") or get_tree().root.has_node("GameState")):
		if GameState.current_party:
			active_party = GameState.current_party.slots

	if battle_hud:
		battle_hud.show()
		# Direct data push to BattleHUD
		if battle_hud.has_method("_on_combat_started"):
			battle_hud._on_combat_started(enemy_data, active_party)

func _on_combat_ended(_victory: bool) -> void:
	if battle_hud:
		battle_hud.hide()
	_set_exploration_ui_visible(true)

## Cleanly toggles exploration overlays (renamed parameter prevents shadowing base CanvasLayer method)
func _set_exploration_ui_visible(show_ui: bool) -> void:
	if minimap_anchor: minimap_anchor.visible = show_ui
	if compass_label: compass_label.visible = show_ui
	if cockpit_background: cockpit_background.visible = show_ui
	if top_bar: top_bar.visible = show_ui
	if right_sidebar_anchor: right_sidebar_anchor.visible = show_ui
	if action_bar_anchor: action_bar_anchor.visible = show_ui


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


# ==============================================================================
# 5. PARTY ROSTER & PORTRAIT MANAGEMENT
# ==============================================================================
func _setup_portrait_click_listeners() -> void:
	for i in range(portrait_slots.size()):
		var slot_rect: TextureRect = portrait_slots[i]
		if slot_rect:
			slot_rect.mouse_filter = Control.MOUSE_FILTER_STOP
			var click_callable: Callable = _on_portrait_gui_input.bind(i)
			if not slot_rect.gui_input.is_connected(click_callable):
				slot_rect.gui_input.connect(click_callable)

func _on_portrait_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if GameState.current_party and slot_index < GameState.current_party.slots.size():
			if GameState.current_party.slots[slot_index] != null:
				var sb: Node = get_tree().root.get_node_or_null("SignalBus")
				if sb and sb.has_signal("portrait_clicked"):
					sb.portrait_clicked.emit(slot_index)

func _update_party_portraits(active_slots: Array) -> void:
	var fallback_image_path: String = "res://ui/portrait.png"
	
	for i in range(6):
		if i >= active_slots.size() or active_slots[i] == null:
			if portrait_slots[i]: portrait_slots[i].texture = null
			continue
			
		var cat: CatCharacter = active_slots[i] as CatCharacter
		if cat:
			if "portrait_path" in cat and not cat.portrait_path.is_empty() and ResourceLoader.exists(cat.portrait_path):
				portrait_slots[i].texture = load(cat.portrait_path) as Texture
			elif "portrait_texture" in cat and cat.portrait_texture:
				portrait_slots[i].texture = cat.portrait_texture
			elif ResourceLoader.exists(fallback_image_path):
				portrait_slots[i].texture = load(fallback_image_path) as Texture


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
			if battle_hud: battle_hud.hide()
		GameState.Mode.BATTLE:
			_set_exploration_ui_visible(false)
			if battle_hud: battle_hud.show()
		GameState.Mode.MANAGEMENT:
			_set_exploration_ui_visible(false)

# Debug hotkeys: 'B' toggles Battle Mode, 'H' triggers Chevron Flash FX
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			var sb: Node = get_tree().root.get_node_or_null("SignalBus")
			if battle_hud and battle_hud.visible:
				if sb and sb.has_signal("combat_ended"):
					sb.combat_ended.emit(true)
				else:
					_on_combat_ended(true)
			else:
				var mock_enemy: EnemyData = load("res://Data/Enemies/ZombieCat_Base.tres") as EnemyData
				var active_party: Array = GameState.current_party.slots if (Engine.has_singleton("GameState") or get_tree().root.has_node("GameState")) and GameState.current_party else []
				
				if sb and sb.has_signal("combat_started"):
					sb.combat_started.emit(mock_enemy, active_party)
				else:
					_on_combat_started(mock_enemy, active_party)
		
		elif event.keycode == KEY_H and battle_hud and battle_hud.visible:
			var sb: Node = get_tree().root.get_node_or_null("SignalBus")
			if sb and sb.has_signal("chevron_flash_requested"):
				sb.chevron_flash_requested.emit(true)
