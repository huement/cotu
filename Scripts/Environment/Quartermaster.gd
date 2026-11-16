# res://Scripts/Environment/Quartermaster.gd
class_name Quartermaster
extends DungeonInteractable

## Field supply cache in FeroShaw until Sylvania Town ships. Opens ShopMenu.

@export var prompt_title: String = "Quartermaster"
@export_multiline var prompt_text: String = "A Guild-Corp supply crate hums with a low charge. Trade credits for gear?"
@export var stock_paths: Array[String] = []


func _ready() -> void:
	is_blocking = true
	super._ready()
	if not has_node("Mesh"):
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		var box := BoxMesh.new()
		box.size = Vector3(1.2, 1.0, 1.2)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.35, 0.28)
		mat.emission_enabled = true
		mat.emission = Color(0.0, 0.6, 0.45)
		mat.emission_energy_multiplier = 0.35
		mesh.material_override = mat
		mesh.position = Vector3(0, 0.5, 0)
		add_child(mesh)


func interact(_player: Node3D) -> void:
	if is_instance_valid(SignalBus):
		SignalBus.popup_requested.emit(&"CONFIRMATION", {
			"title": prompt_title,
			"message": prompt_text,
			"confirm_text": "Trade",
			"cancel_text": "Leave",
			"on_confirm": Callable(self, "_open_shop"),
		})


func _open_shop() -> void:
	var data: Dictionary = {}
	if not stock_paths.is_empty():
		data["stock_paths"] = stock_paths
	if is_instance_valid(SignalBus) and SignalBus.has_signal(&"shop_requested"):
		SignalBus.shop_requested.emit(data)
