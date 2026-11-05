# res://Scripts/WorldData/LoreData.gd
class_name LoreData
extends RefCounted
## One row of Data/Lore/Bosses.csv: the lore entry plus everything a boss chamber needs
## (which boss, which side wall drops, what the reward room holds, where the north gate leads).
## Empty CSV cells keep whatever is already set in the scenes (see LoreManager for the defaults).

const SIDE_EAST: String = "east"
const SIDE_WEST: String = "west"
const SIDE_NONE: String = "none"

# --- Lore ----------------------------------------------------------------------
var id: int = 0
var title: String = ""
var description: String = ""
var ascii_art: String = ""
var loot_item: ItemData = null
var sound_effect: AudioStream = null
var sfx_path: String = ""
var shader_material: ShaderMaterial = null

# --- Boss ----------------------------------------------------------------------
## Boss scene spawned in the chamber (should use DungeonBoss.gd). Empty = no boss.
var boss_scene_path: String = ""
## Replaces the boss scene's base_data. null = keep the scene's.
var enemy_data: EnemyData = null
## Name shown in battle. Empty = the enemy data's name.
var boss_name: String = ""
## 0 = keep the scene's value.
var boss_level: int = 0
## 0.0 = keep the scene's value.
var boss_scale: float = 0.0
## -1 = keep the scene's value, 0 = no minions, 1 = minions.
var has_minions: int = -1

# --- Reward side room --------------------------------------------------------
## Which side wall drops when the boss dies: SIDE_EAST, SIDE_WEST or SIDE_NONE.
var reward_side: String = SIDE_EAST
## Sound played while the wall sinks. Empty = none.
var side_open_sfx: String = ""
## Gold per chest, in chest order ("1000" or "500|500|1000"). Empty = keep the scene's.
var chest_gold: PackedInt32Array = PackedInt32Array()
## Items per chest, in chest order (groups split by "|", items by ";"). Empty = keep the scene's.
var chest_items: Array[Array] = []

# --- Lore object in the reward room (HornedSkull / WallMask) -----------------
var aura_type: String = "" # bad / good / none; empty = keep
var xp_reward: int = -1 # -1 = keep
var scare_flash_texture: Texture2D = null # HornedSkull only; null = keep
var scare_shake: float = -1.0 # HornedSkull only; -1 = keep
var scare_hold: float = -1.0 # HornedSkull only; -1 = keep

# --- North gate (exit) -------------------------------------------------------
var exit_scene: String = "" # empty = the gate stays shut
var exit_arrival: String = "SpawnPoint"
var exit_prompt: String = ""
var exit_requires_boss: bool = true
