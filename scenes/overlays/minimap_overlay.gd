class_name MinimapOverlay
extends Control

@export var radius_cells := 5
@export var cell_size_pixels := 10.0
@export var background_color := Color(0.06, 0.08, 0.10, 0.86)
@export var border_color := Color(0.82, 0.87, 0.93, 0.9)
@export var grid_color := Color(0.35, 0.42, 0.50, 0.45)
@export var blocked_color := Color(0.82, 0.26, 0.26, 0.9)
@export var player_color := Color(0.25, 0.92, 0.62, 0.95)
@export var facing_color := Color(1.0, 0.91, 0.44, 1.0)

var _player_cell := Vector2i.ZERO
var _player_facing := GridDefinitions.Facing.NORTH
var _occupancy: GridOccupancyMap


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_occupancy(occupancy: GridOccupancyMap) -> void:
	_occupancy = occupancy
	queue_redraw()


func set_player_state(cell: Vector2i, facing: GridDefinitions.Facing) -> void:
	_player_cell = cell
	_player_facing = facing
	queue_redraw()


func get_player_cell() -> Vector2i:
	return _player_cell


func get_player_facing() -> GridDefinitions.Facing:
	return _player_facing


func _draw() -> void:
	var draw_rect_area := Rect2(Vector2.ZERO, size)
	draw_rect(draw_rect_area, background_color, true)
	draw_rect(draw_rect_area, border_color, false, 2.0)

	var radius := maxi(radius_cells, 1)
	var cell_px := maxf(cell_size_pixels, 2.0)
	var center := draw_rect_area.size * 0.5
	var half_cell := Vector2.ONE * (cell_px * 0.5)

	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var local_center := center + Vector2(float(dx), float(dz)) * cell_px
			var rect := Rect2(local_center - half_cell, Vector2.ONE * cell_px)
			draw_rect(rect, grid_color, false, 1.0)

			if _occupancy != null:
				var sample_cell := _player_cell + Vector2i(dx, dz)
				if not _occupancy.is_passable(sample_cell):
					draw_rect(rect.grow(-1.0), blocked_color, true)

	var player_rect := Rect2(center - half_cell * 0.9, Vector2.ONE * cell_px * 0.9)
	draw_rect(player_rect, player_color, true)

	var facing := GridDefinitions.facing_to_vec2i(_player_facing)
	var facing_end := center + Vector2(float(facing.x), float(facing.y)) * (cell_px * 0.9)
	draw_line(center, facing_end, facing_color, 2.0)
