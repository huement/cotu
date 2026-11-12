# res://Scripts/search_button.gd
extends "res://Scripts/UI/hud_toolbar_button.gd"
## SEARCH toolbar button. Sound, hover / press pop and shine live in hud_toolbar_button.gd.


func _init() -> void:
	action_type = "SEARCH"


func _activate() -> void:
	# Light blue edge flash for search scan feedback
	var bus: Node = get_tree().root.get_node_or_null(^"SignalBus")
	if is_instance_valid(bus) and bus.has_signal(&"edge_flash_requested"):
		bus.emit_signal(&"edge_flash_requested", Color("38b6ff"), 0.4)

	# Something right in front of the party? Interact with it instead of opening the popup.
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if is_instance_valid(player) and player.has_method("_try_interact_facing_tile"):
		var result: Variant = player.call("_try_interact_facing_tile")
		if result is bool and bool(result):
			return

	_request_popup()
