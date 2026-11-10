class_name MenuKitCurtain
extends CanvasLayer
## Black screen with a short line ("Signal lost"...), shown when the game quits.

var text: String = ""
var _view: Control


func _init(p_text: String = "") -> void:
	name = "Curtain"
	text = p_text
	layer = 126
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_view = Control.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.modulate.a = 0.0
	_view.draw.connect(func() -> void: MenuKit.style.draw_curtain(_view, Rect2(Vector2.ZERO, _view.size), tr(text)))
	add_child(_view)


## Fades in, waits, and returns.
func play(fade: float = 0.5, hold: float = 0.7) -> void:
	get_viewport().gui_release_focus()
	var tween: Tween = create_tween()
	tween.tween_property(_view, "modulate:a", 1.0, fade)
	tween.tween_interval(hold)
	await tween.finished
