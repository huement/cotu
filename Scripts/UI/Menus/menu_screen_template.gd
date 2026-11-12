# res://Scripts/UI/Menus/menu_screen_template.gd
class_name MenuScreenTemplate
extends Control
## Full-screen placeholder: title, subtitle, scrollable body and a Back button.
## Used by Help, Party Builder and About until they get real content. Works over
## the main menu and over the paused game (process mode Always).
##
## Make a new screen: right-click MenuScreenTemplate.tscn > New Inherited Scene,
## then fill the exported texts in the Inspector and add your content to %Body.

## Emitted when Back (or Esc / gamepad B) is pressed.
signal closed

@export var screen_title: String = "SCREEN TITLE"
@export var subtitle: String = ""
@export_multiline var body_text: String = ""
## Optional text / markdown file shown as the body instead of body_text
## ("# Title" lines become headings, everything else is paragraph text).
## Read every time the screen opens, so edits show up without restarting.
@export_file("*.md", "*.txt") var body_file: String = ""
## Frees the screen when it closes (otherwise it just hides).
@export var free_on_close: bool = true
## Adds a LOAD STARTER PARTY button to the header (Help screen): copies the ready-made characters
## in Data/StarterParty into the player's roster (CharacterRoster.add_starter_party).
@export var show_starter_party_button: bool = false

@export_group("Space Background")
## Animated pixel-art space behind the window (Scenes/UI/SpaceBackground.tscn) instead of a flat dim.
@export var space_background: bool = false
@export var space_preset: SpaceBackground.Preset = SpaceBackground.Preset.MAIN_MENU
## How dark the space gets behind the window (0 = none).
@export_range(0.0, 1.0, 0.05) var space_window_dim: float = 0.55
## Seconds of space before the window fades in.
@export_range(0.0, 2.0, 0.05) var window_intro_delay: float = 0.35

var _space: SpaceBackground = null
var _starter_button: Button = null

@onready var _panel: PanelContainer = %Panel as PanelContainer
@onready var _title_label: Label = %TitleLabel as Label
@onready var _subtitle_label: Label = %SubtitleLabel as Label
@onready var _body_label: RichTextLabel = %BodyLabel as RichTextLabel
@onready var _back_button: Button = %BackButton as Button
@onready var _divider: ColorRect = %Divider as ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.add_theme_stylebox_override("panel", ShardsMenuStyle.panel_box())
	ShardsMenuStyle.style_button(_back_button)
	_back_button.add_theme_constant_override("icon_max_width", 22)
	ShardsMenuStyle.style_title(_title_label, 32)
	ShardsMenuStyle.style_body(_subtitle_label, 14, true)
	ShardsMenuStyle.style_body(_body_label, 16)
	_divider.color = ShardsMenuStyle.COLOR_BORDER

	_title_label.text = screen_title
	_subtitle_label.text = subtitle
	_subtitle_label.visible = not subtitle.is_empty()
	_body_label.text = HelpMarkdown.file_to_bbcode(body_file) if not body_file.is_empty() else body_text

	_back_button.focus_neighbor_left = _back_button.get_path_to(_back_button)
	_back_button.focus_neighbor_right = _back_button.get_path_to(_back_button)
	_back_button.focus_neighbor_top = _back_button.get_path_to(_back_button)
	_back_button.focus_neighbor_bottom = _back_button.get_path_to(_back_button)
	_back_button.pressed.connect(close)
	if show_starter_party_button:
		_add_starter_party_button()
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()
	if space_background:
		_setup_space_background()


func _add_starter_party_button() -> void:
	_starter_button = ShardsMenuStyle.make_row_button("LOAD STARTER PARTY")
	_starter_button.custom_minimum_size = Vector2(230.0, 52.0)
	_starter_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_starter_button.tooltip_text = "Adds the ready-made starter characters to your roster."
	_back_button.get_parent().add_child(_starter_button)
	_starter_button.pressed.connect(_on_starter_party_pressed)
	# Left / right move between Back and this button; up / down stay put.
	_back_button.focus_neighbor_right = _back_button.get_path_to(_starter_button)
	_back_button.focus_neighbor_left = _back_button.get_path_to(_starter_button)
	_starter_button.focus_neighbor_left = _starter_button.get_path_to(_back_button)
	_starter_button.focus_neighbor_right = _starter_button.get_path_to(_back_button)
	_starter_button.focus_neighbor_top = _starter_button.get_path_to(_starter_button)
	_starter_button.focus_neighbor_bottom = _starter_button.get_path_to(_starter_button)


func _on_starter_party_pressed() -> void:
	if is_instance_valid(AudioManager) and AudioManager.has_method("play_ui_sound"):
		AudioManager.play_ui_sound("button-press")
	var added: int = CharacterRoster.add_starter_party()
	if added > 0:
		_starter_button.text = "ADDED %d TO ROSTER" % added
		_subtitle_label.text = "%d starter characters are now in your roster. Pick them under New Game." % added
	elif CharacterRoster.starter_party_size() > 0:
		_starter_button.text = "ALREADY IN ROSTER"
		_subtitle_label.text = "The starter characters are already in your roster."
	else:
		_starter_button.text = "NONE FOUND"
		_subtitle_label.text = "No starter characters ship with this build."
	_subtitle_label.visible = true
	_starter_button.disabled = true
	_back_button.grab_focus()


func _setup_space_background() -> void:
	_space = SpaceBackground.new()
	_space.name = "SpaceBackground"
	_space.preset = space_preset
	add_child(_space)
	move_child(_space, 0)
	var dim: ColorRect = get_node_or_null(^"Dim") as ColorRect
	if dim != null:
		dim.color.a = 0.15
	_panel.resized.connect(_focus_space_on_panel)
	get_viewport().size_changed.connect(_focus_space_on_panel)
	_focus_space_on_panel.call_deferred()
	# The window appears over the drifting space
	_panel.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_interval(window_intro_delay)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.35)


func _focus_space_on_panel() -> void:
	if is_instance_valid(_space) and space_window_dim > 0.0:
		_space.focus_on(_panel, space_window_dim, 0.06)


func open() -> void:
	show()


func close() -> void:
	if not visible:
		return
	if is_instance_valid(AudioManager) and AudioManager.has_method("play_ui_sound"):
		AudioManager.play_ui_sound("button-press")
	hide()
	closed.emit()
	if free_on_close:
		queue_free()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_visibility_changed() -> void:
	if visible and is_inside_tree():
		_back_button.grab_focus.call_deferred()
