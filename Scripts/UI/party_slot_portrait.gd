# res://Scripts/UI/party_slot_portrait.gd
class_name PartySlotPortrait
extends Control

@export var slot_index: int = 0
@export var slot_size: Vector2 = Vector2(76.0, 76.0)

@onready var portrait_texture: TextureRect = %PortraitTexture as TextureRect
@onready var hp_bar: ProgressBar = %HPBar as ProgressBar
@onready var mp_bar: ProgressBar = %MPBar as ProgressBar
@onready var atb_bar: ProgressBar = %ATBBar as ProgressBar

var bound_character: CatCharacter = null

func _ready() -> void:
	_configure_texture_scaling()
	
	if hp_bar: hp_bar.show_percentage = false
	if mp_bar: mp_bar.show_percentage = false
	if atb_bar: atb_bar.show_percentage = false
	
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb:
		if sb.has_signal("turn_meter_updated"):
			sb.turn_meter_updated.connect(_on_turn_meter_updated)
		if sb.has_signal("character_health_changed"):
			sb.character_health_changed.connect(_on_character_health_changed)

## Forces the TextureRect to ignore native image resolution and fit the slot
func _configure_texture_scaling() -> void:
	if portrait_texture:
		portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_texture.custom_minimum_size = slot_size
		portrait_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # Crisp pixel art rendering
		
func setup_slot(character: CatCharacter) -> void:
	bound_character = character
	
	if bound_character == null:
		hide()
		return
		
	show()
	_update_portrait_image()
	_refresh_stats()

func _update_portrait_image() -> void:
	if bound_character == null or portrait_texture == null:
		return
		
	if "portrait_texture" in bound_character and bound_character.portrait_texture:
		portrait_texture.texture = bound_character.portrait_texture
	elif "portrait_path" in bound_character and not bound_character.portrait_path.is_empty():
		if ResourceLoader.exists(bound_character.portrait_path):
			portrait_texture.texture = load(bound_character.portrait_path) as Texture2D
	else:
		var fallback_path: String = "res://ui/portrait.png"
		if ResourceLoader.exists(fallback_path):
			portrait_texture.texture = load(fallback_path) as Texture2D

func _refresh_stats() -> void:
	if bound_character == null:
		return
		
	if hp_bar and "max_health" in bound_character and "current_health" in bound_character:
		hp_bar.max_value = bound_character.max_health
		hp_bar.value = bound_character.current_health
		
	if mp_bar and "max_mana" in bound_character and "current_mana" in bound_character:
		mp_bar.max_value = bound_character.max_mana
		mp_bar.value = bound_character.current_mana

func _on_character_health_changed(target_slot: int, current_hp: int) -> void:
	if target_slot == slot_index and hp_bar:
		var tween: Tween = create_tween()
		tween.tween_property(hp_bar, "value", current_hp, 0.2)

func _on_turn_meter_updated(combatant_id: String, percent: float) -> void:
	if combatant_id == "party_slot_%d" % slot_index and atb_bar:
		atb_bar.value = percent * atb_bar.max_value
