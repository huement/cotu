extends Label3D

@export var max_alpha: float = 0.5
@export var fade_in_time: float = 1.3
@export var fade_out_time: float = 1.5

var _tween: Tween

func _ready() -> void:
	modulate.a = 0.0
	outline_modulate.a = 0.0

func show_level_banner(banner_text: String) -> void:
	text = banner_text
	
	if _tween and _tween.is_running():
		_tween.kill()
		
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", max_alpha, fade_in_time)
	_tween.tween_property(self, "outline_modulate:a", max_alpha * 0.8, fade_in_time)

func hide_level_banner() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
		
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, fade_out_time)
	_tween.tween_property(self, "outline_modulate:a", 0.0, fade_out_time)
