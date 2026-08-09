# res://Core/SignalBus.gd
extends Node

enum Direction {
	NORTH,
	EAST,
	SOUTH,
	WEST,
}
enum CombatPhase {
	SELECTION,
	EXECUTION,
	RESOLUTION,
}

# Exploration & Navigation
signal party_moved(new_grid_pos: Vector3i, facing: Direction)
signal party_roster_updated(roster_slots: Array)

# Combat Triggers
signal combat_started(enemy_data_or_group: Variant, player_party: Array)
signal combat_ended(victory: bool)
signal combat_phase_changed(new_phase: CombatPhase)

# Combat Actions & Escapes
# Active Time Battle (ATB) Engine
signal turn_meter_updated(combatant_id: String, percent: float)
signal combatant_turn_ready(combatant_id: String, slot_index: int)
signal player_action_selected(slot_index: int, action_type: StringName, target_index: int)
signal character_guarded(character_index: int)
signal party_flee_attempted(success: bool)

# 3D Visual Enemy Animations
signal enemy_attack_started(enemy_id: String)
signal enemy_damaged_visual(enemy_id: String, damage: int)

# Vitals & Visual FX
signal character_health_changed(target_slot: int, current_hp: int)
signal character_mana_changed(target_slot: int, current_mp: int, max_mp: int)
signal enemy_health_changed(enemy_id: String, current_hp: int, max_hp: int)
signal chevron_flash_requested(is_player_hit: bool)

# 🎯 Progression & XP Signals
signal character_xp_changed(slot_index: int, current_xp: int, max_xp: int)
signal character_leveled_up(slot_index: int, new_level: int)
signal party_gold_changed(new_total: int, amount_changed: int)

# Popups & UI
signal popup_requested(action_type: StringName, data: Dictionary)
signal popup_confirmed(action_type: StringName, extra_data: Dictionary)
signal portrait_clicked(slot_index: int)
signal battle_victory_popup_requested(data: Dictionary)

# JUICE IT
signal camera_shake_requested(trauma: float)

# Logging / Displaying Messages
signal log_message_emitted(formatted_text: String, color_hex_or_name: String)
signal show_toast(message: String, is_error: bool)
