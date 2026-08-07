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


## Builds a styled mini-card for an individual dropped item
func _create_loot_card(item: ItemData) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(120, 60)

	# Style Box for Item Card
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.9)
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_color = Color(0.0, 0.8, 0.9, 0.8) # Neon Cyan
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Item Icon
	if is_instance_valid(item.icon):
		var icon_rect := TextureRect.new()
		icon_rect.texture = item.icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.custom_minimum_size = Vector2(32, 32)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(icon_rect)

	# Item Name Label
	var name_label := Label.new()
	name_label.text = item.item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	hbox.add_child(name_label)

	card.add_child(hbox)
	card.tooltip_text = "%s\nValue: ₡ %d" % [item.description, item.credit_value]
	return card


func _on_confirm_pressed() -> void:
	victory_confirmed.emit()
