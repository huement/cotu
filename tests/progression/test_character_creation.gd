# res://tests/progression/test_character_creation.gd
extends GutTest

const TEST_POOL: String = "user://test_character_pool/"


func _race(n: String) -> CatBreed:
	return load("res://Data/Races/%s.tres" % n) as CatBreed


func _cls(n: String) -> ProfessionData:
	return load("res://Data/Classes/%s.tres" % n) as ProfessionData


func before_each() -> void:
	CharacterRoster.pool_dir = TEST_POOL
	_wipe_pool()


func after_all() -> void:
	_wipe_pool()
	CharacterRoster.pool_dir = CharacterRoster.DEFAULT_DIR


func _wipe_pool() -> void:
	if DirAccess.dir_exists_absolute(TEST_POOL):
		for f: String in DirAccess.get_files_at(TEST_POOL):
			DirAccess.remove_absolute(TEST_POOL + f)


## Draft after a birth roll of `face` (default 6).
func _draft(race: String, cls: String, face: int = 6) -> Dictionary:
	var breed := _race(race)
	var prof := _cls(cls)
	var birth: Dictionary = CharacterCreation.apply_birth_roll(breed, prof, face)
	return {
		"name": "Test " + race,
		"breed": breed,
		"profession": prof,
		"bonus_dice": [int(birth["face"])],
		"bonus_pool": int(birth["face"]),
		"allocation": (birth["allocation"] as Dictionary).duplicate(),
		"ability_points": int(birth["ability"]),
		"spells": CharacterCreation.default_spell_picks(breed, prof),
		"skills": CharacterCreation.default_skill_picks(breed, prof),
	}


func test_lists_load() -> void:
	assert_eq(CharacterCreation.all_races().size(), 11)
	var classes: Array[ProfessionData] = CharacterCreation.all_classes()
	assert_eq(classes.size(), 14)
	assert_eq(classes[0].profession_name, "Spartan", "easiest class first")


func test_base_stats_default_to_eight() -> void:
	var tabby: Dictionary = CharacterCreation.base_stats(_race("Tabby"))
	assert_eq(int(tabby["strength"]), 9)
	assert_eq(int(tabby["intelligence"]), 8, "unset base stats use CatBreed's default 8")


func test_primary_stat() -> void:
	assert_eq(CharacterCreation.primary_stat(_cls("Spartan")), "strength")
	assert_eq(CharacterCreation.primary_stat(_cls("Shade")), "dexterity")
	# Wizard INT 15 and PIE 15 — STATS order picks intelligence first on a tie.
	assert_eq(CharacterCreation.primary_stat(_cls("Wizard")), "intelligence")


func test_birth_die_outcomes() -> void:
	assert_eq(CharacterCreation.creation_bonus_for_roll(1), {"stat": 1, "ability": 0})
	assert_eq(CharacterCreation.creation_bonus_for_roll(4), {"stat": 4, "ability": 0})
	assert_eq(CharacterCreation.creation_bonus_for_roll(5), {"stat": 5, "ability": 1})
	assert_eq(CharacterCreation.creation_bonus_for_roll(6), {"stat": 6, "ability": 2})


func test_points_needed_and_reachability() -> void:
	# Wizard needs INT 15 + PIE 15; birth die only boosts primary (INT). Bengal can't cover PIE.
	assert_false(CharacterCreation.is_class_reachable(_race("Bengal"), _cls("Wizard")))
	assert_true(CharacterCreation.is_class_reachable(_race("Bengal"), _cls("Spartan")))
	# Sphynx STR 5, Spartan STR 12 → primary shortfall 7 > 6 → unreachable
	assert_eq(CharacterCreation.primary_points_needed(_race("Sphynx"), _cls("Spartan")), 7)
	assert_false(CharacterCreation.is_class_reachable(_race("Sphynx"), _cls("Spartan")))
	# every race can be something
	for breed: CatBreed in CharacterCreation.all_races():
		var any: bool = false
		for prof: ProfessionData in CharacterCreation.all_classes():
			any = any or CharacterCreation.is_class_reachable(breed, prof)
		assert_true(any, "%s has at least one class" % breed.breed_name)


func test_dice_is_one_d6() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	assert_eq(CharacterCreation.BONUS_DICE, 1)
	for i: int in 50:
		var dice: Array[int] = CharacterCreation.roll_bonus_dice(rng)
		assert_eq(dice.size(), 1)
		assert_between(dice[0], 1, 6)
		assert_eq(CharacterCreation.sum_dice(dice), dice[0])


func test_apply_birth_roll_primary_and_floor() -> void:
	var breed := _race("Bengal")
	var prof := _cls("Spartan")
	# Bengal STR already meets Spartan 12 — face 3 is pure bonus.
	var birth: Dictionary = CharacterCreation.apply_birth_roll(breed, prof, 3)
	assert_eq(str(birth["primary"]), "strength")
	assert_eq(int(birth["ability"]), 0)
	assert_eq(int((birth["allocation"] as Dictionary).get("strength", 0)), 3)
	assert_true(CharacterCreation.meets_requirements(birth["stats"] as Dictionary, prof))
	# Face 6 also banks ability points.
	var six: Dictionary = CharacterCreation.apply_birth_roll(breed, prof, 6)
	assert_eq(int(six["ability"]), 2)
	assert_eq(int((six["allocation"] as Dictionary).get("strength", 0)), 6)


func test_ability_picks() -> void:
	assert_eq(CharacterCreation.spell_pick_count(_race("Siamese"), _cls("Archanist")), 1)
	assert_eq(CharacterCreation.spell_pick_count(_race("Bengal"), _cls("Spartan")), 0)
	assert_eq(CharacterCreation.skill_pick_count(_race("Bengal"), _cls("Spartan")), 1)
	var free: Array[SkillData] = CharacterCreation.race_skills(_race("Bengal"))
	assert_eq(free.size(), 1)
	assert_eq(free[0].skill_name, "Feral Pounce")
	var pick: Array[SkillData] = CharacterCreation.default_skill_picks(_race("Bengal"), _cls("Spartan"))
	assert_eq(pick[0].skill_type, SkillData.SkillType.COMBAT, "default pick is a combat skill")


func test_build_character() -> void:
	var draft: Dictionary = _draft("Bengal", "Spartan", 6)
	assert_eq(CharacterCreation.validate_draft(draft), [] as Array[String])
	var cat: CatCharacter = CharacterCreation.build_character(draft)
	assert_eq(cat.name, "Test Bengal")
	assert_eq(cat.level, 1)
	assert_true(cat.abilities_initialized)
	assert_eq(cat.known_skills.size(), 2, "Feral Pounce + 1 class pick")
	assert_eq(cat.known_spells.size(), 0)
	assert_gt(cat.max_hp, 0)
	assert_eq(cat.current_hp, cat.max_hp)
	assert_eq(cat.creation_dice, [6] as Array[int])
	assert_eq(int(cat.creation_allocation.get("strength", 0)), 6)
	# Face 6 banks 2 skill/spell — Spartan has skills, no spells → all skill.
	assert_eq(cat.unspent_skill_points, 2)
	assert_eq(cat.unspent_spell_points, 0)
	cat.populate_starting_skills()
	assert_eq(cat.known_skills.size(), 2)
	var again: Dictionary = CharacterCreation.draft_from_character(cat)
	assert_eq(int(again["bonus_pool"]), 6)
	assert_eq((again["skills"] as Array).size(), 1, "race skill isn't a pick")


func test_build_character_face_four_no_ability_bank() -> void:
	var draft: Dictionary = _draft("Bengal", "Spartan", 4)
	var cat: CatCharacter = CharacterCreation.build_character(draft)
	assert_eq(cat.unspent_skill_points, 0)
	assert_eq(cat.unspent_spell_points, 0)
	assert_eq(int(cat.creation_allocation.get("strength", 0)), 4)


func test_validate_draft_problems() -> void:
	var draft: Dictionary = _draft("Bengal", "Spartan")
	draft["name"] = "   "
	assert_eq(CharacterCreation.validate_selection(draft), ["Give your character a name."] as Array[String])
	draft = _draft("Bengal", "Spartan")
	draft["bonus_dice"] = []
	assert_true(CharacterCreation.validate_draft(draft).has("Birth die has not been rolled."))


func test_roster_save_list_lock_remove() -> void:
	var a: CatCharacter = CharacterCreation.build_character(_draft("Bengal", "Spartan"))
	var b: CatCharacter = CharacterCreation.build_character(_draft("Siamese", "Archanist"))
	assert_eq(CharacterRoster.save(a), OK)
	assert_eq(CharacterRoster.save(b), OK)
	assert_false(a.roster_id.is_empty())
	var all: Array[CatCharacter] = CharacterRoster.list()
	assert_eq(all.size(), 2)
	var loaded: CatCharacter = CharacterRoster.load_character(b.roster_id)
	assert_eq(loaded.name, "Test Siamese")
	assert_eq(loaded.known_spells.size(), 1)
	assert_eq(loaded.profession.resource_path, "res://Data/Classes/Archanist.tres", "classes stay shared resources")

	var party: DungeonParty = CharacterRoster.build_party(["", a.roster_id, "", "", b.roster_id, ""])
	assert_null(party.slots[0])
	assert_eq((party.slots[1] as CatCharacter).name, "Test Bengal")
	assert_true((party.slots[1] as CatCharacter).is_front_row)
	assert_false((party.slots[4] as CatCharacter).is_front_row)
	assert_ne(party.slots[1], a, "the game gets a copy")
	assert_eq(CharacterRoster.lock([a.roster_id]), 1)
	assert_true(CharacterRoster.is_locked(a.roster_id))
	assert_false(CharacterRoster.is_locked(b.roster_id))

	var locked: CatCharacter = CharacterRoster.load_character(a.roster_id)
	locked.name = "Renamed"
	assert_eq(CharacterRoster.save(locked), ERR_LOCKED)
	assert_false(CharacterRoster.remove(locked))
	assert_true(CharacterRoster.remove(b))
	assert_eq(CharacterRoster.list().size(), 1)


func test_every_class_has_a_portrait() -> void:
	for prof: ProfessionData in CharacterCreation.all_classes():
		var path: String = CharacterCreation.portrait_path_for(prof)
		assert_false(path.is_empty(), "%s has a portrait in Data/Portraits" % prof.profession_name)
		assert_not_null(load(path) if not path.is_empty() else null, "%s portrait loads" % prof.profession_name)


func test_starter_kit_for_every_class() -> void:
	for prof: ProfessionData in CharacterCreation.all_classes():
		var cat: CatCharacter = CharacterCreation.preview_character(_race("Tabby"), prof)
		var spare: Array[ItemData] = StarterKit.equip(cat)
		for slot: String in ["HEAD", "BODY", "ARMS", "LEGS", "FEET"]:
			assert_not_null(cat.get_equipped_item(slot), "%s starts with %s armour" % [prof.profession_name, slot])
		var weapon: ItemData = cat.get_equipped_item("RIGHT_HAND") as ItemData
		assert_not_null(weapon, "%s starts with a weapon" % prof.profession_name)
		assert_gt(cat.equipment_bonus_defense, 0, "%s armour counts" % prof.profession_name)
		var names: PackedStringArray = []
		for s: ItemData in spare:
			names.append(s.item_name)
		gut.p("%s: %s / %s | pack: %s" % [prof.profession_name, weapon.item_name if weapon else "-",
			(cat.get_equipped_item("LEFT_HAND") as ItemData).item_name if cat.get_equipped_item("LEFT_HAND") else "-", ", ".join(names)])


func test_starter_kit_spares_go_to_the_pack() -> void:
	var warden: CatCharacter = CharacterCreation.preview_character(_race("Tabby"), _cls("Warden"))
	var spare: Array[ItemData] = StarterKit.equip(warden)
	assert_eq((warden.get_equipped_item("RIGHT_HAND") as ItemData).item_name, "Crossbow")
	assert_eq((warden.get_equipped_item("LEFT_HAND") as ItemData).item_name, "Iron Arrows")
	assert_eq(spare.size(), 2)
	assert_eq(spare[0].item_name, "Iron Dagger")
	assert_eq(spare[1].item_name, "Throwing Knife")


func test_soulwright_starts_with_staff_no_shield() -> void:
	var soul: CatCharacter = CharacterCreation.preview_character(_race("Tabby"), _cls("Soulwright"))
	var spare: Array[ItemData] = StarterKit.equip(soul)
	var weapon: ItemData = soul.get_equipped_item("RIGHT_HAND") as ItemData
	assert_not_null(weapon)
	assert_eq(weapon.item_name, "Wooden Staff")
	assert_eq(weapon.equipment_slot, ItemData.EquipmentSlot.BOTH_HANDS)
	assert_null(soul.get_equipped_item("LEFT_HAND"), "Soulwright is a caster — no starter shield")
	for s: ItemData in spare:
		assert_false(s.item_name.contains("Shield"), "Soulwright kit must not spare a shield")
