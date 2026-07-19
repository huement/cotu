extends Node
class_name CoreGameState

# The universal state types for your classic crawler loop
enum Mode { EXPLORING, BATTLE, MANAGEMENT }

# Signal broadcasted whenever the active mode updates
signal core_state_changed(new_mode: Mode)

# Single source of truth state tracker
var current_mode: Mode = Mode.EXPLORING:
	set(value):
		if current_mode != value:
			current_mode = value
			core_state_changed.emit(current_mode)

@export var current_party: DungeonParty
@export var current_floor_id: int = 1

func _ready() -> void:
	_initialize_active_session()

func _initialize_active_session() -> void:
	print("GameState: Assembling tactical data structures...")
	current_party = DungeonParty.new()
	
	for slot in current_party.slots:
		if slot != null:
			slot.initialize_stats()
