extends Camera3D
class_name MinimapCamera

## The Space Cat squad leader node to track from orbit.
@export var player_target: Node3D

## High-altitude layout clearance to peer over corridor walls.
@export var altitude: float = 15.0

func _ready() -> void:
	# Fallback safety: Look for the player node safely via the running scene tree root
	if not player_target:
		player_target = get_tree().root.get_node_or_null("World/Player") as Node3D
		
	if not player_target:
		push_warning("MinimapCamera: Feline target acquisition failed. Please assign Player in Inspector.")

func _physics_process(_delta: float) -> void:
	if not player_target:
		return
		
	# Bind the overhead camera's X and Z to the player, maintaining static altitude
	global_position = Vector3(
		player_target.global_position.x,
		player_target.global_position.y + altitude,
		player_target.global_position.z
	)
