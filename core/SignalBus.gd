extends Node

# Emitted when a cat's health changes. slot_index is 0-5.
signal party_member_stats_changed(slot_index: int, character: CatCharacter)

# Emitted for the classic Wizardry text log
signal game_log_emitted(message: String)

# Emitted when the party moves to a new grid tile
signal party_moved(new_position: Vector3i)
