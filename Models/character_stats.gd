class_name CharacterStats
extends Resource

signal damaged(amount: int, old_health: int, new_health: int)
signal healed(amount: int, old_health: int, new_health: int)

const MAX_INT := 2147483647

@export var max_health: int = 10
@export var attack: int = 2
@export var defence: int = 0

var health: int = 0


func _init(p_max_health: int = 10, p_attack: int = 2, p_defence: int = 0) -> void:
	max_health = p_max_health
	attack = p_attack
	defence = p_defence
	health = max_health


func take_damage(amount: int) -> void:
	var dealt := clampi(amount - defence, 1, MAX_INT)
	var old_health := health
	health = clampi(health - dealt, 0, max_health)
	if health != old_health:
		damaged.emit(dealt, old_health, health)


func heal(amount: int) -> void:
	var applied := clampi(amount, 0, MAX_INT)
	var old_health := health
	health = clampi(health + applied, 0, max_health)
	if health != old_health:
		healed.emit(health - old_health, old_health, health)


func is_dead() -> bool:
	return health <= 0


func fill() -> void:
	var old_health := health
	health = max_health
	if health != old_health:
		healed.emit(health - old_health, old_health, health)
