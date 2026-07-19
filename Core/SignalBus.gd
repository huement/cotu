extends Node
# Core/SignalBus.gd - Must be added as an Autoload in Project Settings

## Emitted whenever the party moves positions or alters cardinal headings
@warning_ignore("unused_signal")
signal party_moved(new_grid_pos: Vector3i, facing_direction: String)

# Dispatched whenever the tactical roster initializes or warps
@warning_ignore("unused_signal")
signal party_roster_updated(roster_slots: Array)

## Emitted during phased selection loops to alert the action manager
@warning_ignore("unused_signal")
signal party_action_selected(slot_index: int, action_type: String)

## Dispatched when combat shifts phase states (e.g., SELECTION to EXECUTION)
@warning_ignore("unused_signal")
signal combat_phase_changed(new_phase: int)

# 🎯 POPUP SYSTEM SIGNALS: Dispatched to open/close the modal window
@warning_ignore("unused_signal")
signal popup_requested(action_type: String)
@warning_ignore("unused_signal")
signal popup_confirmed(action_type: String, extra_data: Dictionary)
