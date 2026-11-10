extends RefCounted
## Built-in settings of the options menu.
##
## Settings marked "applied" change the game by themselves. The others only store
## the player's choice: read them in your code with
## [code]MenuKit.settings.get_value("camera/invert_y")[/code] or react to
## [signal MenuKit.setting_changed]. Hide the ones your game does not use with
## [code]MenuKit.settings.hide("camera/head_bob")[/code] or a whole tab with
## [code]MenuKit.settings.hide_section("camera")[/code].

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_VOICE: StringName = &"Voice"
const BUS_UI: StringName = &"UI"


static func register(_kit: Node, settings: MenuKitSettings, system: MenuKitSystem, sounds: MenuKitSounds) -> void:
	settings.add_section("video", "Video")
	settings.add_section("audio", "Audio")
	_add_video(settings, system)
	_add_audio(settings, system, sounds)


static func _add_video(settings: MenuKitSettings, system: MenuKitSystem) -> void:
	var desktop: bool = system.can_manage_window() or DisplayServer.get_name() == "headless"
	# Applied: window mode.
	settings.add_choice("video/display", "Display", ["Window", "Borderless", "Fullscreen"],
		MenuKitSystem.get_project_display_mode(), [0, 1, 2]) \
		.applies_with(func(value: Variant) -> void: system.set_display_mode(int(value)))
	# Applied: window size in windowed mode.
	var resolution: MenuKitSetting = MenuKitSetting.new()
	resolution.type = MenuKitSetting.Type.LIST
	resolution.options_provider = system.get_resolution_options
	settings.add("video/resolution", "Resolution", resolution, MenuKitSystem.get_project_window_size())
	resolution.apply = func(value: Variant) -> void:
		if value is Vector2i:
			system.set_resolution(value as Vector2i)
	# Applied.
	var vsync_default: bool = int(ProjectSettings.get_setting("display/window/vsync/vsync_mode", 1)) != 0
	settings.add_toggle("video/vsync", "VSync", vsync_default) \
		.applies_with(func(value: Variant) -> void: system.set_vsync(bool(value)))
	# Applied: Engine.max_fps.
	var fps_default: int = int(ProjectSettings.get_setting("application/run/max_fps", 0))
	var fps_values: Array = [30, 60, 120, 144, 0]
	settings.add_list("video/max_fps", "Frame rate limit", ["30", "60", "120", "144", "Unlimited"],
		fps_default if fps_values.has(fps_default) else 0, fps_values) \
		.applies_with(func(value: Variant) -> void: system.set_max_fps(int(value)))
	settings.add_choice("video/quality", "Quality", ["Low", "Mid", "High", "Ultra"], "high",
		["low", "medium", "high", "ultra"])
	var compatibility: bool = RenderingServer.get_rendering_device() == null
	# Applied: 3D resolution (Forward+ and Mobile renderers).
	settings.add_range("video/render_scale", "Render scale", 100.0, 50.0, 100.0, 5.0, "%") \
		.applies_with(func(value: Variant) -> void: system.set_render_scale(float(value)))
	# Applied: anti-aliasing of the 3D view.
	var aa_labels: PackedStringArray = ["Off", "FXAA", "MSAA 2×", "MSAA 4×", "TAA"]
	var aa_values: Array = [0, 1, 2, 3, 4]
	if compatibility:
		aa_labels = ["Off", "MSAA 2×", "MSAA 4×"]
		aa_values = [0, 2, 3]
	settings.add_list("video/antialiasing", "Anti-aliasing", aa_labels, _project_antialiasing(aa_values), aa_values) \
		.applies_with(func(value: Variant) -> void: system.set_antialiasing(int(value)))
	# Applied: screen filter.
	settings.add_range("video/brightness", "Brightness", 50.0, 0.0, 100.0) \
		.applies_with(func(value: Variant) -> void: system.set_brightness(float(value)))
	# Applied: FPS counter in the top-left corner.
	settings.add_toggle("video/show_fps", "Show FPS", false) \
		.applies_with(func(value: Variant) -> void: system.set_show_fps(bool(value)))
	if not desktop:
		settings.hide("video/display")
		settings.hide("video/resolution")
		settings.hide("video/vsync")
	if compatibility and Engine.get_version_info().hex < 0x040400:
		settings.hide("video/render_scale")


static func _add_audio(settings: MenuKitSettings, system: MenuKitSystem, sounds: MenuKitSounds) -> void:
	# Applied: volume of each audio bus (created if missing, sent to Master).
	_add_volume(settings, system, "audio/master", "Master", 100.0, BUS_MASTER)
	_add_volume(settings, system, "audio/music", "Music", 80.0, BUS_MUSIC)
	_add_volume(settings, system, "audio/effects", "Effects", 100.0, BUS_SFX)
	_add_volume(settings, system, "audio/voices", "Voices", 100.0, BUS_VOICE)
	_add_volume(settings, system, "audio/interface", "Interface", 70.0, BUS_UI)
	# Applied: the sound played when the cursor moves over a button.
	settings.add_toggle("audio/hover_sounds", "Hover sounds", true) \
		.applies_with(func(value: Variant) -> void: sounds.hover_enabled = bool(value))
	# Applied.
	settings.add_toggle("audio/mute_unfocused", "Mute in background", true) \
		.applies_with(func(value: Variant) -> void: system.set_mute_unfocused(bool(value)))


static func _add_volume(settings: MenuKitSettings, system: MenuKitSystem, key: String, label: String,
		default_value: float, bus: StringName) -> void:
	settings.add_range(key, label, default_value, 0.0, 100.0, 1.0, "%") \
		.applies_with(func(value: Variant) -> void: system.set_bus_volume(bus, float(value) / 100.0))


static func _project_antialiasing(allowed: Array) -> int:
	var result: int = 0
	if bool(ProjectSettings.get_setting("rendering/anti_aliasing/quality/use_taa", false)):
		result = 4
	elif int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0)) >= 2:
		result = 3
	elif int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0)) == 1:
		result = 2
	elif int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa", 0)) == 1:
		result = 1
	return result if allowed.has(result) else 0
