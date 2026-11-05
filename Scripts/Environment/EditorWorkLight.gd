@tool
class_name EditorWorkLight
extends Node3D
## Editor-only lighting so dark maps are easy to edit (drop it into any map).
## In the editor it adds two soft directional lights and swaps the map's WorldEnvironment
## for a brighter, fog-free preview copy. Nothing it adds is saved: the lights are internal
## (unowned) children, and the real environment is put back right before every save.
## In the running game this node deletes itself.
##
## To edit the map's REAL environment, untick `enabled` first (otherwise you'd be editing
## the temporary preview copy).
##
## Safety: Godot blocks adding/removing children while it sends the save notifications,
## so the lights are created once and only shown/hidden afterwards; during a save this
## script only swaps the environment property back.

@export var enabled: bool = true:
	set(value):
		enabled = value
		_update_lights()
		_queue_preview_refresh()

@export_range(0.0, 4.0, 0.05) var light_energy: float = 1.0:
	set(value):
		light_energy = value
		_update_lights()

@export var disable_fog: bool = true:
	set(value):
		disable_fog = value
		_queue_preview_refresh()

## Minimum ambient light energy while editing.
@export_range(0.0, 4.0, 0.05) var ambient_energy: float = 1.5:
	set(value):
		ambient_energy = value
		_queue_preview_refresh()

var _key_light: DirectionalLight3D = null
var _fill_light: DirectionalLight3D = null
var _world_env: WorldEnvironment = null
var _saved_env: Environment = null
var _preview_env: Environment = null
var _refresh_queued: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	_create_lights.call_deferred()
	_queue_preview_refresh()


func _enter_tree() -> void:
	# Re-entering (e.g. switching back to this scene tab): show the preview again.
	if Engine.is_editor_hint() and is_node_ready():
		_queue_preview_refresh()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		_restore_environment()


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_restore_environment() # property swap only - no tree changes here
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_queue_preview_refresh()


func _create_lights() -> void:
	if not is_inside_tree() or _key_light != null:
		return
	_key_light = _make_light(Vector3(-60.0, 35.0, 0.0))
	_fill_light = _make_light(Vector3(-45.0, -145.0, 0.0))
	_update_lights()


## Internal children are never saved and don't show in the Scene dock.
func _make_light(rotation_deg: Vector3) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = rotation_deg
	light.shadow_enabled = false
	add_child(light, false, Node.INTERNAL_MODE_FRONT)
	return light


func _update_lights() -> void:
	if is_instance_valid(_key_light):
		_key_light.visible = enabled
		_key_light.light_energy = light_energy
	if is_instance_valid(_fill_light):
		_fill_light.visible = enabled
		_fill_light.light_energy = light_energy * 0.5


func _queue_preview_refresh() -> void:
	if not Engine.is_editor_hint() or _refresh_queued:
		return
	_refresh_queued = true
	_refresh_preview.call_deferred()


func _refresh_preview() -> void:
	_refresh_queued = false
	_restore_environment()
	if not enabled or not is_inside_tree():
		return
	_world_env = _find_world_environment()
	if _world_env == null or _world_env.environment == null:
		return
	_saved_env = _world_env.environment
	_preview_env = _saved_env.duplicate() as Environment
	if disable_fog:
		_preview_env.fog_enabled = false
	_preview_env.ambient_light_energy = maxf(_preview_env.ambient_light_energy, ambient_energy)
	_world_env.environment = _preview_env


func _restore_environment() -> void:
	if is_instance_valid(_world_env) and _saved_env != null and _world_env.environment == _preview_env:
		_world_env.environment = _saved_env
	_saved_env = null
	_preview_env = null
	_world_env = null


func _find_world_environment() -> WorldEnvironment:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return null
	for child: Node in parent_node.get_children():
		if child is WorldEnvironment:
			return child as WorldEnvironment
	return null
