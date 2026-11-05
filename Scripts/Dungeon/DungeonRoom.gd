class_name DungeonRoom
extends Node3D
## Root script for a dungeon room part (Scenes/Dungeons/Parts/*.tscn).
##
## Scene layout it expects:
##   RoomModel                             - the room .glb
##   Walls                                 - StaticBody3D, one box per blocked 2 m cell (generated)
##   Doors/Door_N, Door_E, Door_S, Door_W  - Marker3D on each doorway cell, -Z pointing OUT of the room
##   Caps/Cap_N, Cap_E, Cap_S, Cap_W       - gate + blocker that closes an UNUSED doorway
##   anything with "Unique Name" (%)       - optional dressing, randomly kept or removed:
##                                           torches (Torch.tscn) use torch_chance, everything else
##                                           decor_chance; plain Node3D folders (e.g. Environment,
##                                           Torches) are searched, not removed.
## Door letters are room-local: N = -Z, E = +X, S = +Z, W = -X (before the room is rotated).
## Put the room's centre on a 2 m cell centre (odd world x/z) so doorways line up with movement.
##
## The level generator sets `open_doors` and `removed_nodes` on each placed room; they are applied
## while the level loads, before the children run _ready (so a removed barrel never registers its
## blocked cell and an open doorway's cap never blocks it).

const DOOR_LETTERS: Array[String] = ["N", "E", "S", "W"]
const STRUCTURE_NODES: Array[String] = ["RoomModel", "Walls", "Doors", "Caps"]
const TORCH_SCENE_SUFFIX: String = "Torch.tscn"

## Room size in metres (x, z) - used by the level generator for overlap checks.
@export var footprint: Vector2i = Vector2i(12, 12)

## Which doorways are connected. A closed doorway keeps its Cap_X node.
@export_flags("North", "East", "South", "West") var open_doors: int = 15

## Node paths (relative to this room) removed when the level loads. Filled in by the generator.
@export var removed_nodes: PackedStringArray = PackedStringArray()

## Prepended to every `object_id` inside this room ("<prefix>/<object_id>") when the level loads, so
## the same room scene used in several levels keeps separate chest/mask save state. Set by the generator.
@export var id_prefix: String = ""

@export_group("Randomisation")
## Chance each decoration survives. Override per node with metadata `spawn_chance` (0..1).
@export_range(0.0, 1.0, 0.05) var decor_chance: float = 0.6
## Chance each torch survives. Override per node with metadata `spawn_chance` (0..1).
@export_range(0.0, 1.0, 0.05) var torch_chance: float = 1.0

var _applied: bool = false


func _enter_tree() -> void:
	# Runs before the children's _enter_tree/_ready, so removals are clean.
	if _applied or Engine.is_editor_hint():
		return
	_applied = true
	for i: int in range(DOOR_LETTERS.size()):
		if is_door_open(open_doors, i):
			_remove_path("Caps/Cap_" + DOOR_LETTERS[i])
	for path: String in removed_nodes:
		_remove_path(path)
	if not id_prefix.is_empty():
		_prefix_object_ids(self)


static func is_door_open(door_mask: int, door_index: int) -> bool:
	return (door_mask & (1 << door_index)) != 0


## Every optional dressing node in `room`: unique-named nodes outside the structure nodes.
## Plain Node3D folders are searched instead of returned.
static func find_dressing(room: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in room.get_children():
		if STRUCTURE_NODES.has(String(child.name)):
			continue
		_collect_dressing(child, found)
	return found


static func is_torch(node: Node) -> bool:
	return node.scene_file_path.ends_with(TORCH_SCENE_SUFFIX)


## Rolls which dressing nodes to remove. Works on a freshly instantiated room (also inside
## EditorScripts). Returns paths relative to the room, for `removed_nodes`.
static func roll_removed_nodes(room: Node, rng: RandomNumberGenerator) -> PackedStringArray:
	var removed := PackedStringArray()
	var decor_default: float = _float_or(room.get("decor_chance"), 0.6)
	var torch_default: float = _float_or(room.get("torch_chance"), 1.0)
	for node: Node in find_dressing(room):
		var default_chance: float = torch_default if is_torch(node) else decor_default
		var chance: float = _float_or(node.get_meta("spawn_chance", default_chance), default_chance)
		if rng.randf() >= chance:
			removed.append(String(room.get_path_to(node)))
	return removed


static func _collect_dressing(node: Node, found: Array[Node]) -> void:
	var is_folder: bool = node.get_class() == "Node3D" and node.scene_file_path.is_empty() and node.get_child_count() > 0
	if is_folder:
		for child: Node in node.get_children():
			_collect_dressing(child, found)
	elif node.unique_name_in_owner:
		found.append(node)


## Chests, masks etc. read `object_id` in their own _ready, which runs after this (children are
## not ready yet during the room's _enter_tree), so they load their saved state under the new id.
func _prefix_object_ids(node: Node) -> void:
	for child: Node in node.get_children():
		if "object_id" in child:
			var current: String = str(child.get("object_id"))
			if not current.begins_with(id_prefix + "/"):
				child.set("object_id", id_prefix + "/" + current)
		_prefix_object_ids(child)


func _remove_path(path: String) -> void:
	var node: Node = get_node_or_null(NodePath(path))
	if node == null:
		return
	node.get_parent().remove_child(node)
	node.free()


static func _float_or(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		return float(value)
	return fallback
