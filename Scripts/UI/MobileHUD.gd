# res://Scripts/UI/MobileHUD.gd
class_name MobileHUD
extends Node
## Touch-screen layout for the exploration HUD (the battle HUD is unchanged). Created by DungeonHUD
## (Scripts/hud.gd) and switched on automatically on touch devices - see is_wanted().
##
##   * Party portraits move from the right sidebar to a bottom-left panel: 2 rows of 3 between the
##     party_panel_top / party_panel_btm bars. Front row (slots 0-2) is the bottom row; the top row
##     (slots 3-5) only shows when someone is in it.
##   * SEARCH / ITEMS / REST move to the bottom centre, spaced out for fingers.
##   * A D-pad bottom-right: strafe left, forward, strafe right / turn left, back, turn right
##     (TouchScreenButtons, so several fingers work at once). They press the same input actions as the
##     keyboard (move_forward, move_backward, turn_left, turn_right, strafe_left, strafe_right), so
##     holding forward runs and holding back turns around, exactly like the keys.
##   * Everything here hides in battle with the rest of the exploration HUD.
##
## Art: ui/MOBILE/*.svg (normal + pressed_*). Sizes below are the SVG viewBox sizes, so the layout
## doesn't change if the SVGs are re-imported at a different svg/scale (use 2-3 for sharp phone screens).
##
## Preview on desktop: debug menu (`) > MOBILE HUD, or Project Settings > shards/hud/force_mobile_hud.
## In a preview the mouse drives the D-pad (Input.emulate_touch_from_mouse).

const FORCE_SETTING: String = "shards/hud/force_mobile_hud"
const ART: String = "res://ui/MOBILE/"

## [action, normal svg, pressed svg, position, design size] - positions in px from the pad's top-left.
const DPAD_BUTTONS: Array[Array] = [
	[&"strafe_left", "strafe_left", "pressed_strafe_left", Vector2(0, 45), Vector2(75.68, 57.68)],
	[&"move_forward", "up", "pressed_up", Vector2(83, 0), Vector2(88.3, 101.84)],
	[&"strafe_right", "strafe_right", "pressed_strafe_right", Vector2(178, 45), Vector2(75.78, 57.68)],
	[&"turn_left", "left", "pressed_left", Vector2(0, 114), Vector2(75.49, 75.49)],
	[&"move_backward", "down", "pressed_down", Vector2(83, 114), Vector2(88.3, 76.0)],
	[&"turn_right", "right", "pressed_right", Vector2(178, 114), Vector2(75.49, 75.49)],
]
const DPAD_SIZE: Vector2 = Vector2(254, 190)
const WIRES_POS: Vector2 = Vector2(36, 100)
const WIRES_SIZE: Vector2 = Vector2(179.89, 111)
const DPAD_MARGIN: Vector2 = Vector2(12, 14)

const PORTRAIT_CELL: Vector2 = Vector2(54, 62)
const PORTRAIT_GAP: Vector2 = Vector2(16, 12)
const PANEL_MARGIN: Vector2 = Vector2(12, 8)
const PANEL_TOP_SIZE: Vector2 = Vector2(197.83, 6.81)
const PANEL_BTM_SIZE: Vector2 = Vector2(197.05, 20.98)

const ACTION_SPACING: int = 44
const ACTION_BOTTOM_MARGIN: float = 14.0

var enabled: bool = false

var _hud: DungeonHUD
var _root: Control
var _top_row: HBoxContainer
var _cells: Array[Control] = []
var _actions_anchor: Control
var _dpad_buttons: Array[TouchScreenButton] = []
var _built: bool = false
var _portrait_home: Array[Dictionary] = [] # { node, parent, index }
var _actions_home: Dictionary = {}
var _old_emulate_touch: bool = false


## True on phones / tablets (and touch browsers), or when forced for a desktop preview.
static func is_wanted() -> bool:
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		return true
	return bool(ProjectSettings.get_setting(FORCE_SETTING, false))


func setup(hud: DungeonHUD) -> void:
	_hud = hud
	if is_wanted():
		set_enabled(true)


func set_enabled(on: bool) -> void:
	if on == enabled or not is_instance_valid(_hud):
		return
	if on:
		_build()
		_move_portraits_in()
		_move_actions_in()
		_root.show()
		_hud.add_exploration_node(_root)
		_root.visible = not SessionFlow.is_in_battle()
		# A desktop preview has no touch screen: let the mouse act as a finger on the D-pad.
		_old_emulate_touch = Input.emulate_touch_from_mouse
		if not DisplayServer.is_touchscreen_available():
			Input.emulate_touch_from_mouse = true
	else:
		_release_all()
		_hud.remove_exploration_node(_root)
		_root.hide()
		_move_portraits_out()
		_move_actions_out()
		Input.emulate_touch_from_mouse = _old_emulate_touch
	enabled = on
	# The right-hand sidebar frame (CockpitBackground) frames nothing once the portraits move.
	# Fade it rather than hide it, because the HUD re-shows it after every battle.
	if is_instance_valid(_hud.cockpit_background):
		_hud.cockpit_background.self_modulate.a = 0.0 if on else 1.0


func _process(_delta: float) -> void:
	if not enabled or not is_instance_valid(_top_row):
		return
	# Back row only when someone stands in it.
	var slots: Array = GameState.current_party.slots if GameState.current_party != null else []
	var back_used: bool = false
	for i: int in range(3, 6):
		if i < slots.size() and slots[i] != null:
			back_used = true
	_top_row.visible = back_used


## Lets go of every held direction (e.g. when the HUD hides for a battle mid-press).
func _release_all() -> void:
	for b: TouchScreenButton in _dpad_buttons:
		if Input.is_action_pressed(b.action):
			Input.action_release(b.action)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and enabled:
		Input.emulate_touch_from_mouse = _old_emulate_touch


# ==============================================================================
# Build
# ==============================================================================
func _build() -> void:
	if _built:
		return
	_built = true
	_root = Control.new()
	_root.name = "MobileHUD"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visibility_changed.connect(func() -> void:
		if not _root.visible:
			_release_all())
	_hud.main_hud_layout.add_child(_root)
	_build_party_panel()
	_build_actions_anchor()
	_build_dpad()


func _build_party_panel() -> void:
	var grid_w: float = PORTRAIT_CELL.x * 3.0 + PORTRAIT_GAP.x * 2.0
	var bar_w: float = grid_w + 16.0
	var panel := VBoxContainer.new()
	panel.name = "PartyPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_constant_override("separation", 6)
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = PANEL_MARGIN.x
	panel.offset_right = PANEL_MARGIN.x + bar_w
	panel.offset_bottom = -PANEL_MARGIN.y
	_root.add_child(panel)

	panel.add_child(_bar("party_panel_top", Vector2(bar_w, bar_w * PANEL_TOP_SIZE.y / PANEL_TOP_SIZE.x)))
	_top_row = _row()
	panel.add_child(_top_row)
	var bottom_row: HBoxContainer = _row()
	panel.add_child(bottom_row)
	for i: int in 6:
		var cell := Control.new()
		cell.custom_minimum_size = PORTRAIT_CELL
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cells.append(cell)
	# Front row (0-2) at the bottom, back row (3-5) on top.
	for i: int in range(3, 6):
		_top_row.add_child(_cells[i])
	for i: int in range(0, 3):
		bottom_row.add_child(_cells[i])
	panel.add_child(_bar("party_panel_btm", Vector2(bar_w, bar_w * PANEL_BTM_SIZE.y / PANEL_BTM_SIZE.x)))


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(PORTRAIT_GAP.x))
	return row


func _bar(file: String, bar_size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(ART + file + ".svg") as Texture2D
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = bar_size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _build_actions_anchor() -> void:
	_actions_anchor = Control.new()
	_actions_anchor.name = "ActionsAnchor"
	_actions_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actions_anchor.anchor_left = 0.5
	_actions_anchor.anchor_right = 0.5
	_actions_anchor.anchor_top = 1.0
	_actions_anchor.anchor_bottom = 1.0
	_root.add_child(_actions_anchor)


func _build_dpad() -> void:
	var pad := Control.new()
	pad.name = "DPad"
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.anchor_left = 1.0
	pad.anchor_right = 1.0
	pad.anchor_top = 1.0
	pad.anchor_bottom = 1.0
	pad.offset_left = -DPAD_SIZE.x - DPAD_MARGIN.x
	pad.offset_right = -DPAD_MARGIN.x
	pad.offset_top = -DPAD_SIZE.y - DPAD_MARGIN.y
	pad.offset_bottom = -DPAD_MARGIN.y
	_root.add_child(pad)

	var wires := TextureRect.new()
	wires.texture = load(ART + "dpad_wires.svg") as Texture2D
	wires.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wires.stretch_mode = TextureRect.STRETCH_SCALE
	wires.position = WIRES_POS
	wires.size = WIRES_SIZE
	wires.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(wires)

	for spec: Array in DPAD_BUTTONS:
		var b := TouchScreenButton.new()
		b.name = "Pad_" + String(spec[0])
		b.action = StringName(spec[0])
		b.texture_normal = load(ART + str(spec[1]) + ".svg") as Texture2D
		b.texture_pressed = load(ART + str(spec[2]) + ".svg") as Texture2D
		b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
		b.position = spec[3] as Vector2
		var design: Vector2 = spec[4] as Vector2
		if b.texture_normal != null:
			b.scale = design / b.texture_normal.get_size()
		pad.add_child(b)
		_dpad_buttons.append(b)


# ==============================================================================
# Moving the desktop pieces in / out
# ==============================================================================
func _move_portraits_in() -> void:
	_portrait_home.clear()
	# Remember every home first (moving one shifts the others' indices).
	for p: Control in _hud.portrait_slots:
		if is_instance_valid(p):
			_portrait_home.append({ "node": p, "parent": p.get_parent(), "index": p.get_index() })
	for i: int in mini(_hud.portrait_slots.size(), _cells.size()):
		var p: Control = _hud.portrait_slots[i]
		if is_instance_valid(p):
			p.reparent(_cells[i], false)
			p.position = Vector2.ZERO


func _move_portraits_out() -> void:
	_portrait_home.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["index"]) < int(b["index"]))
	for home: Dictionary in _portrait_home:
		var p: Control = home["node"] as Control
		var parent: Node = home["parent"] as Node
		if is_instance_valid(p) and is_instance_valid(parent):
			p.reparent(parent, false)
			parent.move_child(p, mini(int(home["index"]), parent.get_child_count() - 1))
	_portrait_home.clear()


func _action_buttons() -> HBoxContainer:
	var search: Node = _hud.get_node_or_null(^"%SearchButton")
	return search.get_parent() as HBoxContainer if search != null else null


func _move_actions_in() -> void:
	var box: HBoxContainer = _action_buttons()
	if box == null:
		return
	_actions_home = {
		"parent": box.get_parent(), "index": box.get_index(), "position": box.position,
		"separation": box.get_theme_constant("separation"),
	}
	box.reparent(_actions_anchor, false)
	box.add_theme_constant_override("separation", ACTION_SPACING)
	# Centre it on the anchor, sitting on the bottom edge.
	box.reset_size()
	var sz: Vector2 = box.get_combined_minimum_size()
	box.position = Vector2(-sz.x * 0.5, -sz.y - ACTION_BOTTOM_MARGIN)


func _move_actions_out() -> void:
	var box: HBoxContainer = _action_buttons()
	if box == null or _actions_home.is_empty():
		return
	box.reparent(_actions_home["parent"] as Node, false)
	box.position = _actions_home["position"] as Vector2
	box.add_theme_constant_override("separation", int(_actions_home["separation"]))
	_actions_home.clear()
