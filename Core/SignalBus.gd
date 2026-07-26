@warning_ignore("unused_signal")
extends Node
# Core/SignalBus.gd - Autoloaded Event Bus

# Tip: Use enums for fixed states like directions or combat phases to prevent typo bugs
enum Direction { NORTH, EAST, SOUTH, WEST }
enum CombatPhase { SELECTION, EXECUTION, RESOLUTION }

## Emitted whenever the party moves positions or alters cardinal headings
signal party_moved(new_grid_pos: Vector3i, facing: Direction)

# Dispatched whenever the tactical roster initializes or warps
signal party_roster_updated(roster_slots: Array)

## Emitted during phased selection loops to alert the action manager
signal party_action_selected(slot_index: int, action_type: StringName)

## Dispatched when combat shifts phase states
signal combat_phase_changed(new_phase: CombatPhase)

# 🎯 POPUP SYSTEM SIGNALS
signal popup_requested(action_type: StringName, data: Dictionary)
signal popup_confirmed(action_type: StringName, extra_data: Dictionary)

signal portrait_clicked(slot_index: int)

## Combat Triggers
signal combat_started(enemy_group: EnemyGroupData)
signal combat_ended(victory: bool)

## Active Time Battle Signals
signal turn_meter_updated(combatant_id: String, percent: float)
signal combatant_turn_ready(combatant_id: String, is_player: bool)

## Visual FX Signals
signal chevron_flash_requested(is_player_hit: bool)
signal enemy_health_changed(current_hp: int, max_hp: int)

## Active Time Battle & Party UI Signals
signal character_health_changed(target_slot: int, current_hp: int)
