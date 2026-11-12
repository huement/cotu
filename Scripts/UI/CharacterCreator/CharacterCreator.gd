# res://Scripts/UI/CharacterCreator/CharacterCreator.gd
class_name CharacterCreator
extends Control
## Two-step character creator over the space background:
##   1  RACE & CLASS — race list | fur ⬢ class portrait | class list, INFO popups. Classes the race
##                      can't reach even with a best birth die (+6 on primary) are greyed out.
##   2  ABILITIES & NAME — starter spell/skill picks, name, summary. CREATE rolls one irrevocable
##                      1d6 (DiceRollPopup), auto-applies primary-stat bonus (+ ability bank on 5/6),
##                      then CharacterRoster.save(). Editing a rolled character skips the birth roll.
## Rules live in CharacterCreation (pure, tested); this file is only the screens.
##
##   var creator := CharacterCreator.new()
##   creator.editing = roster_cat          # optional: edit an unlocked roster character
##   add_child(creator); creator.character_saved.connect(...); creator.closed.connect(...)

signal closed
signal character_saved(cat: CatCharacter)

const STEP_TITLES: Array[String] = ["CHOOSE RACE & CLASS", "ABILITIES & NAME"]
const RANDOM_NAMES: Array[String] = [
	"Whiskers", "Mittens", "Nyx", "Pounce", "Tigris", "Saber", "Lynx", "Mochi", "Ember", "Sable",
	"Onyx", "Kit", "Rook", "Vesper", "Juno", "Bastet", "Felix", "Talon", "Cinder", "Pixel",
	"Socks", "Marrow", "Quill", "Rune", "Shadowpaw", "Clawdia", "Purrcival", "Meowra",
]

## The roster character being edited (null = make a new one).
var editing: CatCharacter = null
## Draw our own space background (off when a screen that already has one hosts us).
var show_background: bool = true
var free_on_close: bool = true

var _step: int = 0
var _breed: CatBreed = null
var _prof: ProfessionData = null
var _dice: Array[int] = []
var _alloc: Dictionary = {}
var _ability_points: int = 0
var _picks_for: Array = [null, null] # [breed, prof] the picks were made for
var _spells: Array[SpellData] = []
var _skills: Array[SkillData] = []
var _char_name: String = ""
var _rolling: bool = false
var _info: Control = null

var _space: SpaceBackground
var _window: PanelContainer
var _steps: HBoxContainer
var _step_title: Label
var _pages: Array[Control] = []
var _back_button: Button
var _confirm_button: Button
var _hint: Label

# step 1
var _race_buttons: Dictionary = {} # Button -> CatBreed
var _class_buttons: Dictionary = {} # Button -> ProfessionData
var _race_group := ButtonGroup.new()
var _class_group := ButtonGroup.new()
var _fur_rect: TextureRect
var _portrait_rect: TextureRect
var _race_name: Label
var _class_name: Label
var _fit_label: Label
var _req_grid: GridContainer

# step 2
var _spell_header: Label
var _spell_list: VBoxContainer
var _skill_header: Label
var _skill_list: VBoxContainer
var _race_skill_label: Label
var _ability_detail: Label
var _pick_buttons: Dictionary = {} # Button -> Resource
var _name_edit: LineEdit
var _confirm_fur: TextureRect
var _confirm_portrait: TextureRect
var _summary_title: Label
var _summary_sub: Label
var _summary_stats: Label
var _summary_abilities: Label
var _summary_birth: Label
var _problems: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	CreationUI.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if editing != null:
		_load_draft(CharacterCreation.draft_from_character(editing))
	_build()
	_select_initial()
	_go_to_step(0, false)
	_window.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_interval(0.3 if show_background else 0.05)
	tw.tween_property(_window, "modulate:a", 1.0, 0.3)


func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if is_instance_valid(_info):
		_close_info()
	elif not _rolling:
		_on_back_pressed()


func close() -> void:
	CreationUI.play("button-press")
	hide()
	closed.emit()
	if free_on_close:
		queue_free()


# ==============================================================================
# State
# ==============================================================================
func _load_draft(d: Dictionary) -> void:
	_breed = d.get("breed") as CatBreed
	_prof = d.get("profession") as ProfessionData
	_dice.assign(d.get("bonus_dice", []) as Array)
	_alloc = (d.get("allocation", {}) as Dictionary).duplicate()
	_ability_points = int(d.get("ability_points", 0))
	_picks_for = [_breed, _prof]
	_spells.clear()
	for s: Variant in d.get("spells", []):
		if s is SpellData:
			_spells.append(s)
	_skills.clear()
	for s: Variant in d.get("skills", []):
		if s is SkillData:
			_skills.append(s)
	_char_name = str(d.get("name", ""))


func _draft() -> Dictionary:
	return {
		"name": _char_name,
		"breed": _breed,
		"profession": _prof,
		"bonus_dice": _dice.duplicate(),
		"bonus_pool": CharacterCreation.sum_dice(_dice),
		"allocation": _alloc.duplicate(),
		"ability_points": _ability_points,
		"spells": _spells.duplicate(),
		"skills": _skills.duplicate(),
	}


func _preview_stats() -> Dictionary:
	if not _alloc.is_empty():
		return CharacterCreation.apply_allocation(_breed, _alloc)
	# Before birth roll: show race base (primary will bump on CREATE).
	return CharacterCreation.base_stats(_breed)


## Race / class changed: reset default picks (keep name).
func _sync_to_selection() -> void:
	if _picks_for[0] == _breed and _picks_for[1] == _prof:
		return
	_spells = CharacterCreation.default_spell_picks(_breed, _prof)
	_skills = CharacterCreation.default_skill_picks(_breed, _prof)
	# New selection invalidates a previous birth roll (editing keeps dice until race/class change).
	if editing == null or _picks_for[0] != null:
		_dice.clear()
		_alloc.clear()
		_ability_points = 0
	_picks_for = [_breed, _prof]


# ==============================================================================
# Build
# ==============================================================================
func _build() -> void:
	if show_background:
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

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	_window.add_child(root)

	_steps = CreationUI.step_indicator(2)
	var head: Array = CreationUI.header(STEP_TITLES[0], _steps)
	root.add_child(head[0] as Control)
	_step_title = head[1] as Label

	var pages := MarginContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pages)
	_pages = [_build_step_race_class(), _build_step_abilities_name()]
	for p: Control in _pages:
		pages.add_child(p)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	root.add_child(footer)
	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(left)
	_back_button = CreationUI.action_button("BACK", CreationUI.RED)
	_back_button.pressed.connect(_on_back_pressed)
	left.add_child(_back_button)
	_confirm_button = CreationUI.action_button("CONFIRM", CreationUI.GREEN, true, 20)
	_confirm_button.custom_minimum_size = Vector2(230, 48)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	footer.add_child(_confirm_button)
	_hint = CreationUI.body("", 13, Color(CreationUI.WHITE, 0.6))
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(_hint)


func _build_step_race_class() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 22)

	var race_col: VBoxContainer = _list_column("RACE", 210)
	var race_list: VBoxContainer = race_col.get_meta(&"list") as VBoxContainer
	for breed: CatBreed in CharacterCreation.all_races():
		var b: Button = CreationUI.list_button(breed.breed_name.to_upper(), CreationUI.WHITE)
		b.button_group = _race_group
		b.toggled.connect(func(on: bool) -> void:
			if on:
				_select_race(breed))
		b.focus_entered.connect(func() -> void: b.button_pressed = true)
		_race_buttons[b] = breed
		race_list.add_child(b)
	var race_info: Button = CreationUI.small_button("?  INFO", CreationUI.YELLOW)
	race_info.pressed.connect(_show_race_info)
	race_col.add_child(race_info)
	page.add_child(race_col)

	var centre := VBoxContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_theme_constant_override("separation", 10)
	page.add_child(centre)

	var images := HBoxContainer.new()
	images.alignment = BoxContainer.ALIGNMENT_CENTER
	images.add_theme_constant_override("separation", 0)
	centre.add_child(images)
	var race_box: Array = CreationUI.image_box(230.0, CreationUI.WHITE)
	_fur_rect = race_box[1] as TextureRect
	_fur_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	images.add_child(race_box[0] as Control)
	var link := CreationUI.HexLink.new()
	link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	images.add_child(link)
	var class_box: Array = CreationUI.image_box(230.0, CreationUI.PINK)
	_portrait_rect = class_box[1] as TextureRect
	images.add_child(class_box[0] as Control)

	var names := HBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(names)
	_race_name = CreationUI.title("", 34, CreationUI.WHITE)
	_race_name.custom_minimum_size = Vector2(230, 0)
	_race_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.add_child(_race_name)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(70, 0)
	names.add_child(gap)
	_class_name = CreationUI.title("", 34, CreationUI.PINK)
	_class_name.custom_minimum_size = Vector2(230, 0)
	_class_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.add_child(_class_name)

	_req_grid = GridContainer.new()
	_req_grid.columns = CharacterCreation.STATS.size() + 1
	_req_grid.add_theme_constant_override("h_separation", 14)
	_req_grid.add_theme_constant_override("v_separation", 2)
	var req_center := CenterContainer.new()
	req_center.add_child(_req_grid)
	centre.add_child(req_center)

	_fit_label = CreationUI.body("", 15)
	_fit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CreationUI.wrap(_fit_label)
	centre.add_child(_fit_label)

	var class_col: VBoxContainer = _list_column("CLASS", 250)
	var class_list: VBoxContainer = class_col.get_meta(&"list") as VBoxContainer
	for prof: ProfessionData in CharacterCreation.all_classes():
		var b: Button = CreationUI.list_button(prof.profession_name.to_upper(), CreationUI.PINK)
		b.button_group = _class_group
		var diff := Label.new()
		diff.text = str(ClassProgression.for_class(prof.profession_name).get("difficulty_label", "")).to_upper()
		diff.add_theme_font_override("font", ShardsMenuStyle.BODY_FONT)
		diff.add_theme_font_size_override("font_size", 11)
		diff.add_theme_color_override("font_color", Color(CreationUI.WHITE, 0.45))
		diff.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		diff.offset_left = -80
		diff.offset_right = -10
		diff.offset_top = -9
		diff.offset_bottom = 9
		diff.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		diff.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(diff)
		b.set_meta(&"difficulty", diff)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				_select_class(prof))
		b.focus_entered.connect(func() -> void: b.button_pressed = true)
		_class_buttons[b] = prof
		class_list.add_child(b)
	var class_info: Button = CreationUI.small_button("?  INFO", CreationUI.YELLOW)
	class_info.pressed.connect(_show_class_info)
	class_col.add_child(class_info)
	page.add_child(class_col)
	return page


func _list_column(heading: String, width: float) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(width, 0)
	col.add_theme_constant_override("separation", 8)
	col.add_child(CreationUI.title(heading, 15, Color(CreationUI.WHITE, 0.55)))
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fs: StyleBoxFlat = CreationUI.flat(Color(0, 0, 0, 0.3), CreationUI.GREY, 2, 4)
	fs.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", fs)
	col.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	col.set_meta(&"list", list)
	return col


func _panel_column(heading: String, width: float) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(width, 0)
	col.add_theme_constant_override("separation", 10)
	col.add_child(CreationUI.title(heading, 15, Color(CreationUI.WHITE, 0.55)))
	return col


func _build_step_abilities_name() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 24)

	# Portrait + name
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	left.add_theme_constant_override("separation", 12)
	page.add_child(left)
	var frame := PanelContainer.new()
	var fs: StyleBoxFlat = CreationUI.flat(Color(0, 0, 0, 0.6), CreationUI.WHITE, 3, 4)
	fs.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", fs)
	frame.custom_minimum_size = Vector2(260, 260)
	left.add_child(frame)
	_confirm_fur = TextureRect.new()
	_confirm_fur.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_confirm_fur.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_confirm_fur.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_confirm_fur.modulate = Color(1, 1, 1, 0.55)
	frame.add_child(_confirm_fur)
	_confirm_portrait = TextureRect.new()
	_confirm_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_confirm_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_confirm_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_confirm_portrait)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	left.add_child(name_row)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "NAME"
	_name_edit.max_length = CharacterCreation.NAME_MAX_LENGTH
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.custom_minimum_size = Vector2(0, 42)
	_name_edit.add_theme_font_override("font", ShardsMenuStyle.TITLE_FONT)
	_name_edit.add_theme_font_size_override("font_size", 20)
	_name_edit.add_theme_stylebox_override("normal", CreationUI.flat(Color(0, 0, 0, 0.6), CreationUI.GREY, 2))
	_name_edit.add_theme_stylebox_override("focus", CreationUI.flat(Color(0, 0, 0, 0.6), CreationUI.GREEN, 2))
	_name_edit.text_changed.connect(func(t: String) -> void:
		_char_name = t
		_refresh())
	_name_edit.text_submitted.connect(func(_t: String) -> void: _on_confirm_pressed())
	name_row.add_child(_name_edit)
	var dice_name: Button = CreationUI.small_button("RANDOM", CreationUI.YELLOW)
	dice_name.custom_minimum_size = Vector2(96, 42)
	dice_name.pressed.connect(func() -> void:
		_char_name = RANDOM_NAMES[randi() % RANDOM_NAMES.size()]
		_name_edit.text = _char_name
		_refresh())
	name_row.add_child(dice_name)

	# Abilities
	var ab_col: VBoxContainer = _panel_column("STARTING ABILITIES", 300)
	ab_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(ab_col)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ab_col.add_child(scroll)
	var ab := VBoxContainer.new()
	ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ab.add_theme_constant_override("separation", 6)
	scroll.add_child(ab)
	_spell_header = CreationUI.body("", 13, CreationUI.YELLOW)
	ab.add_child(_spell_header)
	_spell_list = VBoxContainer.new()
	_spell_list.add_theme_constant_override("separation", 4)
	ab.add_child(_spell_list)
	_skill_header = CreationUI.body("", 13, CreationUI.YELLOW)
	ab.add_child(_skill_header)
	_skill_list = VBoxContainer.new()
	_skill_list.add_theme_constant_override("separation", 4)
	ab.add_child(_skill_list)
	_race_skill_label = CreationUI.wrap(CreationUI.body("", 13, CreationUI.GREEN))
	ab.add_child(_race_skill_label)
	_ability_detail = CreationUI.wrap(CreationUI.body("", 12, Color(CreationUI.WHITE, 0.65)))
	_ability_detail.custom_minimum_size = Vector2(0, 70)
	ab_col.add_child(_ability_detail)

	# Summary
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(340, 0)
	right.add_theme_constant_override("separation", 10)
	page.add_child(right)
	_summary_title = CreationUI.title("", 32)
	right.add_child(_summary_title)
	_summary_sub = CreationUI.title("", 16, CreationUI.PINK)
	right.add_child(_summary_sub)
	_summary_stats = CreationUI.body("", 14)
	right.add_child(_summary_stats)
	_summary_birth = CreationUI.wrap(CreationUI.body("", 13, CreationUI.YELLOW))
	right.add_child(_summary_birth)
	_summary_abilities = CreationUI.wrap(CreationUI.body("", 13, Color(CreationUI.WHITE, 0.8)))
	right.add_child(_summary_abilities)
	_problems = CreationUI.wrap(CreationUI.body("", 14, CreationUI.RED))
	right.add_child(_problems)
	return page


# ==============================================================================
# Step flow
# ==============================================================================
func _select_initial() -> void:
	var race_btn: Button = _race_buttons.keys()[0] as Button
	for b: Button in _race_buttons.keys():
		if _race_buttons[b] == _breed:
			race_btn = b
	race_btn.button_pressed = true
	_breed = _race_buttons[race_btn] as CatBreed
	var class_btn: Button = null
	for b: Button in _class_buttons.keys():
		if _class_buttons[b] == _prof:
			class_btn = b
	if class_btn == null:
		for b: Button in _class_buttons.keys():
			if CharacterCreation.is_class_reachable(_breed, _class_buttons[b] as ProfessionData):
				class_btn = b
				break
	class_btn.button_pressed = true
	_prof = _class_buttons[class_btn] as ProfessionData
	_refresh()


func _go_to_step(step: int, sound: bool = true) -> void:
	_step = step
	for i: int in _pages.size():
		_pages[i].visible = i == step
	CreationUI.set_step(_steps, step)
	_step_title.text = STEP_TITLES[step]
	_confirm_button.text = "●  CONFIRM" if step == 0 else ("●  SAVE CHANGES" if editing != null and not _dice.is_empty() else "●  CREATE")
	_back_button.text = "CANCEL" if step == 0 else "BACK"
	if sound:
		CreationUI.play("button-confirm")
	match step:
		0:
			_focus_selected(_race_buttons)
		1:
			_sync_to_selection()
			_rebuild_picks()
			if _char_name.strip_edges().is_empty():
				_char_name = RANDOM_NAMES[randi() % RANDOM_NAMES.size()]
			_name_edit.text = _char_name
			_name_edit.grab_focus.call_deferred()
			_name_edit.caret_column = _char_name.length()
	_refresh()


func _focus_selected(buttons: Dictionary) -> void:
	for b: Button in buttons.keys():
		if b.button_pressed:
			b.grab_focus.call_deferred()
			return


func _on_back_pressed() -> void:
	if _rolling:
		return
	if _step == 0:
		close()
	else:
		CreationUI.play("button-press")
		_go_to_step(_step - 1, false)


func _on_confirm_pressed() -> void:
	if _rolling or _confirm_button.disabled:
		return
	match _step:
		0:
			_go_to_step(1)
		1:
			_save()


func _save() -> void:
	var problems: Array[String] = CharacterCreation.validate_selection(_draft())
	if not problems.is_empty():
		_problems.text = "\n".join(problems)
		return
	# Editing a character that already has a birth die: keep it.
	var needs_birth_roll: bool = _dice.is_empty()
	if needs_birth_roll:
		_rolling = true
		_confirm_button.disabled = true
		_back_button.disabled = true
		var primary: String = CharacterCreation.primary_stat(_prof)
		var face: int = await DiceRollPopup.roll_d6(
			get_tree(),
			"BIRTH ROLL",
			"%s  ·  primary %s" % [_prof.profession_name.to_upper(), str(CharacterCreation.STAT_SHORT[primary])],
			0,
			func(v: int) -> String:
				var b: Dictionary = CharacterCreation.creation_bonus_for_roll(v)
				var parts: PackedStringArray = ["+%d %s" % [int(b["stat"]), str(CharacterCreation.STAT_SHORT[primary])]]
				if int(b["ability"]) > 0:
					parts.append("+%d SKILL/SPELL (banks for level-up)" % int(b["ability"]))
				return "  ·  ".join(parts),
			2.0)
		var birth: Dictionary = CharacterCreation.apply_birth_roll(_breed, _prof, face)
		_dice = [int(birth["face"])]
		_alloc = (birth["allocation"] as Dictionary).duplicate()
		_ability_points = int(birth["ability"])
		_rolling = false
		_back_button.disabled = false
	var final_problems: Array[String] = CharacterCreation.validate_draft(_draft())
	if not final_problems.is_empty():
		_problems.text = "\n".join(final_problems)
		_confirm_button.disabled = false
		return
	var cat: CatCharacter = CharacterCreation.build_character(_draft(), editing)
	var err: Error = CharacterRoster.save(cat)
	if err != OK:
		_problems.text = "Couldn't save the character (error %d)." % err
		_confirm_button.disabled = false
		return
	CreationUI.play("button-confirm")
	if is_instance_valid(SignalBus):
		SignalBus.show_toast.emit("%s joined your roster." % cat.name if editing == null else "%s updated." % cat.name, false)
	character_saved.emit(cat)
	close()


# ==============================================================================
# Step 1
# ==============================================================================
func _select_race(breed: CatBreed) -> void:
	if _breed == breed and _fur_rect.texture != null:
		return
	_breed = breed
	CreationUI.play("button-hover")
	_refresh()


func _select_class(prof: ProfessionData) -> void:
	if _prof == prof and _portrait_rect.texture != null:
		return
	_prof = prof
	CreationUI.play("button-hover")
	_refresh()


func _refresh_step_race_class() -> void:
	_fur_rect.texture = CharacterCreation.fur_texture(_breed)
	CreationUI.set_portrait(_portrait_rect, CharacterCreation.portrait_texture(_prof))
	_race_name.text = _breed.breed_name.to_upper() if _breed else ""
	_class_name.text = _prof.profession_name.to_upper() if _prof else ""
	for b: Button in _class_buttons.keys():
		var reachable: bool = CharacterCreation.is_class_reachable(_breed, _class_buttons[b] as ProfessionData)
		b.modulate = Color(1, 1, 1, 1.0 if reachable else 0.35)
		b.tooltip_text = "" if reachable else "A %s can't reach this class's minimums (birth die only boosts primary)." % _breed.breed_name
	for c: Node in _req_grid.get_children():
		c.queue_free()
	var base: Dictionary = CharacterCreation.base_stats(_breed)
	var req: Dictionary = CharacterCreation.class_requirements(_prof)
	var primary: String = CharacterCreation.primary_stat(_prof)
	_req_grid.add_child(CreationUI.body("", 12))
	for stat: String in CharacterCreation.STATS:
		var accent: Color = CreationUI.YELLOW if stat == primary else Color(CreationUI.WHITE, 0.5)
		var h: Label = CreationUI.body(str(CharacterCreation.STAT_SHORT[stat]), 12, accent)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_req_grid.add_child(h)
	_req_grid.add_child(CreationUI.body("RACE", 12, Color(CreationUI.WHITE, 0.5)))
	for stat: String in CharacterCreation.STATS:
		var ok: bool = int(base[stat]) >= int(req[stat])
		var v: Label = CreationUI.title(str(base[stat]), 16, CreationUI.WHITE if ok else CreationUI.RED)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_req_grid.add_child(v)
	_req_grid.add_child(CreationUI.body("MIN", 12, Color(CreationUI.PINK, 0.8)))
	for stat: String in CharacterCreation.STATS:
		var m: Label = CreationUI.title(str(req[stat]) if int(req[stat]) > 0 else "-", 16, Color(CreationUI.PINK, 0.85))
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_req_grid.add_child(m)

	var need: int = CharacterCreation.primary_points_needed(_breed, _prof)
	if not CharacterCreation.is_class_reachable(_breed, _prof):
		_fit_label.text = "A %s can't reach the %s (non-primary mins must be met by the race; primary needs ≤ +6)." % [
			_breed.breed_name, _prof.profession_name]
		_fit_label.add_theme_color_override("font_color", CreationUI.RED)
	elif need == 0:
		_fit_label.text = "Primary %s — birth die (+1..6) is pure bonus on CREATE." % str(CharacterCreation.STAT_SHORT[primary])
		_fit_label.add_theme_color_override("font_color", CreationUI.GREEN)
	else:
		_fit_label.text = "Primary %s needs +%d (birth die +1..6 on CREATE covers it)." % [
			str(CharacterCreation.STAT_SHORT[primary]), need]
		_fit_label.add_theme_color_override("font_color", CreationUI.YELLOW)
	_confirm_button.disabled = not CharacterCreation.is_class_reachable(_breed, _prof)
	_hint.text = "Out of reach - choose another class or race" if _confirm_button.disabled else "%s %s" % [_breed.breed_name, _prof.profession_name]


# ==============================================================================
# Step 2
# ==============================================================================
func _rebuild_picks() -> void:
	for c: Node in _spell_list.get_children():
		c.queue_free()
	for c: Node in _skill_list.get_children():
		c.queue_free()
	_pick_buttons.clear()
	var spell_choices: Array[SpellData] = CharacterCreation.spell_choices(_breed, _prof)
	var spell_n: int = CharacterCreation.spell_pick_count(_breed, _prof)
	var unlock: int = int(ClassProgression.for_class(_prof.profession_name).get("spells_unlock_at_level", 0))
	if AbilityRules.parse_spellbooks(_prof.spellbook_type).is_empty():
		_spell_header.text = "NO SPELLBOOK"
	elif spell_n == 0:
		_spell_header.text = "SPELLBOOK OPENS AT LEVEL %d" % unlock
	else:
		_spell_header.text = "SPELLS  ·  CHOOSE %d" % spell_n
	for s: SpellData in spell_choices:
		_spell_list.add_child(_make_pick(s, "T%d · %d MP" % [s.tier, s.energy_cost]))
	var free: Array[SkillData] = CharacterCreation.race_skills(_breed)
	var skill_n: int = CharacterCreation.skill_pick_count(_breed, _prof)
	_skill_header.text = "CLASS SKILLS  ·  CHOOSE %d" % skill_n if skill_n > 0 else "NO CLASS SKILLS AT LEVEL 1"
	for s: SkillData in CharacterCreation.skill_choices(_breed, _prof):
		if free.has(s):
			continue
		var meta: String = "%d MP" % s.energy_cost if s.energy_cost > 0 else String(SkillData.SkillType.keys()[s.skill_type]).capitalize()
		_skill_list.add_child(_make_pick(s, meta))
	var names: PackedStringArray = []
	for s: SkillData in free:
		names.append(s.skill_name)
	_race_skill_label.text = "%s SKILL (FREE):  %s" % [_breed.breed_name.to_upper(), ", ".join(names)] if not names.is_empty() else ""


func _make_pick(ability: Resource, meta: String) -> Button:
	var b: Button = CreationUI.list_button("%s   ·  %s" % [AbilityInfo.display_name(ability), meta], CreationUI.GREEN, 14)
	b.custom_minimum_size = Vector2(0, 30)
	b.toggled.connect(_on_pick_toggled.bind(ability))
	b.mouse_entered.connect(_show_ability_detail.bind(ability))
	b.focus_entered.connect(_show_ability_detail.bind(ability))
	_pick_buttons[b] = ability
	return b


func _on_pick_toggled(on: bool, ability: Resource) -> void:
	var is_spell: bool = ability is SpellData
	var limit: int = CharacterCreation.spell_pick_count(_breed, _prof) if is_spell else CharacterCreation.skill_pick_count(_breed, _prof)
	if is_spell:
		if on and not _spells.has(ability):
			_spells.append(ability as SpellData)
			while _spells.size() > limit:
				_spells.remove_at(0)
		elif not on:
			_spells.erase(ability)
	else:
		if on and not _skills.has(ability):
			_skills.append(ability as SkillData)
			while _skills.size() > limit:
				_skills.remove_at(0)
		elif not on:
			_skills.erase(ability)
	CreationUI.play("button-hover")
	_refresh()


func _show_ability_detail(ability: Resource) -> void:
	var desc: String = str(ability.get("description")) if "description" in ability else ""
	_ability_detail.text = "%s\n%s" % [AbilityInfo.display_name(ability).to_upper(), desc]


func _refresh_step_abilities_name() -> void:
	_confirm_fur.texture = CharacterCreation.fur_texture(_breed)
	CreationUI.set_portrait(_confirm_portrait, CharacterCreation.portrait_texture(_prof))
	var shown_name: String = CharacterCreation.clean_name(_char_name)
	_summary_title.text = shown_name.to_upper() if not shown_name.is_empty() else "UNNAMED"
	_summary_sub.text = "%s  ·  %s  ·  LEVEL 1" % [_breed.breed_name.to_upper(), _prof.profession_name.to_upper()]
	var stats: Dictionary = _preview_stats()
	var primary: String = CharacterCreation.primary_stat(_prof)
	var parts: PackedStringArray = []
	for stat: String in CharacterCreation.STATS:
		var mark: String = " *" if stat == primary else ""
		parts.append("%s %d%s" % [CharacterCreation.STAT_SHORT[stat], int(stats[stat]), mark])
	var preview: CatCharacter = CharacterCreation.preview_character(_breed, _prof, stats)
	_summary_stats.text = "  ".join(parts.slice(0, 4)) + "\n" + "  ".join(parts.slice(4)) + "\n\nHP %d   MP %d" % [preview.max_hp, preview.max_energy]
	if _dice.is_empty():
		_summary_birth.text = "CREATE rolls 1d6 → +1..6 to %s (5/6 also bank skill/spell for level-up). No re-roll." % str(CharacterCreation.STAT_SHORT[primary])
	else:
		var face: int = int(_dice[0])
		var bonus: Dictionary = CharacterCreation.creation_bonus_for_roll(face)
		var msg: String = "Birth die %d → +%d %s" % [face, int(bonus["stat"]), str(CharacterCreation.STAT_SHORT[primary])]
		if int(bonus["ability"]) > 0:
			msg += " · +%d skill/spell banked" % int(bonus["ability"])
		_summary_birth.text = msg
	var abilities: PackedStringArray = []
	for s: SpellData in _spells:
		abilities.append(s.spell_name)
	for s: SkillData in CharacterCreation.race_skills(_breed):
		abilities.append(s.skill_name)
	for s: SkillData in _skills:
		abilities.append(s.skill_name)
	_summary_abilities.text = "KNOWS:  " + (", ".join(abilities) if not abilities.is_empty() else "nothing yet")

	for b: Button in _pick_buttons.keys():
		var a: Resource = _pick_buttons[b] as Resource
		b.set_pressed_no_signal((a is SpellData and _spells.has(a as SpellData)) or (a is SkillData and _skills.has(a as SkillData)))

	if not _rolling:
		var problems: Array[String] = CharacterCreation.validate_selection(_draft())
		_problems.text = "\n".join(problems)
		_confirm_button.disabled = not problems.is_empty()
		_hint.text = "Saved to your roster - edit until it goes on an adventure." if problems.is_empty() else problems[0]


func _refresh() -> void:
	if _breed == null or _prof == null or _pages.is_empty():
		return
	match _step:
		0:
			_refresh_step_race_class()
		1:
			_refresh_step_abilities_name()


# ==============================================================================
# INFO popups
# ==============================================================================
func _show_race_info() -> void:
	var base: Dictionary = CharacterCreation.base_stats(_breed)
	var lines: PackedStringArray = []
	for stat: String in CharacterCreation.STATS:
		lines.append("%s %d" % [CharacterCreation.STAT_SHORT[stat], int(base[stat])])
	var skills: PackedStringArray = []
	for s: SkillData in CharacterCreation.race_skills(_breed):
		skills.append("[color=#5cf285]%s[/color] - %s" % [s.skill_name, s.description])
	var reach: PackedStringArray = []
	for prof: ProfessionData in CharacterCreation.all_classes():
		if CharacterCreation.is_class_reachable(_breed, prof):
			reach.append(prof.profession_name)
	var body: String = _breed.description
	body += "\n\n[color=#ffcc2e]BASE STATS[/color]\n" + "   ".join(lines)
	if not skills.is_empty():
		body += "\n\n[color=#ffcc2e]RACE SKILL[/color]\n" + "\n".join(skills)
	body += "\n\n[color=#ffcc2e]CAN BECOME[/color]\n" + ", ".join(reach)
	_open_info(_breed.breed_name.to_upper(), CharacterCreation.fur_texture(_breed), body, CreationUI.WHITE)


func _show_class_info() -> void:
	var row: Dictionary = ClassProgression.for_class(_prof.profession_name)
	var text: Dictionary = CharacterCreation.class_text(_prof.profession_name)
	var req: Dictionary = CharacterCreation.class_requirements(_prof)
	var primary: String = CharacterCreation.primary_stat(_prof)
	var mins: PackedStringArray = []
	for stat: String in CharacterCreation.STATS:
		if int(req[stat]) > 0:
			var tag: String = " (primary)" if stat == primary else ""
			mins.append("%s %d%s" % [CharacterCreation.STAT_SHORT[stat], int(req[stat]), tag])
	var body: String = "[color=#ffcc2e]%s[/color]  ·  based on the %s\n" % [str(row.get("difficulty_label", "")).to_upper(), str(text.get("based_on", "?"))]
	if not str(text.get("features", "")).is_empty():
		body += "\n" + str(text["features"]) + "\n"
	for pair: Array in [["WEAPONRY", "weaponry"], ["PHYSICAL", "physical"], ["MAGIC", "academia"]]:
		if not str(text.get(pair[1], "")).is_empty():
			body += "\n[color=#ffcc2e]%s[/color]  %s" % [pair[0], str(text[pair[1]])]
	body += "\n\n[color=#ffcc2e]MINIMUM STATS[/color]  " + ("   ".join(mins) if not mins.is_empty() else "none")
	body += "\n[color=#ffcc2e]BIRTH DIE[/color]  +1..6 to %s on CREATE (5/6 also bank skill/spell)" % str(CharacterCreation.STAT_SHORT[primary])
	var unlock: int = int(row.get("spells_unlock_at_level", 0))
	if not AbilityRules.parse_spellbooks(_prof.spellbook_type).is_empty():
		body += "\n[color=#ffcc2e]SPELLBOOK[/color]  %s, opens at level %d" % [_prof.spellbook_type, unlock]
	if not str(row.get("notes", "")).is_empty():
		body += "\n\n[i]%s[/i]" % str(row["notes"])
	_open_info(_prof.profession_name.to_upper(), CharacterCreation.portrait_texture(_prof), body, CreationUI.PINK)


func _open_info(title: String, image: Texture2D, bbcode: String, accent: Color) -> void:
	_close_info()
	CreationUI.play("button-press")
	_info = Control.new()
	_info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_info.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_info)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_info.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_info.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.add_theme_stylebox_override("panel", CreationUI.glass_panel(accent))
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	var box: Array = CreationUI.image_box(180.0, accent)
	if accent == CreationUI.PINK:
		CreationUI.set_portrait(box[1] as TextureRect, image)
	else:
		(box[1] as TextureRect).texture = image
	(box[0] as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(box[0] as Control)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	row.add_child(col)
	col.add_child(CreationUI.title(title, 30, accent))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(520, 0)
	rt.add_theme_font_override("normal_font", ShardsMenuStyle.BODY_FONT)
	rt.add_theme_font_override("italics_font", ShardsMenuStyle.BODY_FONT)
	rt.add_theme_font_size_override("normal_font_size", 14)
	rt.add_theme_font_size_override("italics_font_size", 13)
	rt.add_theme_color_override("default_color", Color(CreationUI.WHITE, 0.85))
	rt.text = bbcode
	col.add_child(rt)
	var ok: Button = CreationUI.action_button("OK", accent)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.pressed.connect(_close_info)
	col.add_child(ok)
	ok.grab_focus.call_deferred()


func _close_info() -> void:
	if is_instance_valid(_info):
		_info.queue_free()
		_info = null
		CreationUI.play("button-press")
		if _step == 0:
			_focus_selected(_race_buttons)
