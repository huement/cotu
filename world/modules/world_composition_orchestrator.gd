extends Node
class_name WorldCompositionOrchestrator


func bootstrap_world(root: Node3D, context_orchestrator: WorldContextOrchestrator, required_nodes: Dictionary, overlay_paths: Dictionary, configure_context: Dictionary) -> bool:
	if not assert_required_modules(root, required_nodes):
		return false

	var overlay_scene_paths := context_orchestrator.build_overlay_registry(overlay_paths)
	var overlay_module := configure_context["overlay_module"] as WorldOverlayModule
	overlay_module.set_overlay_scene_paths(overlay_scene_paths)

	var ctx := configure_context.duplicate(true)
	ctx["root"] = root
	ctx["overlay_scene_paths"] = overlay_scene_paths
	configure_modules(ctx)
	return true


func build_bootstrap_context(world: Node3D, resolved_context: Dictionary) -> Dictionary:
	return {
		"player": world.get("_player"),
		"grid_module": world.get("_grid_module"),
		"overlay_module": world.get("_overlay_module"),
		"run_outcome_module": world.get("_run_outcome_module"),
		"encounter_module": world.get("_encounter_module"),
		"ui_module": world.get("_ui_module"),
		"state_orchestrator": world.get("_state_orchestrator"),
		"turn_orchestrator": world.get("_turn_orchestrator"),
		"policy_orchestrator": world.get("_policy_orchestrator"),
		"input_orchestrator": world.get("_input_orchestrator"),
		"event_bus": world.get("_event_bus"),
		"event_router_orchestrator": world.get("_event_router_orchestrator"),
		"overlay_mount": resolved_context.get("overlay_mount"),
		"debug_panel": resolved_context.get("debug_panel"),
		"grid_coords_label": resolved_context.get("grid_coords_label"),
		"minimap_overlay": resolved_context.get("minimap_overlay"),
		"btn_open_inventory": resolved_context.get("btn_open_inventory"),
		"btn_open_combat": resolved_context.get("btn_open_combat"),
		"btn_open_town": resolved_context.get("btn_open_town"),
		"btn_toggle_minimap": resolved_context.get("btn_toggle_minimap"),
		"btn_close_overlay": resolved_context.get("btn_close_overlay"),
		"open_inventory_overlay": Callable(world, "open_inventory_overlay"),
		"open_combat_overlay": Callable(world, "open_combat_overlay"),
		"open_town_overlay": Callable(world, "open_town_overlay"),
		"toggle_minimap_overlay": Callable(world, "toggle_minimap_overlay"),
		"close_active_overlay": Callable(world, "close_active_overlay"),
		"enable_cell_end_conditions": world.get("enable_cell_end_conditions"),
		"failure_goal_cell": world.get("failure_goal_cell"),
		"restart_current_run": Callable(world, "restart_current_run"),
		"return_to_title": Callable(world, "return_to_title"),
		"finish_with_success": Callable(world, "finish_with_success"),
		"finish_with_failure": Callable(world, "finish_with_failure"),
		"process_enemy_action": Callable(world.get("_turn_orchestrator"), "process_enemy_action"),
		"process_player_action": Callable(world.get("_turn_orchestrator"), "process_player_action"),
		"start_combat": Callable(world, "start_combat"),
		"on_state_side_effects": Callable(world, "apply_state_side_effects"),
		"is_gameplay_state_active": Callable(world, "is_gameplay_state_active"),
		"is_combat_state_active": Callable(world, "is_combat_state_active"),
		"end_combat": Callable(world, "end_combat"),
		"finish_with_failure_in_combat": Callable(world, "finish_with_failure"),
	}


func assert_required_modules(root: Node, required_nodes: Dictionary) -> bool:
	for node_name in required_nodes.keys():
		if required_nodes[node_name] == null:
			root.push_error("Missing required node: %s" % String(node_name))
			return false
	return true


func configure_modules(ctx: Dictionary) -> void:
	var root := ctx["root"] as Node3D
	var player = ctx["player"]
	var grid_module := ctx["grid_module"] as WorldGridModule
	var overlay_module := ctx["overlay_module"] as WorldOverlayModule
	var run_outcome_module := ctx["run_outcome_module"] as WorldRunOutcomeModule
	var encounter_module := ctx["encounter_module"] as WorldEncounterModule
	var ui_module := ctx["ui_module"] as WorldUIModule
	var state_orchestrator := ctx["state_orchestrator"] as WorldStateOrchestrator
	var turn_orchestrator := ctx["turn_orchestrator"] as WorldTurnOrchestrator
	var policy_orchestrator := ctx["policy_orchestrator"] as WorldPolicyOrchestrator
	var input_orchestrator := ctx["input_orchestrator"] as WorldInputOrchestrator
	var event_bus := ctx["event_bus"] as WorldEventBus
	var event_router_orchestrator := ctx["event_router_orchestrator"] as WorldEventRouterOrchestrator

	overlay_module.configure(ctx["overlay_mount"], ctx["overlay_scene_paths"])
	if not overlay_module.restart_requested.is_connected(event_bus.emit_overlay_restart_requested):
		overlay_module.restart_requested.connect(event_bus.emit_overlay_restart_requested)
	if not overlay_module.return_to_title_requested.is_connected(event_bus.emit_overlay_return_to_title_requested):
		overlay_module.return_to_title_requested.connect(event_bus.emit_overlay_return_to_title_requested)

	run_outcome_module.call(
			"configure",
			ctx["enable_cell_end_conditions"],
			ctx["failure_goal_cell"],
			root,
			Callable(root, "get_enemies"))
	run_outcome_module.reset_run()
	if not run_outcome_module.success_reached.is_connected(event_bus.emit_run_outcome_success_reached):
		run_outcome_module.success_reached.connect(event_bus.emit_run_outcome_success_reached)
	if not run_outcome_module.failure_reached.is_connected(event_bus.emit_run_outcome_failure_reached):
		run_outcome_module.failure_reached.connect(event_bus.emit_run_outcome_failure_reached)

	encounter_module.configure(root, player, grid_module)
	if not encounter_module.encounter_detected.is_connected(event_bus.emit_encounter_detected):
		encounter_module.encounter_detected.connect(event_bus.emit_encounter_detected)
	if not encounter_module.enemy_acted.is_connected(event_bus.emit_enemy_acted):
		encounter_module.enemy_acted.connect(event_bus.emit_enemy_acted)

	ui_module.configure(
			player,
			ctx["debug_panel"],
			ctx["grid_coords_label"],
			ctx["minimap_overlay"],
			ctx["btn_open_inventory"],
			ctx["btn_open_combat"],
			ctx["btn_open_town"],
			ctx["btn_close_overlay"])

	state_orchestrator.configure(ctx["on_state_side_effects"])
	turn_orchestrator.configure(
			ui_module,
			grid_module,
			encounter_module,
			run_outcome_module,
			root,
			player,
			ctx["is_gameplay_state_active"],
			ctx["is_combat_state_active"],
			ctx["end_combat"],
			ctx["finish_with_failure_in_combat"])

	policy_orchestrator.configure(
			player,
			overlay_module,
			ui_module,
			ctx["btn_open_inventory"])

	input_orchestrator.configure(
			ctx["btn_open_inventory"],
			ctx["btn_open_combat"],
			ctx["btn_open_town"],
			ctx["btn_toggle_minimap"],
			ctx["btn_close_overlay"],
			ctx["open_inventory_overlay"],
			ctx["open_combat_overlay"],
			ctx["open_town_overlay"],
			ctx["toggle_minimap_overlay"],
			ctx["close_active_overlay"])

	event_router_orchestrator.configure(
			event_bus,
			ctx["restart_current_run"],
			ctx["return_to_title"],
			ctx["finish_with_success"],
			ctx["finish_with_failure"],
			ctx["process_enemy_action"],
			ctx["process_player_action"],
			ctx["start_combat"],
			ctx["is_gameplay_state_active"])


func configure_run_outcome(run_outcome_module: WorldRunOutcomeModule, enable_cell_end_conditions: bool, failure_goal_cell: Vector2i, world_root: Node3D, get_enemies_fn: Callable) -> void:
	run_outcome_module.call("configure", enable_cell_end_conditions, failure_goal_cell, world_root, get_enemies_fn)
	run_outcome_module.reset_run()
