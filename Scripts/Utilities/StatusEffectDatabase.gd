# res://Scripts/Utilities/StatusEffectDatabase.gd
extends Node
class_name StatusEffectDatabase

const EFFECTS_DIR: String = "res://Data/StatusEffects/"
static var _registry: Dictionary = {}

static func initialize() -> void:
	_registry.clear()
	# Export-safe folder listing (exported builds only have *.remap files on disk).
	for res: Resource in AbilityLibrary.load_all(EFFECTS_DIR):
		var effect_res := res as StatusEffectData
		if is_instance_valid(effect_res) and not effect_res.effect_id.is_empty():
			_registry[effect_res.effect_id] = effect_res

static func get_effect(effect_id: String) -> StatusEffectData:
	if _registry.is_empty():
		initialize()
	return _registry.get(effect_id, null) as StatusEffectData

## PUBLIC API: Helper that returns full display data & preloaded texture for a string ID
static func get_effect_info(effect_id: String) -> Dictionary:
	var effect := get_effect(effect_id)
	if not is_instance_valid(effect):
		return {}

	var icon_texture: Texture2D = null
	if not effect.icon_path.is_empty() and ResourceLoader.exists(effect.icon_path):
		icon_texture = load(effect.icon_path) as Texture2D

	return {
		"resource": effect,
		"id": effect.effect_id,
		"name": effect.name,
		"description": effect.description,
		"level": effect.level,
		"type": effect.type,
		"duration": effect.duration,
		"modifier_stat": effect.modifier_stat,
		"modifier_value": effect.modifier_value,
		"icon": icon_texture,
		"is_positive": effect.type == StatusEffectData.EffectType.POSITIVE
	}
