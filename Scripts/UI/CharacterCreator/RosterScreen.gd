# res://Scripts/UI/CharacterCreator/RosterScreen.gd
class_name RosterScreen
extends Control
## Every character the player has made (CharacterRoster), over the space background.
##   * + NEW CHARACTER opens the CharacterCreator; EDIT re-opens it for an unlocked character; DELETE asks twice.
##   * Characters that have been taken into a game are locked (shown "LOCKED"): they can still join new
##     parties, but can't be edited or deleted.
##   * Mode.START (main menu > New Game): fill the front / back rows (up to 6) and START GAME.
##     Debug builds also get QUICK START, which uses the old test party (Data/default_save.tres).
##   * Mode.MANAGE (main menu > Party Builder): the same roster without the party / start controls.

signal closed

enum Mode { START, MANAGE }

const ROW_SIZE: int = 3

var mode: Mode = Mode.START
var free_on_close: bool = true

var _cats: Array[CatCharacter] = []
var _selected: CatCharacter = null
var _party: Array[String] = ["", "", "", "", "", ""] # roster ids per slot (0-2 front, 3-5 back)
var _delete_armed: bool = false
var _creator: CharacterCreator = null

var _space: SpaceBackground
var _window: PanelContainer
var _count_label: Label
var _grid: GridContainer
var _detail_portrait: TextureRect
var _detail_fur: TextureRect
var _detail_name: Label
var _detail_sub: Label
var _detail_body: Label
var _add_button: Button
var _row_button: Button
var _edit_button: Button
var _delete_button: Button
var _slot_buttons: Array[Button] = []
var _start_button: Button
var _hint: Label
var _new_button: Button


static func open_on(parent: Node, screen_mode: Mode) -> RosterScreen:
	var screen := RosterScreen.new()
	screen.mode = screen_mode
	parent.add_child(screen)
	return screen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	CreationUI.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_reload()
	_window.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(_window, "modulate:a", 1.0, 0.3)
	if _cats.is_empty():
		_new_button.grab_focus.call_deferred()


func open() -> void:
	show()


func close() -> void:
	CreationUI.play("button-press")
	hide()
	closed.emit()
	if free_on_close:
		queue_free()


func _input(event: InputEvent) -> void:
	if not visible or is_instance_valid(_creator) or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close()


# ==============================================================================
# Data
# ==============================================================================
func _reload(select_id: String = "") -> void:
	_cats = CharacterRoster.list()
	# Drop party slots whose character was deleted.
	for i: int in _party.size():
		if not _party[i].is_empty() and _find(_party[i]) == null:
			_party[i] = ""
	var keep: String = select_id if not select_id.is_empty() else (_selected.roster_id if _selected != null else "")
	_selected = _find(keep)
	if _selected == null and not _cats.is_empty():
		_selected = _cats[0]
	_rebuild_cards()
	_refresh()


func _find(roster_id: String) -> CatCharacter:
	if roster_id.is_empty():
		return null
	for c: CatCharacter in _cats:
		if c.roster_id == roster_id:
			return c
	return null


func _party_slot_of(cat: CatCharacter) -> int:
	return _party.find(cat.roster_id) if cat != null else -1


func _party_count() -> int:
	var n: int = 0
	for id: String in _party:
		if not id.is_empty():
			n += 1
	return n


# ==============================================================================
# Build
# ==============================================================================
func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_space = SpaceBackground.new()
	_space.preset = SpaceBackground.Preset.MAIN_MENU
	_space.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_space)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	_window = PanelContainer.new()
	_window.add_theme_stylebox_override("panel", CreationUI.glass_panel(CreationUI.DIM_GREY))
	margin.add_child(_window)
	_window.resized.connect(func() -> void: _space.focus_on(_window, 0.45, 0.06))

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	_window.add_child(root)
	_count_label = CreationUI.title("", 15, Color(CreationUI.WHITE, 0.55))
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var head: Array = CreationUI.header("ASSEMBLE YOUR PARTY" if mode == Mode.START else "YOUR ROSTER", _count_label)
	_count_label.offset_left = -250
	_count_label.offset_bottom = 32
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(head[0] as Control)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	root.add_child(body)

	# Roster cards
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	left.add_child(CreationUI.title("CHARACTERS", 15, Color(CreationUI.WHITE, 0.55)))
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fs: StyleBoxFlat = CreationUI.flat(Color(0, 0, 0, 0.3), CreationUI.GREY, 2, 4)
	fs.set_content_margin_all(8)
	frame.add_theme_stylebox_override("panel", fs)
	left.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)

	# Details (+ party rows)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	right.add_child(top)
	var pframe := PanelContainer.new()
	var ps: StyleBoxFlat = CreationUI.flat(Color(0, 0, 0, 0.6), CreationUI.WHITE, 2, 4)
	ps.set_content_margin_all(3)
	pframe.add_theme_stylebox_override("panel", ps)
	pframe.custom_minimum_size = Vector2(120, 120)
	pframe.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(pframe)
	_detail_fur = _texture_rect()
	_detail_fur.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_detail_fur.modulate = Color(1, 1, 1, 0.55)
	pframe.add_child(_detail_fur)
	_detail_portrait = _texture_rect()
	pframe.add_child(_detail_portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	_detail_name = CreationUI.title("", 24)
	info.add_child(_detail_name)
	_detail_sub = CreationUI.title("", 13, CreationUI.PINK)
	info.add_child(_detail_sub)
	_detail_body = CreationUI.wrap(CreationUI.body("", 12))
	info.add_child(_detail_body)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	right.add_child(actions)
	_add_button = CreationUI.small_button("ADD TO PARTY", CreationUI.GREEN)
	_add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_button.pressed.connect(_on_add_pressed)
	_row_button = CreationUI.small_button("BACK ROW", CreationUI.YELLOW)
	_row_button.pressed.connect(_on_row_pressed)
	_edit_button = CreationUI.small_button("EDIT", CreationUI.YELLOW)
	_edit_button.pressed.connect(_on_edit_pressed)
	_delete_button = CreationUI.small_button("DELETE", CreationUI.RED)
	_delete_button.pressed.connect(_on_delete_pressed)
	if mode == Mode.START:
		actions.add_child(_add_button)
		actions.add_child(_row_button)
	actions.add_child(_edit_button)
	actions.add_child(_delete_button)
	if mode == Mode.MANAGE:
		_edit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if mode == Mode.START:
		for row: int in 2:
			right.add_child(CreationUI.title("FRONT ROW" if row == 0 else "BACK ROW", 13, Color(CreationUI.WHITE, 0.55)))
			var slots := HBoxContainer.new()
			slots.add_theme_constant_override("separation", 6)
			right.add_child(slots)
			for i: int in ROW_SIZE:
				var idx: int = row * ROW_SIZE + i
				var b: Button = CreationUI.list_button("", CreationUI.GREEN, 13)
				b.toggle_mode = false
				b.alignment = HORIZONTAL_ALIGNMENT_CENTER
				b.custom_minimum_size = Vector2(0, 40)
				b.clip_text = true
				b.pressed.connect(_on_slot_pressed.bind(idx))
				slots.add_child(b)
				_slot_buttons.append(b)
	else:
		var note: Label = CreationUI.wrap(CreationUI.body("Characters can be edited until they go on an adventure. Start a party from NEW GAME on the title screen.", 12, Color(CreationUI.WHITE, 0.5)))
		right.add_child(note)

	# Footer
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	root.add_child(footer)
	var fl := HBoxContainer.new()
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(fl)
	var back: Button = CreationUI.action_button("BACK", CreationUI.RED)
	back.pressed.connect(close)
	fl.add_child(back)
	if mode == Mode.START:
		_start_button = CreationUI.action_button("START GAME", CreationUI.GREEN, true, 20)
		_start_button.custom_minimum_size = Vector2(250, 48)
		_start_button.pressed.connect(_on_start_pressed)
		footer.add_child(_start_button)
	var fr := HBoxContainer.new()
	fr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fr.alignment = BoxContainer.ALIGNMENT_END
	footer.add_child(fr)
	_hint = CreationUI.body("", 12, Color(CreationUI.WHITE, 0.6))
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint.clip_text = true
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fr.add_child(_hint)
	if mode == Mode.START and OS.is_debug_build():
		var quick: Button = CreationUI.small_button("QUICK START (TEST PARTY)", CreationUI.GREY)
		quick.tooltip_text = "Debug builds only: start with the test party from Data/default_save.tres"
		quick.pressed.connect(_on_quick_start_pressed)
		fr.add_child(quick)


func _texture_rect() -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t


func _rebuild_cards() -> void:
	for c: Node in _grid.get_children():
		c.queue_free()
	_new_button = _make_card(null)
	_grid.add_child(_new_button)
	for cat: CatCharacter in _cats:
		_grid.add_child(_make_card(cat))


func _make_card(cat: CatCharacter) -> Button:
	var b: Button = CreationUI.list_button("", CreationUI.WHITE, 15)
	b.toggle_mode = false
	b.custom_minimum_size = Vector2(0, 88)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.offset_top = 6
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	if cat == null:
		var plus: Label = CreationUI.title("+   NEW CHARACTER", 18, CreationUI.GREEN)
		plus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.size_flags_vertical = Control.SIZE_FILL
		row.add_child(plus)
		b.pressed.connect(_open_creator.bind(null))
		return b
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(74, 74)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var fur: TextureRect = _texture_rect()
	fur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fur.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fur.modulate = Color(1, 1, 1, 0.5)
	fur.texture = CharacterCreation.fur_texture(cat.breed as CatBreed)
	pic.add_child(fur)
	var portrait: TextureRect = _texture_rect()
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	CreationUI.set_portrait(portrait, CharacterCreation.portrait_texture(cat.profession as ProfessionData))
	if portrait.stretch_mode == TextureRect.STRETCH_KEEP_CENTERED:
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.add_child(portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(CreationUI.title(cat.name.to_upper(), 17))
	col.add_child(CreationUI.title("%s · %s" % [AbilityRules.race_name_of(cat).to_upper(), AbilityRules.class_name_of(cat).to_upper()], 11, CreationUI.PINK))
	var tag := CreationUI.body("", 11)
	col.add_child(tag)
	b.set_meta(&"tag", tag)
	b.set_meta(&"roster_id", cat.roster_id)
	b.pressed.connect(_select.bind(cat))
	b.focus_entered.connect(_select.bind(cat, false))
	return b


# ==============================================================================
# Refresh
# ==============================================================================
func _refresh() -> void:
	_count_label.text = "%d CHARACTER%s" % [_cats.size(), "" if _cats.size() == 1 else "S"]
	for b: Node in _grid.get_children():
		if not (b is Button) or not b.has_meta(&"roster_id"):
			continue
		var id: String = str(b.get_meta(&"roster_id"))
		var cat: CatCharacter = _find(id)
		var tag: Label = b.get_meta(&"tag") as Label
		var slot: int = _party.find(id)
		var bits: PackedStringArray = ["LV %d" % cat.level, "HP %d" % cat.max_hp]
		if slot >= 0:
			bits.append("FRONT ROW" if slot < ROW_SIZE else "BACK ROW")
		if cat.roster_locked:
			bits.append("LOCKED")
		tag.text = "  ·  ".join(bits)
		tag.add_theme_color_override("font_color", CreationUI.GREEN if slot >= 0 else (CreationUI.YELLOW if cat.roster_locked else Color(CreationUI.WHITE, 0.6)))
		var selected: bool = _selected != null and _selected.roster_id == id
		var border: Color = CreationUI.GREEN if slot >= 0 else (CreationUI.WHITE if selected else CreationUI.DIM_GREY)
		(b as Button).add_theme_stylebox_override("normal", CreationUI.flat(Color(1, 1, 1, 0.08) if selected else Color(0, 0, 0, 0.35), border, 2 if selected or slot >= 0 else 1))

	var has: bool = _selected != null
	_detail_name.text = _selected.name.to_upper() if has else ("NO CHARACTERS YET" if _cats.is_empty() else "")
	_detail_sub.text = "%s · %s · LEVEL %d" % [AbilityRules.race_name_of(_selected).to_upper(), AbilityRules.class_name_of(_selected).to_upper(), _selected.level] if has else ""
	_detail_fur.texture = CharacterCreation.fur_texture(_selected.breed as CatBreed) if has else null
	if has:
		CreationUI.set_portrait(_detail_portrait, CharacterCreation.portrait_texture(_selected.profession as ProfessionData))
	else:
		_detail_portrait.texture = CreationUI.CREST
	_detail_body.text = _detail_text(_selected) if has else "Create a character to begin. Each one rolls their own bonus dice."

	_add_button.disabled = not has
	_row_button.disabled = not has or _party_slot_of(_selected) < 0
	if has:
		var slot: int = _party_slot_of(_selected)
		_add_button.text = "REMOVE" if slot >= 0 else "ADD TO PARTY"
		_add_button.disabled = slot < 0 and _party_count() >= CharacterRoster.PARTY_SIZE
		_row_button.text = "TO BACK ROW" if slot >= 0 and slot < ROW_SIZE else "TO FRONT ROW"
	var locked: bool = has and _selected.roster_locked
	_edit_button.disabled = not has or locked
	_delete_button.disabled = not has or locked
	_edit_button.tooltip_text = "Locked - this character has been on an adventure." if locked else ""
	_delete_button.text = "SURE?" if _delete_armed else "DELETE"

	for i: int in _slot_buttons.size():
		var cat: CatCharacter = _find(_party[i])
		_slot_buttons[i].text = cat.name.to_upper() if cat != null else "·  EMPTY  ·"
		_slot_buttons[i].add_theme_color_override("font_color", CreationUI.GREEN if cat != null else CreationUI.DIM_GREY)
		_slot_buttons[i].tooltip_text = "Click to remove" if cat != null else ""
	if _start_button != null:
		_start_button.disabled = _party_count() == 0
		if _cats.is_empty():
			_hint.text = "Create your first character."
		elif _party_count() == 0:
			_hint.text = "Add up to 6 characters to your party."
		else:
			_hint.text = "%d / 6 in the party" % _party_count()
	else:
		_hint.text = ""


func _detail_text(cat: CatCharacter) -> String:
	var parts: PackedStringArray = []
	for stat: String in CharacterCreation.STATS:
		parts.append("%s %d" % [CharacterCreation.STAT_SHORT[stat], int(cat.get(stat))])
	var abilities: PackedStringArray = []
	for s: Resource in cat.known_spells:
		abilities.append(AbilityInfo.display_name(s))
	for s: Resource in cat.known_skills:
		abilities.append(AbilityInfo.display_name(s))
	var text: String = "  ".join(parts.slice(0, 4)) + "\n" + "  ".join(parts.slice(4))
	text += "\nHP %d   MP %d" % [cat.max_hp, cat.max_energy]
	text += "\n" + (", ".join(abilities) if not abilities.is_empty() else "No abilities")
	if cat.roster_locked:
		text += "\nLOCKED - has been on an adventure."
	return text


# ==============================================================================
# Actions
# ==============================================================================
func _select(cat: CatCharacter, sound: bool = true) -> void:
	if _selected == cat:
		return
	_selected = cat
	_delete_armed = false
	if sound:
		CreationUI.play("button-hover")
	_refresh()


func _on_add_pressed() -> void:
	if _selected == null:
		return
	var slot: int = _party_slot_of(_selected)
	if slot >= 0:
		_party[slot] = ""
	else:
		# Front row first (fighters), then the back row.
		var free: int = _party.find("")
		if free < 0:
			return
		_party[free] = _selected.roster_id
	CreationUI.play("button-confirm")
	_refresh()


func _on_row_pressed() -> void:
	var slot: int = _party_slot_of(_selected)
	if slot < 0:
		return
	var target_row: int = 1 if slot < ROW_SIZE else 0
	for i: int in ROW_SIZE:
		var idx: int = target_row * ROW_SIZE + i
		if _party[idx].is_empty():
			_party[idx] = _party[slot]
			_party[slot] = ""
			CreationUI.play("button-confirm")
			_refresh()
			return
	# Row full: swap with its first member.
	var other: int = target_row * ROW_SIZE
	var tmp: String = _party[other]
	_party[other] = _party[slot]
	_party[slot] = tmp
	CreationUI.play("button-confirm")
	_refresh()


func _on_slot_pressed(idx: int) -> void:
	if _party[idx].is_empty():
		# Put the selected character here (moving it if it's already in the party).
		if _selected == null:
			return
		var current: int = _party_slot_of(_selected)
		if current >= 0:
			_party[current] = ""
		_party[idx] = _selected.roster_id
	else:
		_select(_find(_party[idx]), false)
		_party[idx] = ""
	CreationUI.play("button-press")
	_refresh()


func _on_edit_pressed() -> void:
	if _selected == null or _selected.roster_locked:
		return
	_open_creator(_selected)


func _on_delete_pressed() -> void:
	if _selected == null or _selected.roster_locked:
		return
	if not _delete_armed:
		_delete_armed = true
		CreationUI.play("button-press")
		_refresh()
		return
	_delete_armed = false
	var gone: String = _selected.name
	if CharacterRoster.remove(_selected):
		_selected = null
		if is_instance_valid(SignalBus):
			SignalBus.show_toast.emit("%s left the roster." % gone, false)
	_reload()


func _open_creator(cat: CatCharacter) -> void:
	_creator = CharacterCreator.new()
	_creator.show_background = false
	_creator.editing = CharacterRoster.load_character(cat.roster_id) if cat != null else null
	_window.hide()
	add_child(_creator)
	_creator.character_saved.connect(_on_character_saved)
	_creator.closed.connect(_on_creator_closed)


func _on_character_saved(cat: CatCharacter) -> void:
	# New characters go straight into the party when there's room.
	if mode == Mode.START and _party.find(cat.roster_id) < 0 and _party.find("") >= 0:
		_party[_party.find("")] = cat.roster_id
	_reload(cat.roster_id)


func _on_creator_closed() -> void:
	_creator = null
	_window.show()
	_reload()
	_focus_selected_card()


func _focus_selected_card() -> void:
	for b: Node in _grid.get_children():
		if b is Button and _selected != null and str(b.get_meta(&"roster_id", "")) == _selected.roster_id:
			(b as Button).grab_focus.call_deferred()
			return
	if is_instance_valid(_new_button):
		_new_button.grab_focus.call_deferred()


func _on_start_pressed() -> void:
	if _party_count() == 0:
		return
	CreationUI.play("button-confirm")
	SessionFlow.start_new_game_with_roster(get_tree(), _party.duplicate())


func _on_quick_start_pressed() -> void:
	CreationUI.play("button-confirm")
	SessionFlow.start_new_game(get_tree())
