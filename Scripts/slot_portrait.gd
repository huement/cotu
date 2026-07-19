extends TextureRect

@export var hover_scale: Vector2 = Vector2(1.1, 1.1)
@export var default_scale: Vector2 = Vector2(1.0, 1.0)

func _ready() -> void:
	# 1. IMPORTANT: Make sure the portrait detects the mouse
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# 2. Connect only the hover signals (TextureRects don't have click signals)
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)

func _on_hover_start() -> void:
	# Grab the container-approved size for the pivot point
	pivot_offset = size / 2
	z_index = 1
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", hover_scale, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.15) # Subtle brightness boost

func _on_hover_end() -> void:
	z_index = 0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", default_scale, 0.15)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.15)
