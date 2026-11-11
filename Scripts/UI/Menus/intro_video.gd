# res://Scripts/UI/Menus/intro_video.gd
class_name IntroVideo
extends Control
## Opening cinematic for a brand-new game (Scenes/GameMenus/IntroVideo.tscn).
## SessionFlow.start_new_game_with_roster() opens this scene; when the video ends (or the
## player skips it) the game world opens. The new-game save is already written by then
## (GameState.start_new_game_with_party), so quitting mid-video still Continues in GreenGrove.
##
## Skip: confirm / cancel / any mouse click or screen tap.

const VIDEO_PATH: String = "res://assets/intro.ogv"
const FADE_OUT_SECONDS: float = 0.4
## Ignore skip presses for a moment so the click that pressed "Start" can't skip the video.
const SKIP_GRACE_SECONDS: float = 0.5

## Scene opened after the video.
var next_scene: String = SessionFlow.GAME_SCENE

var _player: VideoStreamPlayer = null
var _frame: AspectRatioContainer = null
var _hint: Label = null
var _leaving: bool = false
var _age: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_instance_valid(AudioManager):
		AudioManager.stop_bgm()
		AudioManager.stop_level_sound()

	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var stream: VideoStream = load(VIDEO_PATH) as VideoStream if ResourceLoader.exists(VIDEO_PATH) else null
	if stream == null:
		push_warning("IntroVideo: could not load %s - skipping the intro." % VIDEO_PATH)
		_leave.call_deferred(false)
		return

	# Letterboxed: the video keeps its own shape on any window size.
	_frame = AspectRatioContainer.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.ratio = 2.0
	add_child(_frame)

	_player = VideoStreamPlayer.new()
	_player.stream = stream
	_player.expand = true
	_player.loop = false
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_player)
	_player.finished.connect(_on_video_finished)
	_player.play()
	_fit_to_video()

	_hint = Label.new()
	_hint.text = "Press any button to skip"
	_hint.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_right = -24.0
	_hint.offset_bottom = -16.0
	add_child(_hint)
	# Show the hint briefly, then get out of the way.
	var tween: Tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(_hint, "modulate:a", 0.7, 0.5)
	tween.tween_interval(3.0)
	tween.tween_property(_hint, "modulate:a", 0.0, 1.0)


func _process(delta: float) -> void:
	_age += delta


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _age < SKIP_GRACE_SECONDS:
		return
	var skip: bool = false
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		skip = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		skip = true
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		skip = true
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		_leave(true)


func _on_video_finished() -> void:
	_leave(true)


## Matches the letterbox frame to the real video size (known once playback has started).
func _fit_to_video() -> void:
	var texture: Texture2D = _player.get_video_texture()
	if texture == null:
		return
	var size_px: Vector2 = texture.get_size()
	if size_px.x > 0.0 and size_px.y > 0.0:
		_frame.ratio = size_px.x / size_px.y


func _leave(fade: bool) -> void:
	if _leaving:
		return
	_leaving = true
	if fade and is_instance_valid(_frame):
		var tween: Tween = create_tween()
		tween.tween_property(_frame, "modulate", Color.BLACK, FADE_OUT_SECONDS)
		await tween.finished
	if is_instance_valid(_player):
		_player.stop()
	MenuKit.change_scene(next_scene)
