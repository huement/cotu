# res://Scripts/UI/LootPopup.gd
class_name LootPopup
extends VBoxContainer

signal closed()

var _chest_ref: Node3D = null
var _loot_items: Array[ItemData] = []
var _gold_amount: int = 0


## Initializes and renders the loot container contents
func setup_loot_display(chest_node: Node3D, loot_items: Array[ItemData], gold: int) -> void:
	_chest_ref = chest_node
	_loot_items = loot_items
	_gold_amount = gold

	_build_ui()


func _build_ui() -> void:
	# Clear previous content
	for child in get_children():
		child.queue_free()

	add_theme_constant_override("separation", 12)

	# 1. Gold / Credits Display Banner
	if _gold_amount > 0:
		var gold_banner := PanelContainer.new()
		var gold_style := StyleBoxFlat.new()
		gold_style.bg_color = Color(0.12, 0.1, 0.02, 0.85)
		gold_style.border_color = Color(0.9, 0.75, 0.2, 0.9)
		gold_style.set_border_width_all(1)
		gold_style.corner_radius_top_left = 4
		gold_style.corner_radius_bottom_right = 4
		gold_banner.add_theme_stylebox_override("panel", gold_style)

		var gold_margin := MarginContainer.new()
		gold_margin.add_theme_constant_override("margin_left", 12)
		gold_margin.add_theme_constant_override("margin_top", 6)
		gold_margin.add_theme_constant_override("margin_right", 12)
		gold_margin.add_theme_constant_override("margin_bottom", 6)
		gold_banner.add_child(gold_margin)

		var gold_label := Label.new()
		gold_label.text = "💰 CREDITS FOUND: %d GOLD" % _gold_amount
		gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		gold_label.add_theme_font_size_override("font_size", 14)
		gold_margin.add_child(gold_label)

		add_child(gold_banner)

	# 2. Item Scroll List Container
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 140)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var item_vbox := VBoxContainer.new()
	item_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(item_vbox)

	if _loot_items.is_empty() and _gold_amount <= 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "The container is empty."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		item_vbox.add_child(empty_lbl)
	else:
		for item in _loot_items:
			if is_instance_valid(item):
				var row := _create_item_row(item)
				item_vbox.add_child(row)

	add_child(scroll)

	# 3. Action Buttons (COLLECT ALL / LEAVE)
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)

	var collect_btn := Button.new()
	collect_btn.text = "[ COLLECT ALL ]"
	collect_btn.custom_minimum_size = Vector2(130, 36)
	collect_btn.focus_mode = Control.FOCUS_NONE

	var collect_style := StyleBoxFlat.new()
	collect_style.bg_color = Color(0.0, 0.7, 0.6, 0.9)
	collect_style.corner_radius_top_left = 3
	collect_style.corner_radius_bottom_right = 3
	collect_btn.add_theme_stylebox_override("normal", collect_style)
	collect_btn.add_theme_color_override("font_color", Color.BLACK)
	collect_btn.add_theme_font_size_override("font_size", 13)

	var leave_btn := Button.new()
	leave_btn.text = "[ LEAVE ]"
	leave_btn.custom_minimum_size = Vector2(110, 36)
	leave_btn.focus_mode = Control.FOCUS_NONE

	var leave_style := StyleBoxFlat.new()
	leave_style.bg_color = Color(0.25, 0.28, 0.32, 0.9)
	leave_style.corner_radius_top_left = 3
	leave_style.corner_radius_bottom_right = 3
	leave_btn.add_theme_stylebox_override("normal", leave_style)
	leave_btn.add_theme_color_override("font_color", Color.WHITE)
	leave_btn.add_theme_font_size_override("font_size", 13)

	collect_btn.pressed.connect(_on_collect_all_pressed)
	leave_btn.pressed.connect(_on_leave_pressed)

	btn_hbox.add_child(collect_btn)
	btn_hbox.add_child(leave_btn)
	add_child(btn_hbox)


func _create_item_row(item: ItemData) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.12, 0.15, 0.85)
	style.border_color = Color(0.0, 0.6, 0.55, 0.5)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if is_instance_valid(item.icon):
		icon_rect.texture = item.icon
	hbox.add_child(icon_rect)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	var qty_suffix: String = " (x%d)" % item.quantity if item.quantity > 1 else ""
	name_lbl.text = item.item_name.to_upper() + qty_suffix
	name_lbl.add_theme_color_override("font_color", Color(0.0, 0.95, 0.85))
	name_lbl.add_theme_font_size_override("font_size", 12)
	text_vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item.description
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.8))
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.clip_text = true
	text_vbox.add_child(desc_lbl)

	hbox.add_child(text_vbox)
	return panel


func _on_collect_all_pressed() -> void:
	var gs: Node = get_tree().root.get_node_or_null("GameState")

	# 1. Add gold to wallet
	if _gold_amount > 0 and is_instance_valid(gs) and gs.has_method("add_gold"):
		gs.add_gold(_gold_amount)

	# 2. Transfer items into inventory
	if is_instance_valid(gs) and "inventory" in gs and gs.inventory != null:
		for item in _loot_items:
			if is_instance_valid(item) and gs.inventory.has_method("add_item"):
				gs.inventory.add_item(item)

	# 3. Mark chest as looted & save
	if is_instance_valid(_chest_ref) and _chest_ref.has_method("mark_as_looted"):
		_chest_ref.call("mark_as_looted")

	var item_count: int = _loot_items.size()
	SignalBus.show_toast.emit("Loot collected! (+%d Gold, %d Items)" % [_gold_amount, item_count], false)

	closed.emit()


func _on_leave_pressed() -> void:
	closed.emit()
