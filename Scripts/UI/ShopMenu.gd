# res://Scripts/UI/ShopMenu.gd
extends CanvasLayer
class_name ShopMenu

## Buy / sell party credits (₡). Opened via SignalBus.shop_requested.

const COLOR_TEXT: Color = Color(0.0, 1.0, 0.784, 1.0)
const COLOR_MUTED: Color = Color(0.45, 0.7, 0.65, 1.0)
const COLOR_GOLD: Color = Color(1.0, 0.85, 0.25, 1.0)
const COLOR_ERROR: Color = Color(1.0, 0.35, 0.35, 1.0)
const SELL_RATIO: float = 0.5

const DEFAULT_STOCK: Array[String] = [
	"res://Data/Items/Consumables/PotHealthVial.tres",
	"res://Data/Items/Consumables/PotManaVial.tres",
	"res://Data/Items/Consumables/CatnipPotion.tres",
	"res://Data/Items/Consumables/PotGroupHp25.tres",
	"res://Data/Items/Equipment/Broadsword.tres",
	"res://Data/Items/Equipment/IronBodyArmor.tres",
	"res://Data/Items/Equipment/Crossbow.tres",
	"res://Data/Items/Equipment/ElderStaff.tres",
]

@onready var overlay_panel: Control = %OverlayPanel as Control
@onready var title_label: Label = %TitleLabel as Label
@onready var gold_label: Label = %GoldLabel as Label
@onready var buy_list: VBoxContainer = %BuyList as VBoxContainer
@onready var sell_list: VBoxContainer = %SellList as VBoxContainer
@onready var close_button: Button = %CloseButton as Button
@onready var buy_tab: Button = %BuyTab as Button
@onready var sell_tab: Button = %SellTab as Button
@onready var buy_scroll: ScrollContainer = %BuyScroll as ScrollContainer
@onready var sell_scroll: ScrollContainer = %SellScroll as ScrollContainer

var _stock: Array[ItemData] = []
var _was_paused: bool = false
var _mode: String = "buy"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if is_instance_valid(overlay_panel):
		overlay_panel.visible = false
		KeyboardModal.attach(overlay_panel, _on_close_pressed)

	if is_instance_valid(close_button) and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if is_instance_valid(buy_tab) and not buy_tab.pressed.is_connected(_show_buy):
		buy_tab.pressed.connect(_show_buy)
	if is_instance_valid(sell_tab) and not sell_tab.pressed.is_connected(_show_sell):
		sell_tab.pressed.connect(_show_sell)

	var sb: Node = SignalBus
	if is_instance_valid(sb) and sb.has_signal(&"shop_requested"):
		if not sb.shop_requested.is_connected(_on_shop_requested):
			sb.shop_requested.connect(_on_shop_requested)
	if is_instance_valid(sb) and sb.has_signal(&"party_gold_changed"):
		if not sb.party_gold_changed.is_connected(_on_gold_changed):
			sb.party_gold_changed.connect(_on_gold_changed)


func _on_shop_requested(data: Dictionary = {}) -> void:
	open(data)


func open(data: Dictionary = {}) -> void:
	_load_stock(data)
	_refresh_gold()
	_show_buy()
	if not visible:
		_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	if is_instance_valid(overlay_panel):
		overlay_panel.visible = true
	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound("button-press")


func close() -> void:
	visible = false
	if is_instance_valid(overlay_panel):
		overlay_panel.visible = false
	get_tree().paused = _was_paused


func _on_close_pressed() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound("button-confirm")
	close()


func _on_gold_changed(_new_total: int, _amount_changed: int) -> void:
	if visible:
		_refresh_gold()


func _refresh_gold() -> void:
	if is_instance_valid(gold_label):
		gold_label.text = "%d" % GameState.party_gold


func _load_stock(data: Dictionary) -> void:
	_stock.clear()
	var paths: Array = data.get("stock_paths", DEFAULT_STOCK) as Array
	for path_var: Variant in paths:
		var path: String = str(path_var)
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var item: ItemData = load(path) as ItemData
		if is_instance_valid(item):
			_stock.append(item)


func _show_buy() -> void:
	_mode = "buy"
	if is_instance_valid(buy_scroll):
		buy_scroll.visible = true
	if is_instance_valid(sell_scroll):
		sell_scroll.visible = false
	_rebuild_buy_list()
	_style_tabs()


func _show_sell() -> void:
	_mode = "sell"
	if is_instance_valid(buy_scroll):
		buy_scroll.visible = false
	if is_instance_valid(sell_scroll):
		sell_scroll.visible = true
	_rebuild_sell_list()
	_style_tabs()


func _style_tabs() -> void:
	if is_instance_valid(buy_tab):
		buy_tab.modulate = COLOR_TEXT if _mode == "buy" else COLOR_MUTED
	if is_instance_valid(sell_tab):
		sell_tab.modulate = COLOR_TEXT if _mode == "sell" else COLOR_MUTED


func _rebuild_buy_list() -> void:
	_clear_children(buy_list)
	for item: ItemData in _stock:
		var price: int = maxi(1, item.credit_value)
		var row: HBoxContainer = _make_row(item.item_name, "₡ %d" % price, "BUY")
		var btn: Button = row.get_node("ActionButton") as Button
		btn.pressed.connect(_buy_item.bind(item, price))
		if GameState.party_gold < price:
			btn.disabled = true
			btn.modulate = COLOR_ERROR
		buy_list.add_child(row)


func _rebuild_sell_list() -> void:
	_clear_children(sell_list)
	var inv: Inventory = GameState.inventory as Inventory
	if not is_instance_valid(inv):
		return
	for item: ItemData in inv.get_items():
		if not is_instance_valid(item) or item.credit_value <= 0:
			continue
		var price: int = maxi(1, int(round(float(item.credit_value) * SELL_RATIO)))
		var qty_tag: String = "" if item.quantity <= 1 else " x%d" % item.quantity
		var row: HBoxContainer = _make_row(item.item_name + qty_tag, "₡ %d" % price, "SELL")
		var btn: Button = row.get_node("ActionButton") as Button
		btn.pressed.connect(_sell_item.bind(item, price))
		sell_list.add_child(row)
	if sell_list.get_child_count() == 0:
		var empty: Label = Label.new()
		empty.text = "Nothing worth selling."
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		sell_list.add_child(empty)


func _make_row(name_text: String, price_text: String, action_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := Label.new()
	name_label.text = name_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	row.add_child(name_label)
	var price_label := Label.new()
	price_label.text = price_text
	price_label.add_theme_color_override("font_color", COLOR_GOLD)
	row.add_child(price_label)
	var btn := Button.new()
	btn.name = "ActionButton"
	btn.text = action_text
	btn.custom_minimum_size = Vector2(72, 28)
	row.add_child(btn)
	return row


func _buy_item(item: ItemData, price: int) -> void:
	if not GameState.spend_gold(price):
		if is_instance_valid(SignalBus):
			SignalBus.show_toast.emit("Not enough credits.", true)
		_rebuild_buy_list()
		return
	var inv: Inventory = GameState.inventory as Inventory
	if not is_instance_valid(inv) or not inv.add_item(item, 1):
		GameState.add_gold(price) # refund
		if is_instance_valid(SignalBus):
			SignalBus.show_toast.emit("Inventory full.", true)
		return
	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound("button-confirm")
	if is_instance_valid(SignalBus):
		SignalBus.show_toast.emit("Bought %s (−₡ %d)" % [item.item_name, price], false)
	if GameState.has_method("save_game"):
		GameState.save_game()
	_refresh_gold()
	_rebuild_buy_list()


func _sell_item(item: ItemData, price: int) -> void:
	var inv: Inventory = GameState.inventory as Inventory
	if not is_instance_valid(inv):
		return
	if not inv.remove_item(item, 1):
		return
	GameState.add_gold(price)
	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound("button-confirm")
	if is_instance_valid(SignalBus):
		SignalBus.show_toast.emit("Sold %s (+₡ %d)" % [item.item_name, price], false)
	if GameState.has_method("save_game"):
		GameState.save_game()
	_refresh_gold()
	_rebuild_sell_list()


func _clear_children(node: Node) -> void:
	if not is_instance_valid(node):
		return
	for child: Node in node.get_children():
		child.queue_free()
