# res://tests/progression/test_weapon_rules.gd
extends GutTest


func test_profession_allows_listed_weapon_types() -> void:
	var spartan := ProfessionData.new()
	spartan.allowed_weapon_types = [
		ItemData.WeaponType.BLADE,
		ItemData.WeaponType.BASH,
	]
	assert_true(spartan.allows_weapon_type(ItemData.WeaponType.BLADE))
	assert_true(spartan.allows_weapon_type(ItemData.WeaponType.BASH))
	assert_false(spartan.allows_weapon_type(ItemData.WeaponType.RANGED))
	assert_true(spartan.allows_weapon_type(ItemData.WeaponType.NONE))


func test_empty_allowlist_is_unrestricted() -> void:
	var open := ProfessionData.new()
	assert_true(open.allows_weapon_type(ItemData.WeaponType.BLADE))
	assert_true(open.allows_weapon_type(ItemData.WeaponType.RANGED))


func test_cat_equip_respects_profession_weapon_rules() -> void:
	var wizard := ProfessionData.new()
	wizard.profession_name = "Wizard"
	wizard.allowed_weapon_types = [ItemData.WeaponType.BASH]

	var cat := CatCharacter.new()
	cat.name = "Test Wizard"
	cat.profession = wizard

	var staff := ItemData.new()
	staff.item_name = "Staff"
	staff.weapon_type = ItemData.WeaponType.BASH
	assert_true(cat.can_equip_item(staff))
	assert_true(cat.equip_item("RIGHT_HAND", staff))

	var sword := ItemData.new()
	sword.item_name = "Sword"
	sword.weapon_type = ItemData.WeaponType.BLADE
	assert_false(cat.can_equip_item(sword))
	assert_false(cat.equip_item("LEFT_HAND", sword))
	assert_eq(cat.get_equipped_item("LEFT_HAND"), null)
