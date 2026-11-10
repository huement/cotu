# res://Scripts/UI/AbilityLearnScreen.gd
class_name AbilityLearnScreen
extends CanvasLayer
## "Learn a new spell / skill" picker, opened by using a Spell Book or Skill Crystal on a party member
## (Inventory.use_item). Lists what that character can learn now (AbilityRules) plus the class's
## not-yet-available spells greyed out with the reason. Pauses the game while open.
##
##   var learned: Resource = await AbilityLearnScreen.open(get_tree(), cat, &"SPELL")   # null = cancelled
##
## The caller decides what to do with the result (Inventory consumes the item only when something was learned).

signal finished(learned: Resource)

const KIND_SPELL: StringName = &"SPELL"
const KIND_SKILL: StringName = &"SKILL"

var character: CatCharacter
var kind: StringName = KIND_SPELL

var _selected: Resource = null
var _rows: Dictionary = {} # Button -> Resource
var _list: VBoxContainer
var _detail_title: Label
var _detail_meta: Label
var _detail_body: Label
var _learn_button: Button
var _cancel_button: Button
var _was_paused: bool = false
var _done: bool = false


## Spell Book -> &"SPELL", Skill Crystal -> &"SKILL", anything else -> &"".
static func kind_for_item(item: ItemData) -> StringName:
	if item == null:
		return &""
	match item.effects.strip_edges().to_lower():
		"learnspell":
			return KIND_SPELL
		"learnskill":
			return KIND_SKILL
	return &""


static func open(tree: SceneTree, cat: CatCharacter, ability_kind: StringName) -> Resource:
	var screen := AbilityLearnScreen.new()
	screen.character = cat
	screen.kind = ability_kind
	tree.root.add_child(screen)
	return await screen.finished


func _ready() -> void:
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	_build()
	_populate()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(null)


func _finish(learned: Resource) -> void:
	if _done:
		return
	_done = true
	get_tree().paused = _was_paused
	finished.emit(learned)
	queue_free()


# ------------------------------------------------------------------------------
func _populate() -> void:
	var learnable: Array[Resource] = []
	var upcoming: Array[Resource] = []
	if kind == KIND_SPELL:
		learnable.assign(AbilityRules.learnable_spells(character, AbilityLibrary.all_spells()))
		upcoming.assign(AbilityRules.upcoming_spells(character, AbilityLibrary.all_spells()))
	else:
		learnable.assign(AbilityRules.learnable_skills(character, AbilityLibrary.all_skills()))

	var first: Button = null
	if learnable.is_empty():
		_list.add_child(_muted_label(_empty_reason()))
	for ability: Resource in learnable:
		var b: Button = _make_row(ability, "")
		if first == null:
			first = b
	if not upcoming.is_empty():
		var header: Label = _muted_label("LATER")
		header.add_theme_color_override("font_color", ShardsMenuStyle.COLOR_ACCENT)
		_list.add_child(header)
		for ability: Resource in upcoming:
			_make_row(ability, AbilityRules.spell_block_reason(character, ability as SpellData))

	if first != null:
		first.grab_focus.call_deferred()
		_select(first)
	else:
		_show_detail(null, "")
		_cancel_button.grab_focus.call_deferred()


func _empty_reason() -> String:
	if kind == KIND_SKILL:
		return "%s already knows every skill open to their class and breed." % character.name
	if AbilityRules.spellbooks_of(character).is_empty():
		return "%s's class can't use spellbooks." % character.name
	var unlock: int = AbilityRules.spell_unlock_level(character)
	if character.level < unlock:
		return "%s's spellbook opens at level %d." % [character.name, unlock]
	return "%s knows every spell available at their level." % character.name


func _make_row(ability: Resource, blocked_reason: String) -> Button:
	var b: Button = Button.new()
	b.text = "%s    %s" % [AbilityInfo.display_name(ability), _short_meta(ability)]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 34)
	ShardsMenuStyle.style_button(b, ShardsMenuStyle.COLOR_ACCENT, 14)
	if not blocked_reason.is_empty():
		b.text = "%s    — %s" % [AbilityInfo.display_name(ability), blocked_reason]
		b.modulate = Color(1, 1, 1, 0.45)
		b.set_meta(&"blocked", blocked_reason)
	b.focus_entered.connect(_select.bind(b))
	b.mouse_entered.connect(_select.bind(b))
	b.pressed.connect(_on_row_pressed.bind(b))
	_rows[b] = ability
	_list.add_child(b)
	return b


func _short_meta(ability: Resource) -> String:
	if ability is SpellData:
		var s := ability as SpellData
		return "T%d · %d MP" % [s.tier, s.energy_cost]
	var k := ability as SkillData
	return "%d MP" % k.energy_cost if k.energy_cost > 0 else "passive"


func _select(b: Button) -> void:
	_selected = _rows.get(b) as Resource
	var blocked: String = str(b.get_meta(&"blocked", ""))
	_show_detail(_selected, blocked)
	_learn_button.disabled = _selected == null or not blocked.is_empty()


func _on_row_pressed(b: Button) -> void:
	_select(b)
	if not _learn_button.disabled:
		_on_learn_pressed()


func _show_detail(ability: Resource, blocked: String) -> void:
	if ability == null:
		_detail_title.text = ""
		_detail_meta.text = ""
		_detail_body.text = ""
		_learn_button.disabled = true
		return
	_detail_title.text = AbilityInfo.display_name(ability).to_upper()
	var meta: PackedStringArray = []
	if ability is SpellData:
		var s := ability as SpellData
		meta.append("%s spellbook" % String(SpellData.SpellbookType.keys()[s.spellbook]).capitalize())
		meta.append("Tier %d" % s.tier)
		meta.append("%d MP" % s.energy_cost)
		meta.append(String(SpellData.TargetType.keys()[s.target_type]).replace("_", " ").capitalize())
	else:
		var k := ability as SkillData
		meta.append(String(SkillData.SkillType.keys()[k.skill_type]).capitalize() + " skill")
		meta.append("%d MP" % k.energy_cost if k.energy_cost > 0 else "No cost")
	meta.append(AbilityInfo.category(ability).capitalize())
	_detail_meta.text = "  ·  ".join(meta)
	var desc: String = str(ability.get("description")) if "description" in ability else ""
	_detail_body.text = desc + ("\n\n" + blocked.to_upper() if not blocked.is_empty() else "")


func _on_learn_pressed() -> void:
	if _selected == null or _learn_button.disabled:
		return
	if not AbilityRules.teach(character, _selected):
		return
	if is_instance_valid(AudioManager) and AudioManager.has_method("play_ui_sound"):
		AudioManager.play_ui_sound("button-confirm")
	SignalBus.show_toast.emit("%s learned %s!" % [character.name, AbilityInfo.display_name(_selected)], false)
	_finish(_selected)


# ------------------------------------------------------------------------------
func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 480)
	panel.add_theme_stylebox_override("panel", ShardsMenuStyle.panel_box())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.text = "LEARN A NEW SPELL" if kind == KIND_SPELL else "LEARN A NEW SKILL"
	ShardsMenuStyle.style_title(title, 26)
	root.add_child(title)
	var sub := Label.new()
	var cls: String = AbilityRules.class_name_of(character)
	sub.text = "%s  ·  %s  ·  LEVEL %d" % [character.name.to_upper(), cls.to_upper() if not cls.is_empty() else "NO CLASS", character.level]
	ShardsMenuStyle.style_body(sub, 14, true)
	root.add_child(sub)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	root.add_child(columns)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	columns.add_child(detail)
	_detail_title = Label.new()
	ShardsMenuStyle.style_title(_detail_title, 20)
	detail.add_child(_detail_title)
	_detail_meta = Label.new()
	ShardsMenuStyle.style_body(_detail_meta, 13, true)
	_detail_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_detail_meta)
	_detail_body = Label.new()
	ShardsMenuStyle.style_body(_detail_body, 15)
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(_detail_body)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 16)
	root.add_child(buttons)
	_cancel_button = Button.new()
	_cancel_button.text = "CANCEL"
	_cancel_button.custom_minimum_size = Vector2(150, 40)
	ShardsMenuStyle.style_button(_cancel_button, ShardsMenuStyle.COLOR_DANGER, 16)
	_cancel_button.pressed.connect(_finish.bind(null))
	buttons.add_child(_cancel_button)
	_learn_button = Button.new()
	_learn_button.text = "LEARN"
	_learn_button.custom_minimum_size = Vector2(150, 40)
	ShardsMenuStyle.style_button(_learn_button, ShardsMenuStyle.COLOR_ACCENT, 16)
	_learn_button.pressed.connect(_on_learn_pressed)
	buttons.add_child(_learn_button)


func _muted_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ShardsMenuStyle.style_body(l, 14, true)
	return l
