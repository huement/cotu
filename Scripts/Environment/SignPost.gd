# res://Scripts/Environment/SignPost.gd
class_name SignPost
extends DungeonInteractable
## Road sign (Scenes/Environment/SignPost.tscn).
## Face the post and press interact to open a message box.
## Set `title` and `text` on each instance in the inspector.

## Header on the message box.
@export var title: String = "SIGN"
## Body of the message. Line breaks are kept.
@export_multiline var text: String = "The letters have worn away."
## Label on the button that closes the message.
@export var button_text: String = "OK"


func _ready() -> void:
	# Base class registers the sign on its grid cell and snaps it to that cell.
	# Leave is_blocking on so the party reads it from the tile in front.
	super._ready()


func interact(_player: Node3D) -> void:
	if not is_instance_valid(SignalBus):
		return
	var body: String = text.strip_edges()
	if body.is_empty():
		body = "..."
	SignalBus.popup_requested.emit(&"LORE_POPUP", {
		"title": title,
		"body": body,
		"button_text": button_text,
		"aura_type": "none",
		"object_id": object_id,
	})
