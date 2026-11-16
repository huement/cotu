# res://Scripts/UI/Menus/hud_shard_menu.gd
class_name HudShardMenu
extends CanvasLayer
## Exploration shard progress overlay. Opened from the HUD ShardMenuButton.
## Area rows come from ShardLedger.areas() (one row per area: collected / total) and are rebuilt
## every time the menu opens and whenever a shard is collected. Time is GameState.play_time_seconds.
## Kills is GameState.enemies_killed (one per enemy that falls in combat, saved with the session).

signal menu_opened
signal menu_closed

const COLOR_BG: Color = Color(0.29, 0.29, 0.29, 1.0) # #4A4A4A
const COLOR_MAGENTA: Color = Color(1.0, 0.267, 0.533, 1.0) # #FF4488
const COLOR_WHITE: Color = Color(1.0, 1.0, 1.0, 1.0)
const TITLE_FONT: FontFile = preload("res://ui/fonts/Nexa-Heavy.otf")
const BACK_ICON: Texture2D = preload("res://ui/icons/menu/arrow_left.svg")

@onready var _root: Control = %Root as Control
@onready var _content: Control = %Content as Control
@onready var _back_button: Button = %BackButton as Button
@onready var _time_value: Label = %TimeValue as Label
@onready var _kills_value: Label = %KillsValue as Label
@onready var _area_list: VBoxContainer = %AreaList as VBoxContainer
@onready var _hud_frame: TextureRect = %HudFrame as TextureRect
@onready var _scroll_inset: Control = get_node_or_null(^"Root/Content/HBox/ShardHud/ScrollInset") as Control

## ScrollInset's offsets inside the *drawn* green frame (the frame keeps its aspect and is centred,
## so on wide phones it is narrower than its box - the text must follow the art, not the box).
const FRAME_INSET_LEFT: float = 27.0
const FRAME_INSET_TOP: float = 10.0
const FRAME_INSET_RIGHT: float = 18.0
const FRAME_INSET_BOTTOM: float = 28.0

var is_open: bool = false
var _was_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.hide()
	_style_labels()
	_style_back_button()
	_back_button.pressed.connect(close_menu)
	if is_instance_valid(_hud_frame):
		_hud_frame.resized.connect(_fit_text_to_frame)
	SignalBus.shard_collected.connect(_on_shard_collected)
	refresh()
	# Preview when this scene is run directly from the editor / CLI.
	if get_tree().current_scene == self:
		open_menu.call_deferred()


func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	if is_open:
		return
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	refresh()
	_root.show()
	_fit_text_to_frame.call_deferred()
	_play_ui_sound("button-press")
	_animate_in()
	_back_button.grab_focus.call_deferred()
	menu_opened.emit()


func close_menu() -> void:
	if not is_open:
		return
	is_open = false
	_root.hide()
	get_tree().paused = _was_paused
	get_viewport().gui_release_focus()
	_play_ui_sound("button-press")
	menu_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close_menu()


func _style_labels() -> void:
	_apply_stat_label(%TimeLabel as Label)
	_apply_stat_label(%KillsLabel as Label)
	_time_value.add_theme_font_override("font", TITLE_FONT)
	_time_value.add_theme_font_size_override("font_size", 22)
	_time_value.add_theme_color_override("font_color", COLOR_MAGENTA)
	_kills_value.add_theme_font_override("font", TITLE_FONT)
	_kills_value.add_theme_font_size_override("font_size", 22)
	_kills_value.add_theme_color_override("font_color", COLOR_MAGENTA)
	var title: Label = %TitleLabel as Label
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", COLOR_WHITE)
	# Wrap instead of forcing the panel wider than the frame on narrow frames.
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _apply_stat_label(label: Label) -> void:
	if label == null:
		return
	label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", COLOR_WHITE)


func _style_back_button() -> void:
	var normal: StyleBoxFlat = _outline_box(COLOR_WHITE, 2)
	var hover: StyleBoxFlat = _outline_box(COLOR_MAGENTA, 2)
	var pressed: StyleBoxFlat = _outline_box(COLOR_MAGENTA.lightened(0.2), 3)
	var focus: StyleBoxFlat = _outline_box(COLOR_MAGENTA, 2)
	focus.draw_center = false
	_back_button.add_theme_stylebox_override("normal", normal)
	_back_button.add_theme_stylebox_override("hover", hover)
	_back_button.add_theme_stylebox_override("pressed", pressed)
	_back_button.add_theme_stylebox_override("focus", focus)
	_back_button.add_theme_font_override("font", TITLE_FONT)
	_back_button.add_theme_font_size_override("font_size", 18)
	_back_button.add_theme_color_override("font_color", COLOR_WHITE)
	_back_button.add_theme_color_override("font_hover_color", COLOR_MAGENTA)
	_back_button.add_theme_color_override("font_focus_color", COLOR_MAGENTA)
	_back_button.add_theme_color_override("font_pressed_color", COLOR_MAGENTA.lightened(0.2))
	_back_button.add_theme_color_override("icon_normal_color", COLOR_WHITE)
	_back_button.add_theme_color_override("icon_hover_color", COLOR_MAGENTA)
	_back_button.add_theme_color_override("icon_focus_color", COLOR_MAGENTA)
	_back_button.add_theme_color_override("icon_pressed_color", COLOR_MAGENTA.lightened(0.2))
	_back_button.add_theme_constant_override("icon_max_width", 22)
	_back_button.add_theme_constant_override("h_separation", 10)
	_back_button.icon = BACK_ICON
	_back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_back_button.focus_neighbor_left = _back_button.get_path_to(_back_button)
	_back_button.focus_neighbor_right = _back_button.get_path_to(_back_button)
	_back_button.focus_neighbor_top = _back_button.get_path_to(_back_button)
	_back_button.focus_neighbor_bottom = _back_button.get_path_to(_back_button)


func _outline_box(border: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(12.0)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	return style


## Rebuilds the area rows, play time, and kill total from the live game data.
func refresh() -> void:
	_populate_areas()
	var minutes: int = int(GameState.play_time_seconds / 60.0)
	_time_value.text = "%d:%02d" % [minutes / 60, minutes % 60]
	_kills_value.text = str(GameState.enemies_killed)


func _on_shard_collected(_shard_id: String, _area: String) -> void:
	refresh()


func _populate_areas() -> void:
	while _area_list.get_child_count() > 0:
		var child: Node = _area_list.get_child(0)
		_area_list.remove_child(child)
		child.free()
	for entry: Dictionary in ShardLedger.areas():
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label: Label = Label.new()
		name_label.text = String(entry["name"]).to_upper()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_override("font", TITLE_FONT)
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", COLOR_WHITE)
		var count_label: Label = Label.new()
		count_label.text = "%d / %d" % [int(entry["collected"]), int(entry["total"])]
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.add_theme_font_override("font", TITLE_FONT)
		count_label.add_theme_font_size_override("font_size", 22)
		count_label.add_theme_color_override("font_color", COLOR_WHITE)
		row.add_child(name_label)
		row.add_child(count_label)
		_area_list.add_child(row)


## Keeps the title + area rows inside the green frame art on any screen shape.
func _fit_text_to_frame() -> void:
	if not is_instance_valid(_hud_frame) or not is_instance_valid(_scroll_inset) or _hud_frame.texture == null:
		return
	var box: Vector2 = _hud_frame.size
	var tex: Vector2 = _hud_frame.texture.get_size()
	if box.x <= 0.0 or box.y <= 0.0 or tex.x <= 0.0 or tex.y <= 0.0:
		return
	# Same maths as STRETCH_KEEP_ASPECT_CENTERED.
	var fit: float = minf(box.x / tex.x, box.y / tex.y)
	var drawn: Vector2 = tex * fit
	var pad: Vector2 = (box - drawn) * 0.5
	_scroll_inset.offset_left = pad.x + FRAME_INSET_LEFT
	_scroll_inset.offset_right = -pad.x - FRAME_INSET_RIGHT
	_scroll_inset.offset_top = pad.y + FRAME_INSET_TOP
	_scroll_inset.offset_bottom = -pad.y - FRAME_INSET_BOTTOM


func _animate_in() -> void:
	_content.pivot_offset = _content.size * 0.5
	_content.modulate.a = 0.0
	_content.scale = Vector2(0.97, 0.97)
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_content, "modulate:a", 1.0, 0.18)
	tween.tween_property(_content, "scale", Vector2.ONE, 0.22)


func _play_ui_sound(sound_name: String) -> void:
	if is_instance_valid(AudioManager) and AudioManager.has_method("play_ui_sound"):
		AudioManager.play_ui_sound(sound_name)
