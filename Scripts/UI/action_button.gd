extends TextureButton
class_name ActionButton

enum Direction { LEFT, RIGHT }

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_node_ready() and %IconDisplay:
			%IconDisplay.texture = icon_texture

@export var direction: Direction = Direction.LEFT:
	set(value):
		direction = value
		if is_node_ready():
			_update_background_direction()

@export var auto_shimmer: bool = false
@export var shimmer_interval: float = 6.0

var _shimmer_timer: float = 0.0


func _ready() -> void:
	if icon_texture and %IconDisplay:
		%IconDisplay.texture = icon_texture

	if material:
		material = material.duplicate()

	_update_background_direction()

	_shimmer_timer = randf_range(0.0, shimmer_interval)
	mouse_entered.connect(play_shimmer)


func _update_background_direction() -> void:
	if direction == Direction.RIGHT:
		# 1. Use dedicated right-facing PNG assets if available
		if ResourceLoader.exists("res://ui/BATTLE/btnRight.png"):
			texture_normal = load("res://ui/BATTLE/btnRight.png") as Texture2D
			if ResourceLoader.exists("res://ui/BATTLE/btnRightPressed.png"):
				texture_pressed = load("res://ui/BATTLE/btnRightPressed.png") as Texture2D
			if ResourceLoader.exists("res://ui/BATTLE/btnRightHover.png"):
				texture_hover = load("res://ui/BATTLE/btnRightHover.png") as Texture2D
			flip_h = false
		else:
			# 2. Fallback: Horizontally flip the button's background texture (does NOT flip child nodes like %IconDisplay)
			flip_h = true
	else:
		if ResourceLoader.exists("res://ui/BATTLE/btnLeft.png"):
			texture_normal = load("res://ui/BATTLE/btnLeft.png") as Texture2D
			if ResourceLoader.exists("res://ui/BATTLE/btnLeftPressed.png"):
				texture_pressed = load("res://ui/BATTLE/btnLeftPressed.png") as Texture2D
			if ResourceLoader.exists("res://ui/BATTLE/btnLeftHover.png"):
				texture_hover = load("res://ui/BATTLE/btnLeftHover.png") as Texture2D
		flip_h = false


func _process(delta: float) -> void:
	if not auto_shimmer or material == null:
		return

	_shimmer_timer += delta
	if _shimmer_timer >= shimmer_interval:
		_shimmer_timer = 0.0
		play_shimmer()


func play_shimmer() -> void:
	var mat := material as ShaderMaterial
	if not is_instance_valid(mat):
		return

	var tween: Tween = create_tween()
	tween.tween_property(mat, "shader_parameter/shine_progress", 1.5, 0.35) \
		.from(-0.5) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
