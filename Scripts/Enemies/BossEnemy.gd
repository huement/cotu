# res://Scripts/Enemies/BossEnemy.gd
class_name BossEnemy
extends WorldEnemy

## Specialized stationary boss enemy with model scaling, fixed facing alignment,
## and automatic minion party layout for combat.

# ==============================================================================
# 1. EXPORTED BOSS CONFIGURATION
# ==============================================================================
## Facing direction in the room (lets you align the boss with its back to the wall)
@export var default_facing: Facing = Facing.SOUTH

## Model scale multiplier applied to the standard overworld model size
@export var model_scale_multiplier: float = 1.5

## Optional minion resource to flank the boss in combat
@export var minion_data: Resource

## Total number of minions accompanying the boss (e.g., 2 places 1 minion on each side)
@export_range(0, 4) var minion_count: int = 2


# ==============================================================================
# 2. LIFECYCLE & COMBAT PARTY SETUP
# ==============================================================================
func _ready() -> void:
	_current_facing = default_facing
	# Apply scale multiplier before base script instantiates the 3D mesh
	model_scale *= model_scale_multiplier
	super._ready()


func _setup_enemy_group() -> void:
	# If enemy_group was manually populated in the Inspector, preserve it
	if not enemy_group.is_empty():
		return

	var primary_boss_resource: Resource = data if data != null else enemy_data
	if not is_instance_valid(primary_boss_resource):
		super._setup_enemy_group()
		return

	enemy_group.clear()

	# Build party array: Minions on left, Boss in center, Minions on right
	if is_instance_valid(minion_data) and minion_count > 0:
		var left_count: int = minion_count / 2
		var right_count: int = minion_count - left_count

		for i in range(left_count):
			enemy_group.append(minion_data.duplicate())

		enemy_group.append(primary_boss_resource.duplicate())

		for i in range(right_count):
			enemy_group.append(minion_data.duplicate())
	else:
		# Solo boss encounter
		enemy_group.append(primary_boss_resource.duplicate())


# ==============================================================================
# 3. STATIONARY OVERRIDE
# ==============================================================================
## Overrides movement logic so the boss remains locked in place
func _check_pursuit_range() -> void:
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var player_cell: Vector2i = player.current_grid_pos if is_instance_valid(player) and ("current_grid_pos" in player) else Vector2i(-9999, -9999)

	var dist_to_player: int = absi(_grid_position.x - player_cell.x) + absi(_grid_position.y - player_cell.y)

	# Trigger combat when player walks into adjacent tile without moving boss from tile
	if dist_to_player <= 1:
		trigger_combat_encounter()
