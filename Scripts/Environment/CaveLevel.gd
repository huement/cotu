class_name CaveLevel
extends Node3D
## Root of a generated cave level (see Scripts/Utilities/GenerateCaveLevel.gd).
## MapManager reads `map_type` (footstep sounds) and `bgm_track_name` (music).
## The generator values record how the level was built; RebuildCaveWalls.gd reuses
## `level_seed` so wall variants stay stable when you rebuild after hand edits.

@export var map_type: String = "dungeon"
@export var bgm_track_name: String = "Environment/dungeon-creepy-quite"

@export_group("Generator")
@export var level_seed: int = 0
@export var grid_size: Vector2i = Vector2i(24, 24)
@export var room_count: int = 6
@export var enemy_count: int = 2
