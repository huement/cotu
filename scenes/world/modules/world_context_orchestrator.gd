extends Node
class_name WorldContextOrchestrator


func default_node_paths() -> Dictionary:
	return {
		"context_orchestrator": "ContextOrchestrator",
		"player": "Player",
		"scene_initializer_module": "SceneInitializerModule",
		"overlay_module": "OverlayModule",
		"grid_module": "GridModule",
		"encounter_module": "EncounterModule",
		"run_outcome_module": "RunOutcomeModule",
		"ui_module": "UIModule",
		"state_orchestrator": "StateOrchestrator",
		"turn_orchestrator": "TurnOrchestrator",
		"composition_orchestrator": "CompositionOrchestrator",
		"policy_orchestrator": "PolicyOrchestrator",
		"input_orchestrator": "InputOrchestrator",
		"movement_orchestrator": "MovementOrchestrator",
		"event_bus": "EventBus",
		"event_router_orchestrator": "EventRouterOrchestrator",
		"overlay_mount": "OverlayLayer/OverlayMount",
		"debug_panel": "OverlayLayer/DebugPanel",
		"grid_coords_label": "OverlayLayer/MinimapOverlay/GridCoordsLabel",
		"minimap_overlay": "OverlayLayer/MinimapOverlay",
		"btn_open_inventory": "OverlayLayer/DebugPanel/Margin/VBox/OpenInventory",
		"btn_open_combat": "OverlayLayer/DebugPanel/Margin/VBox/OpenCombat",
		"btn_open_town": "OverlayLayer/DebugPanel/Margin/VBox/OpenTown",
		"btn_toggle_minimap": "OverlayLayer/DebugPanel/Margin/VBox/ToggleMinimap",
		"btn_close_overlay": "OverlayLayer/DebugPanel/Margin/VBox/CloseOverlay",
	}


func resolve_world_context(root: Node, node_paths: Dictionary) -> Dictionary:
	var resolved := {}
	for key in node_paths.keys():
		resolved[key] = root.get_node_or_null(String(node_paths[key]))
	return resolved


func assign_resolved_world_context(world: Node, resolved: Dictionary) -> void:
	world.set("_context_orchestrator", resolved.get("context_orchestrator"))
	world.set("_player", resolved.get("player"))
	world.set("_scene_initializer_module", resolved.get("scene_initializer_module"))
	world.set("_overlay_module", resolved.get("overlay_module"))
	world.set("_grid_module", resolved.get("grid_module"))
	world.set("_encounter_module", resolved.get("encounter_module"))
	world.set("_run_outcome_module", resolved.get("run_outcome_module"))
	world.set("_ui_module", resolved.get("ui_module"))
	world.set("_state_orchestrator", resolved.get("state_orchestrator"))
	world.set("_turn_orchestrator", resolved.get("turn_orchestrator"))
	world.set("_composition_orchestrator", resolved.get("composition_orchestrator"))
	world.set("_policy_orchestrator", resolved.get("policy_orchestrator"))
	world.set("_input_orchestrator", resolved.get("input_orchestrator"))
	world.set("_movement_orchestrator", resolved.get("movement_orchestrator"))
	world.set("_event_bus", resolved.get("event_bus"))
	world.set("_event_router_orchestrator", resolved.get("event_router_orchestrator"))


func build_required_modules_from_world(world: Node) -> Dictionary:
	return {
		"SceneInitializerModule": world.get("_scene_initializer_module"),
		"OverlayModule": world.get("_overlay_module"),
		"GridModule": world.get("_grid_module"),
		"EncounterModule": world.get("_encounter_module"),
		"RunOutcomeModule": world.get("_run_outcome_module"),
		"UIModule": world.get("_ui_module"),
		"StateOrchestrator": world.get("_state_orchestrator"),
		"TurnOrchestrator": world.get("_turn_orchestrator"),
		"CompositionOrchestrator": world.get("_composition_orchestrator"),
		"PolicyOrchestrator": world.get("_policy_orchestrator"),
		"InputOrchestrator": world.get("_input_orchestrator"),
		"MovementOrchestrator": world.get("_movement_orchestrator"),
		"EventBus": world.get("_event_bus"),
		"EventRouterOrchestrator": world.get("_event_router_orchestrator"),
		"ContextOrchestrator": world.get("_context_orchestrator"),
	}


func build_overlay_paths_from_world(world: Node) -> Dictionary:
	return {
		&"inventory": world.get("overlay_inventory_scene_path"),
		&"combat": world.get("overlay_combat_scene_path"),
		&"town": world.get("overlay_town_scene_path"),
		&"victory": world.get("overlay_victory_scene_path"),
		&"defeat": world.get("overlay_defeat_scene_path"),
	}


func build_overlay_registry(overlay_paths: Dictionary) -> Dictionary:
	return overlay_paths.duplicate(true)
