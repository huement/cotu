extends Node3D

@export var base_energy: float = 1.2
@export var flicker_range: float = 0.3
@export var flicker_speed: float = 12.0

@onready var light: OmniLight3D = %OmniLight3D

var _noise: FastNoiseLite = FastNoiseLite.new()
var _time: float = 0.0

func _ready() -> void:
	# Randomize noise per torch instance so they don't flicker in sync
	_noise.seed = randi()
	_noise.frequency = 0.1

func _process(delta: float) -> void:
	if not light:
		return
	
	_time += delta * flicker_speed
	var noise_val: float = _noise.get_noise_1d(_time)
	light.light_energy = base_energy + (noise_val * flicker_range)