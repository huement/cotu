# res://Scripts/UI/Menus/loading_screen.gd
class_name LoadingScreen
extends CanvasLayer
## Full-screen loading overlay: black background, assets/loading_screen.png centred, a thin
## progress bar underneath. Loads the scene on a background thread, switches to it, then fades out.
##
## It lives on the tree root (not inside a scene), so it stays up while the old scene is swapped
## for the new one. If the scene is already in memory it switches straight away with no overlay.
## If loading fails it says so on screen and offers the main menu - exported builds give no other
## clue (change_scene_to_file just fails silently and leaves the old screen up).
##
## Use: LoadingScreen.change_scene(get_tree(), "res://Scenes/world.tscn")

const IMAGE_PATH: String = "res://assets/loading_screen.png"
## Largest share of the screen the image may take (it never grows past its own pixel size).
const MAX_SCREEN_SHARE: float = 0.8
const FADE_IN_SECONDS: float = 0.15
const FADE_OUT_SECONDS: float = 0.3
## Frames the new scene gets to run _ready and settle before the overlay fades away.
const SETTLE_FRAMES: int = 3
## Matches the "LOADING" lettering in the image.
const BAR_COLOR: Color = Color(0.79, 0.33, 0.45)
## Just under MenuKit's own layer (128: curtains, toasts); above every HUD / popup layer.
const LAYER: int = 127

static var _active: LoadingScreen = null

var _path: String = ""
var _root: Control = null
var _bar: ProgressBar = null
var _message: Label = null
var _menu_button: Button = null
var _finished: bool = false


## Opens the scene at `path`, behind the loading screen if it still has to be loaded.
static func change_scene(tree: SceneTree, path: String) -> void:
	if is_instance_valid(_active):
		return # a load is already under way
	tree.root.gui_release_focus()
	if ResourceLoader.has_cached(path):
		tree.change_scene_to_file.call_deferred(path)
		return
	var screen := LoadingScreen.new()
	screen._path = path
	_active = screen
	tree.root.add_child(screen)


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, FADE_IN_SECONDS)
	var err: Error = ResourceLoader.load_threaded_request(_path, "PackedScene")
	if err != OK:
		_fail("Couldn't start loading %s (error %d)." % [_path.get_file(), err])


func _process(_delta: float) -> void:
	if _finished:
		return
	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not progress.is_empty():
				_bar.value = float(progress[0]) * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			_finished = true
			_bar.value = 100.0
			_open(ResourceLoader.load_threaded_get(_path) as PackedScene)
		_:
			_fail("Couldn't load %s. A file it needs is missing from this build." % _path.get_file())


func _open(scene: PackedScene) -> void:
	if scene == null:
		_fail("%s loaded, but it isn't a scene." % _path.get_file())
		return
	var tree: SceneTree = get_tree()
	var err: Error = tree.change_scene_to_packed(scene)
	if err != OK:
		_fail("Couldn't open %s (error %d)." % [_path.get_file(), err])
		return
	for _i: int in SETTLE_FRAMES:
		await tree.process_frame
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, FADE_OUT_SECONDS)
	await tween.finished
	_close()


func _fail(text: String) -> void:
	_finished = true
	GameLogger.error("LoadingScreen: " + text)
	_root.modulate.a = 1.0
	_bar.hide()
	_message.text = text
	_message.show()
	_menu_button.show()
	_menu_button.grab_focus.call_deferred()


func _on_menu_pressed() -> void:
	_close()
	SessionFlow.quit_to_main_menu(get_tree())


func _close() -> void:
	if _active == self:
		_active = null
	queue_free()


# ==============================================================================
# Build
# ==============================================================================
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP # no clicks reach the old scene while loading
	add_child(_root)

	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var image_width: float = 360.0
	var texture: Texture2D = load(IMAGE_PATH) as Texture2D if ResourceLoader.exists(IMAGE_PATH) else null
	if texture != null:
		var view: Vector2 = get_viewport().get_visible_rect().size
		var tex_size: Vector2 = texture.get_size()
		var fit: float = minf(1.0, minf(view.x * MAX_SCREEN_SHARE / tex_size.x, view.y * MAX_SCREEN_SHARE / tex_size.y))
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # crisp pixel art
		image.custom_minimum_size = tex_size * fit
		box.add_child(image)
		image_width = tex_size.x * fit
	else:
		var fallback := Label.new()
		fallback.text = "NOW LOADING..."
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ShardsMenuStyle.style_title(fallback, 30)
		box.add_child(fallback)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(image_width * 0.45, 6.0)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	var fill := StyleBoxFlat.new()
	fill.bg_color = BAR_COLOR
	_bar.add_theme_stylebox_override("background", track)
	_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_bar)

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(image_width, 0.0)
	ShardsMenuStyle.style_body(_message, 15)
	_message.add_theme_color_override("font_color", ShardsMenuStyle.COLOR_DANGER)
	_message.hide()
	box.add_child(_message)

	_menu_button = ShardsMenuStyle.make_row_button("MAIN MENU")
	_menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_menu_button.custom_minimum_size = Vector2(220.0, 52.0)
	_menu_button.pressed.connect(_on_menu_pressed)
	_menu_button.hide()
	box.add_child(_menu_button)
