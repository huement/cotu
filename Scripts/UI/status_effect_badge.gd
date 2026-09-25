extends PanelContainer
class_name StatusEffectBadge

@onready var icon_rect: TextureRect = %IconTexture
@onready var duration_label: Label = %DurationLabel

const BORDER_COLOR_POSITIVE := Color(0.0, 0.65, 1.0, 1.0)
const BORDER_COLOR_NEGATIVE := Color(1.0, 0.25, 0.25, 1.0)

func setup(effect_info: Dictionary, current_duration: int = -1) -> void:
	var is_positive: bool = effect_info.get("is_positive", true)
	var effect_name: String = effect_info.get("name", "Effect")
	var icon_tex: Texture2D = effect_info.get("icon", null)
	var desc: String = effect_info.get("description", "")
	
	# Restrict badge dimensions so it remains a clean square
	custom_minimum_size = Vector2(40, 40)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Apply dynamic border styling (Blue for Positive, Red for Negative)
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.04, 0.06, 0.08, 0.9)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = BORDER_COLOR_POSITIVE if is_positive else BORDER_COLOR_NEGATIVE
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_right = 4
	style_box.corner_radius_bottom_left = 4
	add_theme_stylebox_override("panel", style_box)
	
	if is_instance_valid(icon_rect) and icon_tex != null:
		icon_rect.texture = icon_tex
		
	if is_instance_valid(duration_label):
		var dur: int = current_duration
		# If no duration override was provided, fall back to base effect info duration
		if dur < 0:
			dur = int(effect_info.get("duration", 0))
			
		# Equipment status effects (duration 0) hide the turn counter text
		if dur <= 0:
			duration_label.visible = false
		else:
			duration_label.visible = true
			duration_label.text = "%dt" % dur
		
	tooltip_text = "%s\n%s" % [effect_name, desc]