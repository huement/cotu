class_name DungeonLevel
extends Node3D
## Root of a generated dungeon level (see Scripts/Utilities/GenerateDungeonLevel.gd).
## MapManager reads `map_type` (footstep sounds) and `bgm_track_name` (music).
## The generator values record how the level was built.
##
## Layout: rooms are DungeonRoom scenes under Rooms/, corridors are model instances under
## Corridors/, FloorMap is the (empty) 2 m movement grid and WallMap holds invisible blockers
## for corridor walls (rooms block with their own collision).

@export var map_type: String = "dungeon"
@export var bgm_track_name: String = "Environment/dungeon-creepy"

@export_group("Generator")
@export var level_seed: int = 0
@export var room_count: int = 6
@export var enemy_count: int = 6
