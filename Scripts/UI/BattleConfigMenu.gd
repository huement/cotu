# res://Scripts/UI/BattleConfigMenu.gd
class_name BattleConfigMenu
extends CanvasLayer
## In-world debug / test menu for picking a custom enemy pack (main x1-3 + optional minions).
## Opened by BattleConfigTerminal. Emits `fight_confirmed` with a Dictionary:
##   main_path: String, main_count: int, minion_a_path: String, minion_b_path: String
## Empty minion paths mean that slot is unused. Max pack size is 5.

signal fight_confirmed(config: Dictionary)
signal cancelled

const ENEMY_DIR: String = "res://Data/Enemies/"
const NONE_LABEL: String = "(none)"
const MAX_PACK: int = 5

var _root: Control
var _main_pick: OptionButton
var _count_pick: OptionButton
var _minion_a_pick: OptionButton
var _minion_b_pick: OptionButton
var _summary: Label
var _confirm_btn: Button
var _enemy_paths: PackedStringArray = PackedStringArray()


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()


func is_open() -> bool:
	return is_instance_valid(_root) and _root.visible


func open() -> void:
	if not is_instance_valid(_root):
		_build()
	_refresh_enemies()
	_update_summary()
	_root.show()


func close() -> void:
	if is_instance_valid(_root):
		_root.hide()


## Every EnemyData .tres under Data/Enemies, sorted by display name. Export-safe.
static func all_enemy_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for file_name: String in AbilityLibrary.list_resource_files(ENEMY_DIR):
		var path: String = ENEMY_DIR + file_name
		var data: EnemyData = load(path) as EnemyData
		if data == null:
			continue
		var label: String = data.enemy_name.strip_edges()
		if label.is_empty():
			label = file_name.get_basename()
		entries.append({"path": path, "label": label, "file": file_name.get_basename()})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["label"]).nocasecmp_to(str(b["label"])) < 0)
	return entries


func _build() -> void:
	if is_instance_valid(_root):
		return
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CreationUI.glass_panel(CreationUI.PINK))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260.0
	panel.offset_right = 260.0
	panel.offset_top = -240.0
	panel.offset_bottom = 240.0
	_root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	col.add_child(CreationUI.title("BATTLE CONFIG", 22, CreationUI.PINK))
	col.add_child(CreationUI.wrap(CreationUI.body(
		"Pick a main enemy (x1–x3) and up to two optional minions. Max pack: 5.", 13, Color(CreationUI.WHITE, 0.65))))

	col.add_child(_section("MAIN ENEMY"))
	_main_pick = _option()
	_main_pick.item_selected.connect(_on_selection_changed)
	col.add_child(_main_pick)

	col.add_child(_section("PACK SIZE"))
	_count_pick = _option()
	for n: int in [1, 2, 3]:
		_count_pick.add_item("x %d" % n, n)
	_count_pick.select(0)
	_count_pick.item_selected.connect(_on_selection_changed)
	col.add_child(_count_pick)

	col.add_child(_section("MINION A"))
	_minion_a_pick = _option()
	_minion_a_pick.item_selected.connect(_on_selection_changed)
	col.add_child(_minion_a_pick)

	col.add_child(_section("MINION B"))
	_minion_b_pick = _option()
	_minion_b_pick.item_selected.connect(_on_selection_changed)
	col.add_child(_minion_b_pick)

	_summary = CreationUI.body("", 13, CreationUI.YELLOW)
	col.add_child(_summary)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var cancel: Button = CreationUI.action_button("CANCEL", CreationUI.GREY, false, 16)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_on_cancel)
	row.add_child(cancel)
	_confirm_btn = CreationUI.action_button("FIGHT", CreationUI.GREEN, true, 16)
	_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_btn.pressed.connect(_on_confirm)
	row.add_child(_confirm_btn)


func _section(text: String) -> Label:
	return CreationUI.title(text, 13, Color(CreationUI.WHITE, 0.55))


func _option() -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(0, 34)
	o.add_theme_font_override("font", ShardsMenuStyle.BODY_FONT)
	o.add_theme_font_size_override("font_size", 14)
	o.fit_to_longest_item = false
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return o


func _refresh_enemies() -> void:
	var keep_main: String = _selected_path(_main_pick)
	var keep_a: String = _selected_path(_minion_a_pick)
	var keep_b: String = _selected_path(_minion_b_pick)
	_enemy_paths.clear()
	_main_pick.clear()
	_fill_minion_pick(_minion_a_pick)
	_fill_minion_pick(_minion_b_pick)

	var entries: Array[Dictionary] = all_enemy_entries()
	for entry: Dictionary in entries:
		var path: String = str(entry["path"])
		var label: String = "%s  ·  %s" % [str(entry["label"]), str(entry["file"])]
		_enemy_paths.append(path)
		_main_pick.add_item(label)
		_main_pick.set_item_metadata(_main_pick.item_count - 1, path)
		_minion_a_pick.add_item(label)
		_minion_a_pick.set_item_metadata(_minion_a_pick.item_count - 1, path)
		_minion_b_pick.add_item(label)
		_minion_b_pick.set_item_metadata(_minion_b_pick.item_count - 1, path)

	_select_path(_main_pick, keep_main, 0)
	_select_path(_minion_a_pick, keep_a, 0) # 0 = (none)
	_select_path(_minion_b_pick, keep_b, 0)


func _fill_minion_pick(pick: OptionButton) -> void:
	pick.clear()
	pick.add_item(NONE_LABEL)
	pick.set_item_metadata(0, "")


func _select_path(pick: OptionButton, path: String, fallback: int) -> void:
	if path.is_empty():
		pick.select(clampi(fallback, 0, maxi(0, pick.item_count - 1)))
		return
	for i: int in pick.item_count:
		if str(pick.get_item_metadata(i)) == path:
			pick.select(i)
			return
	pick.select(clampi(fallback, 0, maxi(0, pick.item_count - 1)))


func _selected_path(pick: OptionButton) -> String:
	if not is_instance_valid(pick) or pick.selected < 0:
		return ""
	return str(pick.get_item_metadata(pick.selected))


func _main_count() -> int:
	if _count_pick.selected < 0:
		return 1
	return maxi(1, _count_pick.get_item_id(_count_pick.selected))


func _pack_size() -> int:
	var n: int = _main_count()
	if not _selected_path(_minion_a_pick).is_empty():
		n += 1
	if not _selected_path(_minion_b_pick).is_empty():
		n += 1
	return n


func _on_selection_changed(_idx: int = 0) -> void:
	_update_summary()


func _update_summary() -> void:
	var size: int = _pack_size()
	var over: bool = size > MAX_PACK or _main_pick.item_count == 0
	_summary.text = "Pack: %d / %d enemies" % [size, MAX_PACK]
	_summary.add_theme_color_override("font_color", CreationUI.RED if over else CreationUI.YELLOW)
	_confirm_btn.disabled = over or _main_pick.item_count == 0


func _on_cancel() -> void:
	close()
	cancelled.emit()


func _on_confirm() -> void:
	if _confirm_btn.disabled:
		return
	var config: Dictionary = {
		"main_path": _selected_path(_main_pick),
		"main_count": _main_count(),
		"minion_a_path": _selected_path(_minion_a_pick),
		"minion_b_path": _selected_path(_minion_b_pick),
	}
	close()
	fight_confirmed.emit(config)
