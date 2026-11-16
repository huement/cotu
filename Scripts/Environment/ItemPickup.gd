# res://Scripts/Environment/ItemPickup.gd
class_name ItemPickup
extends DungeonInteractable
## A single item lying in the world (Spell Book, Skill Crystal, keys...). It floats, spins and glows;
## searching the tile in front of it (the same as opening a chest) adds it to the party inventory, and it
## vanishes for good (saved per map in GameState.environment_states).
##
## Put it on any scene root that has the model(s) + a StaticBody3D (for the search query), e.g.
## Scenes/Objects/SpellBook.tscn and SkillCrystal.tscn. Drop instances anywhere in a map - each copy gets
## its own save id automatically (from its name + grid cell), so you don't have to fill object_id in.

## What the party gets.
@export var item: ItemData
@export_range(1, 99) var quantity: int = 1
## Toast shown on pickup ("{item}" is replaced by the item name). Empty = default text.
@export var pickup_message: String = ""

@export_group("Look")
@export var glow_color: Color = Color(0.7, 0.45, 1.0)
@export_range(0.0, 4.0) var glow_energy: float = 1.2
## Height the visuals float above their placed position.
@export var float_height: float = 0.25
@export var bob_amplitude: float = 0.08
@export var bob_speed: float = 1.6
## Radians per second around the vertical axis (0 = no spin).
@export var spin_speed: float = 0.7

const DEFAULT_OBJECT_ID: String = "interactable_01"

var collected: bool = false
var _visual: Node3D
var _light: OmniLight3D
var _time: float = 0.0


func _ready() -> void:
	super._ready()
	_build_visual_pivot()
	_resolve_object_id.call_deferred()


func _resolve_object_id() -> void:
	# _align_to_grid (deferred in super) has set _grid_position by now.
	if object_id.is_empty() or object_id == DEFAULT_OBJECT_ID:
		object_id = "pickup_%s_%d_%d" % [String(name).to_snake_case(), _grid_position.x, _grid_position.y]
	var state: Dictionary = GameState.get_object_state(_get_current_map_id(), object_id)
	if bool(state.get("collected", false)):
		collected = true
		queue_free()


func _process(delta: float) -> void:
	if not is_instance_valid(_visual) or collected:
		return
	_time += delta
	_visual.position.y = float_height + sin(_time * bob_speed) * bob_amplitude
	_visual.rotation.y += spin_speed * delta
	if is_instance_valid(_light):
		_light.light_energy = glow_energy * (0.8 + 0.2 * sin(_time * bob_speed * 1.7))


func interact(_player: Node3D) -> void:
	if collected:
		return
	if item == null:
		push_warning("ItemPickup '%s' has no item set." % name)
		return
	var inv: Inventory = GameState.inventory
	if inv == null or not inv.add_item(item, quantity):
		SignalBus.show_toast.emit("Your pack is full - make room for the %s." % item.item_name, true)
		return

	collected = true
	GameState.set_object_state_flag(_get_current_map_id(), object_id, "collected", true)
	GameState.save_game()

	if is_instance_valid(AudioManager) and AudioManager.has_method("play_environment"):
		AudioManager.play_environment("collect-loot")
	SignalBus.edge_flash_requested.emit(Color(glow_color, 0.85), 0.5)
	var label: String = item.item_name if quantity <= 1 else "%d x %s" % [quantity, item.item_name]
	var message: String = pickup_message.replace("{item}", label) if not pickup_message.is_empty() else _default_message(label)
	SignalBus.show_toast.emit(message, false)
	GameLogger.info("ItemPickup: collected %s (%s)" % [label, object_id])
	_vanish()


func _default_message(label: String) -> String:
	match item.effects:
		"LearnSpell":
			return "Found a %s! Use it from ITEMS to teach a new spell." % label
		"LearnSkill":
			return "Found a %s! Use it from ITEMS to teach a new skill." % label
	return "Found %s!" % label


func _vanish() -> void:
	is_blocking = false
	remove_from_group(&"dungeon_interactables")
	var tw: Tween = create_tween().set_parallel(true)
	if is_instance_valid(_visual):
		tw.tween_property(_visual, "position:y", _visual.position.y + 0.8, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_visual, "scale", Vector3.ONE * 0.05, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if is_instance_valid(_light):
		tw.tween_property(_light, "light_energy", glow_energy * 3.0, 0.15)
		tw.chain().tween_property(_light, "light_energy", 0.0, 0.3)
	tw.chain().tween_callback(queue_free)


## Moves every visual child (not the StaticBody3D) under one pivot so it can bob + spin as a unit.
func _build_visual_pivot() -> void:
	_visual = Node3D.new()
	_visual.name = "PickupVisual"
	var movers: Array[Node] = []
	for child: Node in get_children():
		if child is Node3D and not (child is CollisionObject3D):
			movers.append(child)
	add_child(_visual)
	for child: Node in movers:
		child.reparent(_visual, true)
	_visual.position.y = float_height
	_light = OmniLight3D.new()
	_light.name = "PickupGlow"
	_light.light_color = glow_color
	_light.light_energy = glow_energy
	_light.omni_range = 2.6
	_light.position = Vector3(0.0, float_height + 0.6, 0.0)
	add_child(_light)
