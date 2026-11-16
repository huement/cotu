# res://Scripts/UI/KeyboardModal.gd
class_name KeyboardModal
extends Node
## Makes any panel playable with the keyboard. Attach it to the panel once:
##
##     KeyboardModal.attach(panel, _on_cancel_pressed)
##
## While the panel is visible (and is the topmost keyboard panel):
##   * every enabled button / slider / option button inside it can take keyboard focus and shows a
##     cyan outline (TextureButtons show their hover texture instead),
##   * focus starts on the control with meta "kb_default", else the first focusable one, and comes
##     back there if it is ever lost (content rebuilt, a button got disabled...),
##   * Tab / Shift+Tab / arrows move, Enter / Space press (Godot's ui_accept / ui_focus_next),
##   * Esc (ui_cancel) calls the cancel callable,
##   * Enter on a slider presses the "kb_default" button (REST: pick hours, Enter to rest).
## Buttons created later (popups that rebuild their content) are picked up automatically.
##
## The party can't walk while a keyboard panel is open (DungeonPlayer checks is_any_open()), so the
## arrow keys only move the focus. Panels that allow the 1-6 party hotkeys set meta
## "allow_party_hotkeys" on the panel (character sheet, battle action bar).

const PANEL_GROUP: StringName = &"keyboard_modal"
const META_DEFAULT: StringName = &"kb_default"
const META_ALLOW_PARTY_KEYS: StringName = &"allow_party_hotkeys"
const META_NO_FOCUS: StringName = &"kb_skip"
const FOCUS_COLOR: Color = Color(0.0, 1.0, 0.9, 1.0)
## Seconds between re-scans for new / re-enabled buttons while the panel is open.
const SCAN_INTERVAL: float = 0.2

## Visible keyboard panels, oldest first. The last one gets the keys.
static var _open_stack: Array[KeyboardModal] = []

var cancel_callable: Callable = Callable()
var _host: Control = null
var _was_open: bool = false
var _scan_timer: float = 0.0
static var _focus_style: StyleBoxFlat = null


## Adds a KeyboardModal to `host` (or returns the one already there).
static func attach(host: Control, on_cancel: Callable = Callable()) -> KeyboardModal:
	for child: Node in host.get_children():
		if child is KeyboardModal:
			(child as KeyboardModal).cancel_callable = on_cancel
			return child as KeyboardModal
	var modal := KeyboardModal.new()
	modal.name = "KeyboardModal"
	modal.cancel_callable = on_cancel
	host.add_child(modal)
	return modal


## True while any keyboard panel is on screen (the party should not move).
static func is_any_open() -> bool:
	_prune()
	return not _open_stack.is_empty()


## The panel that currently gets the keys, or null.
static func top_host() -> Control:
	_prune()
	return _open_stack.back()._host if not _open_stack.is_empty() else null


## True when the 1-6 party keys may act (nothing open, or the top panel allows them).
static func party_hotkeys_allowed() -> bool:
	var host: Control = top_host()
	return host == null or bool(host.get_meta(META_ALLOW_PARTY_KEYS, false))


## Marks the control that should get focus first (and that Enter on a slider presses).
static func set_default(control: Control) -> void:
	if is_instance_valid(control):
		control.set_meta(META_DEFAULT, true)


static func _prune() -> void:
	_open_stack = _open_stack.filter(func(m: KeyboardModal) -> bool:
		return is_instance_valid(m) and is_instance_valid(m._host) and m._host.is_visible_in_tree())


func _ready() -> void:
	_host = get_parent() as Control
	if _host == null:
		push_warning("KeyboardModal must be a child of a Control.")
		set_process(false)
		set_process_input(false)
		return
	_host.add_to_group(PANEL_GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	_open_stack.erase(self)


func _process(delta: float) -> void:
	var open: bool = _host.is_visible_in_tree()
	if open != _was_open:
		_was_open = open
		if open:
			_open_stack.erase(self)
			_open_stack.append(self)
			_scan_timer = 0.0
		else:
			_open_stack.erase(self)
			_release_focus_inside()
	if not open or not _is_top():
		return

	_scan_timer -= delta
	var focus: Control = get_viewport().gui_get_focus_owner()
	var focus_ok: bool = focus != null and _host.is_ancestor_of(focus) and focus.is_visible_in_tree() \
		and focus.focus_mode != Control.FOCUS_NONE and not (focus is BaseButton and (focus as BaseButton).disabled)
	if _scan_timer > 0.0 and focus_ok:
		return
	_scan_timer = SCAN_INTERVAL
	var focusables: Array[Control] = []
	_sync(_host, focusables)
	if not focus_ok and not focusables.is_empty():
		var start: Control = focusables[0]
		for c: Control in focusables:
			if c.has_meta(META_DEFAULT):
				start = c
				break
		start.grab_focus()


func _input(event: InputEvent) -> void:
	if not _was_open or not _is_top() or event is InputEventMouse:
		return
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		if cancel_callable.is_valid():
			get_viewport().set_input_as_handled()
			cancel_callable.call()
		return
	if event.is_action_pressed(&"ui_accept") and not event.is_echo():
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus is Range and _host.is_ancestor_of(focus):
			var target: BaseButton = _find_default_button(_host)
			if target != null and not target.disabled:
				get_viewport().set_input_as_handled()
				target.pressed.emit()


func _is_top() -> bool:
	_prune()
	return not _open_stack.is_empty() and _open_stack.back() == self


## Makes enabled controls focusable (with an outline) and collects them in tree order.
func _sync(node: Node, out: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is KeyboardModal:
			continue
		var c: Control = child as Control
		if c != null:
			if not c.visible:
				continue
			if _is_interactive(c) and not c.has_meta(META_NO_FOCUS):
				var usable: bool = not (c is BaseButton and (c as BaseButton).disabled)
				c.focus_mode = Control.FOCUS_ALL if usable else Control.FOCUS_NONE
				if usable:
					_style_focus(c)
					out.append(c)
		_sync(child, out)


func _is_interactive(c: Control) -> bool:
	return c is BaseButton or c is Slider or c is SpinBox


func _style_focus(c: Control) -> void:
	if c.has_meta(&"_kb_styled"):
		return
	c.set_meta(&"_kb_styled", true)
	if c is TextureButton:
		var tb: TextureButton = c as TextureButton
		if tb.texture_focused == null and tb.texture_hover != null:
			tb.texture_focused = tb.texture_hover
		return
	if not c.has_theme_stylebox_override(&"focus"):
		c.add_theme_stylebox_override(&"focus", _get_focus_style())


static func _get_focus_style() -> StyleBoxFlat:
	if _focus_style == null:
		_focus_style = StyleBoxFlat.new()
		_focus_style.draw_center = false
		_focus_style.border_color = FOCUS_COLOR
		_focus_style.set_border_width_all(2)
		_focus_style.set_corner_radius_all(3)
		_focus_style.set_expand_margin_all(2.0)
	return _focus_style


func _find_default_button(node: Node) -> BaseButton:
	for child: Node in node.get_children():
		if child is BaseButton and child.has_meta(META_DEFAULT) and (child as Control).is_visible_in_tree():
			return child as BaseButton
		var found: BaseButton = _find_default_button(child)
		if found != null:
			return found
	return null


func _release_focus_inside() -> void:
	if not is_inside_tree():
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null and is_instance_valid(_host) and _host.is_ancestor_of(focus):
		focus.release_focus()
