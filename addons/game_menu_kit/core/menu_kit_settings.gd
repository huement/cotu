class_name MenuKitSettings
extends RefCounted
## Every player setting of the options menu: registration, values and storage.
##
## Read a value anywhere in your game:
## [codeblock]
## var fov: float = MenuKit.settings.get_value("camera/fov")
## MenuKit.setting_changed.connect(func(key, value): if key == "camera/invert_y": ...)
## [/codeblock]
## Add your own settings (in [code]_ready()[/code] of an autoload, before the menu opens):
## [codeblock]
## MenuKit.settings.add_toggle("game/gore", "Show blood", true)
## MenuKit.settings.add_list("game/units", "Units", ["Metric", "Imperial"], "metric", ["metric", "imperial"])
## [/codeblock]
## Hide what your game does not need:
## [codeblock]
## MenuKit.settings.hide_section("camera")
## MenuKit.settings.hide("video/motion_blur")
## [/codeblock]
## Values are saved to [constant FILE_PATH] (a short moment after each change and
## when the options menu closes).

## Emitted after a value changes (also after a reset).
signal changed(key: String, value: Variant)
## Emitted after [method load_from_disk].
signal loaded

const FILE_PATH: String = "user://menu_kit_settings.cfg"
const FORMAT_VERSION: int = 1
const META_SECTION: String = "meta"

var file_path: String = FILE_PATH
var input: MenuKitInput

var _sections: Array[Dictionary] = []
var _settings: Dictionary = {}
var _keys: Array[String] = []
var _values: Dictionary = {}
var _dirty: bool = false


func _init(p_input: MenuKitInput) -> void:
	input = p_input
	input.bindings_changed.connect(_on_bindings_changed)


# --------------------------------------------------------------------------
# Sections (tabs of the options menu)
# --------------------------------------------------------------------------

## Adds a tab. Settings added with an unknown section create their tab automatically.
func add_section(id: String, label: String) -> void:
	if _find_section(id) != -1:
		return
	_sections.append({"id": id, "label": label, "visible": true})


## Shows or hides a whole tab.
func set_section_visible(id: String, visible: bool) -> void:
	var index: int = _find_section(id)
	if index != -1:
		_sections[index]["visible"] = visible


## Hides a whole tab ([code]"camera"[/code] in a 2D game, for example).
func hide_section(id: String) -> void:
	set_section_visible(id, false)


## Tabs that have at least one visible setting, in order: [code][{id, label}][/code].
func get_visible_sections() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for section: Dictionary in _sections:
		if bool(section["visible"]) and not get_settings_in(String(section["id"])).is_empty():
			result.append({"id": section["id"], "label": section["label"]})
	return result


## Label of a tab.
func get_section_label(id: String) -> String:
	var index: int = _find_section(id)
	return String(_sections[index]["label"]) if index != -1 else id.capitalize()


# --------------------------------------------------------------------------
# Registration
# --------------------------------------------------------------------------

## Slider. [param step] 0 means continuous.
func add_range(key: String, label: String, default_value: float, min_value: float = 0.0,
		max_value: float = 100.0, step: float = 1.0, unit: String = "") -> MenuKitSetting:
	var setting: MenuKitSetting = MenuKitSetting.new()
	setting.type = MenuKitSetting.Type.RANGE
	setting.min_value = min_value
	setting.max_value = max_value
	setting.step = step
	setting.unit = unit
	return add(key, label, setting, default_value)


## On / off switch.
func add_toggle(key: String, label: String, default_value: bool) -> MenuKitSetting:
	var setting: MenuKitSetting = MenuKitSetting.new()
	setting.type = MenuKitSetting.Type.TOGGLE
	return add(key, label, setting, default_value)


## Segmented buttons (2 to 4 short options). Stores [param values][i], or the index
## when [param values] is empty.
func add_choice(key: String, label: String, options: PackedStringArray, default_value: Variant = 0,
		values: Array = []) -> MenuKitSetting:
	var setting: MenuKitSetting = MenuKitSetting.new()
	setting.type = MenuKitSetting.Type.CHOICE
	setting.options = options
	setting.values = values
	return add(key, label, setting, default_value)


## "‹ value ›" selector. Stores [param values][i], or the index when [param values]
## is empty.
func add_list(key: String, label: String, options: PackedStringArray, default_value: Variant = 0,
		values: Array = []) -> MenuKitSetting:
	var setting: MenuKitSetting = MenuKitSetting.new()
	setting.type = MenuKitSetting.Type.LIST
	setting.options = options
	setting.values = values
	return add(key, label, setting, default_value)


## Rebinding line for an InputMap action (keyboard / mouse + gamepad).
func add_binding(action: StringName, section: String = "controls") -> MenuKitSetting:
	input.register_action(action)
	var setting: MenuKitSetting = MenuKitSetting.new()
	setting.type = MenuKitSetting.Type.BINDING
	setting.action = action
	var key: String = "%s/bind_%s" % [section, action]
	var is_new: bool = not _settings.has(key)
	add(key, "", setting, null)
	if is_new:
		# Keeps the key bindings together, above the other settings of the section.
		_keys.erase(key)
		var index: int = _keys.size()
		var seen_section: bool = false
		for i: int in _keys.size():
			var other: MenuKitSetting = _settings[_keys[i]] as MenuKitSetting
			if other.section != section:
				if seen_section:
					index = i
					break
				continue
			seen_section = true
			if other.type != MenuKitSetting.Type.BINDING:
				index = i
				break
		_keys.insert(index, key)
	return setting


## Registers a prepared [MenuKitSetting]. Replaces a setting that has the same key.
func add(key: String, label: String, setting: MenuKitSetting, default_value: Variant) -> MenuKitSetting:
	var slash: int = key.find("/")
	if slash <= 0:
		push_error("MenuKit: setting key \"%s\" must look like \"section/name\"." % key)
		return setting
	setting.key = key
	setting.section = key.substr(0, slash)
	setting.label = label
	setting.refresh_options()
	setting.default_value = default_value
	setting.default_value = setting.sanitize(default_value)
	if _find_section(setting.section) == -1:
		add_section(setting.section, setting.section.capitalize())
	if not _settings.has(key):
		_keys.append(key)
	_settings[key] = setting
	if setting.type != MenuKitSetting.Type.BINDING:
		_values[key] = setting.default_value
	return setting


## Removes a setting from the menu and from the saved file.
func remove(key: String) -> void:
	_settings.erase(key)
	_keys.erase(key)
	_values.erase(key)


## Hides a setting from the menu (its value still works).
func hide(key: String) -> void:
	var setting: MenuKitSetting = get_setting(key)
	if setting != null:
		setting.visible = false


## Shows a hidden setting again.
func show(key: String) -> void:
	var setting: MenuKitSetting = get_setting(key)
	if setting != null:
		setting.visible = true


## Moves [param key] right after [param after_key] in the menu.
func move_after(key: String, after_key: String) -> void:
	if not _keys.has(key) or not _keys.has(after_key) or key == after_key:
		return
	_keys.erase(key)
	_keys.insert(_keys.find(after_key) + 1, key)


func has(key: String) -> bool:
	return _settings.has(key)


func get_setting(key: String) -> MenuKitSetting:
	return _settings.get(key) as MenuKitSetting


## Visible settings of a tab, in order.
func get_settings_in(section: String, include_hidden: bool = false) -> Array[MenuKitSetting]:
	var result: Array[MenuKitSetting] = []
	for key: String in _keys:
		var setting: MenuKitSetting = _settings[key]
		if setting.section == section and (include_hidden or setting.visible):
			result.append(setting)
	return result


# --------------------------------------------------------------------------
# Values
# --------------------------------------------------------------------------

## Current value of a setting ([param fallback] for unknown keys).
func get_value(key: String, fallback: Variant = null) -> Variant:
	return _values.get(key, fallback)


## Changes a value, applies it and schedules a save.
func set_value(key: String, value: Variant) -> void:
	var setting: MenuKitSetting = get_setting(key)
	if setting == null or setting.type == MenuKitSetting.Type.BINDING:
		push_warning("MenuKit: unknown setting \"%s\"." % key)
		return
	var clean: Variant = setting.sanitize(value)
	if _values.has(key) and MenuKitSetting.values_equal(_values[key], clean):
		return
	_values[key] = clean
	_dirty = true
	_apply(setting)
	changed.emit(key, clean)


## Index of the selected option of a CHOICE or LIST setting.
func get_index(key: String) -> int:
	var setting: MenuKitSetting = get_setting(key)
	return setting.find_option(get_value(key)) if setting != null else -1


## Restores the defaults of one tab (every tab when [param section] is empty).
func reset(section: String = "") -> void:
	for key: String in _keys:
		var setting: MenuKitSetting = _settings[key]
		if not section.is_empty() and setting.section != section:
			continue
		if setting.type == MenuKitSetting.Type.BINDING:
			continue
		set_value(key, setting.default_value)
	var resets_bindings: bool = section.is_empty()
	for key: String in _keys:
		var setting: MenuKitSetting = _settings[key]
		if setting.type == MenuKitSetting.Type.BINDING and (section.is_empty() or setting.section == section):
			resets_bindings = true
	if resets_bindings:
		input.reset_all()
		_dirty = true


## Calls every [member MenuKitSetting.apply] with the current values.
func apply_all() -> void:
	for key: String in _keys:
		_apply(_settings[key])


func is_dirty() -> bool:
	return _dirty


## Writes every value (and the changed key bindings) to [member file_path].
func save_to_disk() -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(META_SECTION, "version", FORMAT_VERSION)
	for key: String in _keys:
		var setting: MenuKitSetting = _settings[key]
		if setting.type == MenuKitSetting.Type.BINDING:
			continue
		config.set_value(setting.section, key.substr(setting.section.length() + 1), _values[key])
	input.write(config)
	var error: Error = config.save(file_path)
	if error != OK:
		push_error("MenuKit: could not save %s (error %d)." % [file_path, error])
		return error
	_dirty = false
	return OK


## Reads [member file_path] (defaults when it does not exist) and applies everything.
func load_from_disk() -> void:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(file_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("MenuKit: %s is unreadable (error %d), using defaults." % [file_path, error])
	for key: String in _keys:
		var setting: MenuKitSetting = _settings[key]
		if setting.type == MenuKitSetting.Type.BINDING:
			continue
		var value: Variant = setting.default_value
		var name: String = key.substr(setting.section.length() + 1)
		if error == OK and config.has_section_key(setting.section, name):
			value = setting.sanitize(config.get_value(setting.section, name))
		_values[key] = value
	input.read(config if error == OK else null)
	apply_all()
	_dirty = false
	loaded.emit()


func _apply(setting: MenuKitSetting) -> void:
	if setting.apply.is_valid() and setting.type != MenuKitSetting.Type.BINDING:
		setting.apply.call(_values.get(setting.key))


func _find_section(id: String) -> int:
	for i: int in _sections.size():
		if String(_sections[i]["id"]) == id:
			return i
	return -1


func _on_bindings_changed(action: StringName) -> void:
	_dirty = true
	changed.emit("bindings/" + String(action), null)
