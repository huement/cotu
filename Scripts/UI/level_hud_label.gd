extends Label3D

@export var max_alpha: float = 0.5
@export var fade_in_time: float = 1.3
@export var fade_out_time: float = 1.5

var _tween: Tween

func _ready() -> void:
	modulate.a = 0.0
	outline_modulate.a = 0.0

## Longest line the banner shows; longer lines are word-wrapped (wider text runs off screen).
const MAX_LINE_CHARS: int = 12


func show_level_banner(banner_text: String) -> void:
	text = format_title(banner_text)
	
	if _tween and _tween.is_running():
		_tween.kill()
		
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", max_alpha, fade_in_time)
	_tween.tween_property(self, "outline_modulate:a", max_alpha * 0.8, fade_in_time)

func hide_level_banner() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
		
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, fade_out_time)
	_tween.tween_property(self, "outline_modulate:a", 0.0, fade_out_time)


## Trims stray spaces / empty lines, splits CamelCase names ("BrokenBoneMarshCave" -> "Broken Bone
## Marsh Cave") and word-wraps each line to MAX_LINE_CHARS.
static func format_title(raw: String) -> String:
	var camel := RegEx.new()
	camel.compile("(?<=[a-z0-9])(?=[A-Z])")
	var out: PackedStringArray = []
	for source_line: String in raw.split("\n"):
		var line: String = source_line.strip_edges().replace("_", " ")
		if line.is_empty():
			continue
		var current: String = ""
		for word: String in line.split(" ", false):
			var parts: PackedStringArray = [word]
			if word.length() > MAX_LINE_CHARS:
				parts = camel.sub(word, " ", true).split(" ", false)
			for part: String in parts:
				if current.is_empty():
					current = part
				elif current.length() + 1 + part.length() <= MAX_LINE_CHARS:
					current += " " + part
				else:
					out.append(current)
					current = part
		if not current.is_empty():
			out.append(current)
	return "\n".join(out)
