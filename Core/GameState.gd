extends Node
class_name CoreGameState

enum Mode { EXPLORING, BATTLE, MANAGEMENT }

signal core_state_changed(new_mode: Mode)

var current_mode: Mode = Mode.EXPLORING:
	set(value):
		if current_mode != value:
			current_mode = value
			core_state_changed.emit(current_mode)

@export var current_party: DungeonParty
@export var inventory: Inventory = Inventory.new()
@export var current_floor_id: int = 1
var active_character_index: int = 0

## Returns the currently selected Space Cat resource from the active 6-slot party
func get_active_cat() -> Resource:
	if current_party != null:
		var party_slots: Array = current_party.get("slots") as Array
		if party_slots != null and active_character_index >= 0 and active_character_index < party_slots.size():
			return party_slots[active_character_index] as Resource
	return null

func _ready() -> void:
	_initialize_active_session()

func _initialize_active_session() -> void:
	print("GameState: Assembling tactical data structures...")
	
	# 1. Instantiate Party & Setup Starter Cats
	current_party = DungeonParty.new()
	if current_party.has_method("setup_starter_party"):
		current_party.setup_starter_party()
		
	inventory = Inventory.new()

	# 2. Safely resolve party slots array via dynamic property lookup
	var party_slots: Array = current_party.get("slots") as Array if current_party else []

	# 3. Preload starting item resources
	var laser_claw: ItemData = preload("res://Data/Items/Equipment/LaserClaw.tres") as ItemData
	var power_suit: ItemData = preload("res://Data/Items/Equipment/PowerSuit.tres") as ItemData
	var catnip_potion: ItemData = preload("res://Data/Items/Consumables/CatnipPotion.tres") as ItemData

	# 4. Equip starting gear onto Commander Whiskers (Slot 0)
	if party_slots.size() > 0:
		var commander: Resource = party_slots[0] as Resource
		if is_instance_valid(commander) and commander.has_method("equip_item"):
			if is_instance_valid(laser_claw):
				commander.call("equip_item", "RIGHT_HAND", laser_claw)
			if is_instance_valid(power_suit):
				commander.call("equip_item", "BODY", power_suit)

	# 5. Add consumables into central party inventory
	if is_instance_valid(catnip_potion):
		inventory.add_item(catnip_potion)

	# 6. Link inventory and compute stats across all 6 slots
	for slot in party_slots:
		if is_instance_valid(slot):
			if "inventory" in slot:
				slot.inventory = inventory
			if slot.has_method("initialize_stats"):
				slot.initialize_stats()

	# 7. Broadcast roster refresh to HUD
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb and sb.has_signal("party_roster_updated"):
		sb.party_roster_updated.emit(party_slots)
