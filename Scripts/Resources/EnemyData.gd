class_name EnemyData
extends Resource

@export_group("Identity & Visuals")
@export var enemy_id: String = ""
@export var enemy_name: String = "Corrupted Bio-Unit"
@export var model_path: String = ""
@export var texture_path: String = ""
@export var model_scene: PackedScene
@export var custom_material: StandardMaterial3D
@export var model_scale: Vector3 = Vector3(0.5, 0.5, 0.5)

@export_group("Base Stats & Scaling")
@export var base_level: int = 1
@export var scale_with_player: bool = true
@export var max_health: int = 30
@export var current_health: int = 30
@export var attack_damage: int = 8
@export var defense: int = 2
@export var speed: float = 10.0
@export var initiative_speed: int = 12

@export_group("Combat Elements & Equipment")
@export var weakness_element: ItemData.EffectElement = ItemData.EffectElement.NONE
@export var attack_element: ItemData.EffectElement = ItemData.EffectElement.BASH
@export var equipped_weapon_id: String = "NONE"
@export var equipped_item_id: String = "NONE"

@export_group("Magic Capabilities")
@export var can_cast_spells: bool = false
@export var spell_ids: Array[String] = []
@export var max_mana: int = 0

@export_group("Grouping & World AI")
@export var occurs_in_groups: bool = true
@export var min_group_size: int = 1
@export var max_group_size: int = 3
@export var movement_speed: float = 1.0
@export var aggro_range_tiles: int = 3
@export var can_surprise_player: bool = false
@export var can_be_surprised: bool = true

@export_group("Rewards & Economy")
@export var xp_value: int = 50
@export var gold_value: int = 25
@export var drops_loot: bool = true
