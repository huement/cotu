# res://Scripts/Resources/SaveGame.gd
class_name SaveGame
extends Resource

## The active 6-slot party matrix (Commander Whiskers, Baron Von Hiss, etc.)
@export var party: DungeonParty

## Central party inventory containing consumables, quest items, and unequipped gear
@export var inventory: Inventory

## Current dungeon floor ID for dungeon progression
@export var current_floor_id: int = 1

## Timestamp of when this save was created
@export var save_timestamp: String = ""
