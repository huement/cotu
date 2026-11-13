class_name EnemyData
extends Resource

@export_group("Identity & Visuals")
@export var enemy_id: String = ""
## Base taxonomy key used for SFX matching (e.g. "zombie", "skeleton", "cat")
@export var enemy_type: String = "zombie"
@export var enemy_name: String = "Corrupted Bio-Unit"
@export var model_path: String = ""
@export var texture_path: String = ""
@export var model_scene: PackedScene
@export var custom_material: StandardMaterial3D
@export var model_scale: Vector3 = Vector3(0.5, 0.5, 0.5)
## If greater than 0, overrides EnemyVisualManager camera distance for this enemy.
@export var combat_forward_distance: float = 0.0
## Camera-relative Y offset for combat placement (EnemyVisualManager default is -0.85).
@export var vertical_offset: float = -0.85
## The overworld node is the combat mesh. Do not spawn or reorient a second copy.
@export var combat_uses_world_node: bool = false
## Yaw applied after look_at. 180 faces most GLBs at the camera; 0 if the mesh already faces +Z.
@export var combat_yaw_offset_degrees: float = 180.0
## How the battle model shows it got hit (it always flashes white once):
## AUTO = play its hurt/hit clip if the model has one, else shake it in code.
## SHAKE = always shake. Any other value is an animation name to play (e.g. holding-both-shoot).
@export var hit_reaction: String = "AUTO"

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
## Takes weakness_multiplier (x1.5) damage from attacks of this type. MAGIC = all spells.
@export var weakness_element: ItemData.EffectElement = ItemData.EffectElement.NONE
## Magic defense: fraction of spell damage ignored (0.25 = takes 75% from spells). Max 0.9.
@export_range(0.0, 0.9, 0.05) var magic_resist: float = 0.0
## Physical attack type used for the target's weakness/resist checks.
@export var attack_element: ItemData.EffectElement = ItemData.EffectElement.BASH
@export var equipped_weapon_id: String = "NONE"
@export var equipped_item_id: String = "NONE"

@export_group("Magic Capabilities")
@export var can_cast_spells: bool = false
@export var spell_ids: Array[String] = []
@export var max_mana: int = 0
## Caster stat fed into SpellData.calculate_potency (like a player's INT). 0 = spell base damage only.
@export var magic_power: int = 0

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
