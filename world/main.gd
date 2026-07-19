extends Node3D

@export var occupancy_wall_layer := 0
@export var auto_align_gridmap_visual := true
@export var show_debug_panel := false
@export var show_grid_coordinates_overlay := false
@export var show_minimap_overlay := false
@export_enum(
	"Menu",
	"Gameplay",
	"GameOverFailure",
	"GameOverSuccess"
) var initial_game_state := "Gameplay"
@export var enable_cell_end_conditions := true
@export var failure_goal_cell := Vector2i(-2, 2)
@export_enum("Snap", "Smooth") var active_movement_preset := "Smooth"
@export var preset_snap_path := "res://resources/presets/movement_config_snap.tres"
@export var preset_smooth_path := "res://resources/presets/movement_config_smooth.tres"
@export_file("*.tscn") var overlay_inventory_scene_path := "res://scenes/inventory/inventory_overlay.tscn"
@export_file("*.tscn") var overlay_combat_scene_path := "res://scenes/combat/combat_placeholder.tscn"
@export_file("*.tscn") var overlay_town_scene_path := "res://scenes/town/town_overlay.tscn"
@export_file("*.tscn") var overlay_victory_scene_path := "res://scenes/overlays/victory_overlay.tscn"
@export_file("*.tscn") var overlay_defeat_scene_path := "res://scenes/overlays/defeat_overlay.tscn"
@export_file("*.tscn") var title_scene_path := "res://scenes/title/title_screen.tscn"

const OVERLAY_INVENTORY := &"inventory"
const OVERLAY_COMBAT := &"combat"
const OVERLAY_TOWN := &"town"
const OVERLAY_VICTORY := &"victory"
const OVERLAY_DEFEAT := &"defeat"
const GAME_STATE_MENU := &"menu"
const GAME_STATE_GAMEPLAY := &"gameplay"
const GAME_STATE_COMBAT := &"combat"
const GAME_STATE_GAMEOVER_FAILURE := &"gameover_failure"
const GAME_STATE_GAMEOVER_SUCCESS := &"gameover_success"
const NODE_TURN_ORCHESTRATOR := "TurnOrchestrator"
const NODE_COMPOSITION_ORCHESTRATOR := "CompositionOrchestrator"
const NODE_CONTEXT_ORCHESTRATOR := "ContextOrchestrator"
const NODE_EVENT_ROUTER_ORCHESTRATOR := "EventRouterOrchestrator"

var _player: Player
var _scene_initializer_module: WorldSceneInitializerModule
var _overlay_module: WorldOverlayModule
var _grid_module: WorldGridModule
var _encounter_module: WorldEncounterModule
var _run_outcome_module: WorldRunOutcomeModule
var _ui_module: WorldUIModule
var _state_orchestrator: WorldStateOrchestrator
var _turn_orchestrator: WorldTurnOrchestrator
var _composition_orchestrator: WorldCompositionOrchestrator
var _policy_orchestrator: WorldPolicyOrchestrator
var _input_orchestrator: WorldInputOrchestrator
var _movement_orchestrator: WorldMovementOrchestrator
var _context_orchestrator: WorldContextOrchestrator
var _event_bus: WorldEventBus
var _event_router_orchestrator: WorldEventRouterOrchestrator

func _ready() -> void:
	_context_orchestrator = get_node_or_null(NODE_CONTEXT_ORCHESTRATOR) as WorldContextOrchestrator
	if _context_orchestrator == null:
		push_error("Missing required node: %s" % NODE_CONTEXT_ORCHESTRATOR)
		return

	var resolved_context := _context_orchestrator.resolve_world_context(
		self,
		_context_orchestrator.default_node_paths()
	)
	_context_orchestrator.assign_resolved_world_context(self, resolved_context)
	if _turn_orchestrator == null:
		push_error("Missing required node: %s" % NODE_TURN_ORCHESTRATOR)
		return
	if _event_router_orchestrator == null:
		push_error("Missing required node: %s" % NODE_EVENT_ROUTER_ORCHESTRATOR)
		return
	if _composition_orchestrator == null:
		push_error("Missing required node: %s" % NODE_COMPOSITION_ORCHESTRATOR)
		return
	if not _composition_orchestrator.bootstrap_world(
			self,
			_context_orchestrator,
			_context_orchestrator.build_required_modules_from_world(self),
			_context_orchestrator.build_overlay_paths_from_world(self),
			_composition_orchestrator.build_bootstrap_context(self, resolved_context)):
		return
	_input_orchestrator.wire_overlay_controls()
	_setup_game_state_machine()
	_add_world_environment()
	apply_movement_preset(active_movement_preset)

	# Defer to ensure all children (including Player) have finished _ready().
	_wire_occupancy.call_deferred()
	_wire_enemies.call_deferred()
	_wire_end_conditions.call_deferred()
	_apply_debug_panel_visibility()
	_apply_grid_coordinates_overlay_visibility()
	_apply_minimap_overlay_visibility()
	_refresh_grid_coordinates_overlay()
	_refresh_minimap_overlay()
	_refresh_debug_buttons()
	_add_hp_bar.call_deferred()

func _add_world_environment() -> void:
	_scene_initializer_module.add_environment(self)


func _unhandled_input(event: InputEvent) -> void:
	if _input_orchestrator.handle_unhandled_input(event, is_gameplay_state_active()):
		get_viewport().set_input_as_handled()
		return

	if _turn_orchestrator.handle_combat_input(event):
		get_viewport().set_input_as_handled()


func has_active_overlay() -> bool:
	return _overlay_module.has_active_overlay()


func active_overlay_kind() -> StringName:
	return _overlay_module.active_overlay_kind()


func open_inventory_overlay() -> void:
	open_overlay(OVERLAY_INVENTORY)


func open_combat_overlay() -> void:
	open_overlay(OVERLAY_COMBAT)


func open_town_overlay() -> void:
	open_overlay(OVERLAY_TOWN)


func open_overlay(kind: StringName) -> void:
	_policy_orchestrator.open_overlay(kind, false, is_gameplay_state_active())


func close_active_overlay() -> void:
	_policy_orchestrator.close_overlay(true)


func _apply_debug_panel_visibility() -> void:
	_ui_module.apply_debug_panel_visibility(show_debug_panel)


func _apply_grid_coordinates_overlay_visibility() -> void:
	_ui_module.apply_grid_coords_visibility(show_grid_coordinates_overlay)


func _apply_minimap_overlay_visibility() -> void:
	_ui_module.apply_minimap_visibility(show_minimap_overlay)


func _refresh_grid_coordinates_overlay(cell: Vector2i = Vector2i.ZERO) -> void:
	_ui_module.refresh_coords(cell)


func toggle_minimap_overlay() -> void:
	show_minimap_overlay = _ui_module.toggle_minimap()


func _refresh_minimap_overlay(cell: Vector2i = Vector2i.ZERO) -> void:
	_ui_module.refresh_minimap(cell, _grid_module.occupancy())


func _refresh_debug_buttons() -> void:
	var overlay_open := has_active_overlay()
	_ui_module.refresh_debug_buttons(overlay_open)


func current_game_state() -> StringName:
	return _state_orchestrator.current_game_state()


func is_gameplay_state_active() -> bool:
	return _state_orchestrator.is_gameplay_state_active()


func is_combat_state_active() -> bool:
	return _state_orchestrator.is_combat_state_active()


func start_combat(encountered_enemies: Array = []) -> void:
	_state_orchestrator.start_combat()
	_policy_orchestrator.open_overlay(OVERLAY_COMBAT, true, true)
	if encountered_enemies.is_empty():
		encountered_enemies = get_enemies()
	_turn_orchestrator.start_combat_round(encountered_enemies)


func end_combat() -> void:
	_state_orchestrator.end_combat()
	if active_overlay_kind() == OVERLAY_COMBAT:
		_overlay_module.close_overlay()


func go_to_menu() -> void:
	_state_orchestrator.go_to_menu()


func start_gameplay() -> void:
	_composition_orchestrator.configure_run_outcome(
			_run_outcome_module,
			enable_cell_end_conditions,
			failure_goal_cell,
			self,
			Callable(self, "get_enemies"))
	_state_orchestrator.start_gameplay()
	_refresh_grid_coordinates_overlay()


func finish_with_failure() -> void:
	_state_orchestrator.finish_with_failure()


func finish_with_success() -> void:
	_state_orchestrator.finish_with_success()


func _setup_game_state_machine() -> void:
	_state_orchestrator.setup(initial_game_state)


func apply_state_side_effects() -> void:
	_policy_orchestrator.apply_state_side_effects(
			current_game_state(),
			is_gameplay_state_active(),
			is_combat_state_active(),
			OVERLAY_COMBAT,
			OVERLAY_VICTORY,
			OVERLAY_DEFEAT,
			GAME_STATE_GAMEOVER_FAILURE,
			GAME_STATE_GAMEOVER_SUCCESS)


func apply_movement_preset(preset_name: String = "") -> bool:
	var result := _movement_orchestrator.apply_preset(
			_player,
			preset_name,
			active_movement_preset,
			preset_snap_path,
			preset_smooth_path)
	active_movement_preset = String(result.get("active_name", active_movement_preset))
	return bool(result.get("ok", false))

func return_to_title() -> void:
	if title_scene_path.is_empty():
		return

	get_tree().change_scene_to_file(title_scene_path)


func restart_current_run() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if tree.current_scene == self:
		tree.reload_current_scene()
		return

	var path := scene_file_path
	if path.is_empty():
		path = "res://scenes/world/main.tscn"

	var packed_scene := load(path) as PackedScene
	if packed_scene == null:
		start_gameplay()
		return
	call_deferred("_deferred_restart_with_scene", packed_scene)


func _deferred_restart_with_scene(packed_scene: PackedScene) -> void:
	if packed_scene == null:
		start_gameplay()
		return

	var parent := get_parent()
	if parent == null:
		start_gameplay()
		return

	var previous_name := name
	name = "%s_old" % previous_name

	var replacement := packed_scene.instantiate()
	replacement.name = previous_name
	parent.add_child(replacement)
	parent.move_child(replacement, get_index())
	queue_free()


func get_player_stats() -> CharacterStats:
	if _player == null:
		return null
	return _player.stats


func get_player_inventory_items() -> Array:
	if _player == null or _player.inventory == null:
		return []
	if not _player.inventory.has_method("get_items"):
		return []
	return _player.inventory.get_items()


func use_player_inventory_item(index: int) -> bool:
	if _player == null:
		return false
	return _player.use_item(index)


func rest_player() -> bool:
	if _player == null or _player.stats == null:
		return false
	_player.stats.fill()
	return true


func submit_combat_intent(cmd: GridCommand.Type) -> bool:
	return _turn_orchestrator.submit_player_combat_intent(cmd)


func _wire_end_conditions() -> void:
	if _player == null or _player.movement_controller == null:
		return

	if _player.movement_controller.action_completed.is_connected(_event_bus.emit_player_action_completed):
		return

	_player.movement_controller.action_completed.connect(_event_bus.emit_player_action_completed)


func _wire_enemies() -> void:
	_encounter_module.wire_enemies()
	if _player != null and _player.movement_controller != null:
		_player.movement_controller.passability_fn = _is_player_cell_passable


func get_enemies() -> Array:
	return _encounter_module.get_enemies()


func _is_player_cell_passable(cell: Vector2i) -> bool:
	return _grid_module.is_player_cell_passable(cell, get_enemies())


func _add_hp_bar() -> void:
	_ui_module.setup_hp_bar(get_node_or_null("OverlayLayer") as CanvasLayer)


func _wire_occupancy() -> void:
	var gm := get_node_or_null("GridMap") as GridMap
	if gm == null:
		return

	_grid_module.build_occupancy(gm, occupancy_wall_layer, auto_align_gridmap_visual)

	_refresh_minimap_overlay()
	if _player != null and _player.movement_controller != null:
		_player.movement_controller.passability_fn = _is_player_cell_passable
