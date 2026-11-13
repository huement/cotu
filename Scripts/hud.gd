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
@onready var time_label: Label = %DaytimeLabel
@onready var gold_label: Label = %GoldLabel as Label

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

# Nine HUD Voice Assistant Reference
@onready var nine_hud: Control = %NineHud as Control

# In-game menu (Quit / Settings / Save / Party / Load / Help)
const HUD_GAME_MENU_SCENE: PackedScene = preload("res://Scenes/GameMenus/HudGameMenu.tscn")
const HUD_SHARD_MENU_SCENE: PackedScene = preload("res://Scenes/GameMenus/HudShardMenu.tscn")
## Seconds before the "MAIN MENU" / "SHARDS" hint next to the menu buttons fades out.
const GAME_MENU_LABEL_DELAY: float = 5.0
const GAME_MENU_LABEL_FADE: float = 1.0
## Exploration-only menu button group (hidden in battle; BattleHUD has its own %GameMenuButton).
@onready var game_menu_anchor: Control = %GameMenuAnchor as Control
@onready var game_menu_button: TextureButton = %GameMenuButton as TextureButton
@onready var game_menu_button_label: Label = %GameMenuButtonLabel as Label
var game_menu: HudGameMenu = null
var _game_menu_label_tween: Tween = null
## Exploration-only shard progress menu (not on BattleHUD).
@onready var shard_menu_anchor: Control = %ShardMenuAnchor as Control
@onready var shard_menu_button: TextureButton = %ShardMenuButton as TextureButton
@onready var shard_menu_button_label: Label = %ShardMenuButtonLabel as Label
var shard_menu: HudShardMenu = null
var _shard_menu_label_tween: Tween = null

var _current_enemy_tier: int = 0
var _proximity_step_count: int = 0

## Exploration-only HUD pieces hidden while BattleHUD is up.
## Add new CanvasItem nodes here (or in `_cache_exploration_ui_nodes`) when you
## introduce exploration chrome that must not leak into battle.
var _exploration_only_nodes: Array[CanvasItem] = []
## Extra exploration-only chrome added at runtime (e.g. MobileHUD's layer); hides in battle too.
var _extra_exploration_nodes: Array[CanvasItem] = []
## Touch-screen layout (portraits bottom-left, D-pad). Switched on automatically on touch devices.
var mobile_hud: MobileHUD = null

# ==============================================================================
# 2. LIFECYCLE & INITIALIZATION
# ==============================================================================
## Keys 1-6 (input actions party_slot_1..6) act like clicking that party portrait: open the
## character sheet (or switch it to that character) / pick that ally as a target in battle.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.is_echo() or not event.is_pressed():
		return
	for i: int in 6:
		if not event.is_action_pressed(StringName("party_slot_%d" % (i + 1))):
			continue
		if get_tree().paused or not KeyboardModal.party_hotkeys_allowed():
			return
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return
		if GameState.current_party == null or i >= GameState.current_party.slots.size() \
				or not is_instance_valid(GameState.current_party.slots[i]):
			return
		get_viewport().set_input_as_handled()
		SignalBus.portrait_clicked.emit(i)
		return


func _ready() -> void:
	_verify_ui_nodes()
	_cache_exploration_ui_nodes()
	_initialize_ui_state()
	_setup_portrait_click_listeners()
	_connect_signal_bus()
	_connect_game_state()
	_setup_game_menu()
	_setup_shard_menu()
	mobile_hud = MobileHUD.new()
	mobile_hud.name = "MobileHUDController"
	add_child(mobile_hud)
	mobile_hud.setup(self)

	SignalBus.time_period_changed.connect(_on_time_period_changed)
	_update_time_display(GameState.current_time_period)
	_connect_signal_safe(SignalBus, &"party_gold_changed", _on_party_gold_changed)
	_refresh_gold_label(GameState.party_gold)
	
	# Defer initial portrait update by one frame to resolve potential race
	# conditions with GameState initialization.
	await get_tree().process_frame
	if "current_party" in GameState and is_instance_valid(GameState.current_party) and "slots" in GameState.current_party:
		_update_party_portraits(GameState.current_party.slots)


## Creates the ONE in-game menu and wires every menu button to it:
## - exploration: %GameMenuButton (+ %GameMenuButtonLabel hint) under MainHUDLayout/GameMenuAnchor
## - battle:      %GameMenuButton inside the BattleHUD scene (its own unique name scope)
## No script lives on the buttons themselves; Esc also toggles the menu (HudGameMenu._unhandled_input).
func _setup_game_menu() -> void:
	game_menu = HUD_GAME_MENU_SCENE.instantiate() as HudGameMenu
	add_child(game_menu)
	_hook_game_menu_button(game_menu_button, true)
	if is_instance_valid(battle_hud):
		_hook_game_menu_button(battle_hud.get_node_or_null(^"%GameMenuButton") as TextureButton, false)
	if is_instance_valid(game_menu_button_label):
		game_menu_button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_game_menu_label(0.0, GAME_MENU_LABEL_DELAY)


func _hook_game_menu_button(button: TextureButton, shows_hint_label: bool) -> void:
	if not is_instance_valid(button):
		return
	button.tooltip_text = "Game Menu (Esc)"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(game_menu.toggle_menu)
	button.mouse_entered.connect(_on_game_menu_button_hover.bind(button, true, shows_hint_label))
	button.mouse_exited.connect(_on_game_menu_button_hover.bind(button, false, shows_hint_label))


## Brightens the hovered button; the exploration one also brings its "MAIN MENU" hint back.
func _on_game_menu_button_hover(button: TextureButton, hovered: bool, shows_hint_label: bool) -> void:
	button.modulate = Color(1.25, 1.25, 1.25) if hovered else Color.WHITE
	if shows_hint_label:
		_fade_game_menu_label(1.0 if hovered else 0.0, 0.0 if hovered else 0.6)


func _fade_game_menu_label(target_alpha: float, delay: float) -> void:
	if not is_instance_valid(game_menu_button_label):
		return
	if _game_menu_label_tween != null:
		_game_menu_label_tween.kill()
	_game_menu_label_tween = create_tween()
	if delay > 0.0:
		_game_menu_label_tween.tween_interval(delay)
	var duration: float = GAME_MENU_LABEL_FADE if target_alpha <= 0.0 else 0.15
	_game_menu_label_tween.tween_property(game_menu_button_label, "modulate:a", target_alpha, duration)


## Creates the exploration-only shard menu and wires %ShardMenuButton (+ hint label).
## Unlike the game menu, this is not present on BattleHUD.
func _setup_shard_menu() -> void:
	shard_menu = HUD_SHARD_MENU_SCENE.instantiate() as HudShardMenu
	add_child(shard_menu)
	_hook_shard_menu_button(shard_menu_button)
	if is_instance_valid(shard_menu_button_label):
		shard_menu_button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_shard_menu_label(0.0, GAME_MENU_LABEL_DELAY)


func _hook_shard_menu_button(button: TextureButton) -> void:
	if not is_instance_valid(button):
		return
	button.tooltip_text = "Shards"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(shard_menu.toggle_menu)
	button.mouse_entered.connect(_on_shard_menu_button_hover.bind(button, true))
	button.mouse_exited.connect(_on_shard_menu_button_hover.bind(button, false))


func _on_shard_menu_button_hover(button: TextureButton, hovered: bool) -> void:
	button.modulate = Color(1.25, 1.25, 1.25) if hovered else Color.WHITE
	_fade_shard_menu_label(1.0 if hovered else 0.0, 0.0 if hovered else 0.6)


func _fade_shard_menu_label(target_alpha: float, delay: float) -> void:
	if not is_instance_valid(shard_menu_button_label):
		return
	if _shard_menu_label_tween != null:
		_shard_menu_label_tween.kill()
	_shard_menu_label_tween = create_tween()
	if delay > 0.0:
		_shard_menu_label_tween.tween_interval(delay)
	var duration: float = GAME_MENU_LABEL_FADE if target_alpha <= 0.0 else 0.15
	_shard_menu_label_tween.tween_property(shard_menu_button_label, "modulate:a", target_alpha, duration)


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
	_connect_signal_safe(sb, &"character_vitals_updated", _on_character_vitals_updated)
	_connect_signal_safe(sb, &"character_health_changed", _on_character_vitals_updated)
	_connect_signal_safe(sb, &"character_mana_changed", _on_character_vitals_updated)
	
	_connect_signal_safe(sb, &"combat_started", on_combat_started)
	_connect_signal_safe(sb, &"combat_ended", _on_combat_ended)
	_connect_signal_safe(sb, &"battle_hud_recovery_requested", _on_battle_hud_recovery_requested)
	_connect_signal_safe(sb, &"edge_flash_requested", _on_edge_flash_requested)
	_connect_signal_safe(sb, &"hazard_slash_requested", play_hazard_slash)
	_connect_signal_safe(sb, &"enemy_proximity_changed", _on_enemy_proximity_changed)
	# 🎯 Intercept popup action buttons (e.g. REST, SEARCH, LOOK)
	_connect_signal_safe(sb, &"popup_requested", _on_popup_requested)
	_connect_signal_safe(sb, &"nine_speak_requested", _on_nine_speak_requested)
	_ensure_lore_scare_fx()


func _on_nine_speak_requested(clip_basename: String) -> void:
	if clip_basename.is_empty():
		return
	if is_instance_valid(nine_hud) and nine_hud.has_method("make_nine_talk"):
		nine_hud.make_nine_talk(clip_basename)


## Responds to granular character data changes by refreshing all party portraits
# Update signature to accept optional parameters so any signal can trigger it cleanly
func _on_character_vitals_updated(_arg1 = null, _arg2 = null, _arg3 = null) -> void:
	if GameState.current_party and "slots" in GameState.current_party:
		_update_party_portraits(GameState.current_party.slots)


## Binds global GameState events and synchronizes initial party/mode state
func _connect_game_state() -> void:
	var gs: Node = GameState if is_instance_valid(GameState) else get_tree().root.get_node_or_null("GameState")
	if not is_instance_valid(gs):
		return

	_connect_signal_safe(gs, &"core_state_changed", _on_game_state_changed)

	if "current_mode" in gs:
		_on_game_state_changed(gs.current_mode)


## Helper utility to check signal presence and guard against duplicate connections
func _connect_signal_safe(target: Node, signal_name: StringName, callback: Callable) -> void:
	if target.has_signal(signal_name):
		var sig: Signal = target.get(signal_name)
		if not sig.is_connected(callback):
			sig.connect(callback)


## Builds the exploration-only node list. Keep this as the single registry of
## HUD chrome that swaps off when battle mode starts.
func _cache_exploration_ui_nodes() -> void:
	_exploration_only_nodes.clear()
	var candidates: Array[CanvasItem] = [
		minimap_anchor,
		compass_label,
		cockpit_background,
		top_bar,
		right_sidebar_anchor,
		action_bar_anchor,
		game_menu_anchor,
		shard_menu_anchor,
		time_label, # %DaytimeLabel — must not float over BattleHUD
		gold_label, # %GoldLabel — exploration wallet readout
		enemy_in_range,
	]
	candidates.append_array(_extra_exploration_nodes)
	for node: CanvasItem in candidates:
		if is_instance_valid(node):
			_exploration_only_nodes.append(node)


## Registers runtime-built HUD chrome that should hide in battle like the rest of the exploration HUD.
func add_exploration_node(node: CanvasItem) -> void:
	if is_instance_valid(node) and not _extra_exploration_nodes.has(node):
		_extra_exploration_nodes.append(node)
		_cache_exploration_ui_nodes()


func remove_exploration_node(node: CanvasItem) -> void:
	_extra_exploration_nodes.erase(node)
	_cache_exploration_ui_nodes()


## Toggles every exploration-only control. Prefer `show_battle_hud()` /
## `show_exploration_hud()` for full mode swaps.
func _set_exploration_ui_visible(show_ui: bool) -> void:
	if _exploration_only_nodes.is_empty():
		_cache_exploration_ui_nodes()
	for node: CanvasItem in _exploration_only_nodes:
		if is_instance_valid(node):
			node.visible = show_ui


## Hide exploration chrome and show BattleHUD. Call this (or combat_started)
## whenever entering a fight so new HUD widgets don't get stuck on screen.
func show_battle_hud() -> void:
	_set_exploration_ui_visible(false)
	if is_instance_valid(battle_hud):
		battle_hud.show()


## Hide BattleHUD and restore exploration chrome.
func show_exploration_hud() -> void:
	if is_instance_valid(battle_hud):
		battle_hud.hide()
	_set_exploration_ui_visible(true)


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
			compass_label.text = "N"
		"WEST":
			compass_label.text = "W"
		"SOUTH":
			compass_label.text = "S"
		"EAST":
			compass_label.text = "E"
		_:
			compass_label.text = "?"


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
						AudioManager.play_ui_sound("open-menu")


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
			if _is_battle_running():
				return # never hide the battle HUD while a fight is on
			show_exploration_hud()
		GameState.Mode.BATTLE:
			show_battle_hud()
		GameState.Mode.MANAGEMENT:
			_set_exploration_ui_visible(false)


# ==============================================================================
# 7. Combat Functions
# ==============================================================================
func on_combat_started(enemy_data_or_group: Variant = null, player_party: Array = [], _enemy_facing: String = "") -> void:
	show_battle_hud()

	var active_party: Array = player_party
	if active_party.is_empty() and (Engine.has_singleton("GameState") or get_tree().root.has_node("GameState")):
		if GameState.current_party:
			active_party = GameState.current_party.slots

	if is_instance_valid(battle_hud) and battle_hud.has_method("on_combat_started"):
		battle_hud.on_combat_started(enemy_data_or_group, active_party, _enemy_facing)


func _on_combat_ended(_victory: bool) -> void:
	show_exploration_hud()


## Safety net: a battle is running but its HUD isn't on screen (see CombatManager watchdog).
func _on_battle_hud_recovery_requested(enemy_data_or_group: Variant, player_party: Array) -> void:
	show_battle_hud()
	if is_instance_valid(battle_hud) and battle_hud.has_method("recover"):
		battle_hud.call("recover", enemy_data_or_group, player_party)


func _is_battle_running() -> bool:
	var cm: Node = get_tree().root.get_node_or_null("CombatManager")
	return is_instance_valid(cm) and bool(cm.get("is_combat_active"))


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
	_current_enemy_tier = current_tier
	_update_enemy_in_range_indicator(current_tier)
	_handle_proximity_edge_flash(current_tier)


## Handles popup requests from ActionButtons (REST, SEARCH, etc.)
func _on_popup_requested(action_type: StringName, _data: Dictionary = {}) -> void:
	if String(action_type) == "REST":
		if _are_monsters_nearby():
			if is_instance_valid(nine_hud) and nine_hud.has_method("make_nine_talk"):
				nine_hud.make_nine_talk("cant-sleep-here")
			return
			
	# Proceed with opening standard popups here if allowed


## Returns true if enemies are currently in threat range
func _are_monsters_nearby() -> bool:
	# 1. Primary check: Proximity tracker tier (1 = nearby 3-5 tiles, 2 = close 1-2 tiles)
	if _current_enemy_tier > 0:
		return true

	# 2. Fallback check: 3D distance check against all nodes in "enemies" group
	if not is_instance_valid(player):
		return false

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy is Node3D and enemy.is_visible_in_tree():
			if player.global_position.distance_to(enemy.global_position) <= 8.0:
				return true

	return false


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


func _on_time_period_changed(new_period: String) -> void:
	_update_time_display(new_period)


func _on_party_gold_changed(new_total: int, _amount_changed: int) -> void:
	_refresh_gold_label(new_total)


func _refresh_gold_label(total: int) -> void:
	if is_instance_valid(gold_label):
		gold_label.text = "%d" % total


func _update_time_display(period_text: String) -> void:
	if time_label:
		time_label.text = period_text


# ==============================================================================
# LORE SCARE FX (Horned Skull, etc.)
# ==============================================================================
const _LORE_SCARE_FX_SCRIPT: GDScript = preload("res://Scripts/UI/LoreScareFX.gd")
var _lore_scare_fx: CanvasLayer = null


func _ensure_lore_scare_fx() -> void:
	if is_instance_valid(_lore_scare_fx):
		return
	_lore_scare_fx = _LORE_SCARE_FX_SCRIPT.new() as CanvasLayer
	_lore_scare_fx.name = "LoreScareFX"
	add_child(_lore_scare_fx)


# ==============================================================================
# HAZARD SLASH (exploration screen effect, e.g. rock tentacles)
# ==============================================================================
const BIG_SLASH_SHADER: Shader = preload("res://Shaders/big_slash.gdshader")
var _big_slash_material: ShaderMaterial = null
var _big_slash_tween: Tween = null


## Plays one big slash across the screen on %SliceOverlay.
func play_hazard_slash(duration: float = 0.7) -> void:
	var overlay: ColorRect = get_node_or_null("%SliceOverlay") as ColorRect
	if not is_instance_valid(overlay):
		push_warning("DungeonHUD: %SliceOverlay not found, can't play hazard slash.")
		return

	if _big_slash_material == null:
		_big_slash_material = ShaderMaterial.new()
		_big_slash_material.shader = BIG_SLASH_SHADER
	# Random angle each strike so repeated hits don't look identical
	_big_slash_material.set_shader_parameter("angle_degrees", randf_range(-38.0, -18.0) * (1.0 if randf() < 0.5 else -1.0))
	_big_slash_material.set_shader_parameter("progress", 0.0)

	if is_instance_valid(_big_slash_tween):
		_big_slash_tween.kill()

	overlay.material = _big_slash_material
	overlay.visible = true
	overlay.move_to_front()

	var mat: ShaderMaterial = _big_slash_material
	_big_slash_tween = create_tween()
	_big_slash_tween.tween_method(
		func(value: float) -> void: mat.set_shader_parameter("progress", value),
		0.0, 1.0, duration
	)
	_big_slash_tween.tween_callback(func() -> void: mat.set_shader_parameter("progress", 0.0))
