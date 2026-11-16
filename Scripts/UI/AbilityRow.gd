# res://Scripts/UI/AbilityRow.gd
class_name AbilityRow
extends Button
## One skill / spell in a list. The SAME row is used everywhere abilities are listed, so they all
## look and line up alike: character sheet, ALL SKILLS / ALL SPELLS popup, battle HUD ability
## popup, ability learn screen and the character creator.
##
##   +------+
##   | icon |  TITLE, TRIMMED WITH AN ELLIPSIS...       ( 5 )   <- mana cost (space kept even at 0)
##   +------+  details line, trimmed with an ellipsis...
##
## Every row has the same height and fixed-size icon / badge, so columns line up down the list.
## Full name + description are in the tooltip, since both lines can be cut short.
##
## Usage:
##   var row := AbilityRow.create(spell, {"context": AbilityRow.Context.HUD, "toggle": true})
##   row.pressed.connect(...)
##   row.set_unavailable("Not enough mana (3 / 5)", true)
##
## Options for create():
##   context      Context.MENU (solid, default) or Context.HUD (slightly see-through, for battle)
##   accent       title / border colour (default: the sheet's teal)
##   background   row colour, to match the menu it sits in (default: the character sheet panel)
##   details      text for the second line (default: the ability's description)
##   title_color  override the title colour
##   toggle       true = the row stays highlighted when pressed (selection lists)
##   button_group ButtonGroup for single-selection lists
##   compact      true = shorter row (dense pickers)

enum Context { MENU, HUD }

const ROW_HEIGHT: float = 58.0
const ROW_HEIGHT_COMPACT: float = 48.0
const ICON_SIZE: float = 44.0
const ICON_SIZE_COMPACT: float = 36.0
const BADGE_SIZE: float = 26.0
const TITLE_SIZE: int = 14
const DETAIL_SIZE: int = 12
const COST_SIZE: int = 13

## Colours already used by the game's menus.
const COLOR_TEAL: Color = Color(0.0, 1.0, 0.784)        # character sheet / battle HUD accent
const COLOR_MANA: Color = Color(0.8, 0.2, 1.0)          # "MANA" on the character sheet
const COLOR_PANEL: Color = Color(0.031, 0.063, 0.078)   # character sheet panel background
const COLOR_DETAIL: Color = Color(0.72, 0.78, 0.8)
const COLOR_WARN: Color = Color(1.0, 0.42, 0.38)        # ShardsMenuStyle.COLOR_DANGER
## Background opacity per context: battle popups let the fight show through a little.
const HUD_ALPHA: float = 0.72
const MENU_ALPHA: float = 0.95

const DETAIL_FONT: FontFile = preload("res://ui/fonts/RedditMono-Regular.ttf")

static var _icon_cache: Dictionary = {}

var ability: Resource = null
var accent: Color = COLOR_TEAL
var context: Context = Context.MENU
var background: Color = COLOR_PANEL
var compact: bool = false

var _icon_frame: PanelContainer = null
var _icon_rect: TextureRect = null
var _title: Label = null
var _details: Label = null
var _badge: PanelContainer = null
var _cost_label: Label = null
var _badge_alpha: float = 1.0


static func create(ability_res: Resource, options: Dictionary = {}) -> AbilityRow:
	var row := AbilityRow.new()
	row.ability = ability_res
	row.accent = options.get("accent", COLOR_TEAL)
	row.context = options.get("context", Context.MENU)
	row.background = options.get("background", COLOR_PANEL)
	row.compact = bool(options.get("compact", false))
	row.toggle_mode = bool(options.get("toggle", false))
	if options.get("button_group") is ButtonGroup:
		row.button_group = options["button_group"]
	row._build()
	row.set_details(str(options.get("details", description_of(ability_res))))
	if options.get("title_color") is Color:
		row._title.add_theme_color_override("font_color", options["title_color"])
	return row


## Shows `reason` on the second line in the warning colour and dims the rest of the row.
## block = true also disables the button (e.g. not enough mana in battle).
func set_unavailable(reason: String, block: bool = false) -> void:
	set_details(reason, COLOR_WARN)
	_icon_frame.modulate.a = 0.4
	_title.modulate.a = 0.5
	_badge.modulate.a = _badge_alpha * 0.4
	disabled = block


func set_details(text_value: String, color: Color = COLOR_DETAIL) -> void:
	_details.text = text_value
	_details.add_theme_color_override("font_color", color)


func set_selected(on: bool) -> void:
	set_pressed_no_signal(on)


## Makes the whole row bigger: height, icon, text and cost badge (1.0 = normal size).
## Used by the touch layouts so rows are easy to read and hit with a finger.
func set_ui_scale(factor: float) -> void:
	custom_minimum_size.y = (ROW_HEIGHT_COMPACT if compact else ROW_HEIGHT) * factor
	var icon_size: float = (ICON_SIZE_COMPACT if compact else ICON_SIZE) * factor
	_icon_frame.custom_minimum_size = Vector2(icon_size, icon_size)
	var badge_size: float = BADGE_SIZE * factor
	_badge.custom_minimum_size = Vector2(badge_size, badge_size)
	_badge.add_theme_stylebox_override("panel", _box(COLOR_MANA, COLOR_MANA, 0, int(badge_size / 2.0), 4))
	_title.add_theme_font_size_override("font_size", roundi(TITLE_SIZE * factor))
	_details.add_theme_font_size_override("font_size", roundi(DETAIL_SIZE * factor))
	_cost_label.add_theme_font_size_override("font_size", roundi(COST_SIZE * factor))


# ==============================================================================
# Lookups (also handy for other UI)
# ==============================================================================
## The ability's icon: its `icon` texture if set, else loaded from `icon_path` (cached).
static func icon_for(a: Resource) -> Texture2D:
	if a == null:
		return null
	var tex: Variant = a.get("icon") if "icon" in a else null
	if tex is Texture2D:
		return tex
	var path: String = str(a.get("icon_path")) if "icon_path" in a else ""
	if path.is_empty():
		return null
	if not _icon_cache.has(path):
		_icon_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icon_cache[path]


## Mana cost (energy_cost on SpellData / SkillData).
static func cost_of(a: Resource) -> int:
	if a == null:
		return 0
	for key: String in ["energy_cost", "mana_cost", "mp_cost"]:
		if key in a:
			return int(a.get(key))
	return 0


static func description_of(a: Resource) -> String:
	if a == null or not ("description" in a):
		return ""
	return str(a.get("description")).strip_edges().replace("\n", " ")


# ==============================================================================
# Build
# ==============================================================================
func _build() -> void:
	var row_height: float = ROW_HEIGHT_COMPACT if compact else ROW_HEIGHT
	var icon_size: float = ICON_SIZE_COMPACT if compact else ICON_SIZE
	text = ""
	custom_minimum_size = Vector2(0.0, row_height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	_apply_styles()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	# 1. Icon in a fixed square frame (keeps aspect, centred, smooth when scaled down).
	_icon_frame = PanelContainer.new()
	_icon_frame.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_frame.add_theme_stylebox_override("panel", _box(Color.BLACK, Color(accent, 0.35), 1, 3, 1))
	hbox.add_child(_icon_frame)
	var tex: Texture2D = icon_for(ability)
	if tex != null:
		_icon_rect = TextureRect.new()
		_icon_rect.texture = tex
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_frame.add_child(_icon_rect)
	else:
		var placeholder := Label.new()
		placeholder.text = "?"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.add_theme_color_override("font_color", Color(accent, 0.35))
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_frame.add_child(placeholder)

	# 2 + 3. Title and details, each one line, trimmed with an ellipsis.
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_theme_constant_override("separation", 1)
	hbox.add_child(text_box)
	_title = _one_line_label(ShardsMenuStyle.TITLE_FONT, TITLE_SIZE, accent)
	_title.text = AbilityInfo.display_name(ability).to_upper()
	text_box.add_child(_title)
	_details = _one_line_label(DETAIL_FONT, DETAIL_SIZE, COLOR_DETAIL)
	text_box.add_child(_details)

	# 4. Mana cost badge. Always takes its space so titles line up; hidden when the cost is 0.
	var cost: int = cost_of(ability)
	_badge = PanelContainer.new()
	_badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_theme_stylebox_override("panel", _box(COLOR_MANA, COLOR_MANA, 0, int(BADGE_SIZE / 2.0), 4))
	hbox.add_child(_badge)
	var cost_label := Label.new()
	cost_label.text = str(cost)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.add_theme_font_override("font", ShardsMenuStyle.BODY_FONT)
	cost_label.add_theme_font_size_override("font_size", COST_SIZE)
	cost_label.add_theme_color_override("font_color", Color.WHITE)
	_badge.add_child(cost_label)
	_cost_label = cost_label
	_badge_alpha = 1.0 if cost > 0 else 0.0
	_badge.modulate.a = _badge_alpha

	var desc: String = description_of(ability)
	tooltip_text = AbilityInfo.display_name(ability) + ("\n" + desc if not desc.is_empty() else "") \
		+ ("\nCost: %d mana" % cost if cost > 0 else "")


func _one_line_label(font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _apply_styles() -> void:
	# Opaque backgrounds take the context's opacity; see-through ones (a menu's own tint) keep theirs.
	# In the HUD nothing is more solid than HUD_ALPHA, so the fight still shows through.
	var alpha: float = (HUD_ALPHA if context == Context.HUD else MENU_ALPHA) if background.a >= 0.999 else background.a
	if context == Context.HUD:
		alpha = minf(alpha, HUD_ALPHA)
	var base: Color = Color(background, alpha)
	var hover: Color = Color(base.lightened(0.06), base.a)
	var selected: Color = Color(accent.darkened(0.78), maxf(base.a, 0.85))
	add_theme_stylebox_override("normal", _box(base, Color(accent, 0.25)))
	add_theme_stylebox_override("hover", _box(hover, Color(accent, 0.75)))
	add_theme_stylebox_override("pressed", _box(selected, accent, 2))
	add_theme_stylebox_override("hover_pressed", _box(Color(selected.lightened(0.05), selected.a), accent, 2))
	add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color(accent, 0.9), 1))
	add_theme_stylebox_override("disabled", _box(Color(base, base.a * 0.7), Color(accent, 0.1)))


static func _box(bg: Color, border: Color, border_width: int = 1, radius: int = 3, padding: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	return box
