extends GutTest
## BossCutsceneEnding: the drain maths and the forced-fight pack (no scene tree needed).


func test_drain_leaves_the_percent_of_max() -> void:
	assert_eq(BossCutsceneEnding.drained_value(200, 200, 10.0), 20)
	assert_eq(BossCutsceneEnding.drained_value(200, 200, 1.0), 2)


func test_drain_never_kills_a_living_member() -> void:
	assert_eq(BossCutsceneEnding.drained_value(30, 30, 1.0), 1)


func test_drain_never_heals() -> void:
	assert_eq(BossCutsceneEnding.drained_value(3, 200, 10.0), 3, "already below the floor: untouched")
	assert_eq(BossCutsceneEnding.drained_value(0, 200, 10.0), 0, "the dead stay dead / empty mana stays empty")


func test_apply_drain_does_nothing_when_off() -> void:
	var ending := BossCutsceneEnding.new()
	ending.drain_party = false
	assert_eq(ending.apply_drain([null, null]).size(), 0)


func test_fight_group_is_capped_and_copied() -> void:
	var ending := BossCutsceneEnding.new()
	var source := EnemyData.new()
	source.max_health = 40
	source.current_health = 5
	for i: int in range(6):
		ending.fight_enemies.append(source)
	ending.fight_enemies.append(null)
	var group: Array[Resource] = ending.build_fight_group()
	assert_eq(group.size(), BossCutsceneEnding.MAX_FIGHT_ENEMIES)
	assert_ne(group[0], source, "each fighter is its own copy")
	assert_eq((group[0] as EnemyData).current_health, 40, "copies start at full health")
	assert_eq(source.current_health, 5, "the shared data is not edited")


func test_blank_dialog_text_means_no_dialog() -> void:
	var ending := BossCutsceneEnding.new()
	ending.dialog_text = "  \n "
	assert_false(ending.has_dialog())
	ending.dialog_text = "Kneel."
	assert_true(ending.has_dialog())
