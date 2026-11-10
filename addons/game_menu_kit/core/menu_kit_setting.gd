class_name MenuKitSetting
extends RefCounted
## One line of the options menu: its key, label, widget, default value and,
## optionally, the function that applies it to the game.
##
## Settings are created through [MenuKitSettings], for example:
## [codeblock]
## MenuKit.settings.add_toggle("game/gore", "Show blood", true)
## MenuKit.settings.add_range("camera/zoom", "Camera distance", 6.0, 3.0, 12.0, 0.5, " m")
## [/codeblock]
## The part of the key before the slash is the options tab ("game", "camera"...).

## Widget used in the options menu.
enum Type {
	RANGE, ## Slider between [member min_value] and [member max_value].
	TOGGLE, ## On / off switch.
	CHOICE, ## Segmented buttons, for 2 to 4 short options.
	LIST, ## "‹ value ›" selector, for any number of options.
	BINDING, ## Keyboard / mouse and gamepad inputs of an InputMap action.
}

## Unique id, "section/name" (e.g. [code]"camera/fov"[/code]).
var key: String = ""
## Options tab the setting is shown in (the part of [member key] before the slash).
var section: String = ""
## Text shown in the menu (English, translated with [method Object.tr]).
var label: String = ""
var type: Type = Type.TOGGLE
var default_value: Variant = null
var min_value: float = 0.0
var max_value: float = 100.0
var step: float = 1.0
## Amount added by one left / right press on a slider. 0 = automatic (1/20 of the range).
var keyboard_step: float = 0.0
## Text shown after a slider value ([code]"%"[/code], [code]"°"[/code]...).
var unit: String = ""
## Labels of a CHOICE or LIST setting.
var options: PackedStringArray = PackedStringArray()
## Stored value of each option. Empty = the option index is stored.
var values: Array = []
## InputMap action of a BINDING setting.
var action: StringName = &""
## Hidden settings keep their value but are not shown in the menu.
var visible: bool = true
## Called with the new value when it changes, when settings load and on reset.
var apply: Callable = Callable()
## Optional: returns [code][labels: PackedStringArray, values: Array][/code] when the
## options depend on the machine (screen resolutions, installed languages...).
var options_provider: Callable = Callable()
## Optional: converts a slider value to the text shown next to it.
var formatter: Callable = Callable()


## Sets [member apply] and returns the setting, to chain calls.
func applies_with(callable: Callable) -> MenuKitSetting:
	apply = callable
	return self


## Rebuilds [member options] and [member values] from [member options_provider].
func refresh_options() -> void:
	if not options_provider.is_valid():
		return
	var result: Variant = options_provider.call()
	if result is Array and (result as Array).size() == 2:
		options = PackedStringArray((result as Array)[0])
		values = ((result as Array)[1] as Array).duplicate()


## Number of options of a CHOICE or LIST setting.
func get_option_count() -> int:
	return options.size()


## Stored value of the option at [param index].
func get_option_value(index: int) -> Variant:
	if values.is_empty():
		return index
	return values[clampi(index, 0, values.size() - 1)]


## Index of the option matching [param value], or -1.
func find_option(value: Variant) -> int:
	if values.is_empty():
		if value is int or value is float:
			var index: int = int(value)
			return index if index >= 0 and index < options.size() else -1
		return -1
	for i: int in values.size():
		if MenuKitSetting.values_equal(values[i], value):
			return i
	return -1


## Returns [param value] converted to the type this setting stores, or the default
## value when it cannot be used.
func sanitize(value: Variant) -> Variant:
	match type:
		Type.RANGE:
			if not (value is float or value is int):
				return default_value
			var number: float = clampf(float(value), min_value, max_value)
			if step > 0.0:
				number = clampf(snappedf(number - min_value, step) + min_value, min_value, max_value)
			return number
		Type.TOGGLE:
			if value is bool:
				return value
			if value is int or value is float:
				return float(value) != 0.0
			return default_value
		Type.CHOICE, Type.LIST:
			var index: int = find_option(value)
			if index == -1:
				return default_value
			return get_option_value(index)
	return value


## Text shown next to a slider.
func format_value(value: Variant) -> String:
	if formatter.is_valid():
		return String(formatter.call(value))
	var number: float = float(value) if (value is float or value is int) else 0.0
	var text: String
	if step >= 1.0 or is_zero_approx(step):
		text = str(roundi(number))
	else:
		var decimals: int = clampi(ceili(-log(step) / log(10.0) - 0.0001), 1, 3)
		text = String.num(number, decimals)
	return text + unit


## Amount changed by one left / right press.
func get_keyboard_step() -> float:
	if keyboard_step > 0.0:
		return keyboard_step
	var amount: float = (max_value - min_value) / 20.0
	if step > 0.0:
		amount = maxf(step, snappedf(amount, step))
	return amount


## Compares two stored values (numbers of different types count as equal).
static func values_equal(a: Variant, b: Variant) -> bool:
	var a_number: bool = a is int or a is float
	var b_number: bool = b is int or b is float
	if a_number and b_number:
		return is_equal_approx(float(a), float(b))
	if typeof(a) != typeof(b):
		return false
	return a == b
