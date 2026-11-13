# res://Scripts/UI/LevelUpMenu.gd
extends CanvasLayer
class_name LevelUpMenu

## Player-facing level-up allocation screen (stats + known skill/spell ranks).
##
## Flow: a party member levels up (SignalBus.character_leveled_up, after the victory popup) -> queued ->
## opened when no battle is running. If the character has pending_level_rolls, the frame first shows
## only a D6 (DiceRoll3D) - each roll adds bonus points (LevelUpDice) - then the stats/abilities fade in.
## Rolls are applied + saved the moment they land, so closing the screen can never re-roll them.
## The game is paused while the screen is open.

const STAT_KEYS: Array[String] = [
	"strength", "intelligence", "piety", "vitality", "dexterity", "speed", "personality"
]
const STAT_LABELS: Dictionary = {
	"strength": "STR",
	"intelligence": "INT",
	"piety": "PIE",
	"vitality": "VIT",
	"dexterity": "DEX",
	"speed": "SPD",
	"personality": "PER",
}

const COLOR_TEXT: Color = Color(0.0, 1.0, 0.784, 1.0)
const COLOR_PENDING: Color = Color(1.0, 0.85, 0.25, 1.0)
const COLOR_MUTED: Color = Color(0.45, 0.7, 0.65, 1.0)

@onready var overlay_panel: Control = %OverlayPanel as Control
@onready var portrait_texture: TextureRect = %PortraitTexture as TextureRect
@onready var char_name_label: Label = %CharNameLabel as Label
@onready var level_label: Label = %LevelLabel as Label
@onready var profession_label: Label = %ProfessionLabel as Label
@onready var points_label: Label = %PointsLabel as Label
@onready var stats_list: VBoxContainer = %StatsList as VBoxContainer
@onready var abilities_list: VBoxContainer = %AbilitiesList as VBoxContainer
@onready var confirm_button: Button = %ConfirmButton as Button
@onready var cancel_button: Button = %CancelButton as Button
@onready var frame: PanelContainer = %Frame as PanelContainer
@onready var main_vbox: VBoxContainer = %MainVBox as VBoxContainer

## Seconds the roll result stays on screen before the next roll / the stats fade in.
@export var roll_result_hold: float = 1.2

# Dice stage (built in code, sits inside the Frame on top of the content)
var _dice_stage: VBoxContainer
var _dice: DiceRoll3D
var _roll_title: Label
var _roll_result: Label
var _roll_detail: Label
var _bonus_label: Label
var _is_rolling: bool = false
var _queue: Array[CatCharacter] = []
var _was_paused: bool = false

var _character: CatCharacter = null
var _base_stats: Dictionary = {}
var _pending_stats: Dictionary = {}
var _pending_skill_ranks: Dictionary = {} # ability_id -> true
var _pending_spell_ranks: Dictionary = {} # ability_id -> true
var _stat_row_nodes: Dictionary = {} # stat_key -> { value, pending, minus, plus }


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if is_instance_valid(overlay_panel):
		overlay_panel.visible = false
		KeyboardModal.attach(overlay_panel, close)

	if is_instance_valid(confirm_button) and not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)
	if is_instance_valid(cancel_button) and not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)

	_build_stat_rows()
	_build_dice_stage()

	var sb: Node = SignalBus
	if is_instance_valid(sb) and sb.has_signal(&"level_up_screen_requested"):
		if not sb.level_up_screen_requested.is_connected(_on_level_up_screen_requested):
			sb.level_up_screen_requested.connect(_on_level_up_screen_requested)
	if is_instance_valid(sb) and sb.has_signal(&"character_leveled_up"):
		sb.character_leveled_up.connect(_on_character_leveled_up)


# ------------------------------------------------------------------------------
# Queue: open after real level-ups, one character at a time
# ------------------------------------------------------------------------------
func _on_character_leveled_up(slot_index: int, _new_level: int) -> void:
	if GameState.current_party == null or slot_index < 0 or slot_index >= GameState.current_party.slots.size():
		return
	var cat: CatCharacter = GameState.current_party.slots[slot_index] as CatCharacter
	if is_instance_valid(cat) and not _queue.has(cat) and cat != _character:
		_queue.append(cat)
	_open_next_when_ready.call_deferred()


func _open_next_when_ready() -> void:
	while not _queue.is_empty() and not visible:
		if SessionFlow.is_in_battle():
			await get_tree().create_timer(0.5, true).timeout
			continue
		await get_tree().create_timer(0.35, true).timeout # let the victory popup finish closing
		if visible or _queue.is_empty() or SessionFlow.is_in_battle():
			continue
		open_for(_queue.pop_front())
		return


func _on_level_up_screen_requested(character: Resource) -> void:
	open_for(character)


func open_for(character: Resource) -> void:
	if not character is CatCharacter:
		push_warning("LevelUpMenu: expected CatCharacter, got %s" % character)
		return
	_character = character as CatCharacter
	_reset_draft()
	_render_header()
	_refresh_stat_rows()
	_rebuild_ability_rows()
	_refresh_points_label()
	_bonus_label.visible = false
	if not visible:
		_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	if is_instance_valid(overlay_panel):
		overlay_panel.visible = true
	if _character.pending_level_rolls > 0:
		_play_level_rolls()
	else:
		_dice_stage.visible = false
		main_vbox.modulate.a = 1.0


# ------------------------------------------------------------------------------
# Bonus dice
# ------------------------------------------------------------------------------
func _play_level_rolls() -> void:
	_is_rolling = true
	var cat: CatCharacter = _character
	main_vbox.modulate.a = 0.0
	_dice_stage.visible = true
	_dice_stage.modulate.a = 1.0
	_roll_result.modulate.a = 0.0
	_roll_detail.modulate.a = 0.0

	var count: int = cat.pending_level_rolls
	var rolls: PackedStringArray = []
	var totals: Dictionary = { "stat": 0, "ability": 0, "hp_percent": 0.0 }
	for i: int in range(count):
		_roll_title.text = "%s REACHED LEVEL %d!" % [cat.name.to_upper(), cat.level] if count == 1 \
			else "%s  -  BONUS ROLL %d / %d" % [cat.name.to_upper(), i + 1, count]
		_roll_result.modulate.a = 0.0
		_roll_detail.modulate.a = 0.0
		var value: int = await _dice.roll()
		if cat != _character:
			return # closed while rolling
		var bonus: Dictionary = cat.apply_level_roll(value)
		rolls.append(str(value))
		totals["stat"] = int(totals["stat"]) + int(bonus["stat"])
		totals["ability"] = int(totals["ability"]) + int(bonus["ability"])
		totals["hp_percent"] = float(totals["hp_percent"]) + float(bonus["hp_percent"])
		_roll_result.text = "ROLLED %d" % value
		_roll_detail.text = LevelUpDice.describe(bonus)
		var reveal: Tween = create_tween().set_parallel(true)
		reveal.tween_property(_roll_result, "modulate:a", 1.0, 0.2)
		reveal.tween_property(_roll_detail, "modulate:a", 1.0, 0.3).set_delay(0.1)
		_refresh_points_label()
		await get_tree().create_timer(roll_result_hold, true).timeout

	# Remember the result right away so quitting can't re-roll.
	if is_instance_valid(GameState) and GameState.has_method("save_game"):
		GameState.save_game()

	_bonus_label.text = "BONUS DICE: %s   %s" % [", ".join(rolls), LevelUpDice.describe(totals)]
	_bonus_label.visible = true
	_render_header()
	_refresh_stat_rows()
	_rebuild_ability_rows()
	_refresh_points_label()
	var swap: Tween = create_tween()
	swap.tween_property(_dice_stage, "modulate:a", 0.0, 0.25)
	swap.tween_callback(func() -> void: _dice_stage.visible = false)
	swap.tween_property(main_vbox, "modulate:a", 1.0, 0.35)
	await swap.finished
	_is_rolling = false


func _build_dice_stage() -> void:
	_bonus_label = Label.new()
	_bonus_label.add_theme_color_override("font_color", COLOR_PENDING)
	_bonus_label.add_theme_font_size_override("font_size", 13)
	_bonus_label.visible = false
	main_vbox.add_child(_bonus_label)
	main_vbox.move_child(_bonus_label, 1)

	_dice_stage = VBoxContainer.new()
	_dice_stage.name = "DiceStage"
	_dice_stage.alignment = BoxContainer.ALIGNMENT_CENTER
	_dice_stage.mouse_filter = Control.MOUSE_FILTER_STOP # blocks the hidden buttons while rolling
	_dice_stage.add_theme_constant_override("separation", 6)
	_dice_stage.visible = false
	frame.add_child(_dice_stage)

	_roll_title = _make_stage_label(22, COLOR_TEXT)
	_dice_stage.add_child(_roll_title)
	var sub: Label = _make_stage_label(13, COLOR_MUTED)
	sub.text = "ROLL FOR BONUS POINTS"
	_dice_stage.add_child(sub)
	_dice = DiceRoll3D.new()
	_dice.custom_minimum_size = Vector2(420, 260)
	_dice.die_scale = 0.7
	_dice.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_dice_stage.add_child(_dice)
	_roll_result = _make_stage_label(34, COLOR_TEXT)
	_dice_stage.add_child(_roll_result)
	_roll_detail = _make_stage_label(16, COLOR_PENDING)
	_dice_stage.add_child(_roll_detail)


func _make_stage_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func close() -> void:
	if _is_rolling:
		return
	_character = null
	_reset_draft()
	visible = false
	if is_instance_valid(overlay_panel):
		overlay_panel.visible = false
	get_tree().paused = _was_paused
	if not _queue.is_empty():
		_open_next_when_ready.call_deferred()


func _reset_draft() -> void:
	_pending_stats.clear()
	_pending_skill_ranks.clear()
	_pending_spell_ranks.clear()
	_base_stats.clear()
	if not is_instance_valid(_character):
		return
	for key: String in STAT_KEYS:
		_base_stats[key] = int(_character.get(key))
		_pending_stats[key] = 0


func _build_stat_rows() -> void:
	if not is_instance_valid(stats_list):
		return
	for child in stats_list.get_children():
		child.queue_free()
	_stat_row_nodes.clear()

	for key: String in STAT_KEYS:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl: Label = Label.new()
		name_lbl.text = str(STAT_LABELS.get(key, key.to_upper()))
		name_lbl.custom_minimum_size = Vector2(48, 0)
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		name_lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(name_lbl)

		var value_lbl: Label = Label.new()
		value_lbl.name = "Value"
		value_lbl.custom_minimum_size = Vector2(36, 0)
		value_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		value_lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(value_lbl)

		var pending_lbl: Label = Label.new()
		pending_lbl.name = "Pending"
		pending_lbl.custom_minimum_size = Vector2(48, 0)
		pending_lbl.add_theme_color_override("font_color", COLOR_PENDING)
		pending_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(pending_lbl)

		var spacer: Control = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		var minus_btn: Button = Button.new()
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(32, 28)
		minus_btn.pressed.connect(_on_stat_minus.bind(key))
		row.add_child(minus_btn)

		var plus_btn: Button = Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(32, 28)
		plus_btn.pressed.connect(_on_stat_plus.bind(key))
		row.add_child(plus_btn)

		stats_list.add_child(row)
		_stat_row_nodes[key] = {
			"value": value_lbl,
			"pending": pending_lbl,
			"minus": minus_btn,
			"plus": plus_btn,
		}


func _refresh_stat_rows() -> void:
	for key: String in STAT_KEYS:
		var nodes: Dictionary = _stat_row_nodes.get(key, {})
		if nodes.is_empty():
			continue
		var base_val: int = int(_base_stats.get(key, 0))
		var pending: int = int(_pending_stats.get(key, 0))
		var value_lbl: Label = nodes.get("value") as Label
		var pending_lbl: Label = nodes.get("pending") as Label
		var minus_btn: Button = nodes.get("minus") as Button
		var plus_btn: Button = nodes.get("plus") as Button
		if is_instance_valid(value_lbl):
			value_lbl.text = str(base_val + pending)
		if is_instance_valid(pending_lbl):
			pending_lbl.text = ("(+%d)" % pending) if pending > 0 else ""
		if is_instance_valid(minus_btn):
			minus_btn.disabled = pending <= 0
		if is_instance_valid(plus_btn):
			plus_btn.disabled = _remaining_stat_points() <= 0


func _rebuild_ability_rows() -> void:
	if not is_instance_valid(abilities_list) or not is_instance_valid(_character):
		return
	for child in abilities_list.get_children():
		child.queue_free()

	var skills_header: Label = Label.new()
	skills_header.text = "SKILLS"
	skills_header.add_theme_color_override("font_color", COLOR_MUTED)
	skills_header.add_theme_font_size_override("font_size", 13)
	abilities_list.add_child(skills_header)

	if _character.known_skills.is_empty():
		var empty_s: Label = Label.new()
		empty_s.text = "  (none)"
		empty_s.add_theme_color_override("font_color", COLOR_MUTED)
		abilities_list.add_child(empty_s)
	else:
		for skill_res: Resource in _character.known_skills:
			_add_ability_row(skill_res, true)

	var spells_header: Label = Label.new()
	spells_header.text = "SPELLS"
	spells_header.add_theme_color_override("font_color", COLOR_MUTED)
	spells_header.add_theme_font_size_override("font_size", 13)
	abilities_list.add_child(spells_header)

	if _character.known_spells.is_empty():
		var empty_p: Label = Label.new()
		empty_p.text = "  (none)"
		empty_p.add_theme_color_override("font_color", COLOR_MUTED)
		abilities_list.add_child(empty_p)
	else:
		for spell_res: Resource in _character.known_spells:
			_add_ability_row(spell_res, false)


func _add_ability_row(ability: Resource, is_skill: bool) -> void:
	if not is_instance_valid(ability):
		return
	var ability_id: String = ""
	var ability_name: String = "Unknown"
	if is_skill:
		ability_id = str(ability.get("skill_id")) if "skill_id" in ability else ""
		ability_name = str(ability.get("skill_name")) if "skill_name" in ability else ability_id
	else:
		ability_id = str(ability.get("spell_id")) if "spell_id" in ability else ""
		ability_name = str(ability.get("spell_name")) if "spell_name" in ability else ability_id
	if ability_id.is_empty():
		ability_id = ability_name.to_snake_case()

	var base_rank: int = _character.get_ability_rank(ability_id)
	var pending: bool = false
	if is_skill:
		pending = _pending_skill_ranks.has(ability_id)
	else:
		pending = _pending_spell_ranks.has(ability_id)
	var shown_rank: int = base_rank + (1 if pending else 0)

	var btn: Button = Button.new()
	btn.toggle_mode = true
	btn.button_pressed = pending
	btn.text = "%s %s (Lvl %d)" % ["[x]" if pending else "[ ]", ability_name, shown_rank]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_color_override("font_color", COLOR_PENDING if pending else COLOR_TEXT)
	btn.toggled.connect(_on_ability_toggled.bind(ability_id, is_skill, btn))
	abilities_list.add_child(btn)


func _on_ability_toggled(pressed: bool, ability_id: String, is_skill: bool, btn: Button) -> void:
	if not is_instance_valid(_character):
		return

	if pressed:
		if is_skill:
			if _remaining_skill_points() <= 0:
				btn.set_pressed_no_signal(false)
				return
			_pending_skill_ranks[ability_id] = true
		else:
			if _remaining_spell_points() <= 0:
				btn.set_pressed_no_signal(false)
				return
			_pending_spell_ranks[ability_id] = true
	else:
		if is_skill:
			_pending_skill_ranks.erase(ability_id)
		else:
			_pending_spell_ranks.erase(ability_id)

	call_deferred("_rebuild_ability_rows")
	_refresh_points_label()
	_refresh_stat_rows()


func _on_stat_plus(stat_key: String) -> void:
	if _remaining_stat_points() <= 0:
		return
	_pending_stats[stat_key] = int(_pending_stats.get(stat_key, 0)) + 1
	_refresh_stat_rows()
	_refresh_points_label()


func _on_stat_minus(stat_key: String) -> void:
	var pending: int = int(_pending_stats.get(stat_key, 0))
	if pending <= 0:
		return
	_pending_stats[stat_key] = pending - 1
	_refresh_stat_rows()
	_refresh_points_label()


func _pending_stat_total() -> int:
	var total: int = 0
	for key: String in STAT_KEYS:
		total += int(_pending_stats.get(key, 0))
	return total


func _remaining_stat_points() -> int:
	if not is_instance_valid(_character):
		return 0
	return maxi(0, _character.unspent_stat_points - _pending_stat_total())


func _remaining_skill_points() -> int:
	if not is_instance_valid(_character):
		return 0
	return maxi(0, _character.unspent_skill_points - _pending_skill_ranks.size())


func _remaining_spell_points() -> int:
	if not is_instance_valid(_character):
		return 0
	return maxi(0, _character.unspent_spell_points - _pending_spell_ranks.size())


func _refresh_points_label() -> void:
	if not is_instance_valid(points_label) or not is_instance_valid(_character):
		return
	points_label.text = "STAT POINTS: %d  |  SKILL POINTS: %d  |  SPELL POINTS: %d" % [
		_remaining_stat_points(),
		_remaining_skill_points(),
		_remaining_spell_points(),
	]


func _render_header() -> void:
	if not is_instance_valid(_character):
		return

	if is_instance_valid(char_name_label):
		char_name_label.text = _character.name.to_upper()
	if is_instance_valid(level_label):
		level_label.text = "LEVEL %d" % _character.level
	if is_instance_valid(profession_label):
		var prof_title: String = "UNASSIGNED"
		if is_instance_valid(_character.profession) and not str(_character.profession.profession_name).is_empty():
			prof_title = str(_character.profession.profession_name)
		profession_label.text = prof_title.to_upper()

	if is_instance_valid(portrait_texture):
		var tex: Texture2D = null
		if not str(_character.portrait_path).is_empty() and ResourceLoader.exists(_character.portrait_path):
			tex = load(_character.portrait_path) as Texture2D
		elif _character.portrait is Texture2D:
			tex = _character.portrait
		elif is_instance_valid(_character.breed) and "portrait_path" in _character.breed:
			var breed_path: String = str(_character.breed.get("portrait_path"))
			if not breed_path.is_empty() and ResourceLoader.exists(breed_path):
				tex = load(breed_path) as Texture2D
		portrait_texture.texture = tex


func _on_confirm_pressed() -> void:
	if not is_instance_valid(_character):
		close()
		return

	var deltas: Dictionary = {}
	for key: String in STAT_KEYS:
		var amount: int = int(_pending_stats.get(key, 0))
		if amount > 0:
			deltas[key] = amount

	var skill_ups: Array[String] = []
	for ability_id: Variant in _pending_skill_ranks.keys():
		skill_ups.append(str(ability_id))

	var spell_ups: Array[String] = []
	for ability_id: Variant in _pending_spell_ranks.keys():
		spell_ups.append(str(ability_id))

	_character.apply_level_up_allocation(deltas, skill_ups, spell_ups)

	if is_instance_valid(GameState) and GameState.has_method("save_game"):
		GameState.save_game()

	if is_instance_valid(SignalBus) and SignalBus.has_signal(&"show_toast"):
		SignalBus.show_toast.emit("%s allocation confirmed." % _character.name, false)

	close()


func _on_cancel_pressed() -> void:
	close()
