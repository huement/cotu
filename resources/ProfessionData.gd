# res://resources/ProfessionData.gd
extends Resource
class_name ProfessionData

@export_group("Identity")
@export var profession_name: String = "Spartan"
@export var classic_counterpart: String = "Fighter"

@export_group("Minimum Gate Requirements")
@export var req_strength: int = 10
@export var req_intelligence: int = 10
@export var req_piety: int = 10
@export var req_vitality: int = 10
@export var req_dexterity: int = 10
@export var req_speed: int = 10
@export var req_personality: int = 10

@export_group("Magic Configuration")
@export_enum("None", "Mage", "Priest", "Alchemist", "Psionic") var spellbook_type: String = "None"
@export var level_spells_unlock: int = 0

@export_group("Progression & Point Allocation")
@export var stat_points_per_level: int = 5
@export var skill_points_per_level: int = 2
@export var spell_points_per_level: int = 1

@export_group("Innate Skill Modification Hooks")
@export var native_abilities: Array[String] = []

@export_group("Weapon Restrictions")
## Weapon types this class may equip (from Character_Classes.csv "Weapon Bonus").
## Empty = unrestricted (legacy / missing data). WeaponType.NONE (armor, tools) always allowed.
@export var allowed_weapon_types: Array[ItemData.WeaponType] = []


## True when this profession can equip an item with the given weapon_type.
func allows_weapon_type(weapon_type: ItemData.WeaponType) -> bool:
	if weapon_type == ItemData.WeaponType.NONE:
		return true
	if allowed_weapon_types.is_empty():
		return true
	return allowed_weapon_types.has(weapon_type)
