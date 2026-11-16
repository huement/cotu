@tool
extends EditorPlugin
## Registers the SettingsManager autoload and the addon's project settings.

const AUTOLOAD_NAME: String = "SettingsManager"
const SettingsManagerScript := preload("SettingsManager.gd")


func _enter_tree() -> void:
	_register_project_settings()


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, _get_addon_dir().path_join("SettingsManager.gd"))
	_register_project_settings()
	ProjectSettings.save()


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


func _get_addon_dir() -> String:
	return (get_script() as Script).resource_path.get_base_dir()


func _register_project_settings() -> void:
	_add_setting(
		SettingsManagerScript.SETTING_AUDIO_BUSES,
		SettingsManagerScript.DEFAULT_AUDIO_BUSES,
		TYPE_PACKED_STRING_ARRAY
	)
	_add_setting(SettingsManagerScript.SETTING_BUILTIN_FRENCH, true, TYPE_BOOL)


func _add_setting(setting_name: String, default_value: Variant, type: Variant.Type) -> void:
	if not ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, default_value)
	ProjectSettings.set_initial_value(setting_name, default_value)
	ProjectSettings.add_property_info({"name": setting_name, "type": type})
	ProjectSettings.set_as_basic(setting_name, true)
