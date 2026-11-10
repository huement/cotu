@tool
extends EditorPlugin
## Registers the MenuKit autoload and the kit's project settings
## (Project > Project Settings > Menu Kit, with "Advanced Settings" on).

const AUTOLOAD_NAME: String = "MenuKit"

static func _settings() -> Array:
	return [
		["menu_kit/style/style", "neon", TYPE_STRING, PROPERTY_HINT_NONE, ""],
		["menu_kit/sounds/pack", "soft", TYPE_STRING, PROPERTY_HINT_ENUM, "soft,felt,minimal,off"],
		["menu_kit/localization/builtin_french", true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
		["menu_kit/controls/rebindable_actions", PackedStringArray(), TYPE_PACKED_STRING_ARRAY, PROPERTY_HINT_NONE, ""],
		["menu_kit/controls/excluded_prefixes", PackedStringArray(["ui_"]), TYPE_PACKED_STRING_ARRAY, PROPERTY_HINT_NONE, ""],
		["menu_kit/camera/apply_fov", true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
		["menu_kit/camera/default_fov", 75.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "60,110,1"],
		["menu_kit/scenes/main_menu", "", TYPE_STRING, PROPERTY_HINT_FILE, "*.tscn,*.scn"],
	]


func _enter_tree() -> void:
	_register_project_settings()


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, _addon_dir().path_join("menu_kit.gd"))
	_register_project_settings()
	# Needed by the "Read menus aloud" setting.
	if not ProjectSettings.has_setting("audio/general/text_to_speech"):
		ProjectSettings.set_setting("audio/general/text_to_speech", true)
	ProjectSettings.save()


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


func _addon_dir() -> String:
	return (get_script() as Script).resource_path.get_base_dir()


func _register_project_settings() -> void:
	for entry: Array in _settings():
		var setting_name: String = entry[0]
		if not ProjectSettings.has_setting(setting_name):
			ProjectSettings.set_setting(setting_name, entry[1])
		ProjectSettings.set_initial_value(setting_name, entry[1])
		ProjectSettings.add_property_info({
			"name": setting_name, "type": entry[2], "hint": entry[3], "hint_string": entry[4],
		})
