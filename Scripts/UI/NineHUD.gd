extends Control

@export var cyan_rotation_speed: float = 0.8
@export var blue_rotation_speed: float = -1.4
@export var voice_bus_name: StringName = &"Voice"

@onready var ring_cyan: TextureRect = %RingCyan
@onready var ring_blue: TextureRect = %RingBlue
@onready var waveform: ColorRect = %Waveform

var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _is_speaking: bool = false

func _ready() -> void:
	hide() # Start hidden until Nine speaks
	await get_tree().process_frame
	_init_pivots()
	_init_audio_analyzer()


func _init_pivots() -> void:
	ring_cyan.pivot_offset = ring_cyan.size / 2.0
	ring_blue.pivot_offset = ring_blue.size / 2.0


func _init_audio_analyzer() -> void:
	var bus_idx: int = AudioServer.get_bus_index(voice_bus_name)
	if bus_idx != -1:
		for i: int in AudioServer.get_bus_effect_count(bus_idx):
			var effect: AudioEffect = AudioServer.get_bus_effect(bus_idx, i)
			if effect is AudioEffectSpectrumAnalyzer:
				_spectrum = AudioServer.get_bus_effect_instance(bus_idx, i)
				break


## Main trigger function: Call this to show the HUD and play Nine's dialogue
func make_nine_talk(sound_file_name: String) -> void:
	show()
	_is_speaking = true
	
	if is_instance_valid(AudioManager):
		AudioManager.play_voice(sound_file_name)
		var voice_player: AudioStreamPlayer = AudioManager.get_voice_player()
		if is_instance_valid(voice_player) and not voice_player.finished.is_connected(_on_speech_finished):
			voice_player.finished.connect(_on_speech_finished, CONNECT_ONE_SHOT)


func _on_speech_finished() -> void:
	_is_speaking = false
	# Fade out or hide HUD when speech completes
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		hide()
		modulate.a = 1.0
	)


func _process(delta: float) -> void:
	var vocal_energy: float = _get_vocal_energy() if _is_speaking else 0.0

	# 1. Ring Rotation (Spins faster when speech energy is high)
	var speed_boost: float = 1.0 + (vocal_energy * 3.0)
	ring_cyan.rotation += cyan_rotation_speed * speed_boost * delta
	ring_blue.rotation += blue_rotation_speed * speed_boost * delta

	# 2. Update Waveform Shader Energy
	if waveform and waveform.material is ShaderMaterial:
		var current_energy: float = (waveform.material as ShaderMaterial).get_shader_parameter("energy")
		var target_energy: float = vocal_energy
		var lerped_energy: float = lerpf(current_energy, target_energy, delta * 12.0)
		(waveform.material as ShaderMaterial).set_shader_parameter("energy", lerped_energy)


func _get_vocal_energy() -> float:
	if not _spectrum or not AudioManager.is_voice_playing():
		return 0.0
	var magnitude: Vector2 = _spectrum.get_magnitude_for_frequency_range(200.0, 4000.0)
	return clampf(magnitude.length() * 8.0, 0.0, 1.0)
