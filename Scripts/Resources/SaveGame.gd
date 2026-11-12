# res://Scripts/Resources/SaveGame.gd
class_name SaveGame
extends Resource
## Everything a save file holds. Written by GameState.save_game(), read by GameState.load_game().
## Fields added later default to "not saved" values, so older saves still load (they start on the
## default map with fresh world state).

const CURRENT_VERSION: int = 2

## Bumped when the format changes (1 = party/inventory/floor only, 2 = + location, gold, world state).
@export var save_version: int = 1

## The active 6-slot party matrix (Commander Whiskers, Baron Von Hiss, etc.)
@export var party: DungeonParty

## Central party inventory containing consumables, quest items, and unequipped gear
@export var inventory: Inventory

## Current dungeon floor ID for dungeon progression
@export var current_floor_id: int = 1

## Timestamp of when this save was created
@export var save_timestamp: String = ""

@export_group("Economy")
@export var party_gold: int = 0

@export_group("Location")
## res:// path of the map the party was on ("" = start on the default map).
@export var map_scene_path: String = ""
## Display name of that map (for save/load screens).
@export var location_name: String = ""
## Grid cell and facing ("NORTH" / "EAST" / "SOUTH" / "WEST") inside that map.
@export var player_cell: Vector2i = Vector2i.ZERO
@export var player_facing: String = "NORTH"
## Named Marker3D to use instead of player_cell (e.g. GreenGrove SpawnPointNewGame).
## Cleared once a normal in-world save records a real cell.
@export var spawn_marker: String = ""

@export_group("World")
## GameState.environment_states: map_id -> object_id -> flags (chests opened, puzzles, bosses...).
@export var environment_states: Dictionary = {}
## Day/night clock 0..1 (0.25 = morning) and its period name.
@export var world_time: float = 0.25
@export var time_period: String = "MORNING"
## Total time played, in seconds.
@export var play_time_seconds: float = 0.0
## Arcanum Shards the party holds: shard_id -> { "level", "map_id" } (see ShardLedger).
@export var collected_shards: Dictionary = {}
