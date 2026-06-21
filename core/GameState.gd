extends Node

## Wizardry 7 Rigidity: Absolute 6-slot active party allocation
## The 6-slot active party. Slots 0-2 are Front Row; Slots 3-5 are Back Row.
var party: Array[CatCharacter] = []

## Current navigation tracking for grid movement
var party_position: Vector3i = Vector3i.ZERO
var party_direction: Vector3i = Vector3i.FORWARD # North mapping

func _ready() -> void:
	# Enforce rigid 6-slot sizing
	party.resize(6)
	for i in range(6):
		party[i] = null

## Assigns a cat to a specific slot and fires off an updates notification
func assign_character_to_slot(slot_index: int, character: CatCharacter) -> bool:
	if slot_index < 0 or slot_index >= 6:
		push_error("Invalid party slot index: %d" % slot_index)
		return false
		
	party[slot_index] = character
	
	# Notify UI listeners that a specific slot changed
	SignalBus.party_member_stats_changed.emit(slot_index, character)
	return true

## Clears out a slot (e.g., if a cat is removed or permanently deleted)
func remove_character_from_slot(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < 6:
		party[slot_index] = null
		SignalBus.party_member_stats_changed.emit(slot_index, null)

## Row validation helpers for Wizardry positioning rules
func is_front_row(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index <= 2

func is_back_row(slot_index: int) -> bool:
	return slot_index >= 3 and slot_index <= 5

## Returns all valid, non-null party members
func get_living_party() -> Array[CatCharacter]:
	var active_members: Array[CatCharacter] = []
	for member in party:
		if member != null:
			active_members.append(member)
	return active_members

## Safe data injection pipeline from the Title Screen builder
func set_party_slot(slot_index: int, character: CatCharacter) -> void:
	if slot_index < 0 or slot_index >= 6:
		push_error("Invalid tactical party slot index: %d" % slot_index)
		return
		
	party[slot_index] = character
	
	# Broadcast the update through the newly fixed event bus!
	SignalBus.party_member_stats_changed.emit(slot_index, character)

	_connect_character_stats_signals(character, slot_index)

func _connect_character_stats_signals(character: CatCharacter, slot_index: int) -> void:
	if character == null or character.stats == null:
		return

	# Disconnect any existing connections to prevent duplicates
	if character.stats.damaged.is_connected(Callable(self, "_on_character_stats_changed").bind(slot_index, character)):
		character.stats.damaged.disconnect(Callable(self, "_on_character_stats_changed").bind(slot_index, character))
	if character.stats.healed.is_connected(Callable(self, "_on_character_stats_changed").bind(slot_index, character)):
		character.stats.healed.disconnect(Callable(self, "_on_character_stats_changed").bind(slot_index, character))

	character.stats.damaged.connect(Callable(self, "_on_character_stats_changed").bind(slot_index, character))
	character.stats.healed.connect(Callable(self, "_on_character_stats_changed").bind(slot_index, character))

func _on_character_stats_changed(_amount: int, _old_health: int, _new_health: int, slot_index: int, character: CatCharacter) -> void:
	SignalBus.party_member_stats_changed.emit(slot_index, character)
