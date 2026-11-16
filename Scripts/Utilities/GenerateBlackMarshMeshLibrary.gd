# res://Scripts/Utilities/GenerateBlackMarshMeshLibrary.gd
@tool
extends EditorScript
## Builds the Black Marsh floor tiles: a recoloured copy of the Kenney nature
## library (same 55 tiles, same sizes and collision, new palette).
##
## Run it: open this script in the Script editor, then File > Run (Ctrl/Cmd+Shift+X).
## Tweak PALETTE and run again to regenerate. The source library is never changed.
## To make another area (e.g. a snowy or autumn set), copy this script, change
## OUTPUT_PATH and PALETTE.

const SOURCE_PATH: String = "res://resources/mesh_library/knature_mesh_library.tres"
const OUTPUT_PATH: String = "res://resources/mesh_library/blackmarsh_mesh_library.tres"

## Material name in the source library -> new colour.
## Original nature colours, for reference:
##   grass (0.45, 0.93, 0.87)  dirt (0.95, 0.74, 0.62)  dirtDark (0.86, 0.67, 0.56)
##   water (0.85, 0.98, 1.0)   stone (0.87, 0.95, 0.96)  stoneDark (0.80, 0.86, 0.87)
##   wood (1.0, 0.77, 0.65)    woodBark (0.95, 0.74, 0.62)  woodInner (0.98, 0.93, 0.87)
const PALETTE: Dictionary = {
	"grass": Color(0.36, 0.42, 0.26), # olive moss
	"dirt": Color(0.42, 0.33, 0.26), # peat
	"dirtDark": Color(0.33, 0.26, 0.21), # wet peat edges
	"water": Color(0.17, 0.23, 0.19), # murky swamp water
	"stone": Color(0.55, 0.60, 0.56), # mossy grey
	"stoneDark": Color(0.45, 0.50, 0.47),
	"wood": Color(0.55, 0.42, 0.33), # rotting boards
	"woodBark": Color(0.42, 0.32, 0.26),
	"woodInner": Color(0.65, 0.58, 0.48),
}


func _run() -> void:
	var source: MeshLibrary = load(SOURCE_PATH) as MeshLibrary
	if source == null:
		push_error("Black Marsh: couldn't load %s" % SOURCE_PATH)
		return
	var marsh: MeshLibrary = MeshLibraryRecolor.recolor(source, PALETTE)
	var err: Error = ResourceSaver.save(marsh, OUTPUT_PATH)
	if err != OK:
		push_error("Black Marsh: save failed (%d)" % err)
		return
	EditorInterface.get_resource_filesystem().scan()
	print("Black Marsh: saved %d tiles to %s" % [marsh.get_item_list().size(), OUTPUT_PATH])
