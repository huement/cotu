class_name CameraShake
extends Node

## Non-Destructive Camera Shake Component for Godot 4.
## Applies camera projection offsets without modifying transform coordinates.
##
## Two independent shake sources are summed together:
##   1. Trauma  - short, sharp impact shake (hits, slams). Use add_trauma().
##   2. Quake   - slow rolling "ground shaking" earthquake. Use start_earthquake()
##                or CameraShake.request_earthquake(get_tree(), size, loops).

const GROUP_CAMERA_SHAKE: StringName = &"camera_shake"

enum QuakeSize { SMALL, MEDIUM, LARGE }

## One quake "loop" = BIG rock -> tremors (half size) -> BIG rock -> tremors.
## roll  = max camera roll in degrees during a big rock
## h / v = max camera h_offset / v_offset during a big rock
## freq  = rocks per second during a big rock (lower = slower, heavier sway)
## big   = seconds each big rock lasts, tremor = seconds each tremor phase lasts
const QUAKE_PRESETS: Dictionary = {
	QuakeSize.SMALL:  {"roll": 1.2, "h": 0.06, "v": 0.035, "freq": 2.4, "big": 0.35, "tremor": 0.25},
	QuakeSize.MEDIUM: {"roll": 2.4, "h": 0.12, "v": 0.07,  "freq": 2.0, "big": 0.45, "tremor": 0.30},
	QuakeSize.LARGE:  {"roll": 4.5, "h": 0.24, "v": 0.14,  "freq": 1.6, "big": 0.60, "tremor": 0.40},
}
## Tremors are this fraction of a big rock's size...
const TREMOR_AMPLITUDE: float = 0.5
## ...and rock this much faster (a nervous shiver between the big heaves)
const TREMOR_FREQ_MULT: float = 1.8

@export_group("Target")
@export var target_node: Node

@export_group("Shake Configuration")
## How fast trauma decays per second (Lower = longer lingering rumble)
@export var trauma_decay: float = 1.8
## Maximum horizontal offset (3D camera h_offset)
@export var max_h_offset: float = 0.45
## Maximum vertical offset (3D camera v_offset)
@export var max_v_offset: float = 0.45
## Maximum Z-axis rotation roll (in degrees)
@export var max_roll_degrees: float = 4.5

@export_group("Earthquake")
## Global multiplier on every earthquake preset (tune all quakes at once)
@export_range(0.0, 3.0, 0.05) var quake_strength_multiplier: float = 1.0
## Fine gritty jitter layered on top of the slow rocking (0 = pure smooth sway)
@export_range(0.0, 0.5, 0.01) var quake_grit: float = 0.12

var trauma: float = 0.0
var noise := FastNoiseLite.new()
var noise_time: float = 0.0

# Earthquake state: a queue of pulses, each {amp, freq, dur, roll, h, v}
var _quake_pulses: Array[Dictionary] = []
var _quake_pulse_time: float = 0.0
var _quake_phase: float = 0.0

var _base_position_2d := Vector2.ZERO
var _base_rotation_z: float = 0.0
var _has_saved_base_2d: bool = false


func _ready() -> void:
	add_to_group(GROUP_CAMERA_SHAKE)
	noise.seed = randi()
	noise.frequency = 0.15

	var sb: Node = SignalBus
	if is_instance_valid(sb):
		if not sb.camera_shake_requested.is_connected(add_trauma):
			sb.camera_shake_requested.connect(add_trauma)


func _process(delta: float) -> void:
	if not is_instance_valid(target_node):
		return

	if trauma <= 0.0 and _quake_pulses.is_empty():
		_reset_target()
		return

	noise_time += delta * 120.0

	var off_h: float = 0.0
	var off_v: float = 0.0
	var roll_deg: float = 0.0

	# --- 1. Trauma (sharp impact) ---
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - trauma_decay * delta)
		var shake_amount: float = trauma * trauma
		off_h += max_h_offset * shake_amount * noise.get_noise_2d(noise_time, 0.0)
		off_v += max_v_offset * shake_amount * noise.get_noise_2d(noise_time, 100.0)
		roll_deg += max_roll_degrees * shake_amount * noise.get_noise_2d(noise_time, 200.0)

	# --- 2. Earthquake (slow rocking) ---
	var quake: Vector3 = _process_quake(delta)
	off_h += quake.x
	off_v += quake.y
	roll_deg += quake.z

	# --- 3. Apply non-destructively ---
	if target_node is Camera3D:
		var cam: Camera3D = target_node as Camera3D
		cam.h_offset = off_h
		cam.v_offset = off_v
		cam.rotation.z = deg_to_rad(roll_deg)

	elif target_node is Control or target_node is Node2D:
		if not _has_saved_base_2d:
			_base_position_2d = target_node.position
			_base_rotation_z = target_node.rotation if target_node is Node2D else 0.0
			_has_saved_base_2d = true

		target_node.position = _base_position_2d + Vector2(off_h, off_v) * 120.0
		if "rotation" in target_node:
			target_node.rotation = _base_rotation_z + deg_to_rad(roll_deg)


## Returns (h_offset, v_offset, roll_degrees) for the current quake frame.
func _process_quake(delta: float) -> Vector3:
	if _quake_pulses.is_empty():
		return Vector3.ZERO

	var pulse: Dictionary = _quake_pulses[0]
	var dur: float = pulse["dur"]
	_quake_pulse_time += delta
	# Phase accumulates continuously so frequency changes never cause a jump
	_quake_phase += TAU * float(pulse["freq"]) * delta

	# Smooth swell in and out of each pulse (no hard starts/stops)
	var t: float = clampf(_quake_pulse_time / dur, 0.0, 1.0)
	var envelope: float = sin(PI * t)
	var amp: float = float(pulse["amp"]) * envelope * quake_strength_multiplier

	# Rocking: roll and sideways sway move together like the floor tilting,
	# with a lighter vertical heave at twice the rate.
	var rock: float = sin(_quake_phase)
	var heave: float = sin(_quake_phase * 2.0 + 0.7)
	var grit_h: float = noise.get_noise_2d(noise_time * 0.6, 300.0) * quake_grit
	var grit_v: float = noise.get_noise_2d(noise_time * 0.6, 400.0) * quake_grit

	var result := Vector3(
		float(pulse["h"]) * amp * (rock + grit_h),
		float(pulse["v"]) * amp * (heave + grit_v),
		float(pulse["roll"]) * amp * (sin(_quake_phase - 0.25) + grit_h * 0.5)
	)

	if _quake_pulse_time >= dur:
		_quake_pulses.pop_front()
		_quake_pulse_time = 0.0

	return result


## Resets target node offsets to exact rest state
func _reset_target() -> void:
	if not is_instance_valid(target_node):
		return

	if target_node is Camera3D:
		var cam: Camera3D = target_node as Camera3D
		cam.h_offset = 0.0
		cam.v_offset = 0.0
		cam.rotation.z = 0.0

	elif (target_node is Control or target_node is Node2D) and _has_saved_base_2d:
		target_node.position = _base_position_2d
		if "rotation" in target_node:
			target_node.rotation = _base_rotation_z
		_has_saved_base_2d = false


## Adds trauma to the camera shake bucket (clamped between 0.0 and 1.0)
func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


# ==============================================================================
# EARTHQUAKE API
# ==============================================================================

## Starts a ground-shaking earthquake. Replaces any quake already running.
## loops = how many (BIG -> tremors -> BIG -> tremors) cycles to play.
func start_earthquake(size: QuakeSize, loops: int = 1) -> void:
	_quake_pulses.clear()
	_quake_pulse_time = 0.0

	var preset: Dictionary = QUAKE_PRESETS.get(size, QUAKE_PRESETS[QuakeSize.MEDIUM])
	var freq: float = preset["freq"]

	for _i: int in range(maxi(1, loops)):
		for _j: int in range(2):
			_quake_pulses.append({
				"amp": 1.0, "freq": freq, "dur": preset["big"],
				"roll": preset["roll"], "h": preset["h"], "v": preset["v"],
			})
			_quake_pulses.append({
				"amp": TREMOR_AMPLITUDE, "freq": freq * TREMOR_FREQ_MULT, "dur": preset["tremor"],
				"roll": preset["roll"], "h": preset["h"], "v": preset["v"],
			})


func stop_earthquake() -> void:
	_quake_pulses.clear()
	_quake_pulse_time = 0.0


func is_quaking() -> bool:
	return not _quake_pulses.is_empty()


## Total seconds an earthquake of this size/loops will last.
static func get_earthquake_duration(size: QuakeSize, loops: int = 1) -> float:
	var preset: Dictionary = QUAKE_PRESETS.get(size, QUAKE_PRESETS[QuakeSize.MEDIUM])
	return (float(preset["big"]) + float(preset["tremor"])) * 2.0 * float(maxi(1, loops))


## Convenience: trigger an earthquake on every CameraShake in the scene.
static func request_earthquake(tree: SceneTree, size: QuakeSize, loops: int = 1) -> void:
	if tree:
		tree.call_group(GROUP_CAMERA_SHAKE, &"start_earthquake", size, loops)
