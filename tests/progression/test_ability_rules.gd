# res://tests/progression/test_ability_rules.gd
extends GutTest


func _cat(class_file: String, level: int = 1, breed_file: String = "") -> CatCharacter:
	var cat := CatCharacter.new()
	cat.profession = load("res://Data/Classes/%s.tres" % class_file)
	if not breed_file.is_empty():
		cat.breed = load("res://Data/Races/%s.tres" % breed_file)
	cat.level = level
	return cat


func _ids(list: Array) -> Array[String]:
	var out: Array[String] = []
	for r: Resource in list:
		out.append(AbilityInfo.id(r))
	return out


func test_library_loads_everything() -> void:
	AbilityLibrary.reload()
	assert_eq(AbilityLibrary.all_spells().size(), 22)
	assert_eq(AbilityLibrary.all_skills().size(), 19)
	assert_not_null(AbilityLibrary.spell_by_id("sp_plasma_dart"))
	assert_eq(AbilityLibrary.all_spells()[0].tier, 1)


func test_parse_spellbooks() -> void:
	assert_eq(AbilityRules.parse_spellbooks("Soulwright, Archanist"), [SpellData.SpellbookType.SOULWRIGHT, SpellData.SpellbookType.ARCHANIST] as Array[int])
	assert_eq(AbilityRules.parse_spellbooks("Psynic"), [SpellData.SpellbookType.PSYNIC] as Array[int])
	assert_eq(AbilityRules.parse_spellbooks("None"), [] as Array[int])


func test_tier_gate() -> void:
	assert_eq(AbilityRules.max_tier_for(1, 1), 1)
	assert_eq(AbilityRules.max_tier_for(3, 1), 1)
	assert_eq(AbilityRules.max_tier_for(4, 1), 2)
	assert_eq(AbilityRules.max_tier_for(7, 1), 3)
	assert_eq(AbilityRules.max_tier_for(2, 3), 0)
	assert_eq(AbilityRules.max_tier_for(3, 3), 1)
	assert_eq(AbilityRules.max_tier_for(50, 0), 0)
	assert_eq(AbilityRules.level_for_tier(3, 1), 7)


func test_archanist_level1_learning() -> void:
	var cat := _cat("Archanist", 1)
	var learnable: Array[String] = _ids(AbilityRules.learnable_spells(cat, AbilityLibrary.all_spells()))
	assert_eq(learnable, ["sp_plasma_dart"] as Array[String])
	var static_nova: SpellData = AbilityLibrary.spell_by_id("sp_static_nova")
	assert_eq(AbilityRules.spell_block_reason(cat, static_nova), "Needs level 4")
	cat.level = 4
	assert_true(AbilityRules.can_learn_spell(cat, static_nova))
	assert_false(AbilityRules.can_learn_spell(cat, AbilityLibrary.spell_by_id("sp_plasma_dart_2")) and cat.level < 3)


func test_wrong_book_and_class_lock() -> void:
	var soul := _cat("Soulwright", 20)
	assert_eq(AbilityRules.spell_block_reason(soul, AbilityLibrary.spell_by_id("sp_plasma_dart")), "Wrong spellbook")
	var echo := _cat("Echo", 20) # Archanist book, but class-locked Archanist spells are for Archanists only
	assert_false(AbilityRules.can_learn_spell(echo, AbilityLibrary.spell_by_id("sp_cryo_blast")))
	assert_true(AbilityRules.can_learn_spell(echo, AbilityLibrary.spell_by_id("sp_static_nova")))
	var spartan := _cat("Spartan", 20)
	assert_eq(AbilityRules.learnable_spells(spartan, AbilityLibrary.all_spells()).size(), 0)


func test_spellbook_opens_later() -> void:
	var warden := _cat("Warden", 2)
	assert_eq(AbilityRules.max_spell_tier(warden), 0)
	assert_eq(AbilityRules.spell_block_reason(warden, AbilityLibrary.spell_by_id("sp_corrosive_spray")), "Spellbook opens at level 3")
	AbilityRules.initialize_abilities(warden)
	assert_eq(warden.known_spells.size(), 0)
	warden.level = 3
	var granted: Array[SpellData] = AbilityRules.grant_spellbook_opening(warden)
	assert_eq(_ids(granted), ["sp_corrosive_spray"] as Array[String])


func test_starters() -> void:
	var soul := _cat("Soulwright", 1)
	AbilityRules.initialize_abilities(soul)
	assert_eq(_ids(soul.known_spells), ["sp_nano_repair", "sp_adrenaline_surge"] as Array[String])
	var spartan := _cat("Spartan", 1, "Bengal")
	AbilityRules.initialize_abilities(spartan)
	assert_eq(spartan.known_spells.size(), 0)
	var skills: Array[String] = _ids(spartan.known_skills)
	assert_eq(skills.size(), 2) # one class combat skill + the Bengal race skill
	assert_has(skills, "sk_wild_pounce")
	var wizard := _cat("Wizard", 1)
	AbilityRules.initialize_abilities(wizard)
	assert_eq(wizard.known_spells.size(), 2)


func test_initialize_trims_old_saves_but_keeps_ranked() -> void:
	var arch := _cat("Archanist", 5)
	for s: SpellData in AbilityLibrary.all_spells():
		arch.known_spells.append(s) # old saves knew everything
	arch.ability_ranks["sp_static_nova"] = 2
	AbilityRules.initialize_abilities(arch)
	var ids: Array[String] = _ids(arch.known_spells)
	assert_has(ids, "sp_static_nova")
	assert_has(ids, "sp_plasma_dart")
	assert_does_not_have(ids, "sp_cryo_blast")
	assert_true(arch.abilities_initialized)
	var before: int = arch.known_spells.size()
	AbilityRules.initialize_abilities(arch) # second call is a no-op
	assert_eq(arch.known_spells.size(), before)


func test_skill_eligibility_class_or_race() -> void:
	var lockpick: SkillData = AbilityLibrary.skill_by_id("sk_lockpicking")
	assert_true(AbilityRules.can_learn_skill(_cat("Shade"), lockpick))
	assert_true(AbilityRules.can_learn_skill(_cat("Spartan", 1, "Bobtail"), lockpick))
	assert_false(AbilityRules.can_learn_skill(_cat("Spartan", 1, "Bengal"), lockpick))


func test_teach() -> void:
	var cat := _cat("Archanist")
	var dart: SpellData = AbilityLibrary.spell_by_id("sp_plasma_dart")
	assert_true(AbilityRules.teach(cat, dart))
	assert_false(AbilityRules.teach(cat, dart))
	assert_eq(AbilityRules.spell_block_reason(cat, dart), "Already known")
