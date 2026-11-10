# res://Scripts/Triggers/level_title_trigger.gd
## Data marker for a map's display title. MapManager reads this on load —
## do not place walk-through Area3D copies at every exit.
extends Node3D

const GROUP_LEVEL_TITLE: StringName = &"level_title"

@export_multiline var level_title: String = "Dungeon\nLevel 01"
## When true, MapManager plays a random new-area stinger (new-area / 2 / 3) on load.
@export var play_new_area_sound: bool = true


func _ready() -> void:
	add_to_group(GROUP_LEVEL_TITLE)
