# res://tests/progression/test_shard_ledger.gd
extends GutTest
## Keeps ShardLedger.CATALOG and the ArcanumShard nodes placed in the levels in step.

const SCENE_DIRS: Array[String] = ["res://Scenes", "res://Scenes/Dungeons", "res://Scenes/Caves"]

var _saved: Dictionary = {}


func before_each() -> void:
	_saved = GameState.collected_shards.duplicate(true)
	GameState.collected_shards = {}


func after_each() -> void:
	GameState.collected_shards = _saved


## shard_id -> scene path, read from the level scene files (text .tscn).
func _placed_shards() -> Dictionary:
	var found: Dictionary = {}
	var regex := RegEx.new()
	regex.compile("shard_id = \"([^\"]+)\"")
	for dir: String in SCENE_DIRS:
		for file: String in ResourceLoader.list_directory(dir):
			if not file.ends_with(".tscn"):
				continue
			var path: String = dir.path_join(file)
			var text: String = FileAccess.get_file_as_string(path)
			if not text.contains("ArcanumShard.tscn"):
				continue
			for hit: RegExMatch in regex.search_all(text):
				var id: String = hit.get_string(1)
				assert_false(found.has(id), "shard_id '%s' is used twice (%s and %s)" % [id, found.get(id, ""), path])
				found[id] = path
	return found


func test_every_placed_shard_is_in_the_catalog() -> void:
	var placed: Dictionary = _placed_shards()
	for id: Variant in placed.keys():
		assert_true(ShardLedger.is_known(str(id)), "Shard '%s' in %s has no ShardLedger.CATALOG row" % [id, placed[id]])


func test_every_catalog_row_is_placed_in_its_scene() -> void:
	var placed: Dictionary = _placed_shards()
	for row: Dictionary in ShardLedger.CATALOG:
		var id: String = str(row["id"])
		assert_true(placed.has(id), "CATALOG row '%s' has no ArcanumShard in any level" % id)
		assert_eq(str(placed.get(id, "")), str(row["scene"]), "CATALOG row '%s' points at the wrong scene" % id)


func test_catalog_ids_are_unique() -> void:
	var seen: Dictionary = {}
	for row: Dictionary in ShardLedger.CATALOG:
		assert_false(seen.has(row["id"]), "Duplicate CATALOG id '%s'" % row["id"])
		seen[row["id"]] = true


func test_areas_count_collected_shards() -> void:
	assert_eq(ShardLedger.collected_count(), 0)
	assert_eq(ShardLedger.total_count(), ShardLedger.CATALOG.size())
	var first: Dictionary = ShardLedger.CATALOG[0]
	GameState.collected_shards[str(first["id"])] = {"area": first["area"]}
	assert_true(ShardLedger.is_collected(str(first["id"])))
	assert_eq(ShardLedger.collected_count(), 1)
	assert_eq(ShardLedger.remaining_ids().size(), ShardLedger.CATALOG.size() - 1)
	var rows: Array[Dictionary] = ShardLedger.areas()
	assert_eq(str(rows[0]["name"]), str(first["area"]))
	assert_eq(int(rows[0]["collected"]), 1)


func test_uncatalogued_collected_shard_still_shows() -> void:
	GameState.collected_shards["mystery_shard"] = {"area": "Somewhere"}
	assert_eq(ShardLedger.total_count(), ShardLedger.CATALOG.size() + 1)
	var names: Array[String] = []
	for row: Dictionary in ShardLedger.areas():
		names.append(str(row["name"]))
	assert_has(names, "Somewhere")
