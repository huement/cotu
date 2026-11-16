# res://Scripts/UI/CharacterSheetMobile.gd
class_name CharacterSheetMobile
extends Node
## Touch-screen layout for the character sheet. Created by CharacterSheetMenu and switched on
## whenever MobileUI.is_wanted() (checked each time the sheet opens). The desktop sheet shows
## everything at once; on a phone that is too crowded, so the SAME panels are moved into tabs:
##
##   MAIN            left: player info + load out + status      right: stats / fight (+ spend points)
##   INVENTORY       left: player info + load out               right: filter + inventory (5 big slots wide)
##   SKILLS/SPELLS   left: skill / spell list                   right: caster vitals + details & casting
##   bottom bar      CLOSE | character picker | the three tab buttons
##
## Nothing is duplicated: the desktop panels (stats, load out, inventory, skills, header, status)
## are re-parented into the tab layout and put back when the layout is switched off, so
## CharacterSheetMenu keeps filling them exactly as on desktop. Only the bottom bar and the
## SKILLS tab's right side (caster vitals, ability details, target picker, cast button) are new.
##
## Mockups: Mobile_FIX/ (mobile_1..3, screen_1..3.txt). Everything mobile: _documentation/MOBILE_UI.md.
## Preview on desktop: world.tscn > MapManager > Mobile Preview, or debug menu (`) > Mobile UI.

enum Tab { MAIN, INVENTORY, SKILLS }

const TAB_TITLES: Array[String] = ["MAIN", "INVENTORY", "SKILLS/SPELLS"]
const FILTER_TITLES: Array[String] = ["ALL", "GEAR", "CONSUMABLES"]
const STATUS_HINT: String = "(tap an icon for effect info)"
const NO_ABILITY_TEXT: String = "TAP A SKILL OR SPELL"

const TEAL: Color = Color(0.0, 1.0, 0.784)
const ORANGE: Color = Color(0.99, 0.5, 0.2)
const HEALTH: Color = Color(1.0, 0.2, 0.4)
const MANA: Color = Color(0.8, 0.2, 1.0)
const TEXT: Color = Color(0.86, 0.94, 0.95)
const MUTED: Color = Color(0.55, 0.62, 0.66)
const PANEL_BG: Color = Color(0.031, 0.063, 0.078, 0.88)

## Screen edge padding (the notch / rounded-corner inset is added on top).
const SIDE_MARGIN: float = 16.0
const TOP_MARGIN: float = 10.0
## Keeps the bottom bar off the screen edge, where phones catch swipe-home gestures.
const BOTTOM_MARGIN: float = 14.0
const BAR_HEIGHT: float = 50.0
## Share of the width for the left side (the rest goes to the right panel).
const LEFT_SHARE: float = 0.44
const SKILLS_SHARE: float = 0.58

## Text is enlarged per panel: each one has a different amount of room on a phone.
const FONT_SCALE_INFO: float = 1.2
const FONT_SCALE_LOADOUT: float = 1.3
const FONT_SCALE_STATS: float = 1.7
const FONT_SCALE_SKILL_TABS: float = 1.3
const LOADOUT_SLOT_HEIGHT: float = 52.0

var enabled: bool = false
var current_tab: Tab = Tab.MAIN

var _menu: CharacterSheetMenu
var _built: bool = false
var _character: CatCharacter = null

# Desktop pieces that get moved (looked up once in _build).
var _desktop_root: Control
var _header: Control
var _vitals: Control
var _battle_row: Control
var _status_effects: Control

# Tab layout.
var _root: MarginContainer
var _left_pane: VBoxContainer
var _skills_pane: PanelContainer
var _right_pane: PanelContainer
var _stats_page: VBoxContainer
var _inventory_page: VBoxContainer
var _cast_page: VBoxContainer
var _status_box: PanelContainer
var _status_row: HBoxContainer
var _status_hint: Label
var _allocate_button: Button
var _close_button: Button
var _picker: OptionButton
var _tab_buttons: Array[Button] = []
var _filter_buttons: Array[Button] = []

# SKILLS tab, right side.
var _caster_name: Label
var _caster_breed: Label
var _mana_value: Label
var _mana_bar: ProgressBar
var _health_value: Label
var _health_bar: ProgressBar
var _ability_title: Label
var _ability_desc: Label
var _target_title: Label
var _target_grid: GridContainer
var _cast_button: Button
var _selected_ability: Resource = null
var _selected_target: CatCharacter = null

## Where each moved panel lives on desktop: { node, parent, index }.
var _homes: Array[Dictionary] = []
## Properties changed for the touch layout: { node, prop, value } (value = the desktop value).
var _saved_props: Array[Dictionary] = []


func setup(menu: CharacterSheetMenu) -> void:
	_menu = menu


## Called by CharacterSheetMenu right before the sheet is shown or re-rendered.
## fresh_open = the sheet was closed (so it starts on the MAIN tab again).
func sync(fresh_open: bool) -> void:
	set_enabled(MobileUI.is_wanted())
	if enabled and fresh_open:
		show_tab(Tab.MAIN)


func set_enabled(on: bool) -> void:
	if on == enabled or not is_instance_valid(_menu) or not is_instance_valid(_menu.overlay_panel):
		return
	enabled = on
	if on:
		_build()
		_move_panels_in()
		_apply_touch_sizes()
		_desktop_root.hide()
		_root.show()
		show_tab(current_tab)
	else:
		_restore_desktop_sizes()
		_move_panels_out()
		_selected_ability = null
		_battle_row.show()
		_root.hide()
		_desktop_root.show()


func show_tab(tab: Tab) -> void:
	current_tab = tab
	if not enabled:
		return
	var skills: bool = tab == Tab.SKILLS
	_left_pane.visible = not skills
	_skills_pane.visible = skills
	_stats_page.visible = tab == Tab.MAIN
	_inventory_page.visible = tab == Tab.INVENTORY
	_cast_page.visible = skills
	# Attack type / row toggle and status effects are MAIN-only: INVENTORY keeps "mini vitals".
	_status_box.visible = tab == Tab.MAIN
	_battle_row.visible = tab == Tab.MAIN
	_right_pane.size_flags_stretch_ratio = (1.0 - SKILLS_SHARE) if skills else (1.0 - LEFT_SHARE)
	for i: int in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == int(tab))


## Called by CharacterSheetMenu after it has filled the panels for `character`.
func refresh(character: CatCharacter) -> void:
	if character != _character:
		_selected_target = character # a newly shown caster starts as their own target
	_character = character
	if not enabled or not is_instance_valid(character):
		return
	# The "downed" banner is placed for the desktop layout; the red INCAPACITATED breed line
	# and the downed portrait already say it here.
	var downed_alert: Control = _menu.get_node_or_null(^"%DownedAlertTexture") as Control
	if downed_alert != null:
		downed_alert.visible = false
	_refresh_picker()
	_refresh_allocate_button()
	_refresh_status_hint()
	_refresh_caster_vitals()
	_refresh_targets()
	_refresh_cast_panel()


# ==============================================================================
# Build (once)
# ==============================================================================
func _build() -> void:
	if _built:
		return
	_built = true
	_desktop_root = _menu.overlay_panel.get_node(^"MarginContainer") as Control
	var left_column: Node = _desktop_root.get_node(^"MainHBox/LeftColumn")
	_header = left_column.get_node(^"HeaderHbox") as Control
	_vitals = left_column.get_node(^"MarginContainer") as Control
	_battle_row = _vitals.get_node(^"VitalsVBox/Row2_BattleStatus") as Control
	_status_effects = _menu.get_node(^"%CurrentStatusEffects") as Control

	_root = MarginContainer.new()
	_root.name = "MobileSheet"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets: Dictionary = MobileUI.safe_insets(_menu.overlay_panel)
	_root.add_theme_constant_override("margin_left", int(SIDE_MARGIN + float(insets["left"])))
	_root.add_theme_constant_override("margin_right", int(SIDE_MARGIN + float(insets["right"])))
	_root.add_theme_constant_override("margin_top", int(TOP_MARGIN + float(insets["top"])))
	_root.add_theme_constant_override("margin_bottom", int(BOTTOM_MARGIN + float(insets["bottom"])))
	# Right above the desktop layout, so the downed banner and the CRT overlay stay on top.
	_menu.overlay_panel.add_child(_root)
	_menu.overlay_panel.move_child(_root, _desktop_root.get_index() + 1)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_root.add_child(column)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	_build_left_pane(body)
	_build_skills_pane(body)
	_build_right_pane(body)
	_build_bottom_bar(column)

	_menu.skills_spells_panel.ability_selected.connect(_on_ability_selected)
	_status_effects.child_entered_tree.connect(_on_status_child_added)


func _build_left_pane(body: HBoxContainer) -> void:
	_left_pane = VBoxContainer.new()
	_left_pane.name = "LeftPane"
	_left_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_pane.size_flags_stretch_ratio = LEFT_SHARE
	_left_pane.add_theme_constant_override("separation", 8)
	body.add_child(_left_pane)

	# Status effects: one compact row. Tooltips don't exist on touch, so tapping a badge
	# writes its name + description into the hint label.
	_status_box = PanelContainer.new()
	_status_box.name = "StatusBox"
	_status_box.add_theme_stylebox_override("panel", _box(PANEL_BG, Color(TEAL, 0.3), 1, 4, 8.0))
	_left_pane.add_child(_status_box)
	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 10)
	_status_box.add_child(_status_row)
	_status_row.add_child(_label("STATUS:", 17, TEAL))
	_status_hint = _label(STATUS_HINT, 13, MUTED, AbilityRow.DETAIL_FONT)
	_status_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_hint.max_lines_visible = 2
	_status_row.add_child(_status_hint)


func _build_skills_pane(body: HBoxContainer) -> void:
	_skills_pane = PanelContainer.new()
	_skills_pane.name = "SkillsPane"
	_skills_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills_pane.size_flags_stretch_ratio = SKILLS_SHARE
	_skills_pane.add_theme_stylebox_override("panel", _box(PANEL_BG, Color(TEAL, 0.45), 1, 6, 10.0))
	body.add_child(_skills_pane)


func _build_right_pane(body: HBoxContainer) -> void:
	_right_pane = PanelContainer.new()
	_right_pane.name = "RightPane"
	_right_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_pane.size_flags_stretch_ratio = 1.0 - LEFT_SHARE
	_right_pane.add_theme_stylebox_override("panel", _box(PANEL_BG, Color(TEAL, 0.45), 1, 6, 10.0))
	body.add_child(_right_pane)

	# MAIN: stats (moved in) + the spend-points button.
	_stats_page = VBoxContainer.new()
	_stats_page.name = "StatsPage"
	_stats_page.add_theme_constant_override("separation", 8)
	_right_pane.add_child(_stats_page)
	_allocate_button = _button("+ ALLOCATE POINTS", Color(1.0, 0.85, 0.25), 20)
	_allocate_button.custom_minimum_size = Vector2(0.0, 54.0)
	_allocate_button.pressed.connect(func() -> void: _menu._on_spend_points_pressed())
	_stats_page.add_child(_allocate_button)

	# INVENTORY: filter row + the inventory grid (moved in).
	_inventory_page = VBoxContainer.new()
	_inventory_page.name = "InventoryPage"
	_inventory_page.add_theme_constant_override("separation", 8)
	_right_pane.add_child(_inventory_page)
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	_inventory_page.add_child(filter_row)
	filter_row.add_child(_label("FILTER:", 16, TEXT))
	var filter_group := ButtonGroup.new()
	for i: int in FILTER_TITLES.size():
		var filter_button: Button = _button(FILTER_TITLES[i], TEAL, 16, true)
		filter_button.button_group = filter_group
		filter_button.custom_minimum_size = Vector2(0.0, 42.0)
		filter_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		filter_button.set_pressed_no_signal(i == 0)
		filter_button.pressed.connect(_on_filter_pressed.bind(i))
		filter_row.add_child(filter_button)
		_filter_buttons.append(filter_button)

	_build_cast_page()


## SKILLS tab, right side: who is casting, what is selected, who it goes on, and the cast button.
func _build_cast_page() -> void:
	_cast_page = VBoxContainer.new()
	_cast_page.name = "CastPage"
	_cast_page.add_theme_constant_override("separation", 10)
	_right_pane.add_child(_cast_page)

	var vitals := HBoxContainer.new()
	vitals.add_theme_constant_override("separation", 14)
	_cast_page.add_child(vitals)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 0)
	vitals.add_child(who)
	_caster_name = _label("", 24, ORANGE, ShardsMenuStyle.TITLE_FONT)
	who.add_child(_caster_name)
	_caster_breed = _label("", 14, ORANGE)
	who.add_child(_caster_breed)
	var bars := VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.add_theme_constant_override("separation", 2)
	vitals.add_child(bars)
	var mana: Array = _vital_row(bars, "MANA", MANA)
	_mana_value = mana[0] as Label
	_mana_bar = mana[1] as ProgressBar
	var health: Array = _vital_row(bars, "HEALTH", HEALTH)
	_health_value = health[0] as Label
	_health_bar = health[1] as ProgressBar

	var details := PanelContainer.new()
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_theme_stylebox_override("panel", _box(Color(0.09, 0.06, 0.03, 0.75), Color(ORANGE, 0.7), 1, 6, 10.0))
	_cast_page.add_child(details)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	details.add_child(box)
	var heading: Label = _label("ABILITY DETAILS", 14, MUTED)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	_ability_title = _label(NO_ABILITY_TEXT, 18, TEAL, ShardsMenuStyle.TITLE_FONT)
	_ability_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_ability_title)
	_ability_desc = _label("", 15, TEXT, AbilityRow.DETAIL_FONT)
	_ability_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ability_desc.max_lines_visible = 5
	box.add_child(_ability_desc)
	_target_title = _label("SELECT TARGET:", 15, TEXT)
	box.add_child(_target_title)
	_target_grid = GridContainer.new()
	_target_grid.columns = 2
	_target_grid.add_theme_constant_override("h_separation", 8)
	_target_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_target_grid)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	_cast_button = _button("[ CAST ]", ORANGE, 18)
	_cast_button.custom_minimum_size = Vector2(0.0, 54.0)
	_cast_button.pressed.connect(_on_cast_pressed)
	box.add_child(_cast_button)


## "LABEL          12 / 34" over a thin bar. Returns [value label, bar].
func _vital_row(parent: VBoxContainer, title: String, color: Color) -> Array:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.add_child(_label(title, 15, color))
	var value: Label = _label("0 / 0", 15, color)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 5.0)
	bar.add_theme_stylebox_override("background", _box(Color(0.0, 0.0, 0.0, 0.5), Color(color, 0.3), 0, 2, 0.0))
	bar.add_theme_stylebox_override("fill", _box(color, color, 0, 2, 0.0))
	parent.add_child(bar)
	return [value, bar]


func _build_bottom_bar(column: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.name = "BottomBar"
	bar.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	bar.add_theme_constant_override("separation", 10)
	column.add_child(bar)

	_close_button = _button("[ CLOSE ]", TEAL, 19)
	_close_button.custom_minimum_size = Vector2(128.0, BAR_HEIGHT)
	_close_button.pressed.connect(func() -> void: _menu._on_close_button_pressed())
	KeyboardModal.set_default(_close_button)
	bar.add_child(_close_button)

	# Character picker: replaces the small < 1 | 6 > arrows of the desktop sheet.
	_picker = OptionButton.new()
	_picker.custom_minimum_size = Vector2(300.0, BAR_HEIGHT)
	_picker.fit_to_longest_item = false
	_picker.clip_text = true
	_picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_style_button(_picker, TEAL, 17)
	var picker_menu: PopupMenu = _picker.get_popup()
	picker_menu.add_theme_font_override("font", ShardsMenuStyle.BODY_FONT)
	picker_menu.add_theme_font_size_override("font_size", 20)
	picker_menu.add_theme_constant_override("v_separation", 16)
	_picker.item_selected.connect(_on_picker_selected)
	bar.add_child(_picker)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(gap)

	var tab_group := ButtonGroup.new()
	for i: int in TAB_TITLES.size():
		var tab_button: Button = _button(TAB_TITLES[i], TEAL, 18, true)
		tab_button.button_group = tab_group
		tab_button.custom_minimum_size = Vector2(150.0, BAR_HEIGHT)
		tab_button.pressed.connect(_on_tab_pressed.bind(i))
		bar.add_child(tab_button)
		_tab_buttons.append(tab_button)


# ==============================================================================
# Moving the desktop panels in / out
# ==============================================================================
func _move_panels_in() -> void:
	_homes.clear()
	var moves: Array[Array] = [
		[_header, _left_pane, 0],
		[_vitals, _left_pane, 1],
		[_menu.loadout_panel, _left_pane, 2],
		[_status_effects, _status_row, 1],
		[_menu.stats_panel, _stats_page, 0],
		[_menu.skills_spells_panel, _skills_pane, 0],
		[_menu.inventory_grid, _inventory_page, 1],
	]
	# Remember every home first (moving one shifts the others' indices).
	for move: Array in moves:
		var node: Node = move[0] as Node
		_homes.append({ "node": node, "parent": node.get_parent(), "index": node.get_index() })
	for move: Array in moves:
		var node: Node = move[0] as Node
		var target: Node = move[1] as Node
		node.reparent(target, false)
		target.move_child(node, mini(int(move[2]), target.get_child_count() - 1))


func _move_panels_out() -> void:
	_homes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["index"]) < int(b["index"]))
	for home: Dictionary in _homes:
		var node: Node = home["node"] as Node
		var parent: Node = home["parent"] as Node
		if is_instance_valid(node) and is_instance_valid(parent):
			node.reparent(parent, false)
			parent.move_child(node, mini(int(home["index"]), parent.get_child_count() - 1))
	_homes.clear()


## Bigger text and touch targets for the moved panels. Every change is recorded in _saved_props
## (or done through MobileUI.scale_fonts) so _restore_desktop_sizes() can undo it.
func _apply_touch_sizes() -> void:
	MobileUI.scale_fonts(_header, FONT_SCALE_INFO)
	MobileUI.scale_fonts(_vitals, FONT_SCALE_INFO)
	MobileUI.scale_fonts(_menu.loadout_panel, FONT_SCALE_LOADOUT)
	MobileUI.scale_fonts(_menu.stats_panel, FONT_SCALE_STATS)
	MobileUI.scale_font(_menu.skills_spells_panel.skills_button, FONT_SCALE_SKILL_TABS)
	MobileUI.scale_font(_menu.skills_spells_panel.spells_button, FONT_SCALE_SKILL_TABS)

	# Stats fill the right panel instead of sitting centred at their desktop size.
	_set_prop(_menu.stats_panel, &"size_flags_horizontal", Control.SIZE_EXPAND_FILL)
	_set_prop(_menu.stats_panel, &"size_flags_vertical", Control.SIZE_EXPAND_FILL)

	# Load out: taller slots for fingers.
	for slot: Node in _menu.loadout_panel.find_children("Slot*", "Button", true, false):
		var slot_button: Button = slot as Button
		_set_prop(slot_button, &"custom_minimum_size", Vector2(slot_button.custom_minimum_size.x, LOADOUT_SLOT_HEIGHT))

	# Status: the tall sideways "STATUS" art is replaced by the label in the status box.
	_set_prop(_status_effects, &"custom_minimum_size", Vector2(0.0, 42.0))
	_set_prop(_status_effects, &"size_flags_horizontal", Control.SIZE_SHRINK_BEGIN)
	var status_art: Control = _status_effects.get_node_or_null(^"StatusHeaderTexture") as Control
	if status_art != null:
		_set_prop(status_art, &"visible", false)

	# The bottom ornament sits under the bottom bar.
	var ornament: Control = _menu.overlay_panel.get_node_or_null(^"PolyBtm") as Control
	if ornament != null:
		_set_prop(ornament, &"visible", false)

	_menu.inventory_grid.set_touch_layout(true)
	_menu.skills_spells_panel.set_touch_layout(true)


func _restore_desktop_sizes() -> void:
	_menu.skills_spells_panel.set_touch_layout(false)
	_menu.inventory_grid.set_touch_layout(false)
	for i: int in range(_saved_props.size() - 1, -1, -1):
		var saved: Dictionary = _saved_props[i]
		var node: Object = saved["node"] as Object
		if is_instance_valid(node):
			node.set(saved["prop"] as StringName, saved["value"])
	_saved_props.clear()
	for panel: Node in [_header, _vitals, _menu.loadout_panel, _menu.stats_panel, _menu.skills_spells_panel]:
		MobileUI.restore_fonts(panel)


## Sets a property for the touch layout and remembers the desktop value.
func _set_prop(node: Object, prop: StringName, value: Variant) -> void:
	_saved_props.append({ "node": node, "prop": prop, "value": node.get(prop) })
	node.set(prop, value)


# ==============================================================================
# Refresh
# ==============================================================================
func _refresh_picker() -> void:
	_picker.clear()
	if GameState.current_party == null:
		return
	var slots: Array = GameState.current_party.slots
	for i: int in slots.size():
		var cat: CatCharacter = slots[i] as CatCharacter
		if not is_instance_valid(cat):
			continue
		var job: String = "UNASSIGNED"
		if is_instance_valid(cat.profession) and not cat.profession.profession_name.is_empty():
			job = cat.profession.profession_name.to_upper()
		_picker.add_item("%d. %s — LVL %d %s" % [i + 1, cat.name.to_upper(), cat.level, job], i)
		if cat == _character:
			_picker.select(_picker.item_count - 1)


func _refresh_allocate_button() -> void:
	var has_points: bool = _character.has_method("has_unspent_points") and _character.has_unspent_points()
	_allocate_button.visible = has_points
	if has_points:
		_allocate_button.text = "+ ALLOCATE POINTS  (STAT %d / SKILL %d / SPELL %d)" % [
			_character.unspent_stat_points,
			_character.unspent_skill_points,
			_character.unspent_spell_points,
		]


func _refresh_status_hint() -> void:
	var shown: int = 0
	for child: Node in _status_effects.get_children():
		if child is StatusEffectBadge and not child.is_queued_for_deletion():
			shown += 1
	_status_hint.text = STATUS_HINT if shown > 0 else "NONE"


func _refresh_caster_vitals() -> void:
	_caster_name.text = _character.name.to_upper()
	_caster_breed.text = _character.breed.breed_name.to_upper() if _character.breed else ""
	_mana_value.text = "%d / %d" % [_character.current_energy, _character.max_energy]
	_mana_bar.max_value = maxi(1, _character.max_energy)
	_mana_bar.value = _character.current_energy
	_health_value.text = "%d / %d" % [_character.current_hp, _character.max_hp]
	_health_bar.max_value = maxi(1, _character.max_hp)
	_health_bar.value = _character.current_hp


## One button per party slot (1-6); empty slots are shown greyed out. Starts on the caster.
func _refresh_targets() -> void:
	for child: Node in _target_grid.get_children():
		child.queue_free()
	var slots: Array = GameState.current_party.slots if GameState.current_party != null else []
	if not is_instance_valid(_selected_target) or not slots.has(_selected_target):
		_selected_target = _character
	var group := ButtonGroup.new()
	for i: int in 6:
		var cat: CatCharacter = slots[i] as CatCharacter if i < slots.size() else null
		var target_button: Button = _button("%d. EMPTY" % (i + 1), ORANGE, 15, true)
		target_button.custom_minimum_size = Vector2(0.0, 44.0)
		target_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		target_button.clip_text = true
		if is_instance_valid(cat):
			target_button.text = "%d. %s (%d/%d)" % [i + 1, cat.name.to_upper(), cat.current_hp, cat.max_hp]
			target_button.button_group = group
			target_button.set_pressed_no_signal(cat == _selected_target)
			target_button.pressed.connect(_on_target_pressed.bind(cat))
		else:
			target_button.disabled = true
		_target_grid.add_child(target_button)


## Shows the selected ability and works out whether (and on whom) it can be cast right now.
func _refresh_cast_panel() -> void:
	var ability: Resource = _selected_ability
	var has_ability: bool = is_instance_valid(ability)
	_ability_desc.visible = has_ability
	_cast_button.visible = has_ability
	if not has_ability:
		_ability_title.text = NO_ABILITY_TEXT
		_target_title.visible = false
		_target_grid.visible = false
		return

	var cost: int = AbilityRow.cost_of(ability)
	var title: String = AbilityInfo.display_name(ability).to_upper()
	_ability_title.text = "%s  (COST: %d MP)" % [title, cost] if cost > 0 else title
	_ability_desc.text = AbilityRow.description_of(ability)

	# Combat-only / restricted abilities have nobody to pick; out of mana still shows the targets.
	var blocker: String = _menu.skills_spells_panel.field_use_blocker(ability, _character)
	var needs_target: bool = SkillSpellDetailPopup.needs_target(ability)
	_target_title.visible = blocker.is_empty() and needs_target
	_target_grid.visible = blocker.is_empty() and needs_target

	if blocker.is_empty() and _character.current_hp <= 0:
		blocker = "INCAPACITATED"
	if blocker.is_empty() and _character.current_energy < cost:
		blocker = "NOT ENOUGH MANA (%d / %d)" % [_character.current_energy, cost]
	if not blocker.is_empty():
		_cast_button.text = "[ %s ]" % blocker
		_cast_button.disabled = true
	elif not needs_target:
		_cast_button.text = "[ USE ]"
		_cast_button.disabled = false
	else:
		var has_target: bool = is_instance_valid(_selected_target)
		_cast_button.text = "[ CAST ON %s ]" % _selected_target.name.to_upper() if has_target else "[ SELECT A TARGET ]"
		_cast_button.disabled = not has_target


# ==============================================================================
# Input
# ==============================================================================
func _on_tab_pressed(index: int) -> void:
	_play("button-press")
	show_tab(index as Tab)


func _on_filter_pressed(index: int) -> void:
	_play("button-press")
	_menu.inventory_grid.set_filter(index as CharacterInventoryGrid.Filter)


func _on_picker_selected(item_index: int) -> void:
	_menu.show_slot(_picker.get_item_id(item_index))


func _on_ability_selected(ability: Resource) -> void:
	_selected_ability = ability
	if enabled and is_instance_valid(_character):
		_refresh_cast_panel()


func _on_target_pressed(cat: CatCharacter) -> void:
	_play("button-press")
	_selected_target = cat
	_refresh_cast_panel()


## Casts through the same code as the desktop detail popup (it listens for ABILITY_INFO);
## "cast_now" skips its two pages because the target was already picked here.
func _on_cast_pressed() -> void:
	if not is_instance_valid(_selected_ability) or not is_instance_valid(_character):
		return
	SignalBus.popup_requested.emit(&"ABILITY_INFO", {
		"resource": _selected_ability,
		"character": _character,
		"target": _selected_target,
		"cast_now": true,
	})
	_menu.refresh()


func _on_status_child_added(child: Node) -> void:
	var badge: StatusEffectBadge = child as StatusEffectBadge
	if badge == null:
		return
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	# Badges enter the tree again whenever their container is moved between the layouts.
	var on_input: Callable = _on_badge_input.bind(badge)
	if not badge.gui_input.is_connected(on_input):
		badge.gui_input.connect(on_input)


func _on_badge_input(event: InputEvent, badge: StatusEffectBadge) -> void:
	if not enabled:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_status_hint.text = badge.tooltip_text.replace("\n", " - ")


# ==============================================================================
# Small UI helpers
# ==============================================================================
func _play(sound: String) -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound(sound)


func _label(text: String, font_size: int, color: Color, font: Font = ShardsMenuStyle.BODY_FONT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, accent: Color, font_size: int, toggle: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = toggle
	_style_button(button, accent, font_size)
	return button


## Dark tile with an accent border; pressed / selected = filled with the accent colour.
func _style_button(button: Button, accent: Color, font_size: int) -> void:
	button.add_theme_font_override("font", ShardsMenuStyle.BODY_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("normal", _box(PANEL_BG, Color(accent, 0.35), 1, 4, 6.0))
	button.add_theme_stylebox_override("hover", _box(PANEL_BG.lightened(0.06), Color(accent, 0.8), 1, 4, 6.0))
	button.add_theme_stylebox_override("pressed", _box(Color(accent.darkened(0.7), 0.95), accent, 2, 4, 6.0))
	button.add_theme_stylebox_override("hover_pressed", _box(Color(accent.darkened(0.65), 0.95), accent, 2, 4, 6.0))
	button.add_theme_stylebox_override("disabled", _box(Color(PANEL_BG, 0.4), Color(accent, 0.12), 1, 4, 6.0))
	button.add_theme_color_override("font_color", Color(0.75, 0.82, 0.85))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.6))


func _box(bg: Color, border: Color, border_width: int, radius: int, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style
