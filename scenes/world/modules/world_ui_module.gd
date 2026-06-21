extends Node
class_name WorldUIModule

var _player
var _debug_panel: Control
var _grid_coords_label: Label
var _minimap_overlay: Control
var _btn_open_inventory: Button
var _btn_open_combat: Button
var _btn_open_town: Button
var _btn_close_overlay: Button
var _show_minimap := false


func configure(
		player,
		debug_panel: Control,
		grid_coords_label: Label,
		minimap_overlay: Control,
		btn_inventory: Button,
		btn_combat: Button,
		btn_town: Button,
		btn_close: Button) -> void:
	_player = player
	_debug_panel = debug_panel
	_grid_coords_label = grid_coords_label
	_minimap_overlay = minimap_overlay
	_btn_open_inventory = btn_inventory
	_btn_open_combat = btn_combat
	_btn_open_town = btn_town
	_btn_close_overlay = btn_close


func apply_debug_panel_visibility(show: bool) -> void:
	if _debug_panel != null:
		_debug_panel.visible = show


func apply_grid_coords_visibility(show: bool) -> void:
	if _grid_coords_label != null:
		_grid_coords_label.visible = show


func apply_minimap_visibility(show: bool) -> void:
	_show_minimap = show
	if _minimap_overlay != null:
		_minimap_overlay.visible = show


func toggle_minimap() -> bool:
	_show_minimap = not _show_minimap
	if _minimap_overlay != null:
		_minimap_overlay.visible = _show_minimap
	return _show_minimap


func refresh_coords(cell_hint: Vector2i = Vector2i.ZERO) -> void:
	if _grid_coords_label == null:
		return

	var coords := cell_hint
	if _player != null and _player.grid_state != null:
		coords = _player.grid_state.cell

	_grid_coords_label.text = "Grid X: %d  Y: %d" % [coords.x, coords.y]


func refresh_minimap(cell_hint: Vector2i, occupancy: GridOccupancyMap) -> void:
	if _minimap_overlay == null:
		return

	var coords := cell_hint
	var facing := GridDefinitions.Facing.NORTH
	if _player != null and _player.grid_state != null:
		coords = _player.grid_state.cell
		facing = _player.grid_state.facing

	if _minimap_overlay.has_method("set_occupancy"):
		_minimap_overlay.call("set_occupancy", occupancy)
	if _minimap_overlay.has_method("set_player_state"):
		_minimap_overlay.call("set_player_state", coords, facing)


func refresh_debug_buttons(overlay_open: bool) -> void:
	if _btn_open_inventory != null:
		_btn_open_inventory.disabled = overlay_open
	if _btn_open_combat != null:
		_btn_open_combat.disabled = overlay_open
	if _btn_open_town != null:
		_btn_open_town.disabled = overlay_open
	if _btn_close_overlay != null:
		_btn_close_overlay.disabled = not overlay_open
