@tool
class_name ActionButton
extends TextureButton

## Drag any icon PNG (Sword, Shield, Potion, Spell) into this slot in the Inspector
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_node_ready():
			_update_icon()

## Color tint applied to the icon (optional)
@export var icon_tint: Color = Color.WHITE:
	set(value):
		icon_tint = value
		if is_node_ready():
			_update_icon()

@onready var icon_display: TextureRect = %IconDisplay

func _ready() -> void:
	_update_icon()
	
	# Connect press/release signals for visual click feedback
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _update_icon() -> void:
	if icon_display:
		icon_display.texture = icon_texture
		icon_display.modulate = icon_tint

## Slightly nudges the icon down 2px when pressed for tactile feedback
func _on_button_down() -> void:
	if icon_display:
		icon_display.position.y += 2.0

func _on_button_up() -> void:
	if icon_display:
		icon_display.position.y -= 2.0
