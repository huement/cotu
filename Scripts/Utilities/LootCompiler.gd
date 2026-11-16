# res://Scripts/Utilities/LootCompiler.gd
@tool
extends EditorScript
class_name LootCompiler
## Compiles gem_* / lrn_* / token_* rows from Data/Loot.csv into Data/Items/Loot/*.tres

const CSV_PATHS: Array[String] = ["res://Data/Loot.csv"]
const OUTPUT_DIR: String = "res://Data/Items/Loot/"


func _run() -> void:
	compile_loot()


## Callable from the editor (_run) or a headless SceneTree runner.
static func compile_loot() -> int:
	var csv_path: String = _find_valid_csv_path()
	if csv_path.is_empty():
		printerr("Loot Compiler Error: Cannot find 'Loot.csv' in project root or Data directory!")
		return 0

	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		printerr("Loot Compiler Error: Failed to open CSV file at ", csv_path)
		return 0

	var _header: PackedStringArray = file.get_csv_line()
	var count: int = 0

	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() < 26 or line[0].strip_edges().is_empty():
			continue

		var item_id: String = line[0].strip_edges()
		if not (
			item_id.begins_with("gem_")
			or item_id.begins_with("lrn_")
			or item_id.begins_with("token_")
		):
			push_warning(
				"LootCompiler: skipping '%s' (Loot.csv should only contain gem_* / lrn_* / token_*)."
				% item_id
			)
			continue

		var item := ItemData.new()
		item.item_id = item_id
		item.item_name = line[1].strip_edges()
		item.description = line[2].strip_edges()
		item.item_type = _parse_item_type(line[3].strip_edges())
		item.target_type = _parse_target_type(line[4].strip_edges())
		item.quantity = int(line[5])
		item.can_use_in_battle = _parse_bool(line[6])
		item.can_use_in_field = _parse_bool(line[7])
		item.equipment_slot = _parse_equipment_slot(line[8].strip_edges())
		item.weapon_type = _parse_weapon_type(line[9].strip_edges())
		item.attack_bonus = int(line[10])
		item.defense_bonus = int(line[11])
		item.speed_bonus = int(line[12])
		item.credit_value = int(line[13])
		item.max_durability = int(line[14])
		item.current_durability = int(line[15])
		item.is_consumable = _parse_bool(line[16])
		item.heal_amount = int(line[17])
		item.energy_restore = int(line[18])
		item.mana_restore = int(line[19])
		item.health_restore = int(line[20])
		item.effects = line[21].strip_edges()
		item.effect_amount = float(line[22])
		item.effect_element = _parse_effect_element(line[23].strip_edges())
		item.effect_stat = line[24].strip_edges()
		item.icon_path = line[25].strip_edges()
		item.is_throwable = line.size() > 26 and _parse_bool(line[26])

		if not item.icon_path.is_empty() and ResourceLoader.exists(item.icon_path):
			item.icon = load(item.icon_path) as Texture2D

		var save_path: String = OUTPUT_DIR + item.item_id.to_pascal_case() + ".tres"
		# Prefer UID from the new Loot/ path; fall back to the old root path so scenes keep working.
		var old_uid: int = ResourceUID.INVALID_ID
		if ResourceLoader.exists(save_path):
			old_uid = ResourceLoader.get_resource_uid(save_path)
		else:
			var legacy_path: String = "res://Data/Items/" + item.item_id.to_pascal_case() + ".tres"
			if ResourceLoader.exists(legacy_path):
				old_uid = ResourceLoader.get_resource_uid(legacy_path)

		var err := ResourceSaver.save(item, save_path)
		if err == OK:
			if old_uid != ResourceUID.INVALID_ID:
				ResourceSaver.set_uid(save_path, old_uid)
			count += 1
		else:
			printerr("Failed to save Item resource for: ", item.item_name, " Error: ", err)

	print("Loot Compiler Success: Generated ", count, " Item .tres files into ", OUTPUT_DIR)
	return count


static func _find_valid_csv_path() -> String:
	for path in CSV_PATHS:
		if FileAccess.file_exists(path):
			return path
	return ""


static func _parse_bool(s: String) -> bool:
	var cleaned: String = s.strip_edges().to_upper()
	return cleaned == "TRUE" or cleaned == "1" or cleaned == "YES"


static func _parse_item_type(s: String) -> ItemData.ItemType:
	match s.to_upper():
		"WEAPON":
			return ItemData.ItemType.WEAPON
		"ARMOR":
			return ItemData.ItemType.ARMOR
		"POTION":
			return ItemData.ItemType.POTION
		"CONSUMABLE":
			return ItemData.ItemType.CONSUMABLE
		"EQUIPMENT":
			return ItemData.ItemType.EQUIPMENT
		"QUEST":
			return ItemData.ItemType.QUEST
		_:
			return ItemData.ItemType.MISC


static func _parse_target_type(s: String) -> ItemData.TargetType:
	match s.to_upper():
		"ALL_PARTY":
			return ItemData.TargetType.ALL_PARTY
		"SINGLE_ENEMY":
			return ItemData.TargetType.SINGLE_ENEMY
		"ALL_ENEMIES":
			return ItemData.TargetType.ALL_ENEMIES
		"NONE":
			return ItemData.TargetType.NONE
		_:
			return ItemData.TargetType.SINGLE_PARTY_MEMBER


static func _parse_equipment_slot(s: String) -> ItemData.EquipmentSlot:
	match s.to_upper():
		"BODY":
			return ItemData.EquipmentSlot.BODY
		"ARMS":
			return ItemData.EquipmentSlot.ARMS
		"LEGS":
			return ItemData.EquipmentSlot.LEGS
		"FEET":
			return ItemData.EquipmentSlot.FEET
		"LEFT_HAND":
			return ItemData.EquipmentSlot.LEFT_HAND
		"RIGHT_HAND":
			return ItemData.EquipmentSlot.RIGHT_HAND
		"HEAD":
			return ItemData.EquipmentSlot.HEAD
		"BOTH_HANDS":
			return ItemData.EquipmentSlot.BOTH_HANDS
		"ACCESSORY":
			return ItemData.EquipmentSlot.ACCESSORY_1
		_:
			return ItemData.EquipmentSlot.NONE


static func _parse_weapon_type(s: String) -> ItemData.WeaponType:
	match s.to_upper():
		"BLADE":
			return ItemData.WeaponType.BLADE
		"BASH":
			return ItemData.WeaponType.BASH
		"RANGED":
			return ItemData.WeaponType.RANGED
		_:
			return ItemData.WeaponType.NONE


static func _parse_effect_element(s: String) -> ItemData.EffectElement:
	match s.to_upper():
		"MAGIC":
			return ItemData.EffectElement.MAGIC
		"BLADE":
			return ItemData.EffectElement.BLADE
		"RANGED":
			return ItemData.EffectElement.RANGED
		"LIFE":
			return ItemData.EffectElement.LIFE
		"BASH":
			return ItemData.EffectElement.BASH
		_:
			return ItemData.EffectElement.NONE
