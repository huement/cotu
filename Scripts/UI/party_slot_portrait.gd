# res://Scripts/UI/PartySlotPortrait.gd
@tool
class_name PartySlotPortrait
extends Control

@export var slot_index: int = 0

@export_group("Layout & Dimensions")
@export var portrait_size: Vector2 = Vector2(48.0, 48.0):
	set(value):
		portrait_size = value
		_apply_layout_settings()

@export var bar_height: float = 4.0:
	set(value):
		bar_height = value
		_apply_layout_settings()

@export_group("Feature Toggles")
@export var show_atb_bar: bool = true:
	set(value):
		show_atb_bar = value
		_apply_layout_settings()

@export var show_mp_bar: bool = true:
	set(value):
		show_mp_bar = value
		_apply_layout_settings()

@onready var content_vbox: VBoxContainer = %ContentVBox as VBoxContainer
@onready var portrait_frame: TextureRect = %PortraitFrame as TextureRect
@onready var portrait_texture: TextureRect = %PortraitTexture as TextureRect
@onready var hp_bar: ProgressBar = %HPBar as ProgressBar
@onready var mp_bar: ProgressBar = %MPBar as ProgressBar
@onready var atb_bar: ProgressBar = %ATBBar as ProgressBar
@onready var highlight_rect: TextureRect = %Highlight as TextureRect


func _ready() -> void:
	_apply_layout_settings()
	if is_instance_valid(highlight_rect):
		highlight_rect.hide()

	if not Engine.is_editor_hint():
		_connect_signal_listeners()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_tree().root.has_node("SignalBus"):
			SignalBus.portrait_clicked.emit(slot_index)


func _apply_layout_settings() -> void:
	var vbox: VBoxContainer = content_vbox if content_vbox else get_node_or_null("%ContentVBox") as VBoxContainer
	var frame_node: TextureRect = portrait_frame if portrait_frame else get_node_or_null("%PortraitFrame") as TextureRect
	var p_rect: TextureRect = portrait_texture if portrait_texture else get_node_or_null("%PortraitTexture") as TextureRect
	var h_bar: ProgressBar = hp_bar if hp_bar else get_node_or_null("%HPBar") as ProgressBar
	var m_bar: ProgressBar = mp_bar if mp_bar else get_node_or_null("%MPBar") as ProgressBar
	var a_bar: ProgressBar = atb_bar if atb_bar else get_node_or_null("%ATBBar") as ProgressBar

	if frame_node:
		frame_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame_node.custom_minimum_size = portrait_size
		frame_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if p_rect:
		p_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if h_bar:
		h_bar.show_percentage = false
		h_bar.custom_minimum_size = Vector2(portrait_size.x, bar_height)
		h_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if m_bar:
		m_bar.show_percentage = false
		m_bar.custom_minimum_size = Vector2(portrait_size.x, bar_height)
		m_bar.visible = show_mp_bar
		m_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if a_bar:
		a_bar.show_percentage = false
		a_bar.custom_minimum_size = Vector2(portrait_size.x, bar_height)
		a_bar.visible = show_atb_bar
		a_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if vbox:
		vbox.custom_minimum_size = Vector2(portrait_size.x, 0.0)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var total_height: float = portrait_size.y + bar_height
	if show_mp_bar:
		total_height += bar_height
	if show_atb_bar:
		total_height += bar_height

	custom_minimum_size = Vector2(portrait_size.x, total_height)
	size = custom_minimum_size


func _connect_signal_listeners() -> void:
	var sb: Node = SignalBus
	if is_instance_valid(sb):
		if sb.has_signal("turn_meter_updated") and not sb.turn_meter_updated.is_connected(_on_turn_meter_updated):
			sb.turn_meter_updated.connect(_on_turn_meter_updated)
		if sb.has_signal("character_health_changed") and not sb.character_health_changed.is_connected(_on_character_health_changed):
			sb.character_health_changed.connect(_on_character_health_changed)
		if sb.has_signal("character_mana_changed") and not sb.character_mana_changed.is_connected(_on_character_mana_changed):
			sb.character_mana_changed.connect(_on_character_mana_changed)


func setup_slot(character: CatCharacter) -> void:
	if character == null:
		hide()
		return

	show()
	_update_portrait_image(character)
	_refresh_stats(character)

	var a_bar: ProgressBar = atb_bar if atb_bar else get_node_or_null("%ATBBar") as ProgressBar
	if is_instance_valid(a_bar):
		a_bar.min_value = 0.0
		a_bar.max_value = 100.0
		a_bar.value = 0.0


func _update_portrait_image(character: CatCharacter) -> void:
	var p_rect: TextureRect = portrait_texture if portrait_texture else get_node_or_null("%PortraitTexture") as TextureRect
	if p_rect == null:
		return

	if "portrait" in character and character.portrait:
		p_rect.texture = character.portrait
	elif "portrait_texture" in character and character.portrait_texture:
		p_rect.texture = character.portrait_texture
	elif "portrait_path" in character and not character.portrait_path.is_empty():
		if ResourceLoader.exists(character.portrait_path):
			p_rect.texture = load(character.portrait_path) as Texture2D


func _refresh_stats(character: CatCharacter) -> void:
	var h_bar: ProgressBar = hp_bar if hp_bar else get_node_or_null("%HPBar") as ProgressBar
	var m_bar: ProgressBar = mp_bar if mp_bar else get_node_or_null("%MPBar") as ProgressBar

	if character == null:
		return

	var hp_val: int = character.get("current_hp") if "current_hp" in character else 10
	var max_hp_val: int = character.get("max_hp") if "max_hp" in character else 10

	if h_bar:
		h_bar.min_value = 0
		h_bar.max_value = max(1, max_hp_val)
		h_bar.value = hp_val

	var energy_val: int = character.get("current_energy") if "current_energy" in character else 10
	var max_energy_val: int = character.get("max_energy") if "max_energy" in character else 10

	if m_bar:
		m_bar.min_value = 0
		m_bar.max_value = max(1, max_energy_val)
		m_bar.value = energy_val


func set_active(is_active: bool) -> void:
	var h_rect: Control = highlight_rect if is_instance_valid(highlight_rect) else get_node_or_null("%Highlight") as Control
	if is_instance_valid(h_rect):
		h_rect.visible = is_active


func _on_character_health_changed(target_slot: int, current_hp: int) -> void:
	var h_bar: ProgressBar = hp_bar if hp_bar else get_node_or_null("%HPBar") as ProgressBar
	if target_slot == slot_index and is_instance_valid(h_bar):
		var tween: Tween = create_tween()
		tween.tween_property(h_bar, "value", current_hp, 0.2)


func _on_character_mana_changed(target_slot: int, current_mp: int) -> void:
	var m_bar: ProgressBar = mp_bar if mp_bar else get_node_or_null("%MPBar") as ProgressBar
	if target_slot == slot_index and is_instance_valid(m_bar):
		var tween: Tween = create_tween()
		tween.tween_property(m_bar, "value", current_mp, 0.2)


func _on_turn_meter_updated(combatant_id: String, percent: float) -> void:
	var a_bar: ProgressBar = atb_bar if atb_bar else get_node_or_null("%ATBBar") as ProgressBar
	if show_atb_bar and combatant_id == "party_slot_%d" % slot_index and is_instance_valid(a_bar):
		a_bar.value = percent * a_bar.max_value
