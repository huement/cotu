extends Area3D

@export_multiline var level_title: String = "Dungeon\nLevel 01"
@export var trigger_once: bool = true
@export var trigger_sound: AudioStream

var _has_triggered: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if trigger_once and _has_triggered:
		return
		
	var hud = body.find_child("LevelHUDLabel", true, false)
	if hud and hud.has_method("show_level_banner"):
		hud.show_level_banner(level_title)
		_has_triggered = true
		
		# Play audio effect if assigned in Inspector
		if trigger_sound:
			_play_trigger_sound()

func _on_body_exited(body: Node3D) -> void:
	var hud = body.find_child("LevelHUDLabel", true, false)
	if hud and hud.has_method("hide_level_banner"):
		hud.hide_level_banner()

func _play_trigger_sound() -> void:
	var audio_player := AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.stream = trigger_sound
	audio_player.play()
	# Automatically remove the audio node when finished playing
	audio_player.finished.connect(audio_player.queue_free)
