@tool
class_name PartySlotPortrait
extends Control

# ==============================================================================
# 1. EXPORTED CONFIGURATION
# ==============================================================================
@export var slot_index: int = 0

@export_group("Layout & Dimensions")
## Target pixel dimensions for the cat portrait image frame
@export var portrait_size: Vector2 = Vector2(48.0, 48.0):
	set(value):
		portrait_size = value
		_apply_layout_settings()

## Vertical thickness (in pixels) for status bars
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


# ==============================================================================
# 2. NODE REFERENCES (% SceneUniqueNodes)
# ==============================================================================
@onready var content_vbox: VBoxContainer = %ContentVBox as VBoxContainer
@onready var portrait_frame: TextureRect = %PortraitFrame as TextureRect
@onready var portrait_texture: TextureRect = %PortraitTexture as TextureRect
@onready var hp_bar: ProgressBar = %HPBar as ProgressBar
@onready var mp_bar: ProgressBar = %MPBar as ProgressBar
@onready var atb_bar: ProgressBar = %ATBBar as ProgressBar


# ==============================================================================
# 3. DYNAMIC SIZING & LAYOUT
# ==============================================================================
func _ready() -> void:
	_apply_layout_settings()
	
	if not Engine.is_editor_hint():
		_connect_signal_listeners()

## Dynamically resizes frame, portrait, and status bars to matching widths
func _apply_layout_settings() -> void:
	# Tool-safe lookups prevent null errors in Editor Viewport
	var vbox: VBoxContainer = content_vbox if content_vbox else get_node_or_null("%ContentVBox") as VBoxContainer
	var frame_node: TextureRect = portrait_frame if portrait_frame else get_node_or_null("%PortraitFrame") as TextureRect
	var p_rect: TextureRect = portrait_texture if portrait_texture else get_node_or_null("%PortraitTexture") as TextureRect
	var h_bar: ProgressBar = hp_bar if hp_bar else get_node_or_null("%HPBar") as ProgressBar
	var m_bar: ProgressBar = mp_bar if mp_bar else get_node_or_null("%MPBar") as ProgressBar
	var a_bar: ProgressBar = atb_bar if atb_bar else get_node_or_null("%ATBBar") as ProgressBar

	# 1. Size Background Frame & Cat Portrait
	if frame_node:
		frame_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame_node.custom_minimum_size = portrait_size

	if p_rect:
		p_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# 2. Size Status Bars (Width locks strictly to portrait_size.x)
	if h_bar:
		h_bar.show_percentage = false
		h_bar.custom_minimum_size = Vector2(portrait_size.x, bar_height)

	if m_bar:
		m_bar.show_percentage = false
		m_bar.custom_minimum_size = Vector2(portrait_size.x, bar_height)
		m_bar.visible = show_mp_bar

	if a_bar:
		a_bar.show_percentage = false
		a_bar.custom_minimum_size = Vector2(portrait_size.x, bar_height)
		a_bar.visible = show_atb_bar

	# 3. Constrain Main VBox Container
	if vbox:
		vbox.custom_minimum_size = Vector2(portrait_size.x, 0.0)

	# 4. Calculate total height for root Control node
	var total_height: float = portrait_size.y + bar_height
	if show_mp_bar: total_height += bar_height
	if show_atb_bar: total_height += bar_height

	custom_minimum_size = Vector2(portrait_size.x, total_height)
	size = custom_minimum_size

func _connect_signal_listeners() -> void:
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb:
		if sb.has_signal("turn_meter_updated"):
			sb.turn_meter_updated.connect(_on_turn_meter_updated)
		if sb.has_signal("character_health_changed"):
			sb.character_health_changed.connect(_on_character_health_changed)


# ==============================================================================
# 4. DATA BINDING & STATS
# ==============================================================================
func setup_slot(character: CatCharacter) -> void:
	if character == null:
		hide()
		return
		
	show()
	_update_portrait_image(character)
	_refresh_stats(character)

func _update_portrait_image(character: CatCharacter) -> void:
	var p_rect: TextureRect = portrait_texture if portrait_texture else get_node_or_null("%PortraitTexture") as TextureRect
	if p_rect == null:
		return
		
	if "portrait_texture" in character and character.portrait_texture:
		p_rect.texture = character.portrait_texture
	elif "portrait_path" in character and not character.portrait_path.is_empty():
		if ResourceLoader.exists(character.portrait_path):
			p_rect.texture = load(character.portrait_path) as Texture2D
	else:
		var fallback_path: String = "res://ui/portrait.png"
		if ResourceLoader.exists(fallback_path):
			p_rect.texture = load(fallback_path) as Texture2D

# Updates The Portrait Progress Bars!
func _refresh_stats(character: CatCharacter) -> void:
	var h_bar: ProgressBar = hp_bar if hp_bar else get_node_or_null("%HPBar") as ProgressBar
	var m_bar: ProgressBar = mp_bar if mp_bar else get_node_or_null("%MPBar") as ProgressBar

	if character == null:
		return

	# 1. Resolve Health Values (Matches CatCharacter.gd)
	var hp_val: int = 0
	var max_hp_val: int = 10
	
	if "current_hp" in character:
		hp_val = character.current_hp
	elif "current_health" in character:
		hp_val = character.current_health

	if "max_hp" in character:
		max_hp_val = character.max_hp
	elif "max_health" in character:
		max_hp_val = character.max_health

	# 2. Assign Health Bar
	if h_bar:
		h_bar.min_value = 0
		h_bar.max_value = max(1, max_hp_val)
		h_bar.value = hp_val

	# 3. Resolve Energy/Mana Values (Matches CatCharacter.gd)
	var energy_val: int = 0
	var max_energy_val: int = 10
	
	if "current_energy" in character:
		energy_val = character.current_energy
	elif "current_mana" in character:
		energy_val = character.current_mana

	if "max_energy" in character:
		max_energy_val = character.max_energy
	elif "max_mana" in character:
		max_energy_val = character.max_mana # Fixed target variable name

	# 4. Assign Energy/Mana Bar
	if m_bar:
		m_bar.min_value = 0
		m_bar.max_value = max(1, max_energy_val)
		m_bar.value = energy_val


# ==============================================================================
# 5. SIGNAL CALLBACKS
# ==============================================================================
func _on_character_health_changed(target_slot: int, current_hp: int) -> void:
	var h_bar: ProgressBar = hp_bar if hp_bar else get_node_or_null("%HPBar") as ProgressBar
	if target_slot == slot_index and h_bar:
		var tween: Tween = create_tween()
		tween.tween_property(h_bar, "value", current_hp, 0.2)

func _on_turn_meter_updated(combatant_id: String, percent: float) -> void:
	var a_bar: ProgressBar = atb_bar if atb_bar else get_node_or_null("%ATBBar") as ProgressBar
	if show_atb_bar and combatant_id == "party_slot_%d" % slot_index and a_bar:
		a_bar.value = percent * a_bar.max_value
