# res://Scripts/Progression/StarterKit.gd
class_name StarterKit
extends RefCounted
## The gear a newly created character starts a game with: every "regular" item for their class in
## Data/basic_items.csv (armor_<class>_regular_* and weap_<class>_regular_*, compiled to
## Data/Items/Equipment/ by ItemCompiler), found through PartyGearLoot.
##
## Each item goes into its slot (BOTH_HANDS weapons into RIGHT_HAND) in CSV order. When the slot is
## already taken (the Warden's backup dagger after the crossbow), the item has no slot (Ghostblade
## shuriken) or the class can't use its weapon type, it goes to the party's pack instead.
##
##   var spare: Array[ItemData] = StarterKit.equip(cat)        # one character
##   StarterKit.equip_party(party, GameState.inventory)        # whole party, spares into the pack
## Called by GameState.start_new_game_with_party. Tests: tests/progression/test_character_creation.gd

const TIER: String = "regular"
## Throwables in a kit (the Ghostblade's Steel Shuriken) start as a stack of this many.
const THROWABLE_STARTER_COUNT: int = 5
## Equipped ammo in a kit (Warden arrows, Maester flasks) starts as a stack of this many.
const AMMO_STARTER_COUNT: int = 20


## Equips the class's starter kit on an unequipped character. Returns the items that didn't fit.
static func equip(cat: CatCharacter) -> Array[ItemData]:
	var spare: Array[ItemData] = []
	if cat == null or not is_instance_valid(cat.profession):
		return spare
	for kit_item: ItemData in items_for_class(AbilityRules.class_name_of(cat)):
		var item: ItemData = kit_item
		if CombatMath.is_ammo_item(item):
			# Own copy, so firing never drains the shared .tres; start with a full stack.
			item = kit_item.duplicate() as ItemData
			item.quantity = AMMO_STARTER_COUNT
		var slot: String = item.get_slot_string()
		if slot.is_empty() or cat.get_equipped_item(slot) != null or not cat.can_equip_item(item):
			spare.append(item)
			continue
		if not cat.equip_item(slot, item):
			spare.append(item)
	cat.equipment_changed.emit()
	return spare


## Equips everyone in the party and puts the spares in `inventory` (when given). Returns the spares.
static func equip_party(party: DungeonParty, inventory: Inventory = null) -> Array[ItemData]:
	var spare: Array[ItemData] = []
	if party == null:
		return spare
	for slot_cat: Variant in party.slots:
		var cat: CatCharacter = slot_cat as CatCharacter
		if cat != null:
			spare.append_array(equip(cat))
	if inventory != null:
		for item: ItemData in spare:
			if not inventory.add_item(item, THROWABLE_STARTER_COUNT if item.is_throwable else 1):
				push_warning("StarterKit: pack full, dropped %s" % item.item_name)
	return spare


## The class's starter items in CSV order (armour first, then weapons).
static func items_for_class(class_name_str: String) -> Array[ItemData]:
	var items: Array[ItemData] = []
	for path: String in PartyGearLoot.get_gear_paths_for_class(class_name_str, TIER, true, true):
		var item: ItemData = load(path) as ItemData
		if item != null:
			items.append(item)
	if items.is_empty():
		push_warning("StarterKit: no '%s' gear for class '%s' in basic_items.csv." % [TIER, class_name_str])
	return items
