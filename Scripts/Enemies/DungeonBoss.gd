# res://Scripts/Enemies/DungeonBoss.gd
class_name DungeonBoss
extends BlobBossController
## A blob boss that guards a BossChamber. When it's beaten, the chamber sinks one side wall
## (`reward_side`) to open the reward room, unlocks the north gate and remembers the win.
##
## With `boss_id` set, its level, size, minions, name, stats data and reward side come from that
## row of Data/Lore/Bosses.csv (via the LoreManager autoload). Empty CSV cells keep the values
## set on this scene. A BossChamber that spawns the boss sets `boss_id` for you.

## Emitted when the party wins the fight, before the boss is removed.
signal boss_defeated(boss: DungeonBoss, side: String)

## Row of Data/Lore/Bosses.csv to configure this boss from. 0 = use the values on this scene.
@export var boss_id: int = 0

## Which wall of the boss chamber drops when this boss dies (overridden by the CSV row).
@export_enum("east", "west", "none") var reward_side: String = "east"

## Name shown in battle. Empty = the enemy data's own name (overridden by the CSV row).
@export var boss_name: String = ""


func _ready() -> void:
	if boss_id > 0:
		apply_lore(_find_lore(boss_id))
	if not defeated.is_connected(_on_defeated):
		defeated.connect(_on_defeated)
	super._ready()


## Copies the boss settings from a CSV row. Call before the boss enters the tree
## (BossChamber does this) or let _ready do it from `boss_id`.
func apply_lore(lore: LoreData) -> void:
	if lore == null:
		return
	if lore.enemy_data != null:
		base_data = lore.enemy_data
	if lore.boss_level > 0:
		boss_level = lore.boss_level
	if lore.boss_scale > 0.0:
		boss_scale = lore.boss_scale
	if lore.has_minions >= 0:
		has_minions = lore.has_minions == 1
	if not lore.boss_name.is_empty():
		boss_name = lore.boss_name
	reward_side = lore.reward_side


## Adds the display name on top of the normal stat build.
func _build_runtime_enemy_data() -> void:
	super._build_runtime_enemy_data()
	if boss_name.is_empty() or _boss_slot >= enemy_group.size():
		return
	var data: EnemyData = enemy_group[_boss_slot] as EnemyData
	if data != null:
		data.enemy_name = boss_name


func _on_defeated() -> void:
	boss_defeated.emit(self, reward_side)


func _find_lore(lore_id: int) -> LoreData:
	var manager: Node = get_tree().root.get_node_or_null("LoreManager")
	if manager == null or not manager.has_method("get_lore_by_id"):
		push_error("DungeonBoss: LoreManager autoload is missing - add Scripts/Singletons/LoreManager.gd in Project Settings > Globals.")
		return null
	var lore: LoreData = manager.call("get_lore_by_id", lore_id) as LoreData
	if lore == null:
		push_warning("DungeonBoss: no row with id %d in Bosses.csv." % lore_id)
	return lore
