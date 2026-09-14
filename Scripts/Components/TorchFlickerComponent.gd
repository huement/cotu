extends Node3D

@export var light_node: OmniLight3D
@export var base_energy: float = 1.5
@export var flicker_range: float = 0.3
@export var flicker_speed: float = 12.0

var _time_passed: float = 0.0

func _ready() -> void:
	if not light_node and has_node("FlameLight"):
		light_node = $FlameLight as OmniLight3D

func _process(delta: float) -> void:
	if not light_node:
		return
	_time_passed += delta * flicker_speed
	var noise_val: float = sin(_time_passed) * cos(_time_passed * 1.5)
	light_node.light_energy = base_energy + (noise_val * flicker_range)
