# res://Scripts/character_stats_panel.gd
extends PanelContainer
class_name CharacterStatsPanel

# STAT Column Labels
@onready var stat_str: Label = %StatStr as Label
@onready var stat_int: Label = %StatInt as Label
@onready var stat_pie: Label = %StatPie as Label
@onready var stat_vit: Label = %StatVit as Label
@onready var stat_dex: Label = %StatDex as Label
@onready var stat_spd: Label = %StatSpd as Label
@onready var stat_per: Label = %StatPer as Label
@onready var stat_kar: Label = %StatKar as Label

# FIGHT Column Labels
@onready var fight_acc: Label = %FightAcc as Label
@onready var fight_lh: Label = %FightLH as Label
@onready var fight_rh: Label = %FightRH as Label
@onready var fight_crt: Label = %FightCrt as Label
@onready var fight_dmg: Label = %FightDmg as Label
@onready var fight_arm: Label = %FightArm as Label

# Caches incoming character data if called before _ready() executes
var _pending_cat: CatCharacter = null

func _ready() -> void:
	# If stats were pushed before the node entered the tree, draw them now
	if _pending_cat:
		display_character_stats(_pending_cat)
		_pending_cat = null

## Safely reads attributes from the passed CatCharacter resource and updates the labels.
func display_character_stats(cat: CatCharacter) -> void:
	if not is_instance_valid(cat):
		return

	# LIFECYCLE GUARD: If @onready vars haven't initialized yet, cache and defer execution
	if not is_node_ready():
		_pending_cat = cat
		return

	# --- STAT Column ---
	if stat_str: stat_str.text = str(cat.strength)
	if stat_int: stat_int.text = str(cat.intelligence)
	if stat_pie: stat_pie.text = str(cat.piety)
	if stat_vit: stat_vit.text = str(cat.vitality)
	if stat_dex: stat_dex.text = str(cat.dexterity)
	if stat_spd: stat_spd.text = str(cat.speed)
	if stat_per: stat_per.text = str(cat.personality)
	if stat_kar: stat_kar.text = "10" # Default Karma metric

	# --- FIGHT Column (Derived & Direct) ---
	if cat.stats:
		# Accuracy derived from Dexterity & Personality
		var accuracy_bonus: int = (cat.dexterity + cat.personality) / 2
		if fight_acc: fight_acc.text = "%d%%" % (80 + accuracy_bonus)

		# Dual-wielding hand damage base
		var hand_damage: int = cat.strength / 2
		if fight_lh: fight_lh.text = "1d%d" % hand_damage
		if fight_rh: fight_rh.text = "1d%d" % hand_damage
		
		# Critical chance derived from Dexterity & Speed
		var crit_chance: int = (cat.dexterity + cat.speed) / 2
		if fight_crt: fight_crt.text = "%d%%" % (5 + crit_chance / 4)

		# Direct combat stats
		if fight_dmg: fight_dmg.text = "+%d" % cat.stats.attack
		if fight_arm: fight_arm.text = str(cat.stats.defence)
