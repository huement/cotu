# res://Scripts/Utilities/ItemCompiler.gd
@tool
extends EditorScript

# Paths to search for the CSV file (checks project root and Data directory)
const CSV_PATHS: Array[String] = [
	"res://Data/Items/basic_items.csv",
	"res://Data/basic_items.csv"
]

const OUTPUT_DIR_EQUIP: String = "res://Data/Items/Equipment/"
const OUTPUT_DIR_CONSUMABLE: String = "res://Data/Items/Consumables/"
const OUTPUT_DIR_MISC: String = "res://Data/Items/Misc/"

func _run() -> void:
	compile_items()

func compile_items() -> void:
	var csv_path: String = _find_valid_csv_path()
	if csv_path.is_empty():
		printerr("Item Compiler Error: Could not locate 'Items - basic_items.csv'!")
		return

	_ensure_directories()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		printerr("Item Compiler Error: Failed to open CSV file at ", csv_path)
		return

	var _header: PackedStringArray = file.get_csv_line()
	var count: int = 0

	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() < 12 or line[0].strip_edges().is_empty():
			continue

		var item := ItemData.new()
		item.item_id = line[0].strip_edges()
		item.item_name = line[1].strip_edges()
		item.item_type = _parse_item_type(line[2].strip_edges())
		item.equipment_slot = _parse_equip_slot(line[3].strip_edges())
		item.attack_bonus = int(line[4])
		item.defense_bonus = int(line[5])
		item.speed_bonus = int(line[6])
		item.heal_amount = int(line[7])
		item.energy_restore = int(line[8])
		item.credit_value = int(line[9])
		item.description = line[10].strip_edges()
		item.icon_path = line[11].strip_edges()

		if line.size() >= 13: item.effects = line[12].strip_edges()
		if line.size() >= 14: item.effect_amount = float(line[13])
		if line.size() >= 15: item.effect_element = _parse_effect_element(line[14].strip_edges())
		if line.size() >= 16: item.effect_stat = line[15].strip_edges()
		if line.size() >= 17: item.weapon_type = _parse_weapon_type(line[16].strip_edges())
		if line.size() >= 18: item.is_consumable = line[17].strip_edges().to_lower() in ["true", "1", "t", "yes"]
		if line.size() >= 19: _apply_vfx_frames(item, line[18].strip_edges())

		item.stat_effect = {}
		if item.heal_amount > 0:
			item.stat_effect["heal"] = item.heal_amount
		if item.energy_restore > 0:
			item.stat_effect["energy"] = item.energy_restore

		if not item.icon_path.is_empty() and ResourceLoader.exists(item.icon_path):
			item.icon = load(item.icon_path) as Texture2D

		var target_dir: String = OUTPUT_DIR_MISC
		if item.item_type in [ItemData.ItemType.WEAPON, ItemData.ItemType.ARMOR, ItemData.ItemType.EQUIPMENT]:
			target_dir = OUTPUT_DIR_EQUIP
		elif item.item_type in [ItemData.ItemType.POTION, ItemData.ItemType.CONSUMABLE] or item.is_consumable:
			target_dir = OUTPUT_DIR_CONSUMABLE

		# 🎯 SANITIZED FILENAME: item_id.to_pascal_case() eliminates special characters
		var safe_name: String = item.item_id.to_pascal_case() + ".tres"
		var save_path: String = target_dir + safe_name

		var err := ResourceSaver.save(item, save_path)
		if err == OK:
			count += 1
		else:
			printerr("Failed to save Item resource for: ", item.item_name, " Error Code: ", err)

	print("Data Compiler Success: Created/Updated ", count, " Item .tres files from ", csv_path)

func _find_valid_csv_path() -> String:
	for path in CSV_PATHS:
		if FileAccess.file_exists(path):
			return path
	return ""

func _ensure_directories() -> void:
	for dir in [OUTPUT_DIR_EQUIP, OUTPUT_DIR_CONSUMABLE, OUTPUT_DIR_MISC]:
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)

func _parse_item_type(type_str: String) -> ItemData.ItemType:
	match type_str.to_upper():
		"WEAPON": return ItemData.ItemType.WEAPON
		"ARMOR": return ItemData.ItemType.ARMOR
		"POTION": return ItemData.ItemType.POTION
		"CONSUMABLE": return ItemData.ItemType.CONSUMABLE
		"EQUIPMENT": return ItemData.ItemType.EQUIPMENT
		_: return ItemData.ItemType.MISC

func _parse_equip_slot(slot_str: String) -> ItemData.EquipmentSlot:
	match slot_str.to_upper():
		"HEAD": return ItemData.EquipmentSlot.HEAD
		"BODY": return ItemData.EquipmentSlot.BODY
		"ARMS": return ItemData.EquipmentSlot.ARMS
		"LEGS": return ItemData.EquipmentSlot.LEGS
		"FEET": return ItemData.EquipmentSlot.FEET
		"RIGHT_HAND": return ItemData.EquipmentSlot.RIGHT_HAND
		"LEFT_HAND": return ItemData.EquipmentSlot.LEFT_HAND
		"BOTH_HANDS": return ItemData.EquipmentSlot.BOTH_HANDS
		"ACCESSORY": return ItemData.EquipmentSlot.ACCESSORY
		_: return ItemData.EquipmentSlot.NONE

func _parse_weapon_type(wp_str: String) -> ItemData.WeaponType:
	match wp_str.to_upper():
		"BLADE": return ItemData.WeaponType.BLADE
		"BASH": return ItemData.WeaponType.BASH
		"RANGED": return ItemData.WeaponType.RANGED
		_: return ItemData.WeaponType.NONE

func _parse_effect_element(elem_str: String) -> ItemData.EffectElement:
	match elem_str.to_upper():
		"MAGIC": return ItemData.EffectElement.MAGIC
		"BLADE": return ItemData.EffectElement.BLADE
		"RANGED": return ItemData.EffectElement.RANGED
		"BASH": return ItemData.EffectElement.BASH
		"LIFE": return ItemData.EffectElement.LIFE
		_: return ItemData.EffectElement.NONE

## Safely loads and assigns a SpriteFrames resource from a CSV string path
func _apply_vfx_frames(target_resource: Resource, vfx_path_string: String) -> void:
	var clean_path: String = vfx_path_string.strip_edges()
	if clean_path.is_empty():
		return

	if ResourceLoader.exists(clean_path):
		var vfx_frames: SpriteFrames = load(clean_path) as SpriteFrames
		if is_instance_valid(vfx_frames):
			target_resource.set("attack_vfx", vfx_frames)
	else:
		push_warning("DataCompiler: VFX file not found at path: %s" % clean_path)
