# res://Scripts/UI/BattleVictoryPopup.gd
class_name BattleVictoryPopup
extends PanelContainer

signal victory_confirmed

@onready var enemies_label: Label = %EnemiesLabel
@onready var exp_label: Label = %ExpLabel
@onready var gold_label: Label = %GoldLabel
@onready var loot_grid: GridContainer = %LootGrid
@onready var no_loot_label: Label = %NoLootLabel
@onready var confirm_button: Button = %ConfirmButton


func _ready() -> void:
	if is_instance_valid(confirm_button):
		confirm_button.pressed.connect(_on_confirm_pressed)


## Populates the victory screen with combat statistics and item loot cards
func setup_victory_display(data: Dictionary) -> void:
	var enemies_killed: int = data.get("enemies_killed", 0)
	var total_xp: int = data.get("total_xp", 0)
	var total_gold: int = data.get("total_gold", 0)
	var living_members: int = data.get("living_members", 1)
	# var total_members: int = data.get("total_members", living_members)
	var raw_items: Variant = data.get("items_dropped", [])

	var xp_per_member: int = int(float(total_xp) / living_members) if living_members > 0 else 0

	# 1. Update Labels
	exp_label.text = "%d TOTAL | %d EACH" % [total_xp, xp_per_member]

	enemies_label.text = "%d" % enemies_killed
	gold_label.text = "₡ %d" % total_gold

	# 2. Clear Existing Item Grid Slots
	for child in loot_grid.get_children():
		child.queue_free()

	# 3. Process Loot Items
	var items: Array[ItemData] = []
	if raw_items is Array:
		for item in (raw_items as Array):
			if item is ItemData:
				items.append(item as ItemData)

	if items.is_empty():
		no_loot_label.visible = true
		loot_grid.visible = false
	else:
		no_loot_label.visible = false
		loot_grid.visible = true

		for item_data: ItemData in items:
			var card: PanelContainer = _create_loot_card(item_data)
			loot_grid.add_child(card)

	# 4. Focus Confirm Button for Keyboard/Gamepad navigation
	confirm_button.grab_focus()


## Square loot slot: icon alone when present, otherwise a text label. Never both.
func _create_loot_card(item: ItemData) -> PanelContainer:
	const SLOT_SIZE: float = 64.0
	var has_icon: bool = is_instance_valid(item.icon)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	if has_icon:
		style.bg_color = Color(0.08, 0.1, 0.12, 0.95)
		style.border_color = Color(0.35, 0.4, 0.45, 1.0)
	else:
		# Text-only: white tile, black label, sharp 1px border.
		style.bg_color = Color(1.0, 1.0, 1.0, 1.0)
		style.border_color = Color(0.0, 0.0, 0.0, 1.0)
	card.add_theme_stylebox_override("panel", style)

	var qty_suffix: String = " x%d" % item.quantity if item.quantity > 1 else ""
	var display_name: String = str(item.item_name) + qty_suffix

	if has_icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = item.icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(SLOT_SIZE - 10.0, SLOT_SIZE - 10.0)
		icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		card.add_child(icon_rect)
	else:
		var name_label := Label.new()
		name_label.text = display_name.to_upper()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))
		name_label.add_theme_font_size_override("font_size", 10)
		card.add_child(name_label)

	card.tooltip_text = "%s\n%s\nValue: ₡ %d" % [display_name, item.description, item.credit_value]
	return card


func _on_confirm_pressed() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_environment("collect-loot")
	victory_confirmed.emit()
