# res://Scripts/Progression/ShardLedger.gd
class_name ShardLedger
extends RefCounted
## The list of every Arcanum Shard in the game, and which ones the party has collected.
##
## CATALOG is the single list of shards (one row per ArcanumShard placed in a level).
## Collected shards live in GameState.collected_shards and are saved with the game:
##   shard_id -> { "area", "place", "map_id", "play_time" }
##
## For a menu:
##   ShardLedger.areas()            -> one row per area, in catalog order (see areas())
##   ShardLedger.collected_count()  /  ShardLedger.total_count()
##   SignalBus.shard_collected      -> fires when a shard is picked up (refresh then)
##
## Adding a shard: place ArcanumShard.tscn in the level, give it a unique shard_id, and add
## a row here with the same id. tests/progression/test_shard_ledger.gd fails if they differ.

## One row per shard, in the order the areas should be listed.
##   id       = shard_id on the ArcanumShard node
##   area     = name the player sees; shards with the same area are counted together
##   place    = where exactly it is
##   guardian = the boss holding it ("" = lying in the open)
##   scene    = level scene that contains the node
const CATALOG: Array[Dictionary] = [
	{"id": "feroshaw_dungeon", "area": "Fero Shaw", "place": "Fero Shaw Dungeon", "guardian": "Dungeon boss", "scene": "res://Scenes/Dungeons/FeroShawDungeon.tscn"},
	{"id": "verowood_dungeon", "area": "Vero Woods", "place": "Vero Wood Dungeon", "guardian": "Dungeon boss", "scene": "res://Scenes/Dungeons/VeroWoodDungeon.tscn"},
	{"id": "brokenbonemarsh_beast", "area": "Bone Marsh", "place": "Broken Bone Marsh", "guardian": "Beast King", "scene": "res://Scenes/BrokenBoneMarsh.tscn"},
	{"id": "stonetrail_blob", "area": "Stone Trail", "place": "Stone Trail", "guardian": "Blob Monster", "scene": "res://Scenes/StoneTrail.tscn"},
	{"id": "gloomreach_slimelord", "area": "Gloom Reach", "place": "Gloom Reach", "guardian": "Slime Lord", "scene": "res://Scenes/GloomReach.tscn"},
]


# ==============================================================================
# Collecting
# ==============================================================================

## Records the shard, tells listeners (SignalBus.shard_collected) and saves the game.
## `fallback_area` is only used for a shard that has no CATALOG row yet.
static func collect(shard_id: String, fallback_area: String = "") -> void:
	if shard_id.is_empty() or is_collected(shard_id):
		return
	var row: Dictionary = entry(shard_id)
	var area: String = str(row.get("area", fallback_area))
	GameState.collected_shards[shard_id] = {
		"area": area,
		"place": str(row.get("place", fallback_area)),
		"map_id": GameState.get_current_map_id(),
		"play_time": GameState.play_time_seconds,
	}
	SignalBus.shard_collected.emit(shard_id, area)
	GameState.save_game()


static func is_collected(shard_id: String) -> bool:
	return GameState.collected_shards.has(shard_id)


# ==============================================================================
# Reading
# ==============================================================================

## The CATALOG row of a shard ({} when it is not listed).
static func entry(shard_id: String) -> Dictionary:
	for row: Dictionary in CATALOG:
		if str(row["id"]) == shard_id:
			return row
	return {}


static func is_known(shard_id: String) -> bool:
	return not entry(shard_id).is_empty()


## Area name of a shard (falls back to what was recorded when it was collected).
static func area_of(shard_id: String) -> String:
	var row: Dictionary = entry(shard_id)
	if not row.is_empty():
		return str(row["area"])
	var saved: Dictionary = GameState.collected_shards.get(shard_id, {}) as Dictionary
	return str(saved.get("area", ""))


static func total_count() -> int:
	return all_ids().size()


static func collected_count() -> int:
	return GameState.collected_shards.size()


## Every shard id: the catalog, plus any collected shard that is not in it yet.
static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for row: Dictionary in CATALOG:
		ids.append(str(row["id"]))
	for id: Variant in GameState.collected_shards.keys():
		if not ids.has(str(id)):
			ids.append(str(id))
	return ids


static func collected_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in all_ids():
		if is_collected(id):
			ids.append(id)
	return ids


static func remaining_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in all_ids():
		if not is_collected(id):
			ids.append(id)
	return ids


## One row per area, in catalog order - what a progress menu needs:
##   { "name": "Fero Shaw", "collected": 0, "total": 1,
##     "shards": [ { "id", "place", "guardian", "collected": bool } ] }
static func areas() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var index_by_name: Dictionary = {}
	for id: String in all_ids():
		var row: Dictionary = entry(id)
		var area: String = area_of(id)
		if area.is_empty():
			area = "Unknown"
		if not index_by_name.has(area):
			index_by_name[area] = out.size()
			out.append({"name": area, "collected": 0, "total": 0, "shards": []})
		var group: Dictionary = out[int(index_by_name[area])]
		var got: bool = is_collected(id)
		group["total"] = int(group["total"]) + 1
		if got:
			group["collected"] = int(group["collected"]) + 1
		(group["shards"] as Array).append({
			"id": id,
			"place": str(row.get("place", area)),
			"guardian": str(row.get("guardian", "")),
			"collected": got,
		})
	return out
