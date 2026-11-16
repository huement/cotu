# res://Scripts/Utilities/PartyGearLoot.gd
class_name PartyGearLoot
extends RefCounted

## Rolls class-tagged gear from basic_items.csv (compiled to Data/Items/Equipment/).
## Item ids follow: armor_{class}_{tier}_{slot} / weap_{class}_{tier}_{slot}

const CSV_PATH: String = "res://Data/basic_items.csv"
const EQUIP_DIR: String = "res://Data/Items/Equipment/"

## Cache key "{class}|{tier}|armor|weapons" -> Array[String] of .tres paths
static var _pool_cache: Dictionary = {}


## Active profession names for every filled party slot (duplicates kept).
static func get_active_party_classes(party: DungeonParty = null) -> Array[String]:
	var resolved: DungeonParty = party if is_instance_valid(party) else _resolve_party()
	if not is_instance_valid(resolved):
		return []
	return resolved.get_active_class_names()


## Unique profession names currently in the party.
static func get_unique_active_party_classes(party: DungeonParty = null) -> Array[String]:
	var resolved: DungeonParty = party if is_instance_valid(party) else _resolve_party()
	if not is_instance_valid(resolved):
		return []
	return resolved.get_unique_active_classes()


## True when ItemData.effects marks a chest placeholder that expands into party gear.
static func is_party_gear_token(item: ItemData) -> bool:
	if not is_instance_valid(item):
		return false
	return item.effects.strip_edges().begins_with("PartyGear")


## Normalizes tier tokens to regular | bone | advanced (unknown → regular).
static func normalize_tier(tier: String) -> String:
	var clean_tier: String = tier.strip_edges().to_lower()
	match clean_tier:
		"advanced", "bone":
			return clean_tier
		_:
			return "regular"


## Expands a party-gear token into real equipment for the live party.
## effects: "PartyGear" | "PartyGear:bone" | "PartyGear:advanced" (default tier regular).
## effect_stat: "" / "both" | "armor" | "weapons". quantity = piece count (min 1).
static func resolve_token(item: ItemData, party: DungeonParty = null) -> Array[ItemData]:
	var empty: Array[ItemData] = []
	if not is_party_gear_token(item):
		return empty

	var effects: String = item.effects.strip_edges()
	var tier: String = "regular"
	var parts: PackedStringArray = effects.split(":")
	if parts.size() >= 2:
		tier = normalize_tier(parts[1])

	var include_armor: bool = true
	var include_weapons: bool = true
	var filter: String = item.effect_stat.strip_edges().to_lower()
	match filter:
		"armor":
			include_weapons = false
		"weapons", "weapon":
			include_armor = false
		_:
			pass

	var count: int = maxi(1, item.quantity)
	return roll_for_party(count, tier, include_armor, include_weapons, party, false)


## Rolls `count` random gear pieces for the active party at the given tier.
static func roll_for_party(
	count: int,
	tier: String = "regular",
	include_armor: bool = true,
	include_weapons: bool = true,
	party: DungeonParty = null,
	unique_classes_only: bool = false
) -> Array[ItemData]:
	var results: Array[ItemData] = []
	var classes: Array[String] = (
		get_unique_active_party_classes(party) if unique_classes_only
		else get_active_party_classes(party)
	)
	if classes.is_empty() or count <= 0:
		return results

	var clean_tier: String = normalize_tier(tier)
	# Prefer classes that actually have gear at this tier (e.g. bone is only on some classes).
	var eligible: Array[String] = []
	for prof_name: String in classes:
		if not get_gear_paths_for_class(prof_name, clean_tier, include_armor, include_weapons).is_empty():
			eligible.append(prof_name)
	if eligible.is_empty():
		push_warning("PartyGearLoot: no party classes have gear for tier '%s'" % clean_tier)
		return results

	for _i: int in range(count):
		var prof_name: String = eligible[randi() % eligible.size()]
		var item: ItemData = roll_for_class(prof_name, clean_tier, include_armor, include_weapons)
		if is_instance_valid(item):
			results.append(item)
	return results


## Picks one random gear piece for a single class + tier.
static func roll_for_class(
	prof_name: String,
	tier: String = "regular",
	include_armor: bool = true,
	include_weapons: bool = true
) -> ItemData:
	var pool: Array[String] = get_gear_paths_for_class(prof_name, tier, include_armor, include_weapons)
	if pool.is_empty():
		push_warning("PartyGearLoot: no gear for class '%s' tier '%s'" % [prof_name, tier])
		return null
	var path: String = pool[randi() % pool.size()]
	if not ResourceLoader.exists(path):
		push_warning("PartyGearLoot: missing resource %s" % path)
		return null
	return (load(path) as ItemData).duplicate() as ItemData


## Returns compiled Equipment .tres paths for a class/tier.
static func get_gear_paths_for_class(
	prof_name: String,
	tier: String = "regular",
	include_armor: bool = true,
	include_weapons: bool = true
) -> Array[String]:
	var class_key: String = prof_name.strip_edges().to_lower()
	var clean_tier: String = normalize_tier(tier)
	var cache_key: String = "%s|%s|%s|%s" % [
		class_key,
		clean_tier,
		str(include_armor),
		str(include_weapons)
	]
	if _pool_cache.has(cache_key):
		var cached: Array = _pool_cache[cache_key] as Array
		var typed_cached: Array[String] = []
		for entry: Variant in cached:
			typed_cached.append(str(entry))
		return typed_cached

	var paths: Array[String] = []
	for item_id: String in _scan_csv_item_ids(class_key, clean_tier, include_armor, include_weapons):
		var path: String = EQUIP_DIR + item_id.to_pascal_case() + ".tres"
		if ResourceLoader.exists(path):
			paths.append(path)
	_pool_cache[cache_key] = paths
	return paths


static func _scan_csv_item_ids(
	class_key: String,
	tier: String,
	include_armor: bool,
	include_weapons: bool
) -> Array[String]:
	var ids: Array[String] = []
	if not FileAccess.file_exists(CSV_PATH):
		push_warning("PartyGearLoot: CSV missing at %s" % CSV_PATH)
		return ids

	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return ids

	var _header: PackedStringArray = file.get_csv_line()
	var armor_prefix: String = "armor_%s_%s_" % [class_key, tier]
	var weap_prefix: String = "weap_%s_%s_" % [class_key, tier]

	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.is_empty():
			continue
		var item_id: String = line[0].strip_edges()
		if item_id.is_empty():
			continue
		if include_armor and item_id.begins_with(armor_prefix):
			ids.append(item_id)
		elif include_weapons and item_id.begins_with(weap_prefix):
			ids.append(item_id)
	file.close()
	return ids


static func _resolve_party() -> DungeonParty:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var gs: Node = tree.root.get_node_or_null("GameState")
	if not is_instance_valid(gs):
		return null
	var party: Variant = gs.get("current_party")
	return party as DungeonParty if party is DungeonParty else null
