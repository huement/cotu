# res://Scripts/Dungeon/BossExitGate.gd
class_name BossExitGate
extends StaticBody3D
## The boss chamber's north gate (Caps/Cap_N/Blocker). Facing it and pressing interact asks to
## leave the map, then moves the party to `target_scene` on the `arrival_point_name` marker.
## BossChamber fills these in from the boss's CSV row and unlocks it when the boss is beaten.

@export_file("*.tscn") var target_scene: String = ""
@export var arrival_point_name: String = "SpawnPoint"
@export var prompt_message: String = "The gate grinds open onto a passage beyond. Leave this place?"
@export var locked_message: String = "The gate is sealed by a dark force."
@export var no_exit_message: String = "The gate won't budge."
## While locked, interacting only shows `locked_message`.
@export var is_locked: bool = true

@export_group("Opening")
## How far the gate model (sibling "Gate") sinks into the floor when it opens. The invisible
## blocker stays, so the party can't walk through; facing the open doorway asks to leave.
@export var open_sink_depth: float = 4.8
@export var open_seconds: float = 2.0
@export var opened_toast: String = "The north gate has opened. Face it to leave."
@export var exit_light_color: Color = Color(0.45, 1.0, 0.6)

var _is_open_visual: bool = false


func interact(_player: Node3D) -> void:
	if is_locked:
		SignalBus.show_toast.emit(locked_message, false)
		return
	if target_scene.is_empty():
		SignalBus.show_toast.emit(no_exit_message, false)
		return
	SignalBus.popup_requested.emit(&"CONFIRMATION", {
		"message": prompt_message,
		"confirm_text": "Yes",
		"cancel_text": "No",
		"on_confirm": Callable(self, "_on_travel_confirmed"),
	})


## Unlocks the exit. With `animate` the gate sinks with a quake and a toast; without it
## (loading a level where the boss is already dead) it's simply shown open.
func unlock(animate: bool = true) -> void:
	is_locked = false
	if target_scene.is_empty():
		return # no exit configured: nothing to show
	_show_open(animate)


func _show_open(animate: bool) -> void:
	if _is_open_visual:
		return
	_is_open_visual = true
	var gate: Node3D = get_parent().get_node_or_null("Gate") as Node3D
	if is_instance_valid(gate):
		var down: Vector3 = gate.position - Vector3(0.0, open_sink_depth, 0.0)
		if animate:
			var tween: Tween = create_tween()
			tween.tween_property(gate, "position", down, maxf(0.01, open_seconds)) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tween.tween_callback(gate.hide)
		else:
			gate.position = down
			gate.hide()

	# A light in the doorway so the way out reads at a glance.
	var glow := OmniLight3D.new()
	glow.name = "ExitGlow"
	glow.position = Vector3(0.0, 2.2, 0.0)
	glow.light_color = exit_light_color
	glow.light_energy = 2.0
	glow.omni_range = 7.0
	add_child(glow)

	if animate:
		CameraShake.request_earthquake(get_tree(), CameraShake.QuakeSize.SMALL, 1)
		SignalBus.show_toast.emit(opened_toast, false)


func _on_travel_confirmed() -> void:
	MapTransition.travel(get_tree(), target_scene, arrival_point_name)
