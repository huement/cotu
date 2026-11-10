# res://Scripts/UI/CharacterCreator/CharacterCreator.gd
class_name CharacterCreator
extends Control
## The three-step character creator, over the space background:
##   1  RACE & CLASS  - race list | fur  ⬢  class portrait | class list, INFO popups. Classes the race can't
##                      reach even with the best roll are greyed out.
##   2  ROLL & ASSIGN - roll 3 d6 (DiceRoll3D) for bonus points, re-roll any time, spend them with - / +,
##                      pick starting spells / skills. CONFIRM only once the class minimums are met.
##   3  NAME & CONFIRM - name, summary, CREATE -> CharacterRoster.save().
## Rules live in CharacterCreation (pure, tested); this file is only the screens.
##
##   var creator := CharacterCreator.new()
##   creator.editing = roster_cat          # optional: edit an unlocked roster character
##   add_child(creator); creator.character_saved.connect(...); creator.closed.connect(...)

signal closed
signal character_saved(cat: CatCharacter)

const STEP_TITLES: Array[String] = ["CHOOSE RACE & CLASS", "ROLL & ASSIGN ATTRIBUTES", "NAME & CONFIRM"]
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
var _alloc_for: Array = [null, null] # [breed, prof] the allocation / picks were made for
var _spells: Array[SpellData] = []
var _skills: Array[SkillData] = []
var _char_name: String = ""
var _rolling: bool = false
## Re-rolls left for this character (first roll is free). Editing a rolled character = none.
var _rerolls_left: int = CharacterCreation.REROLLS_PER_CHARACTER
var _roll_wait_timer: Timer
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
var _dice_nodes: Array[DiceRoll3D] = []
var _pool_label: Label
var _pool_note: Label
var _reroll_button: Button
var _stat_value_labels: Dictionary = {}
var _stat_min_labels: Dictionary = {}
var _stat_minus: Dictionary = {}
var _stat_plus: Dictionary = {}
var _points_left: Label
var _vitals_label: Label
var _spell_header: Label
var _spell_list: VBoxContainer
var _skill_header: Label
var _skill_list: VBoxContainer
var _race_skill_label: Label
var _ability_detail: Label
var _pick_buttons: Dictionary = {} # Button -> Resource

# step 3
var _name_edit: LineEdit
var _confirm_fur: TextureRect
var _confirm_portrait: TextureRect
var _summary_title: Label
var _summary_sub: Label
var _summary_stats: Label
var _summary_abilities: Label
var _problems: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	CreationUI.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if editing != null:
		_load_draft(CharacterCreation.draft_from_character(editing))
		if not _dice.is_empty():
			_rerolls_left = 0
	_build()
	_roll_wait_timer = Timer.new()
	_roll_wait_timer.wait_time = 0.25
	_roll_wait_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_roll_wait_timer.timeout.connect(_on_roll_wait_tick)
	add_child(_roll_wait_timer)
	_roll_wait_timer.start()
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
	_alloc_for = [_breed, _prof]
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
		"bonus_pool": _pool(),
		"allocation": _alloc.duplicate(),
		"spells": _spells.duplicate(),
		"skills": _skills.duplicate(),
	}


func _pool() -> int:
	return CharacterCreation.sum_dice(_dice)


func _stats() -> Dictionary:
	return CharacterCreation.apply_allocation(_breed, _alloc)


## Race / class changed since the points were spent: redo the allocation and the default picks.
func _sync_to_selection() -> void:
	if _alloc_for[0] == _breed and _alloc_for[1] == _prof:
		return
	_alloc = CharacterCreation.auto_allocate(_breed, _prof, _pool()) if not _dice.is_empty() else {}
	_spells = CharacterCreation.default_spell_picks(_breed, _prof)
	_skills = CharacterCreation.default_skill_picks(_breed, _prof)
	_alloc_for = [_breed, _prof]


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

	_steps = CreationUI.step_indicator(3)
	var head: Array = CreationUI.header(STEP_TITLES[0], _steps)
	root.add_child(head[0] as Control)
	_step_title = head[1] as Label

	var pages := MarginContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pages)
	_pages = [_build_step_race_class(), _build_step_stats(), _build_step_confirm()]
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
	_hint.clip_text = true
	footer.add_child(_hint)

	if show_background:
		_window.resized.connect(func() -> void: _space.focus_on(_window, 0.45, 0.06))


# --- Step 1 -------------------------------------------------------------------
func _build_step_race_class() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 22)

	# Races
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

	# Centre: images, names, fit
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

	# Classes
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


# --- Step 2 -------------------------------------------------------------------
func _build_step_stats() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 20)

	# Dice
	var dice_col: VBoxContainer = _panel_column("BONUS ROLL", 290)
	var dice_row := HBoxContainer.new()
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_row.add_theme_constant_override("separation", 0)
	dice_col.add_child(dice_row)
	for i: int in CharacterCreation.BONUS_DICE:
		var d := DiceRoll3D.new()
		d.custom_minimum_size = Vector2(94, 110)
		d.die_scale = 0.8
		d.roll_duration = 1.1 + 0.15 * i
		d.drop_height = 1.8
		d.visible_before_roll = true
		dice_row.add_child(d)
		_dice_nodes.append(d)
	_pool_label = CreationUI.title("", 44, CreationUI.YELLOW)
	_pool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_col.add_child(_pool_label)
	_pool_note = CreationUI.wrap(CreationUI.body("", 13))
	_pool_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_col.add_child(_pool_note)
	_reroll_button = CreationUI.action_button("RE-ROLL", CreationUI.YELLOW)
	_reroll_button.pressed.connect(_roll_dice)
	dice_col.add_child(_reroll_button)
	var note: Label = CreationUI.wrap(CreationUI.body("Roll %dd6 for bonus points. You get %d re-rolls per character - a new roll resets where the points went." % [CharacterCreation.BONUS_DICE, CharacterCreation.REROLLS_PER_CHARACTER], 12, Color(CreationUI.WHITE, 0.5)))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_col.add_child(note)
	page.add_child(dice_col)

	# Attributes
	var stat_col: VBoxContainer = _panel_column("ATTRIBUTES", 0)
	stat_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	stat_col.add_child(grid)
	for h: String in ["", "", "", "", "MIN"]:
		var hl: Label = CreationUI.body(h, 11, Color(CreationUI.WHITE, 0.45))
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(hl)
	for stat: String in CharacterCreation.STATS:
		var name_l: Label = CreationUI.title(str(CharacterCreation.STAT_LONG[stat]).to_upper(), 15)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_l)
		var minus: Button = CreationUI.small_button("−", CreationUI.RED)
		minus.custom_minimum_size = Vector2(38, 32)
		minus.pressed.connect(_change_stat.bind(stat, -1))
		grid.add_child(minus)
		var value: Label = CreationUI.title("", 20)
		value.custom_minimum_size = Vector2(70, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(value)
		var plus: Button = CreationUI.small_button("+", CreationUI.GREEN)
		plus.custom_minimum_size = Vector2(38, 32)
		plus.pressed.connect(_change_stat.bind(stat, 1))
		grid.add_child(plus)
		var min_l: Label = CreationUI.body("", 14)
		min_l.custom_minimum_size = Vector2(44, 0)
		min_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(min_l)
		_stat_value_labels[stat] = value
		_stat_min_labels[stat] = min_l
		_stat_minus[stat] = minus
		_stat_plus[stat] = plus
	var points_row := HBoxContainer.new()
	points_row.add_theme_constant_override("separation", 10)
	stat_col.add_child(points_row)
	_points_left = CreationUI.title("", 18, CreationUI.YELLOW)
	_points_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	points_row.add_child(_points_left)
	var auto_b: Button = CreationUI.small_button("AUTO", CreationUI.YELLOW)
	auto_b.custom_minimum_size = Vector2(80, 32)
	auto_b.tooltip_text = "Put points on what the class needs first"
	auto_b.pressed.connect(_auto_assign)
	points_row.add_child(auto_b)
	var reset_b: Button = CreationUI.small_button("RESET", CreationUI.RED)
	reset_b.custom_minimum_size = Vector2(80, 32)
	reset_b.pressed.connect(func() -> void:
		_alloc = {}
		_refresh())
	points_row.add_child(reset_b)
	_vitals_label = CreationUI.body("", 14, CreationUI.GREEN)
	stat_col.add_child(_vitals_label)
	page.add_child(stat_col)

	# Abilities
	var ab_col: VBoxContainer = _panel_column("STARTING ABILITIES", 320)
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
	page.add_child(ab_col)
	return page


func _panel_column(heading: String, width: float) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(width, 0)
	col.add_theme_constant_override("separation", 10)
	col.add_child(CreationUI.title(heading, 15, Color(CreationUI.WHITE, 0.55)))
	return col


# --- Step 3 -------------------------------------------------------------------
func _build_step_confirm() -> Control:
	var page := HBoxContainer.new()
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 40)

	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 12)
	page.add_child(left)
	# Portrait over the race's fur
	var frame := PanelContainer.new()
	var fs: StyleBoxFlat = CreationUI.flat(Color(0, 0, 0, 0.6), CreationUI.WHITE, 3, 4)
	fs.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", fs)
	frame.custom_minimum_size = Vector2(300, 300)
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

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.custom_minimum_size = Vector2(420, 0)
	right.add_theme_constant_override("separation", 10)
	page.add_child(right)
	_summary_title = CreationUI.title("", 38)
	right.add_child(_summary_title)
	_summary_sub = CreationUI.title("", 18, CreationUI.PINK)
	right.add_child(_summary_sub)
	_summary_stats = CreationUI.body("", 15)
	right.add_child(_summary_stats)
	_summary_abilities = CreationUI.wrap(CreationUI.body("", 14, Color(CreationUI.WHITE, 0.8)))
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
	_confirm_button.text = "●  CONFIRM" if step < 2 else ("●  SAVE CHANGES" if editing != null else "●  CREATE")
	_back_button.text = "CANCEL" if step == 0 else "BACK"
	if sound:
		CreationUI.play("button-confirm")
	match step:
		0:
			_focus_selected(_race_buttons)
		1:
			_sync_to_selection()
			_rebuild_picks()
			if _dice.is_empty():
				_roll_dice.call_deferred()
			else:
				for i: int in _dice_nodes.size():
					if i < _dice.size():
						_dice_nodes[i].show_value(_dice[i])
			_reroll_button.grab_focus.call_deferred()
		2:
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
		0, 1:
			_go_to_step(_step + 1)
		2:
			_save()


func _save() -> void:
	var problems: Array[String] = CharacterCreation.validate_draft(_draft())
	if not problems.is_empty():
		_problems.text = "\n".join(problems)
		return
	var cat: CatCharacter = CharacterCreation.build_character(_draft(), editing)
	var err: Error = CharacterRoster.save(cat)
	if err != OK:
		_problems.text = "Couldn't save the character (error %d)." % err
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
	# Grey out classes this race can never reach.
	for b: Button in _class_buttons.keys():
		var reachable: bool = CharacterCreation.is_class_reachable(_breed, _class_buttons[b] as ProfessionData)
		b.modulate = Color(1, 1, 1, 1.0 if reachable else 0.35)
		b.tooltip_text = "" if reachable else "A %s can't reach this class's minimum stats." % _breed.breed_name
	# Base vs minimums
	for c: Node in _req_grid.get_children():
		c.queue_free()
	var base: Dictionary = CharacterCreation.base_stats(_breed)
	var req: Dictionary = CharacterCreation.class_requirements(_prof)
	_req_grid.add_child(CreationUI.body("", 12))
	for stat: String in CharacterCreation.STATS:
		var h: Label = CreationUI.body(str(CharacterCreation.STAT_SHORT[stat]), 12, Color(CreationUI.WHITE, 0.5))
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

	var need: int = CharacterCreation.points_needed(_breed, _prof)
	if not CharacterCreation.is_class_reachable(_breed, _prof):
		_fit_label.text = "A %s can't reach the %s's minimums (needs %d bonus points, the best roll is %d)." % [
			_breed.breed_name, _prof.profession_name, need, CharacterCreation.max_bonus()]
		_fit_label.add_theme_color_override("font_color", CreationUI.RED)
	elif need == 0:
		_fit_label.text = "A natural fit - every bonus point is yours to spend."
		_fit_label.add_theme_color_override("font_color", CreationUI.GREEN)
	else:
		_fit_label.text = "Needs %d bonus points  ·  %d%% chance per roll" % [need, roundi(CharacterCreation.roll_success_chance(_breed, _prof) * 100.0)]
		_fit_label.add_theme_color_override("font_color", CreationUI.YELLOW)
	_confirm_button.disabled = not CharacterCreation.is_class_reachable(_breed, _prof)
	_hint.text = "Out of reach - choose another class or race" if _confirm_button.disabled else "%s %s" % [_breed.breed_name, _prof.profession_name]


# ==============================================================================
# Step 2
# ==============================================================================
func _roll_dice() -> void:
	if _rolling:
		return
	var first_roll: bool = _dice.is_empty()
	if not first_roll and _rerolls_left <= 0:
		return
	if CharacterCreation.roll_wait_seconds() > 0.0:
		_update_reroll_button()
		return
	CharacterCreation.register_roll()
	if not first_roll:
		_rerolls_left -= 1
	_rolling = true
	_set_rolling_ui(true)
	CreationUI.play("button-confirm")
	var values: Array[int] = CharacterCreation.roll_bonus_dice()
	for i: int in _dice_nodes.size() - 1:
		_dice_nodes[i].roll(values[i])
	await _dice_nodes[_dice_nodes.size() - 1].roll(values[values.size() - 1])
	await get_tree().create_timer(0.15, true, false, true).timeout
	_dice = values
	_alloc = CharacterCreation.auto_allocate(_breed, _prof, _pool())
	_alloc_for = [_breed, _prof]
	_rolling = false
	_set_rolling_ui(false)
	_refresh()
	_update_reroll_button()


func _on_roll_wait_tick() -> void:
	if _rolling or _step != 1:
		return
	# First roll was blocked by the global limit: roll as soon as it's allowed.
	if _dice.is_empty() and CharacterCreation.roll_wait_seconds() <= 0.0:
		_roll_dice()
		return
	_update_reroll_button()


func _update_reroll_button() -> void:
	if not is_instance_valid(_reroll_button) or _rolling:
		return
	var wait: float = CharacterCreation.roll_wait_seconds()
	if _dice.is_empty():
		_reroll_button.disabled = true
		_reroll_button.text = "WAIT %ds" % ceili(wait) if wait > 0.0 else "ROLLING..."
		if wait > 0.0:
			_pool_note.text = "Dice are cooling down - rolling in %ds." % ceili(wait)
	elif _rerolls_left <= 0:
		_reroll_button.disabled = true
		_reroll_button.text = "NO RE-ROLLS LEFT"
	elif wait > 0.0:
		_reroll_button.disabled = true
		_reroll_button.text = "WAIT %ds" % ceili(wait)
	else:
		_reroll_button.disabled = false
		_reroll_button.text = "RE-ROLL (%d LEFT)" % _rerolls_left


func _set_rolling_ui(on: bool) -> void:
	_reroll_button.disabled = on
	_confirm_button.disabled = on
	_back_button.disabled = on
	for stat: String in CharacterCreation.STATS:
		(_stat_minus[stat] as Button).disabled = on
		(_stat_plus[stat] as Button).disabled = on
	if on:
		_pool_label.text = "..."
		_pool_note.text = "Rolling..."


func _change_stat(stat: String, delta: int) -> void:
	if _rolling:
		return
	if delta > 0 and CharacterCreation.can_raise(_breed, _alloc, stat, _pool()):
		_alloc[stat] = int(_alloc.get(stat, 0)) + 1
		CreationUI.play("button-hover")
	elif delta < 0 and CharacterCreation.can_lower(_alloc, stat):
		_alloc[stat] = int(_alloc[stat]) - 1
		if int(_alloc[stat]) <= 0:
			_alloc.erase(stat)
		CreationUI.play("button-hover")
	_refresh()


## AUTO: class needs first, then the rest round-robin over the class's most useful stats.
func _auto_assign() -> void:
	_alloc = CharacterCreation.auto_allocate(_breed, _prof, _pool())
	var order: Array[String] = []
	var req: Dictionary = CharacterCreation.class_requirements(_prof)
	for stat: String in CharacterCreation.STATS:
		if int(req[stat]) > 0:
			order.append(stat)
	order.sort_custom(func(a: String, b: String) -> bool: return int(req[a]) > int(req[b]))
	for stat: String in CharacterCreation.STATS:
		if not order.has(stat):
			order.append(stat)
	var guard: int = 0
	while CharacterCreation.points_spent(_alloc) < _pool() and guard < 200:
		guard += 1
		for stat: String in order:
			if CharacterCreation.can_raise(_breed, _alloc, stat, _pool()):
				_alloc[stat] = int(_alloc.get(stat, 0)) + 1
				break
	CreationUI.play("button-confirm")
	_refresh()


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


func _refresh_step_stats() -> void:
	var stats: Dictionary = _stats()
	var req: Dictionary = CharacterCreation.class_requirements(_prof)
	var pool: int = _pool()
	var spent: int = CharacterCreation.points_spent(_alloc)
	for stat: String in CharacterCreation.STATS:
		var bonus: int = int(_alloc.get(stat, 0))
		var value_l: Label = _stat_value_labels[stat] as Label
		value_l.text = "%d" % int(stats[stat]) + ("  +%d" % bonus if bonus > 0 else "")
		var ok: bool = int(stats[stat]) >= int(req[stat])
		value_l.add_theme_color_override("font_color", CreationUI.WHITE if ok else CreationUI.RED)
		if bonus > 0 and ok:
			value_l.add_theme_color_override("font_color", CreationUI.GREEN)
		var min_l: Label = _stat_min_labels[stat] as Label
		min_l.text = str(req[stat]) if int(req[stat]) > 0 else "-"
		min_l.add_theme_color_override("font_color", Color(CreationUI.PINK, 0.9) if int(req[stat]) > 0 else Color(CreationUI.WHITE, 0.3))
		if not _rolling:
			(_stat_minus[stat] as Button).disabled = not CharacterCreation.can_lower(_alloc, stat)
			(_stat_plus[stat] as Button).disabled = not CharacterCreation.can_raise(_breed, _alloc, stat, pool)
	if not _rolling:
		_pool_label.text = str(pool) if not _dice.is_empty() else "-"
		var need: int = CharacterCreation.points_needed(_breed, _prof)
		if _dice.is_empty():
			_pool_note.text = ""
		elif pool >= need:
			var faces: PackedStringArray = []
			for d: int in _dice:
				faces.append(str(d))
			_pool_note.text = "%s  =  %d bonus points" % [" + ".join(faces), pool]
			_pool_note.add_theme_color_override("font_color", CreationUI.GREEN)
		else:
			_pool_note.text = "%d points - the %s needs %d. Re-roll!" % [pool, _prof.profession_name, need]
			_pool_note.add_theme_color_override("font_color", CreationUI.RED)
	_points_left.text = "POINTS LEFT  %d" % (pool - spent)

	var preview: CatCharacter = CharacterCreation.preview_character(_breed, _prof, stats)
	_vitals_label.text = "HP %d    MP %d    ·    LEVEL 1 %s" % [preview.max_hp, preview.max_energy, _prof.profession_name.to_upper()]

	for b: Button in _pick_buttons.keys():
		var a: Resource = _pick_buttons[b] as Resource
		b.set_pressed_no_signal((a is SpellData and _spells.has(a as SpellData)) or (a is SkillData and _skills.has(a as SkillData)))

	if not _rolling:
		var problems: Array[String] = _step2_problems()
		_confirm_button.disabled = not problems.is_empty()
		_hint.text = problems[0] if not problems.is_empty() else "Ready"


func _step2_problems() -> Array[String]:
	var out: Array[String] = []
	if _dice.is_empty():
		out.append("Roll the dice")
		return out
	var unmet: Array[String] = CharacterCreation.unmet_requirements(_stats(), _prof)
	if not unmet.is_empty():
		out.append("%s needs %s" % [_prof.profession_name, ", ".join(unmet)])
	elif not CharacterCreation.is_allocation_valid(_breed, _prof, _alloc, _pool()):
		out.append("Spend all bonus points")
	if _spells.size() < CharacterCreation.spell_pick_count(_breed, _prof):
		out.append("Choose %d spell(s)" % CharacterCreation.spell_pick_count(_breed, _prof))
	if _skills.size() < CharacterCreation.skill_pick_count(_breed, _prof):
		out.append("Choose %d skill(s)" % CharacterCreation.skill_pick_count(_breed, _prof))
	return out


# ==============================================================================
# Step 3
# ==============================================================================
func _refresh_step_confirm() -> void:
	_confirm_fur.texture = CharacterCreation.fur_texture(_breed)
	CreationUI.set_portrait(_confirm_portrait, CharacterCreation.portrait_texture(_prof))
	var shown_name: String = CharacterCreation.clean_name(_char_name)
	_summary_title.text = shown_name.to_upper() if not shown_name.is_empty() else "UNNAMED"
	_summary_sub.text = "%s  ·  %s  ·  LEVEL 1" % [_breed.breed_name.to_upper(), _prof.profession_name.to_upper()]
	var stats: Dictionary = _stats()
	var parts: PackedStringArray = []
	for stat: String in CharacterCreation.STATS:
		parts.append("%s %d" % [CharacterCreation.STAT_SHORT[stat], int(stats[stat])])
	var preview: CatCharacter = CharacterCreation.preview_character(_breed, _prof, stats)
	_summary_stats.text = "  ".join(parts.slice(0, 4)) + "\n" + "  ".join(parts.slice(4)) + "\n\nHP %d   MP %d" % [preview.max_hp, preview.max_energy]
	var abilities: PackedStringArray = []
	for s: SpellData in _spells:
		abilities.append(s.spell_name)
	for s: SkillData in CharacterCreation.race_skills(_breed):
		abilities.append(s.skill_name)
	for s: SkillData in _skills:
		abilities.append(s.skill_name)
	_summary_abilities.text = "KNOWS:  " + (", ".join(abilities) if not abilities.is_empty() else "nothing yet")
	var problems: Array[String] = CharacterCreation.validate_draft(_draft())
	_problems.text = "\n".join(problems)
	_confirm_button.disabled = not problems.is_empty()
	_hint.text = "Saved to your roster - edit it any time until it goes on an adventure." if problems.is_empty() else ""


func _refresh() -> void:
	if _breed == null or _prof == null or _pages.is_empty():
		return
	match _step:
		0:
			_refresh_step_race_class()
		1:
			_refresh_step_stats()
		2:
			_refresh_step_confirm()


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
	var mins: PackedStringArray = []
	for stat: String in CharacterCreation.STATS:
		if int(req[stat]) > 0:
			mins.append("%s %d" % [CharacterCreation.STAT_SHORT[stat], int(req[stat])])
	var body: String = "[color=#ffcc2e]%s[/color]  ·  based on the %s\n" % [str(row.get("difficulty_label", "")).to_upper(), str(text.get("based_on", "?"))]
	if not str(text.get("features", "")).is_empty():
		body += "\n" + str(text["features"]) + "\n"
	for pair: Array in [["WEAPONRY", "weaponry"], ["PHYSICAL", "physical"], ["MAGIC", "academia"]]:
		if not str(text.get(pair[1], "")).is_empty():
			body += "\n[color=#ffcc2e]%s[/color]  %s" % [pair[0], str(text[pair[1]])]
	body += "\n\n[color=#ffcc2e]MINIMUM STATS[/color]  " + ("   ".join(mins) if not mins.is_empty() else "none")
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
