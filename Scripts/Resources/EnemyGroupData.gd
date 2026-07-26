# res://Scripts/Resources/EnemyGroupData.gd
class_name EnemyGroupData
extends Resource

@export var group_name: String = "Zombie Cat Pack"
## Holds up to 9 EnemyData resources (Slots 0 to 8)
@export var members: Array[EnemyData] = []
