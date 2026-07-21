# res://Core/CoreGameState.gd (or GameState.gd)
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

func get_active_cat() -> CatCharacter:
	if current_party and active_character_index >= 0 and active_character_index < current_party.slots.size():
		return current_party.slots[active_character_index]
	return null

func _ready() -> void:
	_initialize_active_session()

func _initialize_active_session() -> void:
	print("GameState: Assembling tactical data structures...")
	current_party = DungeonParty.new()
	
	# Clear any old inventory state
	inventory = Inventory.new()

	# 1. Preload starting item resources directly
	var laser_claw: ItemData = preload("res://Data/Items/Equipment/LaserClaw.tres") as ItemData
	var power_suit: ItemData = preload("res://Data/Items/Equipment/PowerSuit.tres") as ItemData
	var catnip_potion: ItemData = preload("res://Data/Items/Consumables/CatnipPotion.tres") as ItemData

	# 2. Equip starting gear directly onto Commander Whiskers
	var commander: CatCharacter = current_party.slots[0]
	if is_instance_valid(commander):
		if is_instance_valid(laser_claw):
			commander.equip_item("RIGHT_HAND", laser_claw)
		if is_instance_valid(power_suit):
			commander.equip_item("BODY", power_suit)

	# 3. Add remaining consumables/backpack items into party inventory
	if is_instance_valid(catnip_potion):
		inventory.add_item(catnip_potion)

	# 3a. Preload and assign starting spells & skills
	var plasma_dart: SpellData = preload("res://Data/Spells/PlasmaDart.tres") as SpellData
	var purr_healing: SpellData = preload("res://Data/Spells/PurrHealing.tres") as SpellData
	var lockpicking: SkillData = preload("res://Data/Skills/Lockpicking.tres") as SkillData
	var laser_claw_prof: SkillData = preload("res://Data/Skills/LaserClawProficiency.tres") as SkillData

	if is_instance_valid(commander):
		commander.known_spells.append(plasma_dart)
		commander.known_spells.append(purr_healing)
		commander.known_skills.append(lockpicking)
		commander.known_skills.append(laser_claw_prof)

	# 4. Link all party members to share the central party inventory
	for slot in current_party.slots:
		if is_instance_valid(slot):
			slot.inventory = inventory
			slot.initialize_stats()
