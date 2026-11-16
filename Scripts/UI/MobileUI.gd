# res://Scripts/UI/MobileUI.gd
class_name MobileUI
extends RefCounted
## The ONE switch for every touch-screen layout in the game, plus the helpers they share.
## Full list of mobile tweaks: _documentation/MOBILE_UI.md.
##
## Who asks:
##   * MobileHUD (exploration HUD: portraits bottom-left, toolbar bottom-centre, D-pad)
##   * CharacterSheetMobile (character sheet split into MAIN / INVENTORY / SKILLS tabs)
## New mobile layouts should ask MobileUI.is_wanted() too, never OS.has_feature() directly.
##
## How it gets switched on:
##   * automatically on phones / tablets and touch browsers,
##   * world.tscn > MapManager > "Mobile Preview" (editor runs only; also reshapes the window),
##   * debug menu (`) > DISPLAY > Mobile UI,
##   * Project Settings > shards/hud/force_mobile_hud.

const FORCE_SETTING: String = "shards/hud/force_mobile_hud"
## Shape of the preview window (19.5:9, a modern phone held sideways). Only the proportions matter.
const DEFAULT_PREVIEW_SIZE: Vector2i = Vector2i(1404, 648)
## Largest notch / rounded-corner inset we honour, in canvas units.
const MAX_SAFE_INSET: float = 80.0

const _META_FONT_BASE: StringName = &"_mobile_font_base"
const _META_FONT_OVERRIDDEN: StringName = &"_mobile_font_overridden"

enum Override { AUTO, OFF, ON }

## AUTO = decide from the device. ON / OFF = forced (phone preview, debug menu).
static var override_mode: Override = Override.AUTO
## True once the desktop window has been reshaped like a phone (see start_phone_preview).
static var preview_active: bool = false


## True when the game should use its touch layouts.
static func is_wanted() -> bool:
	if override_mode == Override.ON:
		return true
	if override_mode == Override.OFF:
		return false
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		return true
	return bool(ProjectSettings.get_setting(FORCE_SETTING, false))


## Forces the touch layouts on or off for this run (debug menu).
static func set_override(on: bool) -> void:
	override_mode = Override.ON if on else Override.OFF


## Desktop "view it as a phone": forces the touch layouts on and reshapes the game window to
## `shape` (keeps the window's height, changes its width). Called by MapManager when
## "Mobile Preview" is ticked on world.tscn. Editor runs only.
static func start_phone_preview(window: Window, shape: Vector2i = DEFAULT_PREVIEW_SIZE) -> void:
	override_mode = Override.ON
	if preview_active or window == null or shape.x <= 0 or shape.y <= 0:
		return
	preview_active = true
	if Engine.is_embedded_in_editor():
		# The editor's Game tab owns the window size; resizing it from the game leaves an empty
		# (red) strip. Letterbox a phone-shaped canvas inside the window instead.
		letterbox(window, shape)
		return
	if window.mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED
	var new_size: Vector2i = Vector2i(roundi(window.size.y * float(shape.x) / float(shape.y)), window.size.y)
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
	if usable.size.x > 0 and new_size.x > usable.size.x:
		# Wider than the monitor: shrink it, keeping the phone shape.
		var fit: float = float(usable.size.x) / float(new_size.x)
		new_size = Vector2i(usable.size.x, roundi(new_size.y * fit))
	window.size = new_size
	if usable.size.x > 0:
		window.position = usable.position + (usable.size - new_size) / 2


## Shows a phone-shaped canvas inside the current window (black bars fill the rest), without
## resizing the window. Used when the game runs embedded in the editor.
static func letterbox(window: Window, shape: Vector2i) -> void:
	var base_height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_size = Vector2i(roundi(base_height * float(shape.x) / float(shape.y)), base_height)


## Space to keep clear of the notch / rounded corners, in canvas units:
## { "left", "top", "right", "bottom" }. All zero on desktop (and in the phone preview).
static func safe_insets(control: Control) -> Dictionary:
	var insets: Dictionary = { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 }
	if not OS.has_feature("mobile") or not is_instance_valid(control) or not control.is_inside_tree():
		return insets
	var screen: Vector2 = Vector2(DisplayServer.screen_get_size())
	var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	var view: Vector2 = control.get_viewport_rect().size
	if screen.x <= 0.0 or screen.y <= 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return insets
	var to_canvas: Vector2 = view / screen
	insets["left"] = clampf(safe.position.x * to_canvas.x, 0.0, MAX_SAFE_INSET)
	insets["top"] = clampf(safe.position.y * to_canvas.y, 0.0, MAX_SAFE_INSET)
	insets["right"] = clampf((screen.x - safe.end.x) * to_canvas.x, 0.0, MAX_SAFE_INSET)
	insets["bottom"] = clampf((screen.y - safe.end.y) * to_canvas.y, 0.0, MAX_SAFE_INSET)
	return insets


## Multiplies the font size of every Label / Button under `root` (and `root` itself) by `factor`.
## Safe to call again (always scales from the original size). Undo with restore_fonts().
static func scale_fonts(root: Node, factor: float) -> void:
	if not is_instance_valid(root):
		return
	scale_font(root as Control, factor)
	for child: Node in root.get_children():
		scale_fonts(child, factor)


## Same as scale_fonts() for one control only.
static func scale_font(control: Control, factor: float) -> void:
	if not (control is Label or control is Button):
		return
	if not control.has_meta(_META_FONT_BASE):
		control.set_meta(_META_FONT_OVERRIDDEN, control.has_theme_font_size_override(&"font_size"))
		control.set_meta(_META_FONT_BASE, control.get_theme_font_size(&"font_size"))
	var base: int = int(control.get_meta(_META_FONT_BASE))
	control.add_theme_font_size_override(&"font_size", maxi(1, roundi(base * factor)))


## Puts back the font sizes changed by scale_fonts() / scale_font().
static func restore_fonts(root: Node) -> void:
	if not is_instance_valid(root):
		return
	var control: Control = root as Control
	if control != null and control.has_meta(_META_FONT_BASE):
		if bool(control.get_meta(_META_FONT_OVERRIDDEN, false)):
			control.add_theme_font_size_override(&"font_size", int(control.get_meta(_META_FONT_BASE)))
		else:
			control.remove_theme_font_size_override(&"font_size")
		control.remove_meta(_META_FONT_BASE)
		control.remove_meta(_META_FONT_OVERRIDDEN)
	for child: Node in root.get_children():
		restore_fonts(child)
