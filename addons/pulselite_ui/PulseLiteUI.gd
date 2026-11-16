extends Node
## PulseLite UI SFX: drop-in sound player for Godot 4 (checked on Godot 4.7.2).
## Free-sample edition: lists only the 20 free files. The full pack's copy lists all 200.
##
## Setup:
##   1. Copy the sample's sounds/ folder into your project so that you get
##      e.g. res://addons/pulselite_ui/sounds/click/click_03.wav
##   2. Project > Project Settings > Globals > Autoload: add this script with
##      the name "PulseLiteUI".
##   3. Call PulseLiteUI.play("menu_confirm") from anywhere, or
##      PulseLiteUI.wire_buttons(self) in a scene's _ready() to give every
##      button hover / click / toggle sounds.
##
## Events (same names as ui_events.json): button_click, button_hover,
## toggle_on, toggle_off, menu_confirm, menu_back, error, notification,
## panel_open, panel_close, transition, coin_pickup, reward, level_up.
##
## No dependencies or plugins. This script is MIT (LICENSE_SCRIPTS.txt). The 20
## sounds are CC BY 4.0, attribution required (LICENSE_SOUNDS.txt).

## Folder that holds <category>/<file>.<extension>. Set before the first play().
var base_path: String = "res://addons/pulselite_ui/sounds/"
## "ogg" (smaller, good for web/mobile) or "wav".
var extension: String = "ogg"  # the free sample ships WAV; the full pack adds OGG
## Pick a random file from the event's list (false = always the recommended one).
var random_variation: bool = true
## Never play the same file twice in a row for one event (needs 2+ files).
var no_repeat: bool = true
## Random pitch change per play, +/- this fraction (0.03 = +/-3 %). Melodic
## events (notification, reward, level_up) are never pitch-shifted.
var pitch_jitter: float = 0.03
## Audio bus for all UI sounds; falls back to "Master" if the bus doesn't exist.
var bus: StringName = &"UI"
## Overall volume offset in dB (levels are already balanced between events).
var volume_db: float = 0.0
## Minimum time between two hover sounds, so fast mouse moves don't machine-gun.
var hover_cooldown_ms: int = 40

## Emitted after every sound, e.g. for debugging or subtitles.
signal played(event: StringName, path: String)

const VOICES := 8  # sounds that can overlap; the oldest voice is reused

# event -> [jitter allowed, [recommended, alternates...]]. Mirrors ui_events.json.
const EVENTS := {
	&"button_click": [true, ["click/click_03", "click/click_09"]],
	&"button_hover": [true, ["hover/hover_01", "hover/hover_05"]],
	&"toggle_on": [true, ["toggle/toggle_01"]],
	&"toggle_off": [true, ["toggle/toggle_02"]],
	&"menu_confirm": [true, ["confirm/confirm_05", "confirm/confirm_06"]],
	&"menu_back": [true, ["back_cancel/back_cancel_01"]],
	&"error": [true, ["error/error_01", "error/error_03"]],
	&"notification": [false, ["notify/notify_02", "notify/notify_05"]],
	&"panel_open": [true, ["panel_open/panel_open_04"]],
	&"panel_close": [true, ["panel_close/panel_close_05"]],
	&"transition": [true, ["whoosh/whoosh_06"]],
	&"coin_pickup": [true, ["coin/coin_01", "coin/coin_07"]],
	&"reward": [false, ["reward/reward_05"]],
	&"level_up": [false, ["level_up/level_up_01"]],
}

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}      # path -> AudioStream
var _available := {}  # event -> Array of paths that exist in the project
var _last := {}       # event -> path played last time
var _hover_ok_at := 0
var _auto_hover := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep UI sounds working while paused
	for _i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## Plays one sound for `event`. Returns the player used (or null).
func play(event: StringName, volume_offset_db: float = 0.0) -> AudioStreamPlayer:
	var files := _files_for(event)
	if files.is_empty():
		return null
	var path: String = files[0]
	if random_variation and files.size() > 1:
		var choices := files.duplicate()
		if no_repeat:
			choices.erase(_last.get(event, ""))
		path = choices[randi() % choices.size()]
	_last[event] = path
	var stream := _stream(path)
	if stream == null:
		return null
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.bus = bus if AudioServer.get_bus_index(bus) != -1 else &"Master"
	p.volume_db = volume_db + volume_offset_db
	var j: float = pitch_jitter if EVENTS[event][0] else 0.0
	p.pitch_scale = 1.0 + randf_range(-j, j)
	p.play()
	played.emit(event, path)
	return p


## Stops every PulseLite sound that is playing.
func stop_all() -> void:
	for p in _players:
		p.stop()


## Loads every available sound now (avoids a tiny hitch on first play).
func preload_all() -> void:
	for event in EVENTS:
		for path in _files_for(event):
			_stream(path)


## Gives every button under `root` (and `root` itself) sounds: hover on mouse-over
## and on keyboard/gamepad focus, button_click on press, toggle_on / toggle_off
## for toggle buttons (CheckBox, CheckButton, toggle_mode). Safe to call again.
## Per-button options via node metadata: "pulselite_event" (String) replaces
## button_click, e.g. "menu_back"; "pulselite_ignore" (bool) skips the button.
func wire_buttons(root: Node, hover: bool = true) -> void:
	if root is BaseButton:
		_wire(root, hover)
	for b in root.find_children("*", "BaseButton", true, false):
		_wire(b, hover)


## Wires every button now and every button added to the tree later.
func enable_auto_wire(hover: bool = true) -> void:
	_auto_hover = hover
	wire_buttons(get_tree().root, hover)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		_wire(n, _auto_hover)


func _wire(b: BaseButton, hover: bool) -> void:
	if b.has_meta(&"_pulselite_wired") or b.get_meta(&"pulselite_ignore", false):
		return
	b.set_meta(&"_pulselite_wired", true)
	if hover:
		b.mouse_entered.connect(_on_hover.bind(b, false))
		b.focus_entered.connect(_on_hover.bind(b, true))
	if b.toggle_mode:
		b.toggled.connect(_on_toggled)
	else:
		b.pressed.connect(_on_pressed.bind(b))


func _on_hover(b: BaseButton, from_focus: bool) -> void:
	# A mouse click also moves focus; don't add a hover sound to the click.
	if b.disabled or (from_focus and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		return
	var now := Time.get_ticks_msec()
	if now < _hover_ok_at:
		return
	_hover_ok_at = now + hover_cooldown_ms
	play(&"button_hover")


func _on_pressed(b: BaseButton) -> void:
	play(StringName(b.get_meta(&"pulselite_event", "button_click")))


func _on_toggled(on: bool) -> void:
	play(&"toggle_on" if on else &"toggle_off")


func _files_for(event: StringName) -> Array:
	if not EVENTS.has(event):
		push_warning("PulseLiteUI: unknown event '%s'" % event)
		return []
	if not _available.has(event):
		var found := []
		for entry in EVENTS[event][1]:
			var path := base_path.path_join("%s.%s" % [entry, extension])
			if ResourceLoader.exists(path):
				found.append(path)
		if found.is_empty():
			push_warning("PulseLiteUI: no files for '%s' under %s (check base_path / extension)" % [event, base_path])
		_available[event] = found
	return _available[event]


func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]
