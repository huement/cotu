extends GutTest
## Which maps fight in a battle room, and which room scene they use (Scripts/Managers/BattleArena.gd).


func test_dungeon_uses_dungeon_room() -> void:
	var map: DungeonLevel = autofree(DungeonLevel.new())
	assert_true(BattleArena.map_uses_battle_room(map))
	assert_eq(BattleArena.room_scene_path_for(map), BattleArena.ROOM_SCENE_PATH)


func test_cave_uses_cave_room() -> void:
	var map: CaveLevel = autofree(CaveLevel.new())
	assert_true(BattleArena.map_uses_battle_room(map))
	assert_eq(BattleArena.room_scene_path_for(map), BattleArena.CAVE_ROOM_SCENE_PATH)


func test_plain_map_fights_in_place() -> void:
	var map: Node3D = autofree(Node3D.new())
	assert_false(BattleArena.map_uses_battle_room(map))


func test_metadata_turns_the_room_off() -> void:
	var map: CaveLevel = autofree(CaveLevel.new())
	map.set_meta(BattleArena.MAP_META, false)
	assert_false(BattleArena.map_uses_battle_room(map))


func test_metadata_picks_a_custom_room() -> void:
	var map: Node3D = autofree(Node3D.new())
	map.set_meta(BattleArena.MAP_META, true)
	map.set_meta(BattleArena.ROOM_SCENE_META, "res://Scenes/Caves/CaveBattle.tscn")
	assert_true(BattleArena.map_uses_battle_room(map))
	assert_eq(BattleArena.room_scene_path_for(map), "res://Scenes/Caves/CaveBattle.tscn")


func test_room_scenes_exist_with_a_spawn_point() -> void:
	for path: String in [BattleArena.ROOM_SCENE_PATH, BattleArena.CAVE_ROOM_SCENE_PATH]:
		assert_true(ResourceLoader.exists(path), path)
		var room: Node3D = autofree((load(path) as PackedScene).instantiate() as Node3D)
		assert_not_null(room.get_node_or_null("SpawnPoint"), "%s needs a SpawnPoint" % path)
