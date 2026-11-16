# res://Scripts/Enemies/MalviathanController.gd
class_name MalviathanController
extends Node3D
## Malviathan, the main villain (Scenes/Enemies/Malviathan.tscn). Drop the scene into a level.
##
## In the editor you see the model, so you know where he stands. In the game he is INVISIBLE until
## the party walks into his ActivationArea (the big box). Then the villain cutscene plays
## (BossVillainCutscene in world.tscn): he appears, taunts the party and is gone again.
## The party does NOT fight him - what happens to them is set under "Cutscene Ending" below.
##
## The StaticBody3D keeps the party from walking through him even while he is hidden.
## The area is checked against its box footprint every time the party moves, so the box's
## height doesn't matter.

const DEFAULT_AVATAR_PATH: String = "res://resources/Lore/cube_avatar.png"

@export_group("Cutscene")
## Sent with the cutscene request (BossVillainCutscene can be limited to one id).
@export var cutscene_id: String = "main_villain_intro"
## Save-state id. Must be different for every Malviathan placed in the game.
@export var object_id: String = "malviathan_01"
## true = the cutscene happens once per save. false = again every time the party walks back in.
@export var play_once: bool = true
## true = walking into the ActivationArea starts the cutscene. false = something else starts it by
## calling start_cutscene() (e.g. the VeroWood Sea Monster after its loot screen closes).
@export var trigger_on_area: bool = true

@export_group("Cutscene Ending")
## Name shown above the dialog text. Empty = no name line.
@export var speaker_name: String = "Malviathan"
## What he says before the screen goes black. Empty = no dialog box.
@export_multiline var dialog_text: String = "You crawl through my halls and call it courage.\n\nI have watched you since the first door. I am not finished watching."
## Picture in the corner of the dialog box. Empty = resources/Lore/cube_avatar.png.
@export var dialog_avatar: Texture2D
## What happens after the dialog. A fight and a trip to another level can't both happen.
@export_enum("Nothing - wake up here", "Path 1 - Fight enemies", "Path 3 - Travel to a level") var after_dialog: int = 0

@export_subgroup("Path 1 - Fight")
## The pack the party is thrown into battle with (up to 4).
@export var fight_enemies: Array[EnemyData] = []

@export_subgroup("Path 2 - Drain (works with any choice above)")
## Leave the party wrecked but alive.
@export var drain_party: bool = true
## HP and Mana each living member is LEFT with, as a percent of their maximum.
@export_range(1.0, 100.0, 1.0) var vitals_left_percent: float = 1.0

@export_subgroup("Path 3 - Travel")
## The level the party wakes up in.
@export_file("*.tscn") var travel_scene: String = ""
## Marker in that level the party arrives on.
@export var travel_arrival_point: String = "SpawnPoint"

var _fired: bool = false
## After a repeatable cutscene the party must leave the area once before it re-arms.
var _wait_for_exit: bool = false

@onready var visual_juice: BlobBossJuice = get_node_or_null("VisualJuice") as BlobBossJuice
@onready var activation_area: Area3D = get_node_or_null("ActivationArea") as Area3D


func _ready() -> void:
	if play_once and _was_seen():
		queue_free()
		return
	visible = false # the editor shows him; the game does not, until the party walks in
	SignalBus.boss_cutscene_villain_visible.connect(_on_villain_visible)
	SignalBus.boss_cutscene_finished.connect(_on_cutscene_finished)
	if not trigger_on_area:
		return
	if not is_instance_valid(activation_area):
		push_warning("MalviathanController '%s': no ActivationArea - the cutscene can never start." % name)
		return
	activation_area.body_entered.connect(_on_body_entered)
	SignalBus.party_moved.connect(_on_party_moved)


## Starts the cutscene from code (trigger_on_area = false). Waits until the game is back to
## exploring (loot screen closed, battle torn down) before asking for it.
func start_cutscene() -> void:
	if _fired or not is_inside_tree():
		return
	_fired = true
	var waited: float = 0.0
	while is_inside_tree() and waited < 5.0 \
			and (GameState.current_mode != GameState.Mode.EXPLORING or GameState.is_battle_in_progress()):
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not is_inside_tree():
		return
	SignalBus.boss_cutscene_requested.emit(cutscene_id, global_position, build_ending())


# ==============================================================================
# Trigger: the party walks into the ActivationArea
# ==============================================================================

func _on_body_entered(body: Node) -> void:
	if body.is_in_group(&"player"):
		_check_party()


func _on_party_moved(_grid_pos: Vector3i, _facing: Variant) -> void:
	_check_party()


func _check_party() -> void:
	if _fired or not is_inside_tree():
		return
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if not is_instance_valid(player):
		return
	var inside: bool = is_point_inside(player.global_position)
	if _wait_for_exit:
		if not inside:
			_wait_for_exit = false
		return
	if not inside:
		return
	# Not in the middle of a battle or its victory screen - try again on the next step.
	if GameState.current_mode != GameState.Mode.EXPLORING or GameState.is_battle_in_progress():
		return
	_fired = true
	SignalBus.boss_cutscene_requested.emit(cutscene_id, global_position, build_ending())


## True when [param world_pos] is inside the footprint (x / z) of the ActivationArea's box shapes.
func is_point_inside(world_pos: Vector3) -> bool:
	if not is_instance_valid(activation_area):
		return false
	for child: Node in activation_area.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node == null or not (shape_node.shape is BoxShape3D):
			continue
		var local: Vector3 = shape_node.global_transform.affine_inverse() * world_pos
		var half: Vector3 = (shape_node.shape as BoxShape3D).size * 0.5
		if absf(local.x) <= half.x and absf(local.z) <= half.z:
			return true
	return false


## The "Cutscene Ending" settings above, packed for the cutscene.
func build_ending() -> BossCutsceneEnding:
	var ending := BossCutsceneEnding.new()
	ending.speaker_name = speaker_name
	ending.dialog_text = dialog_text
	ending.avatar = dialog_avatar
	if ending.avatar == null and ResourceLoader.exists(DEFAULT_AVATAR_PATH):
		ending.avatar = load(DEFAULT_AVATAR_PATH) as Texture2D
	ending.after = after_dialog as BossCutsceneEnding.After
	ending.fight_enemies = fight_enemies
	ending.drain_party = drain_party
	ending.vitals_left_percent = vitals_left_percent
	ending.travel_scene = travel_scene
	ending.travel_arrival_point = travel_arrival_point
	return ending


# ==============================================================================
# The cutscene shows / hides him
# ==============================================================================

func _on_villain_visible(id: String, shown: bool) -> void:
	if not _fired or id != cutscene_id:
		return
	visible = shown
	if shown:
		if is_instance_valid(visual_juice):
			visual_juice.play_hit_shake() # red flash + shudder as he tears into view
		return
	# Gone again (the screen is black). Remember it; the cutscene saves the game right after.
	GameState.set_object_state_flag(GameState.get_current_map_id(), object_id, "cutscene_seen", true)


func _on_cutscene_finished(id: String) -> void:
	if not _fired or id != cutscene_id:
		return
	if play_once:
		queue_free() # takes his collision with him
		return
	_fired = false
	_wait_for_exit = true


func _was_seen() -> bool:
	var saved: Dictionary = GameState.get_object_state(GameState.get_current_map_id(), object_id)
	return bool(saved.get("cutscene_seen", false))
