# res://Scripts/Utilities/mesh_library_recolor.gd
class_name MeshLibraryRecolor
extends RefCounted
## Makes a recoloured copy of a MeshLibrary whose tiles use flat-colour materials
## (like the Kenney nature kit). Materials are matched by their resource_name
## ("grass", "dirt", "water"...). The source library is never modified.


## Returns a copy of [param source] with every material named in [param palette]
## recoloured. Palette: { "grass": Color(...), "dirt": Color(...), ... }
static func recolor(source: MeshLibrary, palette: Dictionary) -> MeshLibrary:
	var result: MeshLibrary = MeshLibrary.new()
	var material_cache: Dictionary = {} # original material -> recoloured copy (keeps sharing)
	for id: int in source.get_item_list():
		result.create_item(id)
		result.set_item_name(id, source.get_item_name(id))
		result.set_item_mesh_transform(id, source.get_item_mesh_transform(id))
		result.set_item_mesh_cast_shadow(id, source.get_item_mesh_cast_shadow(id))
		result.set_item_shapes(id, source.get_item_shapes(id))
		result.set_item_navigation_mesh(id, source.get_item_navigation_mesh(id))
		result.set_item_navigation_mesh_transform(id, source.get_item_navigation_mesh_transform(id))
		result.set_item_preview(id, source.get_item_preview(id))
		var mesh: Mesh = source.get_item_mesh(id)
		if mesh != null:
			result.set_item_mesh(id, _recolor_mesh(mesh, palette, material_cache))
	return result


static func _recolor_mesh(mesh: Mesh, palette: Dictionary, cache: Dictionary) -> Mesh:
	var copy: Mesh = mesh.duplicate() as Mesh
	for surface: int in copy.get_surface_count():
		var material: Material = copy.surface_get_material(surface)
		var recolored: Material = _recolor_material(material, palette, cache)
		if recolored != material:
			copy.surface_set_material(surface, recolored)
	return copy


static func _recolor_material(material: Material, palette: Dictionary, cache: Dictionary) -> Material:
	var base: BaseMaterial3D = material as BaseMaterial3D
	if base == null or not palette.has(base.resource_name):
		return material
	if cache.has(base):
		return cache[base] as Material
	var copy: BaseMaterial3D = base.duplicate() as BaseMaterial3D
	copy.albedo_color = palette[base.resource_name] as Color
	cache[base] = copy
	return copy
