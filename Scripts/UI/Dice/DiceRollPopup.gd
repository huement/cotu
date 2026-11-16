# res://Scripts/UI/Dice/DiceRollPopup.gd
class_name DiceRollPopup
extends CanvasLayer
## Self-contained "roll a D6" window: black frosted-glass panel, title, tumbling die, big result.
## One call, awaitable, cleans itself up - meant for battle skills, traps, chance events...
##
##   var value: int = await DiceRollPopup.roll_d6(get_tree(), "LUCKY STRIKE", "Roll 5+ to crit!")
##   var value2: int = await DiceRollPopup.roll_d6(get_tree(), "TRAP", "", 0, func(v: int) -> String:
##       return "DODGED!" if v >= 4 else "OUCH!")
##
## forced_result 1..6 lets game code decide the outcome and just show it.
## The window closes by itself after `hold_seconds`, or on click / Enter / Space.
## Works while the tree is paused.

const GLASS_SHADER: Shader = preload("res://Shaders/frosted_glass.gdshader")
const TITLE_FONT: FontFile = preload("res://ui/fonts/Nexa-Heavy.otf")
const COLOR_ACCENT: Color = Color(0.0, 1.0, 0.784)
const COLOR_MUTED: Color = Color(0.55, 0.9, 0.85)

signal finished(value: int)

var title_text: String = "ROLL"
var subtitle_text: String = ""
var forced_result: int = 0
## Optional `func(value: int) -> String` shown under the number once the die lands.
var describe: Callable = Callable()
var hold_seconds: float = 1.6

var dice: DiceRoll3D
var _panel: PanelContainer
var _result_label: Label
var _detail_label: Label
var _hint_label: Label
var _can_close: bool = false
var _closing: bool = false


## Opens the window, rolls, waits for it to close and returns the value.
static func roll_d6(tree: SceneTree, title: String = "ROLL", subtitle: String = "", forced: int = 0, describe_fn: Callable = Callable(), hold: float = 1.6) -> int:
	var popup := DiceRollPopup.new()
	popup.title_text = title
	popup.subtitle_text = subtitle
	popup.forced_result = forced
	popup.describe = describe_fn
	popup.hold_seconds = hold
	tree.root.add_child(popup)
	return await popup.finished


## Black frosted glass for any Control (PanelContainer / Panel). Shared so other windows can match.
static func make_glass_material(tint_alpha: float = 0.72) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GLASS_SHADER
	mat.set_shader_parameter("blur_amount", 3.0)
	mat.set_shader_parameter("background_tint", Color(0.01, 0.02, 0.03, tint_alpha))
	mat.set_shader_parameter("vibrancy", 1.15)
	return mat


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_run.call_deferred()


func _run() -> void:
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.9, 0.9)
	_panel.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

	var value: int = await dice.roll(forced_result)
	_result_label.text = str(value)
	_result_label.pivot_offset = _result_label.size * 0.5
	_result_label.scale = Vector2(1.6, 1.6)
	var detail: String = str(describe.call(value)) if describe.is_valid() else ""
	_detail_label.text = detail
	_detail_label.visible = not detail.is_empty()
	var reveal: Tween = create_tween().set_parallel(true)
	reveal.tween_property(_result_label, "modulate:a", 1.0, 0.15)
	reveal.tween_property(_result_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(_detail_label, "modulate:a", 1.0, 0.3).set_delay(0.12)
	_can_close = true
	_hint_label.modulate.a = 0.0
	reveal.tween_property(_hint_label, "modulate:a", 0.7, 0.3).set_delay(0.5)

	await get_tree().create_timer(hold_seconds, true).timeout
	_close(value)


func _input(event: InputEvent) -> void:
	if not _can_close:
		if event is InputEventMouseButton or event is InputEventKey:
			get_viewport().set_input_as_handled() # swallow input while rolling
		return
	var pressed: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or event.is_action_pressed(&"ui_accept")
	if pressed:
		get_viewport().set_input_as_handled()
		_close(dice.last_result)


func _close(value: int) -> void:
	if _closing:
		return
	_closing = true
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.18)
	tw.tween_property(_panel, "scale", Vector2(0.94, 0.94), 0.18)
	await tw.finished
	finished.emit(value)
	queue_free()


# ------------------------------------------------------------------------------
func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.material = make_glass_material()
	_panel.custom_minimum_size = Vector2(340, 0)
	center.add_child(_panel)

	var border := Panel.new()
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.set_border_width_all(1)
	box.border_color = Color(COLOR_ACCENT, 0.8)
	box.set_corner_radius_all(4)
	border.add_theme_stylebox_override("panel", box)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(border)

	var margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	vbox.add_child(_make_label(title_text, 20, COLOR_ACCENT, TITLE_FONT))
	if not subtitle_text.is_empty():
		vbox.add_child(_make_label(subtitle_text, 13, COLOR_MUTED))

	dice = DiceRoll3D.new()
	dice.custom_minimum_size = Vector2(300, 230)
	dice.die_scale = 0.7
	dice.visible_before_roll = false
	vbox.add_child(dice)

	_result_label = _make_label("", 44, COLOR_ACCENT, TITLE_FONT)
	_result_label.modulate.a = 0.0
	vbox.add_child(_result_label)
	_detail_label = _make_label("", 15, Color(1.0, 0.85, 0.25))
	_detail_label.modulate.a = 0.0
	_detail_label.visible = false
	vbox.add_child(_detail_label)
	_hint_label = _make_label("CLICK TO CONTINUE", 11, COLOR_MUTED)
	_hint_label.modulate.a = 0.0
	vbox.add_child(_hint_label)


func _make_label(text: String, size: int, color: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	if font != null:
		label.add_theme_font_override("font", font)
	return label
