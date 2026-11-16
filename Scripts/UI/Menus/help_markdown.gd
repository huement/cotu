# res://Scripts/UI/Menus/help_markdown.gd
class_name HelpMarkdown
extends RefCounted
## Tiny "markdown" reader for help / info screens. Supports exactly two things:
##   # Title      -> a heading (## and ### also work, slightly smaller)
##   anything else -> paragraph text (line breaks are kept, blank lines separate paragraphs)
## Files are read at runtime, so edit the .md and reopen the screen to see changes.
##
## EXPORT NOTE: .md / .txt are not Godot resources. When you create an export preset,
## add  *.md, *.txt  to Resources > "Filters to export non-resource files/folders".

const TITLE_COLOR: String = "#61dbff"
const TITLE_SIZES: Array[int] = [24, 20, 18] # #, ##, ###


## Reads [param path] as text ("" plus a warning if it's missing).
static func read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		push_warning("HelpMarkdown: file not found: %s" % path)
		return ""
	return FileAccess.get_file_as_string(path)


## Splits the text into sections, one per heading:
## [{"title": "MOVEMENT", "level": 1, "body": "W step forward..."}, ...]
## Text before the first heading gets an empty title. Handy for tabs later.
static func parse(text: String) -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	var title: String = ""
	var title_level: int = 0
	var lines: PackedStringArray = [] # value type: kept in a local, not inside a Dictionary
	for raw_line: String in text.replace("\r", "").split("\n"):
		var line: String = raw_line.strip_edges(false, true)
		var level: int = _heading_level(line)
		if level > 0:
			_push_section(sections, title, title_level, lines)
			title = line.substr(level).strip_edges()
			title_level = level
			lines = []
		else:
			lines.append(line)
	_push_section(sections, title, title_level, lines)
	return sections


## Converts the text to BBCode for a RichTextLabel (bbcode_enabled = true).
static func to_bbcode(text: String) -> String:
	var parts: PackedStringArray = []
	for section: Dictionary in parse(text):
		var title: String = String(section["title"])
		if not title.is_empty():
			var size: int = TITLE_SIZES[clampi(int(section["level"]) - 1, 0, TITLE_SIZES.size() - 1)]
			parts.append("[font_size=%d][b][color=%s]%s[/color][/b][/font_size]" % [size, TITLE_COLOR, _escape(title)])
		var body: String = String(section["body"])
		if not body.is_empty():
			parts.append(_escape(body))
		parts.append("") # blank line between sections
	return "\n".join(parts).strip_edges()


## Reads [param path] and converts it straight to BBCode.
static func file_to_bbcode(path: String) -> String:
	return to_bbcode(read_file(path))


static func _heading_level(line: String) -> int:
	var level: int = 0
	while level < line.length() and line[level] == "#":
		level += 1
	# "# Title" (or "#Title") is a heading; a line that is only "#" is plain text.
	if level == 0 or level >= line.length():
		return 0
	return level


static func _push_section(sections: Array[Dictionary], title: String, level: int, lines: PackedStringArray) -> void:
	# Trim blank lines at the edges and collapse runs of blank lines into one.
	var cleaned: PackedStringArray = []
	var last_blank: bool = true
	for line: String in lines:
		var blank: bool = line.strip_edges().is_empty()
		if blank and last_blank:
			continue
		cleaned.append(line)
		last_blank = blank
	while not cleaned.is_empty() and cleaned[cleaned.size() - 1].strip_edges().is_empty():
		cleaned.remove_at(cleaned.size() - 1)
	var body: String = "\n".join(cleaned)
	if title.is_empty() and body.is_empty():
		return
	sections.append({"title": title, "level": level, "body": body})


## Stops "[" in the text from being read as a BBCode tag.
static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
