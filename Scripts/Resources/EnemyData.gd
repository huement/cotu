class_name EnemyData
extends Resource

@export var enemy_name: String = "Cyber-Zombie Cat"
@export var max_health: int = 30
@export var initiative_speed: int = 12
@export var attack_damage: int = 6

## Controls the 3D model visual scale in the world
@export var model_scale: Vector3 = Vector3(0.5, 0.5, 0.5)

## Reference to the visual 3D scene (.glb file or custom inherited scene)
@export var model_scene: PackedScene
