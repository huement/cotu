# res://Scripts/Resources/EnemyData.gd
class_name EnemyData
extends Resource

@export var enemy_id: String = ""
@export var enemy_name: String = "Corrupted Bio-Unit"
@export var max_health: int = 30
@export var current_health: int = 30
@export var attack_damage: int = 8
@export var defense: int = 2
@export var speed: float = 10.0
@export var xp_value: int = 50
@export var gold_value: int = 25 # Base coin drop per enemy

# How fast they move at the start of battle
@export var initiative_speed: int = 12

## Controls the 3D model visual scale in the world
@export var model_scale: Vector3 = Vector3(0.5, 0.5, 0.5)

## Reference to the visual 3D scene (.glb file or custom inherited scene)
@export var model_scene: PackedScene
