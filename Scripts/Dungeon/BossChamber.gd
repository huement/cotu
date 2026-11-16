# res://Scripts/Dungeon/BossChamber.gd
class_name BossChamber
extends DungeonRoom
## Boss room part (Scenes/Dungeons/Parts/BossChamber.tscn). Everything about the fight comes from
## one row of Data/Lore/Bosses.csv, picked with `boss_id`:
##  * spawns the row's boss scene (a DungeonBoss) in the middle of the room,
##  * fills the reward room on the row's `reward_side` (chest gold/items, the lore object's
##    title/text/aura/XP/sound and, for the HornedSkull, its scare FX),
##  * when the boss is beaten: sinks that side's wall (Caps/Cap_E or Caps/Cap_W) and unlocks the
##    north gate (Caps/Cap_N/Blocker, a BossExitGate) which leads to the row's `exit_scene`.
## The win is saved, so coming back later finds the boss gone and the side room open.
##
## Instead of a DungeonBoss you can place a BossEnemy (enemy.tscn + BossEnemy.gd) as a child of the
## chamber: then no boss is spawned from the CSV, and beating that enemy does the same things
## (reward side = the CSV row's reward_side). Leave the row's boss_scene empty for those levels.
##
## Reward rooms: EnvironmentE / EnvironmentW. Their DungeonChest children get the chest values in
## name order; any child with a `lore_title` (HornedSkull, WallMask) gets the lore values.

const SIDE_EAST: String = "east"
const SIDE_WEST: String = "west"
const STATE_ID: String = "boss_chamber"

## Row of Data/Lore/Bosses.csv. 0 = no CSV (use a DungeonBoss placed in this scene by hand).
@export var boss_id: int = 1

@export_group("Boss")
## Where the boss rests before it rises (room-local).
@export var boss_spawn_position: Vector3 = Vector3.ZERO

@export_group("Reward Rooms")
@export var east_room_path: NodePath = NodePath("EnvironmentE")
@export var west_room_path: NodePath = NodePath("EnvironmentW")
## How far the side wall sinks and how long it takes.
@export var side_drop_depth: float = 4.8
@export var side_drop_seconds: float = 2.5
## Pause after the battle screen closes before the wall starts to move.
@export var side_drop_delay: float = 1.0

var lore: LoreData = null
var boss: DungeonBoss = null
var is_boss_defeated: bool = false
var opened_side: String = ""

@onready var _exit_gate: BossExitGate = get_node_or_null("Caps/Cap_N/Blocker") as BossExitGate


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if boss_id > 0:
		lore = _find_lore(boss_id)

	var state: Dictionary = _get_state()
	is_boss_defeated = bool(state.get("boss_defeated", false))
	opened_side = str(state.get("opened_side", ""))

	var side: String = lore.reward_side if lore != null else ""
	if side.is_empty() and not opened_side.is_empty():
		side = opened_side
	if lore != null:
		_fill_reward_room(lore.reward_side)
	_setup_exit_gate()

	if is_boss_defeated:
		_open_side(opened_side if not opened_side.is_empty() else side, false)
		_remove_placed_boss()
	else:
		_spawn_boss()


# ==============================================================================
# Boss
# ==============================================================================

func _spawn_boss() -> void:
	var enemy_boss: BossEnemy = _find_placed_enemy_boss()
	if enemy_boss != null:
		enemy_boss.boss_defeated.connect(_on_enemy_boss_defeated)
		return
	boss = _find_placed_boss()
	if boss == null and lore != null and not lore.boss_scene_path.is_empty():
		var scene: PackedScene = load(lore.boss_scene_path) as PackedScene
		if scene == null:
			push_error("BossChamber: can't load boss scene %s (Bosses.csv row %d)." % [lore.boss_scene_path, boss_id])
			return
		var node: Node = scene.instantiate()
		boss = node as DungeonBoss
		if boss == null:
			push_error("BossChamber: %s needs the DungeonBoss script on its root." % lore.boss_scene_path)
			node.free()
			return
		boss.name = "Boss"
		boss.boss_id = boss_id
		boss.position = boss_spawn_position
		add_child(boss)
	if boss == null:
		push_warning("BossChamber: no boss (set boss_scene in Bosses.csv row %d, or place a DungeonBoss in the room)." % boss_id)
		return
	boss.boss_defeated.connect(_on_boss_defeated)


func _find_placed_boss() -> DungeonBoss:
	for child: Node in get_children():
		if child is DungeonBoss:
			return child as DungeonBoss
	return null


func _find_placed_enemy_boss() -> BossEnemy:
	for child: Node in get_children():
		if child is BossEnemy:
			return child as BossEnemy
	return null


func _remove_placed_boss() -> void:
	var placed: DungeonBoss = _find_placed_boss()
	if placed != null:
		placed.queue_free()
	var enemy_boss: BossEnemy = _find_placed_enemy_boss()
	if enemy_boss != null:
		enemy_boss.queue_free()


func _on_enemy_boss_defeated(_enemy: BossEnemy) -> void:
	_on_boss_defeated(null, lore.reward_side if lore != null else "")


func _on_boss_defeated(_boss: DungeonBoss, side: String) -> void:
	is_boss_defeated = true
	_set_state("boss_defeated", true)
	_set_state("opened_side", side)
	if is_instance_valid(_exit_gate):
		_exit_gate.is_locked = false # usable now; the opening is shown with the side wall below
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(gs) and gs.has_method("save_game"):
		gs.call("save_game")
	if side_drop_delay > 0.0:
		await get_tree().create_timer(side_drop_delay).timeout
	_open_side(side, true)
	if is_instance_valid(_exit_gate):
		_exit_gate.unlock(true)


# ==============================================================================
# Side walls & reward rooms
# ==============================================================================

## Sinks Caps/Cap_E or Caps/Cap_W. Its blocker is removed at once so the party can walk in.
func _open_side(side: String, animate: bool) -> void:
	var cap_name: String = "Cap_E" if side == SIDE_EAST else ("Cap_W" if side == SIDE_WEST else "")
	if cap_name.is_empty():
		return
	opened_side = side
	var cap: Node3D = get_node_or_null("Caps/" + cap_name) as Node3D
	if cap == null:
		return
	var blocker: Node = cap.get_node_or_null("Blocker")
	if blocker != null:
		blocker.get_parent().remove_child(blocker)
		blocker.queue_free()
	if not animate:
		cap.visible = false
		return

	if lore != null and not lore.side_open_sfx.is_empty() and is_instance_valid(AudioManager):
		AudioManager.play_audio_path(lore.side_open_sfx)
	CameraShake.request_earthquake(get_tree(), CameraShake.QuakeSize.MEDIUM, 1)
	SignalBus.show_toast.emit("With a deep rumble, the %s wall sinks into the floor..." % side, false)
	var tween: Tween = create_tween()
	tween.tween_property(cap, "position:y", cap.position.y - side_drop_depth, side_drop_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void: cap.visible = false, CONNECT_ONE_SHOT)


func _fill_reward_room(side: String) -> void:
	var room_path: NodePath = east_room_path if side == SIDE_EAST else (west_room_path if side == SIDE_WEST else NodePath())
	if room_path.is_empty():
		return
	var room: Node = get_node_or_null(room_path)
	if room == null:
		push_warning("BossChamber: reward room %s not found." % room_path)
		return

	var chests: Array[DungeonChest] = []
	for node: Node in room.find_children("*", "", true, false):
		if node is DungeonChest:
			chests.append(node as DungeonChest)
		elif "lore_title" in node:
			_apply_lore_object(node)
	chests.sort_custom(func(a: DungeonChest, b: DungeonChest) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)

	for i: int in range(chests.size()):
		var chest: DungeonChest = chests[i]
		if not lore.chest_gold.is_empty():
			chest.gold_amount = lore.chest_gold[mini(i, lore.chest_gold.size() - 1)]
		var items: Array[ItemData] = []
		if not lore.chest_items.is_empty():
			for item: Variant in lore.chest_items[mini(i, lore.chest_items.size() - 1)]:
				items.append(item as ItemData)
		else:
			items.assign(chest.guaranteed_items)
		if i == 0 and lore.loot_item != null:
			items.append(lore.loot_item) # the boss's signature reward goes in the first chest
		chest.guaranteed_items = items


## HornedSkull / WallMask (anything with lore_title / lore_text).
func _apply_lore_object(node: Node) -> void:
	if not lore.title.is_empty():
		node.set("lore_title", lore.title)
	if not lore.description.is_empty():
		node.set("lore_text", lore.description)
	if not lore.aura_type.is_empty() and "aura_type" in node:
		node.set("aura_type", lore.aura_type)
	if lore.xp_reward >= 0 and "xp_reward" in node:
		node.set("xp_reward", lore.xp_reward)
	if lore.sound_effect != null: # only when the file exists
		if "scare_music_path" in node:
			node.set("scare_music_path", lore.sfx_path)
		elif "inspect_sound_path" in node:
			node.set("inspect_sound_path", lore.sfx_path)
	if lore.scare_flash_texture != null and "flash_texture" in node:
		node.set("flash_texture", lore.scare_flash_texture)
	if lore.scare_shake >= 0.0 and "shake_trauma" in node:
		node.set("shake_trauma", lore.scare_shake)
	if lore.scare_hold >= 0.0 and "aura_hold_seconds" in node:
		node.set("aura_hold_seconds", lore.scare_hold)


# ==============================================================================
# North gate
# ==============================================================================

func _setup_exit_gate() -> void:
	if not is_instance_valid(_exit_gate):
		push_warning("BossChamber: Caps/Cap_N/Blocker needs the BossExitGate script to work as the exit.")
		return
	if lore != null:
		_exit_gate.target_scene = lore.exit_scene
		_exit_gate.arrival_point_name = lore.exit_arrival
		if not lore.exit_prompt.is_empty():
			_exit_gate.prompt_message = lore.exit_prompt
		_exit_gate.is_locked = lore.exit_requires_boss and not is_boss_defeated
	else:
		_exit_gate.is_locked = not is_boss_defeated
	if not _exit_gate.is_locked and is_boss_defeated:
		_exit_gate.unlock(false) # already beaten on an earlier visit: show the doorway open


# ==============================================================================
# Save state (GameState object state; ids are prefixed per placed room)
# ==============================================================================

func _state_id() -> String:
	return STATE_ID if id_prefix.is_empty() else id_prefix + "/" + STATE_ID


func _map_id() -> String:
	return GameState.get_current_map_id()


func _get_state() -> Dictionary:
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if not is_instance_valid(gs) or not gs.has_method("get_object_state"):
		return {}
	return gs.call("get_object_state", _map_id(), _state_id()) as Dictionary


func _set_state(flag: String, value: Variant) -> void:
	var gs: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(gs) and gs.has_method("set_object_state_flag"):
		gs.call("set_object_state_flag", _map_id(), _state_id(), flag, value)


func _find_lore(lore_id: int) -> LoreData:
	var manager: Node = get_tree().root.get_node_or_null("LoreManager")
	if manager == null or not manager.has_method("get_lore_by_id"):
		push_error("BossChamber: LoreManager autoload is missing - add Scripts/Singletons/LoreManager.gd in Project Settings > Globals.")
		return null
	var row: LoreData = manager.call("get_lore_by_id", lore_id) as LoreData
	if row == null:
		push_warning("BossChamber: no row with id %d in Bosses.csv." % lore_id)
	return row
